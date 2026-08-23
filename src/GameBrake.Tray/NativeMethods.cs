using System.Runtime.InteropServices;

namespace GameBrake.Tray;

internal static class NativeMethods
{
    /// <summary>
    /// Releases the handle Bitmap.GetHicon hands out, which nothing else frees.
    /// </summary>
    /// <remarks>
    /// DllImport rather than LibraryImport: the source generator wants
    /// AllowUnsafeBlocks turned on for the whole project, which is a lot of blast
    /// radius for one call that takes a handle and returns a bool.
    /// </remarks>
    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool DestroyIcon(IntPtr handle);
}
