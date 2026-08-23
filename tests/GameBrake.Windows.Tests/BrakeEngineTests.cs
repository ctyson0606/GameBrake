using GameBrake.Core;
using GameBrake.Core.Storage;
using GameBrake.Windows;

namespace GameBrake.Windows.Tests;

/// <summary>
/// The wiring, with a fake watcher and a clock under the test. Forgetting to save
/// state, forgetting to follow a permitted process, or acting on an application
/// nobody protected are engine faults, and none of them need a real game to catch.
/// </summary>
public sealed class BrakeEngineTests : IDisposable
{
    private static readonly DateTimeOffset T0 = new(2026, 8, 23, 10, 0, 0, TimeSpan.Zero);
    private static readonly Guid AppId = Guid.Parse("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee");
    private const string Game = @"C:\Games\Foo\game.exe";
    private const string Other = @"C:\Tools\editor.exe";

    private readonly string _directory =
        Path.Combine(Path.GetTempPath(), "gamebrake-engine-" + Guid.NewGuid().ToString("N"));

    public BrakeEngineTests() => Directory.CreateDirectory(_directory);

    public void Dispose() => Directory.Delete(_directory, recursive: true);

    private StateStore NewStore() => new(Path.Combine(_directory, "state.json"));

    private static Configuration Config => Configuration.Default with
    {
        Protected = [new ProtectedApp(AppId, Game, "Foo", Enabled: true)],
    };

    private sealed class FakeClock(DateTimeOffset now) : TimeProvider
    {
        public DateTimeOffset Now { get; set; } = now;

        public override DateTimeOffset GetUtcNow() => Now;
    }

    private sealed class FakeWatcher : IProcessWatcher
    {
        public event EventHandler<BrakeEvent>? Observed;

        public bool Started { get; private set; }

        public List<(int Pid, string Path)> Followed { get; } = [];

        public void Start() => Started = true;

        public void WatchForExit(int processId, string executablePath) =>
            Followed.Add((processId, executablePath));

        public void Raise(BrakeEvent observed) => Observed?.Invoke(this, observed);

        public void Dispose()
        {
        }
    }

    private sealed class FakeTerminator : IProcessTerminator
    {
        public List<int> Killed { get; } = [];

        public bool Succeeds { get; set; } = true;

        public bool Terminate(int processId, TimeSpan? timeout = null)
        {
            Killed.Add(processId);
            return Succeeds;
        }
    }

    private (BrakeEngine Engine, FakeWatcher Watcher, FakeTerminator Terminator, FakeClock Clock, StateStore Store)
        Build()
    {
        var watcher = new FakeWatcher();
        var terminator = new FakeTerminator();
        var clock = new FakeClock(T0);
        var store = NewStore();
        return (new BrakeEngine(Config, store, watcher, terminator, clock), watcher, terminator, clock, store);
    }

    [Fact] // AC1, the wiring half
    public void A_protected_launch_is_terminated_and_the_cooldown_is_written_to_disk()
    {
        var (engine, watcher, terminator, _, store) = Build();
        using var _engine = engine;

        watcher.Raise(new BrakeEvent.LaunchAttempt(T0, Game, 4242));

        Assert.Equal([4242], terminator.Killed);
        Assert.Equal(Phase.Cooling, store.Load()[AppId].Phase);
        Assert.Equal(T0 + TimeSpan.FromSeconds(300), store.Load()[AppId].CooldownEndsAt);
    }

    [Fact] // G4, AC6
    public void An_unprotected_launch_is_not_touched_and_writes_nothing()
    {
        var (engine, watcher, terminator, _, store) = Build();
        using var _engine = engine;

        watcher.Raise(new BrakeEvent.LaunchAttempt(T0, Other, 4242));

        Assert.Empty(terminator.Killed);
        Assert.Empty(store.Load());
    }

    [Fact]
    public void A_disabled_entry_is_left_alone()
    {
        var watcher = new FakeWatcher();
        var terminator = new FakeTerminator();
        using var engine = new BrakeEngine(
            Config with { Protected = [new ProtectedApp(AppId, Game, "Foo", Enabled: false)] },
            NewStore(),
            watcher,
            terminator,
            new FakeClock(T0));

        watcher.Raise(new BrakeEvent.LaunchAttempt(T0, Game, 4242));

        Assert.Empty(terminator.Killed);
    }

    [Fact] // AC2
    public void Retrying_during_the_cooldown_is_terminated_again_without_moving_the_deadline()
    {
        var (engine, watcher, terminator, _, store) = Build();
        using var _engine = engine;

        watcher.Raise(new BrakeEvent.LaunchAttempt(T0, Game, 1));
        watcher.Raise(new BrakeEvent.LaunchAttempt(T0 + TimeSpan.FromSeconds(30), Game, 2));

        Assert.Equal([1, 2], terminator.Killed);
        Assert.Equal(T0 + TimeSpan.FromSeconds(300), store.Load()[AppId].CooldownEndsAt);
    }

    [Fact] // AC3, and the follow that AC5 depends on
    public void A_permitted_launch_is_left_running_and_followed()
    {
        var (engine, watcher, terminator, clock, store) = Build();
        using var _engine = engine;

        watcher.Raise(new BrakeEvent.LaunchAttempt(T0, Game, 1));
        var afterCooldown = T0 + TimeSpan.FromSeconds(300);
        clock.Now = afterCooldown;
        watcher.Raise(new BrakeEvent.LaunchAttempt(afterCooldown, Game, 2));

        Assert.Equal([1], terminator.Killed);
        Assert.Equal([(2, Game)], watcher.Followed);
        Assert.Equal(Phase.Running, store.Load()[AppId].Phase);
    }

    [Fact] // AC5
    public void Quitting_returns_to_idle_so_the_next_launch_is_charged_again()
    {
        var (engine, watcher, terminator, clock, store) = Build();
        using var _engine = engine;

        watcher.Raise(new BrakeEvent.LaunchAttempt(T0, Game, 1));
        var afterCooldown = T0 + TimeSpan.FromSeconds(300);
        watcher.Raise(new BrakeEvent.LaunchAttempt(afterCooldown, Game, 2));

        var quitAt = afterCooldown + TimeSpan.FromHours(2);
        watcher.Raise(new BrakeEvent.ProcessExited(quitAt, Game));
        Assert.Equal(Phase.Idle, store.Load()[AppId].Phase);

        watcher.Raise(new BrakeEvent.LaunchAttempt(quitAt, Game, 3));

        Assert.Equal([1, 3], terminator.Killed);
        Assert.Equal(quitAt + TimeSpan.FromSeconds(300), store.Load()[AppId].CooldownEndsAt);
    }

    [Fact] // AC8
    public void A_refused_launch_says_so_and_says_how_long_is_left()
    {
        var (engine, watcher, _, _, _) = Build();
        using var _engine = engine;
        BlockedLaunch? announced = null;
        engine.Blocked += (_, blocked) => announced = blocked;

        watcher.Raise(new BrakeEvent.LaunchAttempt(T0, Game, 4242));

        Assert.NotNull(announced);
        Assert.Equal("Foo", announced.App.DisplayName);
        Assert.Equal(TimeSpan.FromSeconds(300), announced.Remaining);
    }

    [Fact]
    public void A_termination_that_did_not_take_is_reported_rather_than_announced_as_a_block()
    {
        var (engine, watcher, terminator, _, _) = Build();
        using var _engine = engine;
        terminator.Succeeds = false;
        var blocked = 0;
        ProtectedApp? failed = null;
        engine.Blocked += (_, _) => blocked++;
        engine.TerminationFailed += (_, app) => failed = app;

        watcher.Raise(new BrakeEvent.LaunchAttempt(T0, Game, 4242));

        Assert.Equal(0, blocked);
        Assert.NotNull(failed);
    }

    [Fact] // AC8
    public void Remaining_time_counts_down_without_any_event_arriving()
    {
        var (engine, watcher, _, clock, _) = Build();
        using var _engine = engine;
        watcher.Raise(new BrakeEvent.LaunchAttempt(T0, Game, 1));

        clock.Now = T0 + TimeSpan.FromSeconds(120);

        var status = Assert.Single(engine.Status());
        Assert.Equal(Phase.Cooling, status.State.Phase);
        Assert.Equal(TimeSpan.FromSeconds(180), status.Remaining);
    }

    [Fact] // AC4
    public void A_lapsed_grace_window_shows_as_idle_and_costs_a_full_cooldown_again()
    {
        var (engine, watcher, terminator, clock, _) = Build();
        using var _engine = engine;
        watcher.Raise(new BrakeEvent.LaunchAttempt(T0, Game, 1));

        var lapsed = T0 + TimeSpan.FromSeconds(300 + 300);
        clock.Now = lapsed;
        engine.Tick();

        Assert.Equal(Phase.Idle, Assert.Single(engine.Status()).State.Phase);

        watcher.Raise(new BrakeEvent.LaunchAttempt(lapsed, Game, 2));

        Assert.Equal([1, 2], terminator.Killed);
    }

    [Fact] // AC7, the wiring half
    public void A_new_engine_over_the_same_file_still_owes_what_the_last_one_charged()
    {
        var (engine, watcher, _, _, _) = Build();
        watcher.Raise(new BrakeEvent.LaunchAttempt(T0, Game, 1));
        engine.Dispose();

        // A fresh process, reading nothing but the file.
        var restartedAt = T0 + TimeSpan.FromSeconds(120);
        var secondWatcher = new FakeWatcher();
        var secondTerminator = new FakeTerminator();
        using var restarted = new BrakeEngine(
            Config, NewStore(), secondWatcher, secondTerminator, new FakeClock(restartedAt));

        secondWatcher.Raise(new BrakeEvent.LaunchAttempt(restartedAt, Game, 2));

        Assert.Equal([2], secondTerminator.Killed);
        Assert.Equal(TimeSpan.FromSeconds(180), Assert.Single(restarted.Status()).Remaining);
    }

    [Fact] // G3
    public void An_edited_configuration_does_not_discharge_what_was_already_owed()
    {
        var (engine, watcher, terminator, clock, _) = Build();
        using var _engine = engine;
        watcher.Raise(new BrakeEvent.LaunchAttempt(T0, Game, 1));

        // The user renames the entry and adds another. Same id, so same debt.
        engine.Reconfigure(Config with
        {
            Protected =
            [
                new ProtectedApp(AppId, Game, "Foo renamed", Enabled: true),
                new ProtectedApp(Guid.NewGuid(), Other, "Editor", Enabled: true),
            ],
        });

        clock.Now = T0 + TimeSpan.FromSeconds(120);
        var status = engine.Status().Single(s => s.App.Id == AppId);

        Assert.Equal("Foo renamed", status.App.DisplayName);
        Assert.Equal(Phase.Cooling, status.State.Phase);
        Assert.Equal(TimeSpan.FromSeconds(180), status.Remaining);
    }

    [Fact]
    public void Starting_the_engine_starts_the_watcher()
    {
        var (engine, watcher, _, _, _) = Build();
        using var _engine = engine;

        engine.Start();

        Assert.True(watcher.Started);
    }
}
