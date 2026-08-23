using System.Diagnostics;

namespace GameBrake.Tray;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        // Two copies would see the same launch and charge it twice, and the second
        // would fight the first over state.json.
        using var single = new Mutex(initiallyOwned: true, "GameBrake.SingleInstance", out var only);
        if (!only && AnotherCopyIsRunning())
        {
            return;
        }

        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
        Application.Run(new TrayContext());
    }

    /// <summary>
    /// Whether a second copy of this program is actually running.
    /// </summary>
    /// <remarks>
    /// The mutex name has no owner. Windows gives it to whoever asks first and
    /// records nothing about who that was, so reading "the name is taken" as
    /// "another copy of me is running" is a guess, and anything in this session can
    /// arrange for it to be wrong: a few lines that take the name and sleep are
    /// enough to make every later start exit without a word, looking exactly like a
    /// tool that was never launched.
    /// <para>
    /// That matters more here than the same hole would elsewhere. Closing this tool
    /// stays possible by decision (N7), but the bargain is that it costs a
    /// deliberate act, paid again every time. Taking the name is paid once and is
    /// silent afterwards, which buys a permanent bypass at no recurring cost — and
    /// leaves nothing to notice, since a missing tray icon is what not launching it
    /// looks like too.
    /// </para>
    /// <para>
    /// So ask the question the name was only standing in for. With no second
    /// process there is nothing to collide over, and whoever holds the name is
    /// welcome to it.
    /// </para>
    /// </remarks>
    private static bool AnotherCopyIsRunning()
    {
        // Asked rather than written down, so renaming the executable cannot quietly
        // turn this check into one that never matches anything.
        using var self = Process.GetCurrentProcess();

        foreach (var other in Process.GetProcessesByName(self.ProcessName))
        {
            using (other)
            {
                if (other.Id != self.Id)
                {
                    return true;
                }
            }
        }

        return false;
    }
}
