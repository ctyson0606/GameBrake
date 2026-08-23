using System.Drawing.Drawing2D;
using GameBrake.Core;
using GameBrake.Core.Storage;
using GameBrake.Windows;

namespace GameBrake.Tray;

/// <summary>
/// The tray icon and everything the user can reach from it. Holds no policy: it
/// shows what <see cref="BrakeEngine"/> reports and passes edits back to it.
/// </summary>
internal sealed class TrayContext : ApplicationContext
{
    private readonly ConfigurationStore _configurationStore = new(GameBrakePaths.ConfigurationFile);
    private readonly NotifyIcon _icon;
    private readonly System.Windows.Forms.Timer _clock;
    private readonly Control _marshal = new();
    private readonly FileSystemWatcher? _configurationChanges;
    private readonly BrakeEngine _engine;
    private readonly Icon _drawnIcon;

    private Configuration _configuration;

    public TrayContext()
    {
        // A handle has to exist before anything can be marshalled onto this thread,
        // and engine events arrive on WMI and process-exit threads.
        _marshal.CreateControl();

        _configuration = LoadConfigurationOrDefault();
        _drawnIcon = BuildIcon();

        _engine = new BrakeEngine(
            _configuration,
            new StateStore(GameBrakePaths.StateFile),
            new WindowsProcessWatcher(),
            new ProcessEnforcer());

        _icon = new NotifyIcon
        {
            Icon = _drawnIcon,
            Visible = true,
            Text = "GameBrake",
            ContextMenuStrip = new ContextMenuStrip(),
        };
        _icon.ContextMenuStrip.Opening += (_, _) => BuildMenu();

        _engine.Blocked += (_, blocked) => OnUiThread(() => Announce(blocked));
        _engine.TerminationFailed += (_, app) => OnUiThread(() => AnnounceFailure(app));
        _engine.Changed += (_, _) => OnUiThread(Refresh);
        _engine.Start();

        _clock = new System.Windows.Forms.Timer { Interval = 1000 };
        _clock.Tick += (_, _) =>
        {
            _engine.Tick();
            Refresh();
        };
        _clock.Start();

        _configurationChanges = WatchConfigurationFile();
        Refresh();
    }

    private Configuration LoadConfigurationOrDefault()
    {
        try
        {
            return _configurationStore.Load();
        }
        catch (InvalidDataException exception)
        {
            // Falling back to the defaults would silently unprotect everything,
            // so say so instead and carry on with nothing protected until it is fixed.
            MessageBox.Show(
                $"{exception.Message}\n\nNothing is protected until that file is valid again.",
                "GameBrake",
                MessageBoxButtons.OK,
                MessageBoxIcon.Warning);
            return Configuration.Default;
        }
    }

    private FileSystemWatcher? WatchConfigurationFile()
    {
        var directory = Path.GetDirectoryName(GameBrakePaths.ConfigurationFile);
        if (string.IsNullOrEmpty(directory))
        {
            return null;
        }

        Directory.CreateDirectory(directory);

        var watcher = new FileSystemWatcher(directory, "config.json")
        {
            NotifyFilter = NotifyFilters.LastWrite | NotifyFilters.FileName,
            EnableRaisingEvents = true,
        };

        void Reload(object? sender, FileSystemEventArgs e) => OnUiThread(() =>
        {
            // Editors write in several steps, so let the file settle before reading.
            Thread.Sleep(150);
            _configuration = LoadConfigurationOrDefault();
            _engine.Reconfigure(_configuration);
            Refresh();
        });

        watcher.Changed += Reload;
        watcher.Created += Reload;
        watcher.Renamed += Reload;
        return watcher;
    }

    private void OnUiThread(Action action)
    {
        if (_marshal.IsDisposed || !_marshal.IsHandleCreated)
        {
            return;
        }

        if (_marshal.InvokeRequired)
        {
            _marshal.BeginInvoke(action);
            return;
        }

        action();
    }

    // --- what the user sees --------------------------------------------------

    private static string Countdown(TimeSpan remaining) =>
        remaining <= TimeSpan.Zero
            ? "0:00"
            : $"{(int)remaining.TotalMinutes}:{remaining.Seconds:00}";

    private static string Describe(AppStatus status) => status.State.Phase switch
    {
        Phase.Cooling => $"{status.App.DisplayName} — wait {Countdown(status.Remaining ?? TimeSpan.Zero)}",
        Phase.Unlocked => $"{status.App.DisplayName} — open it within {Countdown(status.Remaining ?? TimeSpan.Zero)}",
        Phase.Running => $"{status.App.DisplayName} — running",
        _ => $"{status.App.DisplayName} — ready",
    };

    private void Refresh()
    {
        var statuses = _engine.Status();

        // The most urgent countdown goes on the tooltip, so the number is one
        // hover away and never needs looking for (AC8).
        var cooling = statuses
            .Where(status => status.State.Phase == Phase.Cooling && status.Remaining is not null)
            .OrderBy(status => status.Remaining!.Value)
            .FirstOrDefault();

        var text = cooling is not null
            ? $"GameBrake — {cooling.App.DisplayName} {Countdown(cooling.Remaining!.Value)}"
            : statuses.Count == 0
                ? "GameBrake — nothing protected yet"
                : "GameBrake — nothing cooling";

        // NotifyIcon.Text is capped at 63 characters and throws past it.
        _icon.Text = text.Length <= 63 ? text : text[..63];
    }

    private void BuildMenu()
    {
        var menu = _icon.ContextMenuStrip!;
        menu.Items.Clear();

        var statuses = _engine.Status();
        if (statuses.Count == 0)
        {
            menu.Items.Add(new ToolStripMenuItem("Nothing protected yet") { Enabled = false });
        }

        foreach (var status in statuses)
        {
            var entry = new ToolStripMenuItem(Describe(status));
            entry.DropDownItems.Add(status.App.Executable).Enabled = false;
            entry.DropDownItems.Add(new ToolStripSeparator());

            var enabled = new ToolStripMenuItem("Protected", null, (_, _) => SetEnabled(status.App, !status.App.Enabled))
            {
                Checked = status.App.Enabled,
                CheckOnClick = false,
            };
            entry.DropDownItems.Add(enabled);
            entry.DropDownItems.Add("Stop protecting this", null, (_, _) => Remove(status.App));
            menu.Items.Add(entry);
        }

        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Protect an application...", null, (_, _) => Protect());
        menu.Items.Add("Open config.json", null, (_, _) => OpenConfiguration());
        menu.Items.Add(new ToolStripMenuItem("Start with Windows", null, (_, _) => ToggleAutostart())
        {
            Checked = Autostart.IsEnabled(),
            CheckOnClick = false,
        });
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Exit GameBrake", null, (_, _) => Quit());
    }

    private void Announce(BlockedLaunch blocked)
    {
        _icon.BalloonTipTitle = $"{blocked.App.DisplayName} is on the brake";
        _icon.BalloonTipText = $"Try again in {Countdown(blocked.Remaining)}.";
        _icon.BalloonTipIcon = ToolTipIcon.Info;
        _icon.ShowBalloonTip(4000);
        Refresh();
    }

    private void AnnounceFailure(ProtectedApp app)
    {
        _icon.BalloonTipTitle = $"{app.DisplayName} could not be closed";
        _icon.BalloonTipText = "The cooldown has been charged, but it is still running.";
        _icon.BalloonTipIcon = ToolTipIcon.Warning;
        _icon.ShowBalloonTip(6000);
    }

    // --- editing the protected set (G3) --------------------------------------

    private void Save(Configuration configuration)
    {
        _configuration = configuration;
        _configurationStore.Save(configuration);
        _engine.Reconfigure(configuration);
        Refresh();
    }

    private void Protect()
    {
        using var picker = new OpenFileDialog
        {
            Title = "Which application should be put on the brake?",
            Filter = "Applications (*.exe)|*.exe|All files (*.*)|*.*",
            CheckFileExists = true,
        };

        if (picker.ShowDialog() != DialogResult.OK)
        {
            return;
        }

        var executable = picker.FileName;
        if (_configuration.Protected.Any(app =>
                string.Equals(app.Executable, executable, StringComparison.OrdinalIgnoreCase)))
        {
            return;
        }

        Save(_configuration with
        {
            Protected =
            [
                .. _configuration.Protected,
                new ProtectedApp(
                    Guid.NewGuid(),
                    executable,
                    Path.GetFileNameWithoutExtension(executable),
                    Enabled: true),
            ],
        });
    }

    private void SetEnabled(ProtectedApp app, bool enabled) =>
        Save(_configuration with
        {
            Protected = _configuration.Protected
                .Select(entry => entry.Id == app.Id ? entry with { Enabled = enabled } : entry)
                .ToList(),
        });

    private void Remove(ProtectedApp app)
    {
        var confirmed = MessageBox.Show(
            $"Stop protecting {app.DisplayName}?\n\nIt will launch without a wait from now on.",
            "GameBrake",
            MessageBoxButtons.YesNo,
            MessageBoxIcon.Question);

        if (confirmed == DialogResult.Yes)
        {
            Save(_configuration with
            {
                Protected = _configuration.Protected.Where(entry => entry.Id != app.Id).ToList(),
            });
        }
    }

    private void OpenConfiguration()
    {
        if (!File.Exists(GameBrakePaths.ConfigurationFile))
        {
            _configurationStore.Save(_configuration);
        }

        System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(
            GameBrakePaths.ConfigurationFile)
        {
            UseShellExecute = true,
        });
    }

    private void ToggleAutostart()
    {
        Autostart.Set(!Autostart.IsEnabled());
        Save(_configuration with { Autostart = Autostart.IsEnabled() });
    }

    private void Quit()
    {
        // Closing this is a deliberate act, which is the whole bargain (N7). It is
        // still worth one question, because the usual reason to be here is anger at
        // a countdown.
        var cooling = _engine.Status().Count(status => status.State.Phase == Phase.Cooling);
        if (cooling > 0)
        {
            var confirmed = MessageBox.Show(
                cooling == 1
                    ? "One application is still cooling down. Quit anyway?"
                    : $"{cooling} applications are still cooling down. Quit anyway?",
                "GameBrake",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Question);

            if (confirmed != DialogResult.Yes)
            {
                return;
            }
        }

        ExitThread();
    }

    // --- the icon itself -----------------------------------------------------

    private static Icon BuildIcon()
    {
        using var bitmap = new Bitmap(32, 32);
        using (var canvas = Graphics.FromImage(bitmap))
        {
            canvas.SmoothingMode = SmoothingMode.AntiAlias;
            canvas.Clear(Color.Transparent);

            using var disc = new SolidBrush(Color.FromArgb(198, 62, 62));
            canvas.FillEllipse(disc, 1, 1, 30, 30);

            using var bars = new SolidBrush(Color.White);
            canvas.FillRectangle(bars, 10, 9, 4, 14);
            canvas.FillRectangle(bars, 18, 9, 4, 14);
        }

        var handle = bitmap.GetHicon();
        using var drawn = Icon.FromHandle(handle);
        // Clone, so the icon outlives the handle we are about to release.
        var owned = (Icon)drawn.Clone();
        NativeMethods.DestroyIcon(handle);
        return owned;
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _clock.Stop();
            _clock.Dispose();
            _configurationChanges?.Dispose();
            _icon.Visible = false;
            _icon.Dispose();
            _drawnIcon.Dispose();
            _engine.Dispose();
            _marshal.Dispose();
        }

        base.Dispose(disposing);
    }
}
