namespace GameBrake.Core.Storage;

/// <summary>
/// Where the two files live when nobody says otherwise. Both stores take an
/// explicit path instead of reaching for these, so tests never touch the real ones.
/// </summary>
public static class GameBrakePaths
{
    /// <summary>%APPDATA%\GameBrake on Windows.</summary>
    public static string Directory => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "GameBrake");

    public static string ConfigurationFile => Path.Combine(Directory, "config.json");

    public static string StateFile => Path.Combine(Directory, "state.json");
}
