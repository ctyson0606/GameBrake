using System.Diagnostics;
using GameBrake.Windows;

namespace GameBrake.Windows.Tests;

/// <summary>
/// The fallback that reaches a process WMI will not describe. It cannot be tested
/// against an anti-cheat here, so what is held in place is the contract it has to
/// keep: the same full path WMI would have given, and null rather than a guess
/// when there is nothing to give.
/// </summary>
public sealed class ProcessImagePathTests
{
    [Fact]
    public void The_path_of_this_very_process_comes_back_whole()
    {
        var expected = Environment.ProcessPath;
        Assert.NotNull(expected);

        Assert.Equal(expected, ProcessImagePath.Of(Environment.ProcessId), ignoreCase: true);
    }

    [Fact]
    public void It_agrees_with_what_the_ordinary_route_reports()
    {
        // For a process nothing is hiding, the answer must be identical to the one
        // the watcher would have taken from WMI, or the fallback would quietly
        // introduce a second spelling of the same path and break matching (A4).
        using var subject = Process.Start(new ProcessStartInfo(
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "charmap.exe"))
        {
            UseShellExecute = true,
        })!;

        try
        {
            Assert.Equal(subject.MainModule!.FileName, ProcessImagePath.Of(subject.Id), ignoreCase: true);
        }
        finally
        {
            subject.Kill();
            subject.WaitForExit(4000);
        }
    }

    [Fact]
    public void A_process_that_is_not_there_yields_null_rather_than_a_guess()
    {
        // Pid 0 is the idle process and can never be opened this way.
        Assert.Null(ProcessImagePath.Of(0));
    }

    [Fact]
    public void An_ended_process_yields_null()
    {
        using var subject = Process.Start(new ProcessStartInfo(
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "charmap.exe"))
        {
            UseShellExecute = true,
        })!;

        var processId = subject.Id;
        subject.Kill();
        subject.WaitForExit(4000);

        // Windows can hold a pid briefly after exit, so accept either the path or
        // null; what must never happen is a wrong path or a throw.
        var path = ProcessImagePath.Of(processId);
        Assert.True(
            path is null || path.EndsWith("charmap.exe", StringComparison.OrdinalIgnoreCase),
            $"Expected null or the subject path, got {path}");
    }
}
