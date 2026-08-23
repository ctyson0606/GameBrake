namespace GameBrake.Core;

/// <summary>
/// What the host should do about an event. The reducer decides; it does not act.
/// </summary>
public abstract record BrakeAction
{
    /// <summary>Do nothing.</summary>
    public sealed record None : BrakeAction
    {
        public static readonly None Instance = new();
    }

    /// <summary>End this process.</summary>
    public sealed record Terminate(int ProcessId) : BrakeAction;

    /// <summary>Leave this process alone.</summary>
    public sealed record Allow : BrakeAction
    {
        public static readonly Allow Instance = new();
    }
}
