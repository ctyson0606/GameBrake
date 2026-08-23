namespace GameBrake.Core.Storage;

/// <summary>
/// Whole-file writes that a power cut cannot leave half finished.
/// </summary>
internal static class AtomicFile
{
    /// <summary>
    /// Write to a sibling temporary file, then replace the target in one step.
    /// </summary>
    /// <remarks>
    /// state.json is rewritten on every transition, and a torn write there is not
    /// a cosmetic problem: a truncated file fails to parse, and the tool would come
    /// back owing nothing. Losing power mid-cooldown would become a way out of it.
    /// </remarks>
    public static void Write(string filePath, string contents)
    {
        var directory = Path.GetDirectoryName(filePath);
        if (!string.IsNullOrEmpty(directory))
        {
            Directory.CreateDirectory(directory);
        }

        var temporary = filePath + ".tmp";
        File.WriteAllText(temporary, contents);
        File.Move(temporary, filePath, overwrite: true);
    }
}
