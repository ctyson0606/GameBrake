using System.Text.Json;
using System.Text.Json.Serialization;

namespace GameBrake.Core.Storage;

/// <summary>
/// One set of options for both files, so what is written and what is expected
/// on read can never drift apart.
/// </summary>
internal static class GameBrakeJson
{
    public static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
        // config.json is meant to be opened and edited by hand.
        WriteIndented = true,
        Converters =
        {
            new JsonStringEnumConverter(JsonNamingPolicy.CamelCase),
            new UtcInstantConverter(),
        },
    };
}
