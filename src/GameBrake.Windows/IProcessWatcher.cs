using GameBrake.Core;

namespace GameBrake.Windows;

/// <summary>
/// The process activity the engine reacts to. An interface so the wiring can be
/// tested without launching anything: forgetting to save state, or forgetting to
/// follow a permitted process, are engine bugs and should not need a real game to
/// catch.
/// </summary>
public interface IProcessWatcher : IDisposable
{
    /// <summary>Raised on a thread of the implementation, not the caller.</summary>
    event EventHandler<BrakeEvent>? Observed;

    void Start();

    /// <summary>Follow a permitted process so its ending can be reported (AC5).</summary>
    void WatchForExit(int processId, string executablePath);
}

/// <summary>
/// The one action that touches the machine, behind an interface for the same reason.
/// </summary>
public interface IProcessTerminator
{
    bool Terminate(int processId, TimeSpan? timeout = null);
}
