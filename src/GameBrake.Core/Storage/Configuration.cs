using System.Text.Json.Serialization;

namespace GameBrake.Core.Storage;

/// <summary>
/// One entry in the protected set.
/// </summary>
/// <param name="Id">Stable identity. State is keyed by this, not by the path,
/// so a moved executable can be repointed without discharging its cooldown.</param>
/// <param name="Executable">Full path, compared case-insensitively (A4).</param>
/// <param name="DisplayName">What the user calls it.</param>
/// <param name="Enabled">A disabled entry is treated as though it were absent.</param>
public sealed record ProtectedApp(
    Guid Id,
    string Executable,
    string DisplayName,
    bool Enabled);

/// <summary>
/// The contents of config.json. Owned by the user, edited by hand, never
/// rewritten by the tool.
/// </summary>
public sealed record Configuration(
    int CooldownSeconds,
    int GraceWindowSeconds,
    bool Autostart,
    IReadOnlyList<ProtectedApp> Protected)
{
    /// <summary>What a first run gets: the documented durations, nothing protected.</summary>
    public static readonly Configuration Default = new(
        CooldownSeconds: 300,
        GraceWindowSeconds: 300,
        Autostart: true,
        Protected: []);

    /// <summary>The two durations the reducer needs, and nothing else.</summary>
    /// <remarks>
    /// Kept out of the file. It has a getter and no setter, so it would be
    /// written and then ignored on the way back in: a second thing in a
    /// hand-edited file that looks like the setting, sits next to the real one,
    /// and does nothing. Someone edited it instead of cooldownSeconds and the
    /// tool went on using the old value without a word.
    /// </remarks>
    [JsonIgnore]
    public CooldownConfig Cooldown => new(
        TimeSpan.FromSeconds(CooldownSeconds),
        TimeSpan.FromSeconds(GraceWindowSeconds));

    /// <summary>
    /// The protected entry this executable belongs to, or null if it is none of
    /// our business. Anything not matched here is left completely alone (G4, AC6).
    /// </summary>
    public ProtectedApp? Match(string executablePath) =>
        Protected.FirstOrDefault(app =>
            app.Enabled &&
            string.Equals(app.Executable, executablePath, StringComparison.OrdinalIgnoreCase));
}
