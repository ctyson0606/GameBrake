namespace GameBrake.Core.Tests;

/// <summary>
/// Every acceptance criterion that is about the cooldown policy rather than about
/// Windows is settled here: no real process, no Windows API, and no test that
/// waits out a duration it is asserting on (AC10).
/// </summary>
public class ReducerTests
{
    private static readonly DateTimeOffset T0 = new(2026, 8, 23, 10, 0, 0, TimeSpan.Zero);
    private static readonly CooldownConfig Config = CooldownConfig.Default;
    private const string Game = @"C:\Program Files\Foo\game.exe";
    private const int Pid = 4242;

    private static readonly TimeSpan Cooldown = Config.Cooldown;
    private static readonly TimeSpan Grace = Config.GraceWindow;

    private static (AppState State, BrakeAction Action) Launch(AppState state, DateTimeOffset now, int pid = Pid) =>
        Reducer.Reduce(state, new BrakeEvent.LaunchAttempt(now, Game, pid), Config);

    private static (AppState State, BrakeAction Action) Tick(AppState state, DateTimeOffset now) =>
        Reducer.Reduce(state, new BrakeEvent.Tick(now), Config);

    private static (AppState State, BrakeAction Action) Exited(AppState state, DateTimeOffset now) =>
        Reducer.Reduce(state, new BrakeEvent.ProcessExited(now, Game), Config);

    // --- charging the cooldown ------------------------------------------------

    [Fact] // AC1
    public void First_launch_is_terminated_and_starts_the_cooldown()
    {
        var (state, action) = Launch(AppState.Idle, T0);

        Assert.Equal(new BrakeAction.Terminate(Pid), action);
        Assert.Equal(Phase.Cooling, state.Phase);
        Assert.Equal(T0 + Cooldown, state.CooldownEndsAt);
    }

    [Fact] // AC2
    public void Retrying_during_the_cooldown_is_terminated_and_does_not_move_the_deadline()
    {
        var cooling = Launch(AppState.Idle, T0).State;

        var (afterFirstRetry, firstAction) = Launch(cooling, T0 + TimeSpan.FromSeconds(30), pid: 99);
        var (afterSecondRetry, secondAction) = Launch(afterFirstRetry, T0 + TimeSpan.FromSeconds(60), pid: 100);

        Assert.Equal(new BrakeAction.Terminate(99), firstAction);
        Assert.Equal(new BrakeAction.Terminate(100), secondAction);
        Assert.Equal(T0 + Cooldown, afterSecondRetry.CooldownEndsAt);
        Assert.Equal(Phase.Cooling, afterSecondRetry.Phase);
    }

    [Fact]
    public void Cooldown_does_not_expire_one_second_early()
    {
        var cooling = Launch(AppState.Idle, T0).State;

        var state = Tick(cooling, T0 + Cooldown - TimeSpan.FromSeconds(1)).State;

        Assert.Equal(Phase.Cooling, state.Phase);
    }

    // --- serving it out ------------------------------------------------------

    [Fact]
    public void Cooldown_expires_into_a_time_limited_permission()
    {
        var cooling = Launch(AppState.Idle, T0).State;

        var state = Tick(cooling, T0 + Cooldown).State;

        Assert.Equal(Phase.Unlocked, state.Phase);
        Assert.Equal(T0 + Cooldown + Grace, state.GraceEndsAt);
    }

    [Fact] // AC3
    public void Launch_inside_the_grace_window_is_allowed_and_runs()
    {
        var unlocked = Tick(Launch(AppState.Idle, T0).State, T0 + Cooldown).State;

        var (state, action) = Launch(unlocked, T0 + Cooldown + TimeSpan.FromSeconds(10));

        Assert.IsType<BrakeAction.Allow>(action);
        Assert.Equal(Phase.Running, state.Phase);
    }

    [Fact] // N4
    public void A_permitted_session_is_never_interrupted()
    {
        var running = Launch(
            Tick(Launch(AppState.Idle, T0).State, T0 + Cooldown).State,
            T0 + Cooldown).State;

        var (state, action) = Tick(running, T0 + TimeSpan.FromHours(9));

        Assert.Equal(Phase.Running, state.Phase);
        Assert.IsType<BrakeAction.None>(action);
    }

    // --- the two criteria that assert something does NOT happen --------------

    [Fact] // AC4
    public void A_lapsed_grace_window_costs_a_full_cooldown_again()
    {
        var unlocked = Tick(Launch(AppState.Idle, T0).State, T0 + Cooldown).State;
        var lapsedAt = T0 + Cooldown + Grace;

        var idle = Tick(unlocked, lapsedAt).State;
        var (state, action) = Launch(idle, lapsedAt);

        Assert.Equal(Phase.Idle, idle.Phase);
        Assert.Equal(new BrakeAction.Terminate(Pid), action);
        Assert.Equal(lapsedAt + Cooldown, state.CooldownEndsAt);
    }

    [Fact] // AC7, the half of it the reducer owns
    public void A_state_restored_mid_cooldown_still_owes_the_remainder()
    {
        // What Store would hand back after the tool, or Windows, restarted.
        var restored = new AppState(Phase.Cooling, T0 + Cooldown, GraceEndsAt: null);
        var restartedAt = T0 + TimeSpan.FromSeconds(120);

        var (state, action) = Launch(restored, restartedAt);

        Assert.Equal(new BrakeAction.Terminate(Pid), action);
        Assert.Equal(Phase.Cooling, state.Phase);
        Assert.Equal(T0 + Cooldown, state.CooldownEndsAt);
    }

    // --- traps ---------------------------------------------------------------

    [Fact]
    public void The_exit_of_a_process_we_just_terminated_does_not_clear_the_cooldown()
    {
        // Terminating a launch produces an exit event of its own. Treating that as
        // the end of a session would refund the cooldown the moment it was charged.
        var (cooling, _) = Launch(AppState.Idle, T0);

        var (state, action) = Exited(cooling, T0 + TimeSpan.FromMilliseconds(50));

        Assert.Equal(Phase.Cooling, state.Phase);
        Assert.Equal(T0 + Cooldown, state.CooldownEndsAt);
        Assert.IsType<BrakeAction.None>(action);
    }

    [Fact] // AC5
    public void Quitting_and_relaunching_is_charged_a_fresh_cooldown()
    {
        var running = Launch(
            Tick(Launch(AppState.Idle, T0).State, T0 + Cooldown).State,
            T0 + Cooldown).State;
        var quitAt = T0 + TimeSpan.FromHours(3);

        var idle = Exited(running, quitAt).State;
        var (state, action) = Launch(idle, quitAt);

        Assert.Equal(Phase.Idle, idle.Phase);
        Assert.Equal(new BrakeAction.Terminate(Pid), action);
        Assert.Equal(quitAt + Cooldown, state.CooldownEndsAt);
    }

    [Fact]
    public void The_grace_window_is_anchored_to_the_deadline_not_to_when_it_was_noticed()
    {
        // The machine slept through the cooldown and woke a minute after it ended.
        var cooling = Launch(AppState.Idle, T0).State;
        var wokeAt = T0 + Cooldown + TimeSpan.FromSeconds(60);

        var state = Tick(cooling, wokeAt).State;

        Assert.Equal(Phase.Unlocked, state.Phase);
        Assert.Equal(T0 + Cooldown + Grace, state.GraceEndsAt);
        Assert.NotEqual(wokeAt + Grace, state.GraceEndsAt);
    }

    [Fact]
    public void Sleeping_past_both_deadlines_lands_back_at_idle_owing_a_full_cooldown()
    {
        var cooling = Launch(AppState.Idle, T0).State;
        var wokeAt = T0 + TimeSpan.FromDays(1);

        var (state, action) = Launch(cooling, wokeAt);

        Assert.Equal(new BrakeAction.Terminate(Pid), action);
        Assert.Equal(Phase.Cooling, state.Phase);
        Assert.Equal(wokeAt + Cooldown, state.CooldownEndsAt);
    }

    [Fact]
    public void A_launch_is_judged_against_the_clock_not_against_the_last_tick()
    {
        // No Tick is ever delivered here. A launch landing between two ticks must
        // still be judged against a cooldown that has in fact expired.
        var cooling = Launch(AppState.Idle, T0).State;

        var (state, action) = Launch(cooling, T0 + Cooldown + TimeSpan.FromSeconds(1));

        Assert.IsType<BrakeAction.Allow>(action);
        Assert.Equal(Phase.Running, state.Phase);
    }
}
