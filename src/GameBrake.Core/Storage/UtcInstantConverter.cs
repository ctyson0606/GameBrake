using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace GameBrake.Core.Storage;

/// <summary>
/// Writes every instant as UTC ending in Z, which is the shape the data contract
/// documents and the shape someone reading state.json by hand can act on without
/// doing arithmetic first.
/// </summary>
/// <remarks>
/// Trailing zeros in the fraction are dropped, so a whole second comes out as
/// 2026-08-23T10:05:00Z while a finer instant keeps every digit it had. Reading
/// goes through the general parser, so a file hand-edited to carry a local offset
/// is still understood, and still means the same instant.
/// </remarks>
internal sealed class UtcInstantConverter : JsonConverter<DateTimeOffset>
{
    private const string Format = "yyyy-MM-ddTHH:mm:ss.FFFFFFFZ";

    public override DateTimeOffset Read(
        ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options) =>
        DateTimeOffset.Parse(
            reader.GetString() ?? throw new JsonException("Expected an instant, found null."),
            CultureInfo.InvariantCulture,
            DateTimeStyles.RoundtripKind);

    public override void Write(
        Utf8JsonWriter writer, DateTimeOffset value, JsonSerializerOptions options) =>
        writer.WriteStringValue(
            value.ToUniversalTime().ToString(Format, CultureInfo.InvariantCulture));
}
