using System.Text.Json;

namespace GameBrake.Core.Storage;

/// <summary>
/// Reads config.json. The tool does not rewrite this file behind the user;
/// <see cref="Save"/> exists for the settings UI to call deliberately.
/// </summary>
public sealed class ConfigurationStore(string filePath)
{
    public string FilePath { get; } = filePath;

    /// <summary>
    /// Load the configuration, or the defaults if there is no file yet.
    /// </summary>
    /// <exception cref="InvalidDataException">The file exists but cannot be read.</exception>
    public Configuration Load()
    {
        // A first run has no file. That is not an error, and it is not the same
        // thing as a file that is present and unreadable.
        if (!File.Exists(FilePath))
        {
            return Configuration.Default;
        }

        try
        {
            return JsonSerializer.Deserialize<Configuration>(
                       File.ReadAllText(FilePath), GameBrakeJson.Options)
                   ?? throw new InvalidDataException($"{FilePath} contains null.");
        }
        catch (JsonException e)
        {
            // Falling back to the defaults here would silently unprotect every
            // application over a stray comma.
            throw new InvalidDataException($"{FilePath} is not valid configuration.", e);
        }
    }

    public void Save(Configuration configuration) =>
        AtomicFile.Write(FilePath, JsonSerializer.Serialize(configuration, GameBrakeJson.Options));
}
