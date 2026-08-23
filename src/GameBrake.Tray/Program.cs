namespace GameBrake.Tray;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        // Two copies would see the same launch and charge it twice, and the second
        // would fight the first over state.json.
        using var single = new Mutex(initiallyOwned: true, "GameBrake.SingleInstance", out var only);
        if (!only)
        {
            return;
        }

        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
        Application.Run(new TrayContext());
    }
}
