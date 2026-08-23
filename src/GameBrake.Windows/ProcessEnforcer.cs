using System.Diagnostics;

namespace GameBrake.Windows;

/// <summary>
/// Carries out the one action the reducer can ask for that touches the machine.
/// </summary>
public sealed class ProcessEnforcer
{
    /// <summary>
    /// End one process and wait for it to be gone.
    /// </summary>
    /// <returns>
    /// True if the process is no longer running, including when it had already
    /// ended before this was called.
    /// </returns>
    /// <remarks>
    /// One process, never its tree. A game started from a launcher is a child of
    /// that launcher, and taking the tree would close the launcher along with it,
    /// which is neither asked for nor kind. The user chooses which executable is
    /// protected, and that is the only one this ends (A4).
    /// </remarks>
    public bool Terminate(int processId, TimeSpan? timeout = null)
    {
        var wait = timeout ?? TimeSpan.FromSeconds(5);

        try
        {
            using var process = Process.GetProcessById(processId);
            process.Kill();
            return process.WaitForExit((int)wait.TotalMilliseconds);
        }
        catch (ArgumentException)
        {
            // No such process: it ended on its own. The outcome asked for holds.
            return true;
        }
        catch (InvalidOperationException)
        {
            // It ended between the lookup and the kill. Same outcome.
            return true;
        }
    }
}
