namespace GameBrake.Core;

/// <summary>
/// Where one protected application stands in the cooldown cycle.
/// </summary>
public enum Phase
{
    /// <summary>No cooldown owed and none running. The next launch is charged one.</summary>
    Idle,

    /// <summary>A launch was intercepted. Launching is refused until the cooldown ends.</summary>
    Cooling,

    /// <summary>The cooldown was served. Launching is permitted, but not indefinitely.</summary>
    Unlocked,

    /// <summary>A permitted session is under way and is never interrupted.</summary>
    Running,
}
