namespace GameBrake.Core;

/// <summary>
/// The two durations that govern every protected application.
/// </summary>
/// <param name="Cooldown">How long a launch is refused after being intercepted.</param>
/// <param name="GraceWindow">
/// How long permission survives once the cooldown ends. A permission that never
/// lapsed could be banked: trigger every cooldown in the morning, then play
/// unimpeded for the rest of the day.
/// </param>
public sealed record CooldownConfig(TimeSpan Cooldown, TimeSpan GraceWindow)
{
    /// <summary>Five minutes of waiting, five minutes to take it up.</summary>
    public static readonly CooldownConfig Default = new(
        Cooldown: TimeSpan.FromSeconds(300),
        GraceWindow: TimeSpan.FromSeconds(300));
}
