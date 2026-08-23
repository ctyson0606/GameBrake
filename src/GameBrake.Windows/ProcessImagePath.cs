using System.Runtime.InteropServices;
using System.Text;

namespace GameBrake.Windows;

/// <summary>
/// The full path of a running process, for when WMI declines to say.
/// </summary>
/// <remarks>
/// Win32_Process reports ExecutablePath as null for a process an anti-cheat is
/// protecting. Measured against Riot Vanguard: VALORANT.exe and
/// VALORANT-Win64-Shipping.exe both came back null, and Process.MainModule threw
/// access denied, because reading modules wants PROCESS_VM_READ. This route wants
/// only PROCESS_QUERY_LIMITED_INFORMATION, which was granted, and it returned the
/// real path for both.
/// <para>
/// That matters because matching is on the full path by decision (A4). Without
/// this the choice would have been between letting such games through and
/// loosening the match to a file name, and neither is necessary.
/// </para>
/// </remarks>
internal static class ProcessImagePath
{
    private const uint QueryLimitedInformation = 0x1000;

    /// <summary>The image path, or null if it cannot be had.</summary>
    public static string? Of(int processId)
    {
        var process = NativeMethods.OpenProcess(QueryLimitedInformation, false, processId);
        if (process == IntPtr.Zero)
        {
            // Gone already, or genuinely out of reach, as Vanguard's own service is.
            return null;
        }

        try
        {
            var buffer = new StringBuilder(1024);
            var size = (uint)buffer.Capacity;

            return NativeMethods.QueryFullProcessImageNameW(process, 0, buffer, ref size)
                ? buffer.ToString()
                : null;
        }
        finally
        {
            NativeMethods.CloseHandle(process);
        }
    }

    private static class NativeMethods
    {
        // DllImport rather than LibraryImport: the source generator wants
        // AllowUnsafeBlocks for the whole project, which is a lot of blast radius
        // for three calls.
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr OpenProcess(uint desiredAccess, bool inheritHandle, int processId);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool CloseHandle(IntPtr handle);

        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool QueryFullProcessImageNameW(
            IntPtr process, uint flags, StringBuilder buffer, ref uint size);
    }
}
