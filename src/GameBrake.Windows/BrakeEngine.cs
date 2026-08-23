using GameBrake.Core;
using GameBrake.Core.Storage;

namespace GameBrake.Windows;

/// <summary>
/// What happened to one protected application, for the user interface to show.
/// </summary>
/// <param name="App">The entry from the configuration.</param>
/// <param name="State">Where it stands now.</param>
/// <param name="Remaining">
/// Time left on whichever deadline is running, or null when none is.
/// </param>
public sealed record AppStatus(ProtectedApp App, AppState State, TimeSpan? Remaining);

/// <summary>
/// A launch that was refused, raised so the user is told rather than left
/// wondering why the window vanished (AC8).
/// </summary>
public sealed record BlockedLaunch(ProtectedApp App, TimeSpan Remaining);

/// <summary>
/// Wires the watcher, the reducer, the store and the enforcer together. Holds no
/// policy of its own: every decision here comes back from
/// <see cref="Reducer.Reduce"/>.
/// </summary>
public sealed class BrakeEngine : IDisposable
{
    private readonly object _gate = new();
    private readonly Dictionary<Guid, AppState> _states;
    private readonly StateStore _store;
    private readonly IProcessWatcher _watcher;
    private readonly IProcessTerminator _terminator;
    private readonly TimeProvider _time;

    private Configuration _configuration;
    private bool _disposed;

    public BrakeEngine(
        Configuration configuration,
        StateStore store,
        IProcessWatcher watcher,
        IProcessTerminator terminator,
        TimeProvider? time = null)
    {
        _configuration = configuration;
        _store = store;
        _watcher = watcher;
        _terminator = terminator;
        _time = time ?? TimeProvider.System;
        _states = new Dictionary<Guid, AppState>(store.Load());
        _watcher.Observed += OnObserved;
    }

    /// <summary>Raised whenever anything the user interface shows has moved.</summary>
    public event EventHandler? Changed;

    /// <summary>Raised when a launch was refused.</summary>
    public event EventHandler<BlockedLaunch>? Blocked;

    /// <summary>
    /// Raised when a termination did not take. The cooldown has been charged and
    /// the application is still running, which the user should not have to guess at.
    /// </summary>
    public event EventHandler<ProtectedApp>? TerminationFailed;

    public void Start() => _watcher.Start();

    /// <summary>
    /// Swap in a configuration the user has edited, without discharging anything.
    /// State is keyed by application id, so an entry that survives the edit keeps
    /// whatever it owed (G3).
    /// </summary>
    public void Reconfigure(Configuration configuration)
    {
        lock (_gate)
        {
            _configuration = configuration;
        }

        Changed?.Invoke(this, EventArgs.Empty);
    }

    /// <summary>
    /// Let deadlines that have passed take effect. Only the display depends on
    /// this being called: the reducer settles expiries itself on every event, so a
    /// tick that never arrives cannot let a launch through.
    /// </summary>
    public void Tick()
    {
        var now = _time.GetUtcNow();
        var moved = false;

        lock (_gate)
        {
            foreach (var id in _states.Keys.ToList())
            {
                var (next, _) = Reducer.Reduce(
                    _states[id], new BrakeEvent.Tick(now), _configuration.Cooldown);

                if (next != _states[id])
                {
                    _states[id] = next;
                    moved = true;
                }
            }

            if (moved)
            {
                _store.Save(_states);
            }
        }

        if (moved)
        {
            Changed?.Invoke(this, EventArgs.Empty);
        }
    }

    /// <summary>What to show: one line per protected application.</summary>
    public IReadOnlyList<AppStatus> Status()
    {
        var now = _time.GetUtcNow();

        lock (_gate)
        {
            return _configuration.Protected
                .Select(app =>
                {
                    var state = _states.TryGetValue(app.Id, out var known) ? known : AppState.Idle;
                    state = Reducer.Advance(state, now, _configuration.Cooldown);
                    return new AppStatus(app, state, RemainingOf(state, now));
                })
                .ToList();
        }
    }

    private static TimeSpan? RemainingOf(AppState state, DateTimeOffset now) => state.Phase switch
    {
        Phase.Cooling when state.CooldownEndsAt is { } ends => ends - now,
        Phase.Unlocked when state.GraceEndsAt is { } ends => ends - now,
        _ => null,
    };

    private void OnObserved(object? sender, BrakeEvent observed)
    {
        var executablePath = observed switch
        {
            BrakeEvent.LaunchAttempt launch => launch.ExecutablePath,
            BrakeEvent.ProcessExited exited => exited.ExecutablePath,
            _ => null,
        };

        if (executablePath is null)
        {
            return;
        }

        ProtectedApp? app;
        BrakeAction action;
        TimeSpan remaining;

        lock (_gate)
        {
            // Anything not on the list is none of our business, and finding that
            // out is the only thing that happens to it (G4, AC6).
            app = _configuration.Match(executablePath);
            if (app is null)
            {
                return;
            }

            var current = _states.TryGetValue(app.Id, out var known) ? known : AppState.Idle;
            var (next, produced) = Reducer.Reduce(current, observed, _configuration.Cooldown);
            action = produced;

            // The state goes to disk before the action is carried out. Should this
            // process die in between, the cooldown is still owed; the other order
            // would lose it, and losing it is the failure that matters (AC7).
            _states[app.Id] = next;
            _store.Save(_states);

            remaining = RemainingOf(next, observed.Now) ?? TimeSpan.Zero;
        }

        Act(action, observed, app, remaining);
        Changed?.Invoke(this, EventArgs.Empty);
    }

    private void Act(BrakeAction action, BrakeEvent observed, ProtectedApp app, TimeSpan remaining)
    {
        switch (action)
        {
            case BrakeAction.Terminate terminate:
                if (_terminator.Terminate(terminate.ProcessId))
                {
                    Blocked?.Invoke(this, new BlockedLaunch(app, remaining));
                }
                else
                {
                    TerminationFailed?.Invoke(this, app);
                }

                break;

            case BrakeAction.Allow when observed is BrakeEvent.LaunchAttempt launch:
                // Follow it, or its ending goes unnoticed and the next launch is
                // never charged (AC5).
                _watcher.WatchForExit(launch.ProcessId, launch.ExecutablePath);
                break;
        }
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        _watcher.Observed -= OnObserved;
        _watcher.Dispose();
    }
}
