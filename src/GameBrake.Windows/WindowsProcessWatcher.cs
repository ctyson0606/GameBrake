using System.Collections.Concurrent;
using System.Diagnostics;
using System.Management;
using GameBrake.Core;

namespace GameBrake.Windows;

/// <summary>
/// Turns Windows process activity into the events the reducer understands.
/// </summary>
/// <remarks>
/// Starts arrive from a WMI subscription. Win32_ProcessStartTrace would be the
/// natural source but is refused without administrator rights, and this tool runs
/// in user mode by decision (N7), so the route is __InstanceCreationEvent. The
/// interval stays at one second: half a second measured slower, not faster.
/// <para>
/// Exits do not come from a second subscription. Polling twice would double the
/// idle cost that AC9 is about, and there is a cheaper and exact alternative,
/// since the only exit that means anything is that of a process this tool
/// permitted, and its identity is known the moment it is permitted.
/// </para>
/// </remarks>
public sealed class WindowsProcessWatcher : IDisposable
{
    private const string StartQuery =
        "SELECT * FROM __InstanceCreationEvent WITHIN 1 WHERE TargetInstance ISA 'Win32_Process'";

    private readonly ManagementEventWatcher _starts = new(new WqlEventQuery(StartQuery));
    private readonly ConcurrentDictionary<int, Process> _permitted = new();
    private readonly TimeProvider _time;
    private bool _disposed;

    public WindowsProcessWatcher(TimeProvider? time = null)
    {
        _time = time ?? TimeProvider.System;
        _starts.EventArrived += OnProcessStarted;
    }

    /// <summary>
    /// Raised with a <see cref="BrakeEvent.LaunchAttempt"/> for every process start,
    /// and a <see cref="BrakeEvent.ProcessExited"/> for every permitted process that
    /// ends. Handlers run on a WMI or a process-exit thread, not the caller.
    /// </summary>
    public event EventHandler<BrakeEvent>? Observed;

    public void Start() => _starts.Start();

    public void Stop() => _starts.Stop();

    /// <summary>
    /// Follow a process this tool has permitted, so that its ending can close the
    /// session and charge the next launch again (AC5).
    /// </summary>
    public void WatchForExit(int processId, string executablePath)
    {
        var reported = 0;

        void Report()
        {
            // Two paths can notice the same exit: the event, and the check below
            // for one that happened while we were still setting the event up.
            if (Interlocked.Exchange(ref reported, 1) == 0)
            {
                Observed?.Invoke(this, new BrakeEvent.ProcessExited(_time.GetUtcNow(), executablePath));
            }
        }

        Process process;
        try
        {
            process = Process.GetProcessById(processId);
        }
        catch (ArgumentException)
        {
            // Gone before we could take hold of it. Reporting it late is right;
            // never reporting it would strand the application in the running
            // phase, where no further launch is ever charged.
            Report();
            return;
        }

        try
        {
            process.EnableRaisingEvents = true;
        }
        catch (InvalidOperationException)
        {
            Report();
            process.Dispose();
            return;
        }

        _permitted[processId] = process;
        process.Exited += (_, _) =>
        {
            Report();
            if (_permitted.TryRemove(processId, out var finished))
            {
                finished.Dispose();
            }
        };

        // It may have ended between the lookup and the subscription.
        if (process.HasExited)
        {
            Report();
        }
    }

    private void OnProcessStarted(object sender, EventArrivedEventArgs e)
    {
        if (e.NewEvent["TargetInstance"] is not ManagementBaseObject target)
        {
            return;
        }

        var executablePath = target["ExecutablePath"]?.ToString();

        // No path, nothing to match on. App execution aliases and processes owned
        // by other accounts both report none, and matching is on the full path by
        // decision (A4), so there is nothing this tool can say about them.
        if (string.IsNullOrEmpty(executablePath))
        {
            return;
        }

        int processId;
        try
        {
            processId = Convert.ToInt32(target["ProcessId"]);
        }
        catch (Exception exception) when (exception is InvalidCastException or FormatException or OverflowException)
        {
            return;
        }

        Observed?.Invoke(this, new BrakeEvent.LaunchAttempt(_time.GetUtcNow(), executablePath, processId));
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        _starts.EventArrived -= OnProcessStarted;

        try
        {
            _starts.Stop();
        }
        catch (ManagementException)
        {
            // Never started, or already torn down.
        }

        _starts.Dispose();

        foreach (var process in _permitted.Values)
        {
            process.Dispose();
        }

        _permitted.Clear();
    }
}
