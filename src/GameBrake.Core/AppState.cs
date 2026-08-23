namespace GameBrake.Core;

/// <summary>
/// The cooldown state of a single protected application.
/// </summary>
/// <remarks>
/// Both deadlines are absolute instants rather than remaining durations. That is
/// what lets the state be written to disk and picked up again after the tool, or
/// Windows itself, has restarted: a remaining duration would silently restart from
/// full on every load, which would make rebooting a way out of a cooldown (AC7).
/// </remarks>
/// <param name="Phase">Where this application stands in the cycle.</param>
/// <param name="CooldownEndsAt">When the cooldown expires. Set only while cooling.</param>
/// <param name="GraceEndsAt">When permission to launch lapses. Set only while unlocked.</param>
public sealed record AppState(
    Phase Phase,
    DateTimeOffset? CooldownEndsAt,
    DateTimeOffset? GraceEndsAt)
{
    /// <summary>Nothing owed, nothing running.</summary>
    public static readonly AppState Idle = new(Phase.Idle, null, null);
}
