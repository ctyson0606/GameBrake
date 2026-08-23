namespace GameBrake.Core;

/// <summary>
/// The whole of the cooldown policy, as a pure function. No I/O, no clock, no
/// Windows. This project targets plain net10.0 rather than net10.0-windows so
/// that staying that way is enforced by the compiler and not by discipline.
/// </summary>
public static class Reducer
{
    /// <summary>
    /// Fold one observation into one application state.
    /// </summary>
    public static (AppState State, BrakeAction Action) Reduce(
        AppState state,
        BrakeEvent evt,
        CooldownConfig config)
    {
        // Expiries are settled before the event is looked at, so a decision never
        // depends on a Tick having arrived punctually. Without this, a launch that
        // lands in the gap between two ticks would be judged against a deadline
        // that has already passed, and a machine asleep across the whole cooldown
        // would wake still holding it.
        var current = Advance(state, evt.Now, config);

        return evt switch
        {
            BrakeEvent.Tick => (current, BrakeAction.None.Instance),
            BrakeEvent.LaunchAttempt launch => OnLaunchAttempt(current, launch, config),
            BrakeEvent.ProcessExited => OnProcessExited(current),
            _ => (current, BrakeAction.None.Instance),
        };
    }

    /// <summary>
    /// Carry a state forward to <paramref name="now"/> by applying whatever
    /// deadlines have passed.
    /// </summary>
    public static AppState Advance(AppState state, DateTimeOffset now, CooldownConfig config)
    {
        // Loops rather than tests once: a reboot or a long sleep can carry the clock
        // past the cooldown and the grace window together, and a state that stopped
        // at the first of them would hand out a permission nobody was present to use.
        while (true)
        {
            switch (state.Phase)
            {
                case Phase.Cooling when state.CooldownEndsAt is { } cooldownEnd && now >= cooldownEnd:
                    // The grace window is measured from the cooldown deadline, never
                    // from the moment the expiry was noticed. Anchoring it to
                    // observation time would let sleeping through a cooldown stretch
                    // the window by however long the machine was away.
                    state = new AppState(
                        Phase.Unlocked,
                        CooldownEndsAt: null,
                        GraceEndsAt: cooldownEnd + config.GraceWindow);
                    continue;

                case Phase.Unlocked when state.GraceEndsAt is { } graceEnd && now >= graceEnd:
                    state = AppState.Idle;
                    continue;

                default:
                    return state;
            }
        }
    }

    private static (AppState, BrakeAction) OnLaunchAttempt(
        AppState state,
        BrakeEvent.LaunchAttempt launch,
        CooldownConfig config) =>
        state.Phase switch
        {
            Phase.Idle => (
                new AppState(Phase.Cooling, launch.Now + config.Cooldown, GraceEndsAt: null),
                new BrakeAction.Terminate(launch.ProcessId)),

            // The deadline is left exactly as it was. Extending it on every retry
            // would punish impatience and, retried often enough, could put the
            // application permanently out of reach.
            Phase.Cooling => (state, new BrakeAction.Terminate(launch.ProcessId)),

            Phase.Unlocked => (
                new AppState(Phase.Running, CooldownEndsAt: null, GraceEndsAt: null),
                BrakeAction.Allow.Instance),

            // A second instance of something already permitted. The session was
            // already paid for; interrupting it now would break the promise that a
            // session under way is never touched.
            Phase.Running => (state, BrakeAction.Allow.Instance),

            _ => (state, BrakeAction.None.Instance),
        };

    private static (AppState, BrakeAction) OnProcessExited(AppState state) =>
        // Only a permitted session ending returns to idle. An exit seen in any other
        // phase is the remains of a launch just terminated, and treating that as the
        // end of a session would clear the very cooldown the termination started.
        state.Phase is Phase.Running
            ? (AppState.Idle, (BrakeAction)BrakeAction.None.Instance)
            : (state, BrakeAction.None.Instance);
}
