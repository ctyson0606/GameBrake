namespace GameBrake.Core;

/// <summary>
/// Something the host observed. Every event carries the instant it was observed;
/// the reducer never reads a clock of its own, so every time-dependent behaviour
/// can be tested without waiting for it.
/// </summary>
/// <param name="Now">When the host observed this.</param>
public abstract record BrakeEvent(DateTimeOffset Now)
{
    /// <summary>The clock moved. Carries no decision, only the chance to notice an expiry.</summary>
    public sealed record Tick(DateTimeOffset Now) : BrakeEvent(Now);

    /// <summary>A protected executable started.</summary>
    public sealed record LaunchAttempt(DateTimeOffset Now, string ExecutablePath, int ProcessId)
        : BrakeEvent(Now);

    /// <summary>A protected executable stopped, for any reason including our own doing.</summary>
    public sealed record ProcessExited(DateTimeOffset Now, string ExecutablePath) : BrakeEvent(Now);
}
