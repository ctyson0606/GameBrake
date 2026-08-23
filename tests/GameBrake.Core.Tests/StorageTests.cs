using GameBrake.Core.Storage;

namespace GameBrake.Core.Tests;

/// <summary>
/// The half of AC7 the reducer cannot reach: that an absolute deadline survives a
/// real round trip through a real file.
/// </summary>
public sealed class StorageTests : IDisposable
{
    private static readonly DateTimeOffset T0 = new(2026, 8, 23, 10, 0, 0, TimeSpan.Zero);
    private static readonly Guid AppId = Guid.Parse("11111111-2222-3333-4444-555555555555");
    private const string Game = @"C:\Program Files\Foo\game.exe";

    private readonly string _directory =
        Path.Combine(Path.GetTempPath(), "gamebrake-" + Guid.NewGuid().ToString("N"));

    public StorageTests() => Directory.CreateDirectory(_directory);

    public void Dispose() => Directory.Delete(_directory, recursive: true);

    private string ConfigurationPath => Path.Combine(_directory, "config.json");

    private string StatePath => Path.Combine(_directory, "state.json");

    // --- config.json ---------------------------------------------------------

    [Fact]
    public void A_first_run_with_no_config_file_gets_the_documented_defaults()
    {
        var configuration = new ConfigurationStore(ConfigurationPath).Load();

        Assert.Equal(300, configuration.CooldownSeconds);
        Assert.Equal(300, configuration.GraceWindowSeconds);
        Assert.True(configuration.Autostart);
        Assert.Empty(configuration.Protected);
    }

    [Fact]
    public void The_config_shape_from_the_data_contract_loads_as_written()
    {
        File.WriteAllText(ConfigurationPath, """
            {
              "cooldownSeconds": 300,
              "graceWindowSeconds": 300,
              "autostart": true,
              "protected": [
                { "id": "11111111-2222-3333-4444-555555555555",
                  "executable": "C:\\Program Files\\Foo\\game.exe",
                  "displayName": "Foo",
                  "enabled": true }
              ]
            }
            """);

        var configuration = new ConfigurationStore(ConfigurationPath).Load();

        var app = Assert.Single(configuration.Protected);
        Assert.Equal(AppId, app.Id);
        Assert.Equal(Game, app.Executable);
        Assert.Equal("Foo", app.DisplayName);
        Assert.True(app.Enabled);
        Assert.Equal(TimeSpan.FromSeconds(300), configuration.Cooldown.Cooldown);
        Assert.Equal(TimeSpan.FromSeconds(300), configuration.Cooldown.GraceWindow);
    }

    [Fact]
    public void A_saved_config_carries_the_key_names_the_contract_documents()
    {
        var store = new ConfigurationStore(ConfigurationPath);
        store.Save(Configuration.Default with
        {
            Protected = [new ProtectedApp(AppId, Game, "Foo", Enabled: true)],
        });

        var json = File.ReadAllText(ConfigurationPath);

        Assert.Contains("\"cooldownSeconds\"", json);
        Assert.Contains("\"graceWindowSeconds\"", json);
        Assert.Contains("\"autostart\"", json);
        Assert.Contains("\"protected\"", json);
        Assert.Contains("\"executable\"", json);
        Assert.Contains("\"displayName\"", json);
    }

    [Fact]
    public void A_damaged_config_is_refused_rather_than_read_as_nothing_protected()
    {
        File.WriteAllText(ConfigurationPath, "{ \"cooldownSeconds\": 300,,, }");

        Assert.Throws<InvalidDataException>(() => new ConfigurationStore(ConfigurationPath).Load());
    }

    // --- matching ------------------------------------------------------------

    [Fact] // A4
    public void Matching_ignores_the_case_of_the_path()
    {
        var configuration = Configuration.Default with
        {
            Protected = [new ProtectedApp(AppId, Game, "Foo", Enabled: true)],
        };

        Assert.NotNull(configuration.Match(@"c:\program files\foo\GAME.EXE"));
    }

    [Fact]
    public void A_disabled_entry_is_treated_as_absent()
    {
        var configuration = Configuration.Default with
        {
            Protected = [new ProtectedApp(AppId, Game, "Foo", Enabled: false)],
        };

        Assert.Null(configuration.Match(Game));
    }

    [Fact] // G4, AC6
    public void An_unprotected_executable_matches_nothing()
    {
        var configuration = Configuration.Default with
        {
            Protected = [new ProtectedApp(AppId, Game, "Foo", Enabled: true)],
        };

        Assert.Null(configuration.Match(@"C:\Windows\System32\notepad.exe"));
    }

    // --- state.json ----------------------------------------------------------

    [Fact]
    public void A_first_run_with_no_state_file_owes_nothing()
    {
        Assert.Empty(new StateStore(StatePath).Load());
    }

    [Fact]
    public void State_written_to_disk_carries_the_shape_the_contract_documents()
    {
        var store = new StateStore(StatePath);
        store.Save(new Dictionary<Guid, AppState>
        {
            [AppId] = new(Phase.Cooling, T0 + TimeSpan.FromSeconds(300), GraceEndsAt: null),
        });

        var json = File.ReadAllText(StatePath);

        Assert.Contains("\"phase\": \"cooling\"", json);
        Assert.Contains("\"cooldownEndsAt\": \"2026-08-23T10:05:00Z\"", json);
        Assert.Contains("\"graceEndsAt\": null", json);
    }

    [Fact] // AC7
    public void A_deadline_survives_the_round_trip_to_the_exact_instant()
    {
        var deadline = T0 + TimeSpan.FromSeconds(300);
        var store = new StateStore(StatePath);
        store.Save(new Dictionary<Guid, AppState>
        {
            [AppId] = new(Phase.Cooling, deadline, GraceEndsAt: null),
        });

        var loaded = store.Load()[AppId];

        Assert.Equal(Phase.Cooling, loaded.Phase);
        Assert.Equal(deadline, loaded.CooldownEndsAt);
    }

    [Fact]
    public void A_deadline_recorded_in_a_local_offset_reloads_as_the_same_instant()
    {
        // The machine was on UTC+8 when the cooldown was charged. Whatever offset it
        // is on when the file is read again, the deadline is the same moment.
        var deadline = new DateTimeOffset(2026, 8, 23, 18, 5, 0, TimeSpan.FromHours(8));
        var store = new StateStore(StatePath);
        store.Save(new Dictionary<Guid, AppState>
        {
            [AppId] = new(Phase.Cooling, deadline, GraceEndsAt: null),
        });

        var loaded = store.Load()[AppId];

        Assert.Equal(deadline.UtcDateTime, loaded.CooldownEndsAt!.Value.UtcDateTime);
        Assert.Contains("2026-08-23T10:05:00Z", File.ReadAllText(StatePath));
    }

    [Fact]
    public void A_damaged_state_file_is_refused_rather_than_read_as_nothing_owed()
    {
        // Corrupting the file must not become the cheapest way out of every cooldown
        // at once.
        File.WriteAllText(StatePath, "{ \"11111111-2222-3333-4444-555555555555\": { \"phase\"");

        Assert.Throws<InvalidDataException>(() => new StateStore(StatePath).Load());
    }

    [Fact]
    public void Saving_replaces_the_previous_file_and_leaves_no_temporary_behind()
    {
        var store = new StateStore(StatePath);
        store.Save(new Dictionary<Guid, AppState> { [AppId] = AppState.Idle });
        store.Save(new Dictionary<Guid, AppState>
        {
            [AppId] = new(Phase.Cooling, T0 + TimeSpan.FromSeconds(300), GraceEndsAt: null),
        });

        Assert.Equal(Phase.Cooling, store.Load()[AppId].Phase);
        Assert.False(File.Exists(StatePath + ".tmp"));
        Assert.Single(Directory.GetFiles(_directory));
    }

    [Fact]
    public void Saving_creates_the_directory_when_it_is_not_there_yet()
    {
        var nested = Path.Combine(_directory, "GameBrake", "state.json");

        new StateStore(nested).Save(new Dictionary<Guid, AppState> { [AppId] = AppState.Idle });

        Assert.True(File.Exists(nested));
    }

    // --- the two halves together ---------------------------------------------

    [Fact] // AC7, end to end across the file
    public void A_cooldown_charged_before_a_restart_is_still_owed_after_one()
    {
        var configuration = Configuration.Default with
        {
            Protected = [new ProtectedApp(AppId, Game, "Foo", Enabled: true)],
        };
        var store = new StateStore(StatePath);

        // Before the restart: the launch is intercepted and the deadline recorded.
        var (charged, action) = Reducer.Reduce(
            AppState.Idle, new BrakeEvent.LaunchAttempt(T0, Game, 4242), configuration.Cooldown);
        store.Save(new Dictionary<Guid, AppState> { [AppId] = charged });
        Assert.Equal(new BrakeAction.Terminate(4242), action);

        // After it: nothing but the file carries the deadline forward.
        var restartedAt = T0 + TimeSpan.FromSeconds(120);
        var restored = store.Load()[AppId];
        var (afterRestart, actionAfterRestart) = Reducer.Reduce(
            restored, new BrakeEvent.LaunchAttempt(restartedAt, Game, 5150), configuration.Cooldown);

        Assert.Equal(new BrakeAction.Terminate(5150), actionAfterRestart);
        Assert.Equal(Phase.Cooling, afterRestart.Phase);
        Assert.Equal(T0 + TimeSpan.FromSeconds(300), afterRestart.CooldownEndsAt);
    }
}
