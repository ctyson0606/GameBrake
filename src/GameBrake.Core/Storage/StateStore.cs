using System.Text.Json;

namespace GameBrake.Core.Storage;

/// <summary>
/// Reads and writes state.json, the file that makes a cooldown outlive the
/// process that charged it (AC7).
/// </summary>
public sealed class StateStore(string filePath)
{
    public string FilePath { get; } = filePath;

    /// <summary>
    /// Load every known application state, or an empty set on a first run.
    /// </summary>
    /// <exception cref="InvalidDataException">The file exists but cannot be read.</exception>
    public IReadOnlyDictionary<Guid, AppState> Load()
    {
        if (!File.Exists(FilePath))
        {
            return new Dictionary<Guid, AppState>();
        }

        try
        {
            return JsonSerializer.Deserialize<Dictionary<Guid, AppState>>(
                       File.ReadAllText(FilePath), GameBrakeJson.Options)
                   ?? new Dictionary<Guid, AppState>();
        }
        catch (JsonException e)
        {
            // Reading a damaged file as "nothing owed" would turn corrupting it
            // into the cheapest way out of every cooldown at once.
            throw new InvalidDataException($"{FilePath} is not valid state.", e);
        }
    }

    public void Save(IReadOnlyDictionary<Guid, AppState> states) =>
        // Deadlines reach the file in UTC; see UtcInstantConverter for why that is
        // done there rather than here.
        AtomicFile.Write(FilePath, JsonSerializer.Serialize(states, GameBrakeJson.Options));
}
