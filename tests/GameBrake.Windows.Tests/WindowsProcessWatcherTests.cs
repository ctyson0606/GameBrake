using System.Diagnostics;
using GameBrake.Core;
using GameBrake.Windows;

// These launch and kill real processes. Running two of them at once would have
// each seeing the other subject.
[assembly: CollectionBehavior(DisableTestParallelization = true)]

namespace GameBrake.Windows.Tests;

/// <summary>
/// The mechanism behind AC1, exercised against a real process. A plain Win32
/// executable is the subject on purpose; see GOTCHAS.md for what happens with an
/// app execution alias.
/// </summary>
public sealed class WindowsProcessWatcherTests : IDisposable
{
    private static readonly string Subject =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "charmap.exe");

    private static readonly TimeSpan SubscriptionSettle = TimeSpan.FromSeconds(2);
    private static readonly TimeSpan DetectionBudget = TimeSpan.FromSeconds(2);

    public WindowsProcessWatcherTests()
    {
        Assert.True(File.Exists(Subject), $"The test subject {Subject} is not on this machine.");
        KillAnySubject();
    }

    public void Dispose() => KillAnySubject();

    private static void KillAnySubject()
    {
        foreach (var leftover in Process.GetProcessesByName(
                     Path.GetFileNameWithoutExtension(Subject)))
        {
            try
            {
                leftover.Kill();
                leftover.WaitForExit(4000);
            }
            catch (Exception exception) when (exception is InvalidOperationException or System.ComponentModel.Win32Exception)
            {
                // Not ours to end, or already gone.
            }
            finally
            {
                leftover.Dispose();
            }
        }
    }

    private static Process Launch() =>
        Process.Start(new ProcessStartInfo(Subject) { UseShellExecute = true })!;

    [Fact] // AC1, the mechanism half
    public async Task A_launch_is_seen_with_its_full_path_inside_the_budget_AC1_allows()
    {
        using var watcher = new WindowsProcessWatcher();
        var seen = new TaskCompletionSource<BrakeEvent.LaunchAttempt>(
            TaskCreationOptions.RunContinuationsAsynchronously);
        watcher.Observed += (_, observed) =>
        {
            if (observed is BrakeEvent.LaunchAttempt launch &&
                string.Equals(launch.ExecutablePath, Subject, StringComparison.OrdinalIgnoreCase))
            {
                seen.TrySetResult(launch);
            }
        };
        watcher.Start();
        await Task.Delay(SubscriptionSettle);

        var stopwatch = Stopwatch.StartNew();
        using var launched = Launch();

        var finished = await Task.WhenAny(seen.Task, Task.Delay(TimeSpan.FromSeconds(8)));
        Assert.True(finished == seen.Task, "The launch was never seen at all.");
        stopwatch.Stop();

        var attempt = await seen.Task;
        Assert.Equal(Subject, attempt.ExecutablePath, ignoreCase: true);
        Assert.True(
            stopwatch.Elapsed < DetectionBudget,
            $"Seen after {stopwatch.ElapsedMilliseconds} ms, and AC1 allows {DetectionBudget.TotalMilliseconds:0} ms.");

        // And what the reducer would ask for actually ends it.
        Assert.True(new ProcessEnforcer().Terminate(attempt.ProcessId));
        Assert.Empty(Process.GetProcessesByName(Path.GetFileNameWithoutExtension(Subject)));
    }

    [Fact] // AC5, the mechanism half
    public async Task The_end_of_a_permitted_process_is_reported()
    {
        using var watcher = new WindowsProcessWatcher();
        var exited = new TaskCompletionSource<BrakeEvent.ProcessExited>(
            TaskCreationOptions.RunContinuationsAsynchronously);
        watcher.Observed += (_, observed) =>
        {
            if (observed is BrakeEvent.ProcessExited end)
            {
                exited.TrySetResult(end);
            }
        };

        using var launched = Launch();
        watcher.WatchForExit(launched.Id, Subject);

        Assert.True(new ProcessEnforcer().Terminate(launched.Id));

        var finished = await Task.WhenAny(exited.Task, Task.Delay(TimeSpan.FromSeconds(8)));
        Assert.True(finished == exited.Task, "The end of a permitted process went unreported.");
        Assert.Equal(Subject, (await exited.Task).ExecutablePath, ignoreCase: true);
    }

    [Fact]
    public async Task A_process_that_ended_before_we_could_follow_it_is_still_reported()
    {
        // Otherwise the application is stranded in the running phase, where no
        // further launch is ever charged a cooldown.
        using var watcher = new WindowsProcessWatcher();
        var exited = new TaskCompletionSource<BrakeEvent.ProcessExited>(
            TaskCreationOptions.RunContinuationsAsynchronously);
        watcher.Observed += (_, observed) =>
        {
            if (observed is BrakeEvent.ProcessExited end)
            {
                exited.TrySetResult(end);
            }
        };

        var launched = Launch();
        var processId = launched.Id;
        launched.Kill();
        await launched.WaitForExitAsync();
        launched.Dispose();

        watcher.WatchForExit(processId, Subject);

        var finished = await Task.WhenAny(exited.Task, Task.Delay(TimeSpan.FromSeconds(5)));
        Assert.True(finished == exited.Task, "An already finished process went unreported.");
    }

    [Fact] // G4, AC6
    public async Task An_unprotected_launch_is_reported_too_and_left_for_the_policy_to_ignore()
    {
        // The watcher reports every start it can see a path for. Deciding that an
        // executable is none of our business belongs to Configuration.Match, not
        // here, so that one place owns the question.
        using var watcher = new WindowsProcessWatcher();
        var paths = new List<string>();
        watcher.Observed += (_, observed) =>
        {
            if (observed is BrakeEvent.LaunchAttempt launch)
            {
                lock (paths)
                {
                    paths.Add(launch.ExecutablePath);
                }
            }
        };
        watcher.Start();
        await Task.Delay(SubscriptionSettle);

        using var launched = Launch();
        await Task.Delay(TimeSpan.FromSeconds(3));

        lock (paths)
        {
            Assert.Contains(paths, path => string.Equals(path, Subject, StringComparison.OrdinalIgnoreCase));
        }

        new ProcessEnforcer().Terminate(launched.Id);
    }
}
