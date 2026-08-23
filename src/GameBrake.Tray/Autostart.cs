using Microsoft.Win32;

namespace GameBrake.Tray;

/// <summary>
/// Starting with the Windows session (G5), through the per-user Run key.
/// </summary>
/// <remarks>
/// HKEY_CURRENT_USER rather than the machine-wide key or a scheduled task: this
/// tool runs as the user and wants nothing the user cannot grant it, which is the
/// same reasoning that keeps it out of a service (N7).
/// </remarks>
internal static class Autostart
{
    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ValueName = "GameBrake";

    public static bool IsEnabled()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKey);
        return key?.GetValue(ValueName) is not null;
    }

    public static void Set(bool enabled)
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKey, writable: true)
                        ?? Registry.CurrentUser.CreateSubKey(RunKey);

        if (!enabled)
        {
            key.DeleteValue(ValueName, throwOnMissingValue: false);
            return;
        }

        var executable = Environment.ProcessPath;
        if (string.IsNullOrEmpty(executable))
        {
            return;
        }

        key.SetValue(ValueName, $"\"{executable}\"");
    }
}
