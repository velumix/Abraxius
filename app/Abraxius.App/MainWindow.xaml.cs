using System.Diagnostics;
using System.Collections.ObjectModel;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Windows.Input;
using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using Microsoft.Web.WebView2.Core;
using Windows.ApplicationModel;
using Windows.ApplicationModel.DataTransfer;
using WinRT.Interop;

namespace Abraxius.App;

public sealed partial class MainWindow : Window
{
    private static readonly Uri ApiBase = new("http://127.0.0.1:13470/");
    private static readonly Uri AnalyticsBase = new("http://127.0.0.1:13472/");

    private readonly HttpClient _http = new() { BaseAddress = ApiBase, Timeout = TimeSpan.FromSeconds(1) };
    private readonly HttpClient _analytics = new() { BaseAddress = AnalyticsBase, Timeout = TimeSpan.FromSeconds(1) };
    private readonly Dictionary<int, ProcessSample> _processSamples = new();
    private readonly DispatcherTimer _timer = new() { Interval = TimeSpan.FromSeconds(2) };
    private readonly DispatcherTimer _editorRecoveryTimer = new() { Interval = TimeSpan.FromMilliseconds(750) };
    private readonly SemaphoreSlim _serverLifecycle = new(1, 1);
    private readonly SemaphoreSlim _refreshGate = new(1, 1);
    private readonly AppWindow _appWindow;
    private readonly H.NotifyIcon.TaskbarIcon _trayIcon;
    private StartupTask? _startupTask;
    private Process? _daemonProcess;
    private int _quitStarted;
    private DateTimeOffset _nextSupervisionAttempt = DateTimeOffset.MinValue;
    private string? _lastStartError;
    private Health? _lastHealth;
    private bool _allowClose;
    private bool _quitting;
    private bool _intentionalStop;
    private bool _initializing = true;
    private string? _bundledPluginVersion;
    private string? _pluginUpdatePromptedVersion;
    private bool _pluginUpdatePromptActive;
    private IReadOnlyList<OutputRow> _latestOutput = Array.Empty<OutputRow>();
    private readonly ObservableCollection<OutputRow> _playtestOutputItems = new();
    private readonly ObservableCollection<OutputRow> _outputItems = new();
    private readonly ObservableCollection<ScriptActivityRow> _scriptActivityItems = new();
    private readonly ObservableCollection<CommandHistoryRow> _commandHistoryItems = new();
    private readonly ObservableCollection<ApprovalQueueRow> _approvalQueueItems = new();
    private readonly ObservableCollection<ScriptExplorerRow> _scriptExplorerItems = new();
    private readonly Dictionary<string, EditorDocument> _editorDocuments = new(StringComparer.Ordinal);
    private readonly IAiProvider _aiProvider = new GuardedAiProvider(new OllamaProvider());
    private readonly List<AiMessage> _aiConversation = new();
    private readonly ObservableCollection<AiMemoryItem> _aiMemories = new();
    private readonly ObservableCollection<IntelligenceEventRow> _intelligenceTimeline = new();
    private readonly ObservableCollection<IntelligenceSuggestionRow> _intelligenceSuggestions = new();
    private readonly HashSet<string> _intelligenceSeenOutput = new(StringComparer.Ordinal);
    private readonly HashSet<string> _intelligenceSeenScripts = new(StringComparer.Ordinal);
    private readonly HashSet<string> _activeIntelligenceSignals = new(StringComparer.Ordinal);
    private readonly Dictionary<string, int> _errorSignatures = new(StringComparer.Ordinal);
    private IReadOnlyList<ScriptExplorerRow> _allExplorerScripts = Array.Empty<ScriptExplorerRow>();
    private readonly Dictionary<string, JsonElement> _commandSchemas = new(StringComparer.Ordinal);
    private readonly HashSet<string> _favoriteCommands = new(StringComparer.Ordinal);
    private readonly Dictionary<string, CommandPreset> _commandPresets = new(StringComparer.Ordinal);
    private readonly Dictionary<string, CommandWorkflow> _commandWorkflows = new(StringComparer.Ordinal);
    private readonly Dictionary<string, FrameworkElement> _structuredArgumentControls = new(StringComparer.Ordinal);
    private int _historyRetention = 100;
    private bool _syncingStructuredArguments;
    private bool _commandCatalogLoaded;
    private bool _editorInitializing;
    private bool _editorReady;
    private bool _editorDirty;
    private string? _editorLoadedPath;
    private string? _editorSourceHash;
    private bool _switchingEditorTab;
    private bool _scriptExplorerLoaded;
    private string? _styluaPath;
    private string? _luauAnalyzePath;
    private CancellationTokenSource? _aiCancellation;
    private bool _aiInitialized;
    private string _aiProjectId = "local-workspace";
    private string? _lastIntelligenceMode;
    private double? _lastIntelligenceMemory;
    private double? _lastIntelligencePhysics;
    private int? _lastIntelligenceInstances;
    private int? _lastIntelligencePlayers;

    public MainWindow()
    {
        InitializeComponent();
        PlaytestOutputList.ItemsSource = _playtestOutputItems;
        OutputList.ItemsSource = _outputItems;
        ScriptActivityList.ItemsSource = _scriptActivityItems;
        CommandHistoryList.ItemsSource = _commandHistoryItems;
        ApprovalQueueList.ItemsSource = _approvalQueueItems;
        ScriptExplorerList.ItemsSource = _scriptExplorerItems;
        AiMemoryList.ItemsSource = _aiMemories;
        IntelligenceTimelineList.ItemsSource = _intelligenceTimeline;
        IntelligenceSuggestionList.ItemsSource = _intelligenceSuggestions;
        LoadCommandWorkspaceState();
        _trayIcon = new H.NotifyIcon.TaskbarIcon();
        Title = "Abraxius";
        ExtendsContentIntoTitleBar = true;
        SetTitleBar(AppTitleBar);

        var hwnd = WindowNative.GetWindowHandle(this);
        var windowId = Win32Interop.GetWindowIdFromWindow(hwnd);
        _appWindow = AppWindow.GetFromWindowId(windowId);
        _appWindow.Resize(new Windows.Graphics.SizeInt32(1080, 760));
        if (_appWindow.Presenter is OverlappedPresenter presenter)
        {
            presenter.PreferredMinimumWidth = 760;
            presenter.PreferredMinimumHeight = 560;
        }
        _appWindow.Closing += AppWindow_Closing;

        var trayMenu = new MenuFlyout();
        var openItem = new MenuFlyoutItem { Text = "Open Abraxius", Icon = new SymbolIcon(Symbol.OpenFile) };
        openItem.Command = new RelayCommand(ShowWindow);
        var restartItem = new MenuFlyoutItem { Text = "Restart server", Icon = new SymbolIcon(Symbol.Refresh) };
        restartItem.Command = new AsyncRelayCommand(RestartServerAsync, HandleTrayCommandError);
        var quitItem = new MenuFlyoutItem { Text = "Quit Abraxius" };
        quitItem.Command = new RelayCommand(() => _ = QuitAsync());
        trayMenu.Items.Add(openItem);
        trayMenu.Items.Add(restartItem);
        trayMenu.Items.Add(new MenuFlyoutSeparator());
        trayMenu.Items.Add(quitItem);
        var trayIconPath = Path.Combine(AppContext.BaseDirectory, "Assets", "Tray.ico");
        if (File.Exists(trayIconPath))
        {
            _trayIcon.IconSource = new BitmapImage(new Uri(trayIconPath, UriKind.Absolute));
        }
        else
        {
            AppDiagnostics.RecordUnhandled(new FileNotFoundException(
                "The tray icon is unavailable. Abraxius will continue without a notification-area icon.",
                trayIconPath));
        }
        _trayIcon.ToolTipText = "Abraxius";
        _trayIcon.ContextFlyout = trayMenu;
        _trayIcon.DoubleClickCommand = new RelayCommand(ShowWindow);
        _trayIcon.ForceCreate();

        _ = InitializeStartupAsync();
        _timer.Tick += async (_, _) => await RefreshAsync();
        _timer.Start();
        _editorRecoveryTimer.Tick += async (_, _) => { _editorRecoveryTimer.Stop(); await SaveEditorSessionAsync(); };
        Activated += async (_, _) => await RefreshAsync();
        if (Environment.GetCommandLineArgs().Any(arg => arg == "--smoke-quit"))
        {
            _ = SmokeQuitAsync();
        }
    }

    private void RootGrid_SizeChanged(object sender, SizeChangedEventArgs e) => ConfigureResponsiveLayout(e.NewSize.Width);

    private void ConfigureResponsiveLayout(double width)
    {
        var compact = width < 860;
        var medium = width < 1120;
        CategoryNavigation.PaneDisplayMode = medium ? NavigationViewPaneDisplayMode.LeftCompact : NavigationViewPaneDisplayMode.Left;

        ConfigureThreeCardGrid(HomeStatusGrid, ServerStatusCard, StudioStatusCard, PluginStatusCard, compact);
        ConfigureThreeCardGrid(SyncStatsGrid, WatchedScriptsCard, RecentChangesCard, ScriptModeCard, compact);

        HomeControlsGrid.RowDefinitions.Clear();
        if (compact)
        {
            HomeControlsGrid.ColumnDefinitions[0].Width = new GridLength(1, GridUnitType.Star);
            HomeControlsGrid.ColumnDefinitions[1].Width = new GridLength(0);
            HomeControlsGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            HomeControlsGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            Grid.SetColumn(ServerControlsCard, 0); Grid.SetRow(ServerControlsCard, 0);
            Grid.SetColumn(RuntimeCard, 0); Grid.SetRow(RuntimeCard, 1);
        }
        else
        {
            HomeControlsGrid.ColumnDefinitions[0].Width = new GridLength(1.1, GridUnitType.Star);
            HomeControlsGrid.ColumnDefinitions[1].Width = new GridLength(0.9, GridUnitType.Star);
            HomeControlsGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            Grid.SetColumn(ServerControlsCard, 0); Grid.SetRow(ServerControlsCard, 0);
            Grid.SetColumn(RuntimeCard, 1); Grid.SetRow(RuntimeCard, 0);
        }

        if (medium)
        {
            CommandsLayoutGrid.ColumnDefinitions[0].Width = new GridLength(1, GridUnitType.Star);
            CommandsLayoutGrid.ColumnDefinitions[1].Width = new GridLength(0);
            Grid.SetColumn(ApprovalQueuePanel, 0);
            Grid.SetRow(ApprovalQueuePanel, 1);
            ApprovalQueuePanel.Margin = new Thickness(0);
        }
        else
        {
            CommandsLayoutGrid.ColumnDefinitions[0].Width = new GridLength(1.05, GridUnitType.Star);
            CommandsLayoutGrid.ColumnDefinitions[1].Width = new GridLength(0.95, GridUnitType.Star);
            Grid.SetColumn(ApprovalQueuePanel, 1);
            Grid.SetRow(ApprovalQueuePanel, 0);
            ApprovalQueuePanel.Margin = new Thickness(0, 66, 0, 0);
        }

        CodeExplorerPanel.Visibility = width < 860 ? Visibility.Collapsed : Visibility.Visible;
        CodeExplorerColumn.Width = width < 860 ? new GridLength(0) : new GridLength(medium ? 190 : 230);
        CodeInspectorPanel.Visibility = width < 720 ? Visibility.Collapsed : Visibility.Visible;
        CodeInspectorColumn.Width = width < 720 ? new GridLength(0) : new GridLength(medium ? 250 : 300);
        AiContextColumn.Width = new GridLength(medium ? 260 : 320);
        IntelligenceTimelineColumn.Width = compact ? new GridLength(0) : new GridLength(medium ? 0.7 : 0.8, GridUnitType.Star);
        IntelligenceWorkspaceGrid.ColumnDefinitions[1].Width = compact ? new GridLength(1, GridUnitType.Star) : new GridLength(medium ? 1.3 : 1.2, GridUnitType.Star);
        IntelligenceSettingsColumn.Width = compact ? new GridLength(0) : new GridLength(medium ? 250 : 300);
    }

    private static void ConfigureThreeCardGrid(Grid grid, FrameworkElement first, FrameworkElement second, FrameworkElement third, bool compact)
    {
        grid.RowDefinitions.Clear();
        if (compact)
        {
            grid.ColumnDefinitions[0].Width = new GridLength(1, GridUnitType.Star);
            grid.ColumnDefinitions[1].Width = new GridLength(0);
            grid.ColumnDefinitions[2].Width = new GridLength(0);
            for (var index = 0; index < 3; index++) grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            Grid.SetColumn(first, 0); Grid.SetRow(first, 0);
            Grid.SetColumn(second, 0); Grid.SetRow(second, 1);
            Grid.SetColumn(third, 0); Grid.SetRow(third, 2);
        }
        else
        {
            for (var index = 0; index < 3; index++) grid.ColumnDefinitions[index].Width = new GridLength(1, GridUnitType.Star);
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            Grid.SetColumn(first, 0); Grid.SetRow(first, 0);
            Grid.SetColumn(second, 1); Grid.SetRow(second, 0);
            Grid.SetColumn(third, 2); Grid.SetRow(third, 0);
        }
    }

    private async Task RefreshAsync()
    {
        if (_quitting || !await _refreshGate.WaitAsync(0))
        {
            return;
        }

        try
        {
            var health = await _http.GetFromJsonAsync<Health>("health");
            if (_quitting)
            {
                return;
            }
            if (health?.Running != true)
            {
                throw new HttpRequestException("Host did not report a running state.");
            }

            ServerStatus.Text = "Running";
            ServerDot.Fill = ThemeBrush("SystemFillColorSuccessBrush");
            StudioStatus.Text = health.Connected ? "Connected" : "Waiting";
            StudioDot.Fill = ThemeBrush(health.Connected ? "SystemFillColorSuccessBrush" : "SystemFillColorCautionBrush");
            PluginStatus.Text = health.PluginConnected ? "Connected" : "Waiting";
            PluginDot.Fill = ThemeBrush(health.PluginConnected ? "SystemFillColorSuccessBrush" : "SystemFillColorCautionBrush");
            DetailText.Text = $"Rust host v{health.Version ?? "0.1.0"}  |  PID {health.Pid?.ToString() ?? "unknown"}  |  Uptime {FormatDuration(health.Uptime)}";
            _lastHealth = health;
            await RefreshPluginInstallStateAsync(health.PluginVersion);
            await RefreshAnalyticsAsync(health.Pid);
            HostVersionText.Text = health.Version ?? "0.1.0";
            ProcessIdText.Text = health.Pid?.ToString() ?? "--";
            UptimeText.Text = FormatDuration(health.Uptime);
            ToolsLoadedText.Text = health.ToolsLoaded == 1 ? "1 tool" : $"{health.ToolsLoaded} tools";
            LastCheckedText.Text = DateTimeOffset.Now.ToString("h:mm:ss tt");
            TransportText.Text = health.PluginConnected ? "Companion" : health.Connected ? "Legacy MCP" : "Unavailable";
            SupervisionStatusText.Text = SupervisionToggle.IsOn ? "Enabled" : "Paused";
            if (health.PluginConnected)
            {
                ConnectionInfoBar.Severity = InfoBarSeverity.Success;
                ConnectionInfoBar.Title = "Studio companion connected";
                ConnectionInfoBar.Message = "Inspection, full pull, and existing-script push are available.";
            }
            else if (health.Connected)
            {
                ConnectionInfoBar.Severity = InfoBarSeverity.Success;
                ConnectionInfoBar.Title = "Legacy MCP connected";
                ConnectionInfoBar.Message = "MCP tools are available; the companion is still waiting.";
            }
            else
            {
                ConnectionInfoBar.Severity = InfoBarSeverity.Warning;
                ConnectionInfoBar.Title = "Waiting for Studio";
                ConnectionInfoBar.Message = "Open Studio with the Abraxius companion to enable sync.";
            }
            StartButtonText.Text = "Restart server";
            StopButton.IsEnabled = true;
            _trayIcon.ToolTipText = "Abraxius - server running";
        }
        catch
        {
            if (_quitting)
            {
                return;
            }

            ServerStatus.Text = "Stopped";
            _lastHealth = null;
            await RefreshPluginInstallStateAsync(null);
            await RefreshAnalyticsAsync(null);
            ServerDot.Fill = ThemeBrush("SystemFillColorCriticalBrush");
            StudioStatus.Text = "Offline";
            StudioDot.Fill = ThemeBrush("SystemFillColorNeutralBrush");
            PluginStatus.Text = "Offline";
            PluginDot.Fill = ThemeBrush("SystemFillColorNeutralBrush");
            DetailText.Text = _lastStartError ?? "The local Abraxius API is not available.";
            HostVersionText.Text = "--";
            ProcessIdText.Text = "--";
            UptimeText.Text = "--";
            ToolsLoadedText.Text = "--";
            LastCheckedText.Text = DateTimeOffset.Now.ToString("h:mm:ss tt");
            TransportText.Text = "Unavailable";
            SupervisionStatusText.Text = SupervisionToggle.IsOn ? "Retrying" : "Paused";
            ConnectionInfoBar.Severity = InfoBarSeverity.Warning;
            ConnectionInfoBar.Title = "Server unavailable";
            ConnectionInfoBar.Message = "Open logs for startup details or start the Rust host again.";
            StartButtonText.Text = "Start server";
            StopButton.IsEnabled = false;
            _trayIcon.ToolTipText = "Abraxius - server stopped";

            if (SupervisionToggle.IsOn && !_intentionalStop && DateTimeOffset.Now >= _nextSupervisionAttempt)
            {
                _nextSupervisionAttempt = DateTimeOffset.Now.AddSeconds(10);
                await StartServerAsync(showErrors: false);
                if (_lastStartError is not null)
                {
                    DetailText.Text = $"{_lastStartError} Automatic retry is paused for 10 seconds.";
                }
            }
        }
        finally
        {
            _refreshGate.Release();
        }
    }

    private async Task RefreshAnalyticsAsync(uint? daemonPid)
    {
        try
        {
            var analytics = await _analytics.GetFromJsonAsync<AnalyticsSnapshot>("snapshot");
            var studio = analytics?.Studio;
            if (analytics?.Connected == true && studio is not null)
            {
                AnalyticsDot.Fill = ThemeBrush("SystemFillColorSuccessBrush");
                AnalyticsFreshnessText.Text = analytics.AgeMs is long age
                    ? $"Live  |  {age / 1000.0:0.0}s old  |  :13472"
                    : "Live  |  :13472";
                StudioMemoryText.Text = studio.TotalMemoryMb is double memory
                    ? $"Memory  {memory:0.0} MB"
                    : "Memory  unavailable";
                StudioRoleText.Text = $"Role  {studio.Mode ?? "Unknown"}  |  {(studio.IsClient ? "client" : studio.IsServer ? "server" : "editor")}";
                StudioPhysicsText.Text = studio.PhysicsFps is double fps
                    ? $"Physics  {fps:0.0} Hz  |  probe {studio.LatencyMs} ms"
                    : $"Probe latency  {studio.LatencyMs} ms";
                PlayerCountText.Text = $"Players  {studio.Players}";
                InstanceCountText.Text = $"Instances  {studio.Counts?.Instances.ToString("N0") ?? "--"}";
                ScriptCountText.Text = $"Scripts  {studio.Counts?.Scripts.ToString("N0") ?? "--"}";
                PartCountText.Text = $"Parts  {studio.Counts?.Parts.ToString("N0") ?? "--"}";
                UpdatePlaytestViews(studio);
                ProcessStudioIntelligence(studio);
            }
            else
            {
                SetAnalyticsUnavailable("Probe waiting  |  :13472");
            }
        }
        catch
        {
            SetAnalyticsUnavailable("Analytics offline  |  :13472");
        }

        DaemonResourcesText.Text = daemonPid is uint pid
            ? FormatProcessResources("Rust host", TryGetProcess((int)pid))
            : "Rust host  --";
        var studioProcess = Process.GetProcesses()
            .Where(process => process.ProcessName.Contains("RobloxStudio", StringComparison.OrdinalIgnoreCase))
            .Select(process => TryGetProcess(process.Id))
            .Where(process => process is not null)
            .OrderByDescending(process => process!.WorkingSet64)
            .FirstOrDefault();
        StudioResourcesText.Text = FormatProcessResources("Studio", studioProcess);
    }

    private void UpdatePlaytestViews(StudioAnalytics studio)
    {
        var playtest = studio.Playtest;
        PlaytestStateText.Text = playtest?.Enabled == false ? "Collection off" : playtest?.Active == true ? "Running" : "Stopped";
        PlaytestDurationText.Text = playtest is null || !playtest.Enabled ? "--" : FormatDuration((ulong)Math.Max(0, playtest.ElapsedSec));
        PlaytestErrorText.Text = playtest?.Errors.ToString() ?? "0";
        PlaytestWarningText.Text = playtest?.Warnings.ToString() ?? "0";
        PlaytestPrintText.Text = playtest?.Prints.ToString() ?? "0";
        PlaytestMemoryText.Text = studio.TotalMemoryMb is double memory ? $"Memory  {memory:0.0} MB" : "Memory  --";
        PlaytestPlayersText.Text = $"Players  {studio.Players}";
        PlaytestPhysicsText.Text = studio.PhysicsFps is double fps ? $"Physics  {fps:0.0} Hz" : "Physics  --";
        PlaytestSceneText.Text = $"Scene  {studio.Counts?.Instances.ToString("N0") ?? "--"} instances  |  {studio.Counts?.Parts.ToString("N0") ?? "--"} parts";

        _latestOutput = (playtest?.Output ?? Array.Empty<StudioOutput>())
            .Select(output => new OutputRow(
                $"{output.Time}:{output.Level}:{output.Script}:{output.Line}:{output.Message}",
                FormatTimestamp(output.Time),
                FormatOutputLevel(output.Level),
                output.Message ?? string.Empty,
                output.Script is null ? (output.Playtest ? "Playtest" : "Studio") : $"{output.Script}{(output.Line is int line ? $":{line}" : string.Empty)}",
                output.Level ?? "print"))
            .ToArray();
        SyncCollection(_playtestOutputItems, _latestOutput.Take(30).ToArray(), item => item.Key);
        ApplyOutputFilter();

        var scriptRows = (studio.ScriptActivity ?? Array.Empty<StudioScriptActivity>())
            .Select(activity => new ScriptActivityRow(
                $"{activity.Time}:{activity.Path}:{activity.SourceLength}",
                FormatTimestamp(activity.Time),
                activity.Path ?? "Unknown script",
                $"{activity.SourceLength:N0} chars"))
            .ToArray();
        SyncCollection(_scriptActivityItems, scriptRows, item => item.Key);
        WatchedScriptsText.Text = studio.Counts?.Scripts.ToString("N0") ?? "--";
        RecentScriptChangesText.Text = scriptRows.Length.ToString();
        ScriptModeText.Text = studio.Mode ?? "--";

        var errors = playtest?.Errors ?? 0;
        var warnings = playtest?.Warnings ?? 0;
        OutputSummaryBar.Severity = errors > 0 ? InfoBarSeverity.Error : warnings > 0 ? InfoBarSeverity.Warning : InfoBarSeverity.Informational;
        OutputSummaryBar.Title = playtest?.Enabled == false ? "Play data analytics disabled" : _latestOutput.Count == 0 ? "No output captured" : $"{errors} errors  |  {warnings} warnings  |  {playtest?.Prints ?? 0} prints";
        OutputSummaryBar.Message = playtest?.Enabled == false ? "Enable it from the companion Signals page to collect runtime output." : playtest?.Active == true ? "Streaming the current playtest." : "Showing the most recently captured Studio session.";
    }

    private static string FormatTimestamp(long time)
    {
        try { return DateTimeOffset.FromUnixTimeMilliseconds(time).ToLocalTime().ToString("HH:mm:ss"); }
        catch { return "--:--:--"; }
    }

    private static string FormatOutputLevel(string? level) => level switch
    {
        "error" => "ERROR",
        "warning" => "WARNING",
        "info" => "INFO",
        _ => "PRINT",
    };

    private void ProcessStudioIntelligence(StudioAnalytics studio)
    {
        var role = studio.IsClient ? "Client" : studio.IsServer ? "Server" : "Editor";
        var mode = $"{studio.Mode ?? "Unknown"} / {role}";
        if (_lastIntelligenceMode != mode) { AddIntelligenceEvent("Mode transition", _lastIntelligenceMode is null ? $"Connected in {mode}" : $"{_lastIntelligenceMode} → {mode}"); _lastIntelligenceMode = mode; }
        if (_lastIntelligencePlayers is int oldPlayers && oldPlayers != studio.Players) AddIntelligenceEvent("Player count changed", $"{oldPlayers} → {studio.Players}");
        _lastIntelligencePlayers = studio.Players;
        if (IntelligenceChangesToggle.IsOn)
        {
            foreach (var activity in studio.ScriptActivity ?? Array.Empty<StudioScriptActivity>())
            {
                var key = $"{activity.Time}:{activity.Path}";
                if (_intelligenceSeenScripts.Add(key)) AddIntelligenceEvent("Script changed", $"{activity.Path ?? "Unknown script"} • {activity.SourceLength:N0} characters");
            }
        }
        var newOutput = _latestOutput.Where(item => _intelligenceSeenOutput.Add(item.Key)).ToArray();
        if (IntelligenceErrorsToggle.IsOn)
        {
            foreach (var item in newOutput.Where(item => item.Level is "error" or "warning"))
            {
                AddIntelligenceEvent(item.Level == "error" ? "Runtime error" : "Runtime warning", $"{item.Message} • {item.Location}");
                if (item.Level != "error") continue;
                var signature = NormalizeErrorSignature(item.Message);
                _errorSignatures[signature] = _errorSignatures.GetValueOrDefault(signature) + 1;
                var correlated = (studio.ScriptActivity ?? Array.Empty<StudioScriptActivity>()).FirstOrDefault(activity => !string.IsNullOrEmpty(activity.Path) && item.Location.Contains(activity.Path, StringComparison.OrdinalIgnoreCase));
                AddIntelligenceSuggestion("Investigate runtime error", correlated is null ? $"{item.Message}\nLocation: {item.Location}" : $"{item.Message}\nLocation: {item.Location}\nCorrelated recent edit: {correlated.Path}", correlated is null ? 0.72 : 0.92, $"error:{signature}");
                if (_errorSignatures[signature] >= (int)IntelligenceRepeatThreshold.Value) AddIntelligenceSuggestion("Repeated runtime failure", $"The same normalized error occurred {_errorSignatures[signature]} times.\n{item.Message}", 0.95, $"repeat:{signature}");
            }
            var warningCount = newOutput.Count(item => item.Level == "warning");
            if (warningCount >= (int)IntelligenceWarningThreshold.Value) AddIntelligenceSuggestion("Warning spike detected", $"{warningCount} new warnings arrived in one monitoring interval.", 0.86, $"warnings:{DateTimeOffset.Now:yyyyMMddHHmm}");
        }
        if (IntelligencePerformanceToggle.IsOn)
        {
            if (studio.TotalMemoryMb is double memory) { var delta = _lastIntelligenceMemory is double old ? memory - old : 0; RaisePerformanceSignal("memory", delta >= IntelligenceMemoryThreshold.Value, "Memory increased sharply", $"Studio memory increased by {delta:0.0} MB to {memory:0.0} MB.", 0.82); _lastIntelligenceMemory = memory; }
            if (studio.PhysicsFps is double physics) { RaisePerformanceSignal("physics", physics > 0 && physics < IntelligencePhysicsThreshold.Value, "Low physics rate", $"Physics is {physics:0.0} Hz; threshold is {IntelligencePhysicsThreshold.Value:0}.", 0.88); _lastIntelligencePhysics = physics; }
            if (studio.Counts is StudioCounts counts) { var delta = _lastIntelligenceInstances is int old ? counts.Instances - old : 0; RaisePerformanceSignal("instances", delta >= 500, "Instance-count jump", $"Instances increased by {delta:N0} to {counts.Instances:N0}.", 0.78); _lastIntelligenceInstances = counts.Instances; }
        }
        IntelligenceStatusText.Text = IsIntelligenceQuietTime() ? "Observing • quiet hours" : $"Observing • {_intelligenceSuggestions.Count} suggestions";
    }

    private void RaisePerformanceSignal(string key, bool active, string title, string evidence, double confidence)
    {
        if (!active) { _activeIntelligenceSignals.Remove(key); return; }
        if (_activeIntelligenceSignals.Add(key)) AddIntelligenceSuggestion(title, evidence, confidence, $"performance:{key}:{DateTimeOffset.Now:yyyyMMddHH}");
    }

    private void AddIntelligenceEvent(string title, string detail)
    {
        _intelligenceTimeline.Insert(0, new IntelligenceEventRow(DateTimeOffset.Now.ToString("MMM d • h:mm:ss tt"), title, detail));
        while (_intelligenceTimeline.Count > 250) _intelligenceTimeline.RemoveAt(_intelligenceTimeline.Count - 1);
        SaveIntelligenceState();
    }

    private void AddIntelligenceSuggestion(string title, string evidence, double confidence, string key)
    {
        if (IsIntelligenceQuietTime() || _intelligenceSuggestions.Any(item => item.Key == key)) return;
        _intelligenceSuggestions.Insert(0, new IntelligenceSuggestionRow(key, DateTimeOffset.Now.ToString("MMM d • h:mm:ss tt"), title, evidence, $"{confidence:P0}"));
        while (_intelligenceSuggestions.Count > 100) _intelligenceSuggestions.RemoveAt(_intelligenceSuggestions.Count - 1);
        SaveIntelligenceState();
    }

    private bool IsIntelligenceQuietTime() => IntelligenceQuietHoursToggle.IsOn && (DateTimeOffset.Now.Hour >= 22 || DateTimeOffset.Now.Hour < 8);
    private static string NormalizeErrorSignature(string message) => System.Text.RegularExpressions.Regex.Replace(message.ToLowerInvariant(), "\\d+", "#").Trim();

    private void ApplyOutputFilter()
    {
        if (OutputList is null || OutputFilter?.SelectedItem is not ComboBoxItem selected)
        {
            return;
        }
        var filter = selected.Tag?.ToString() ?? "all";
        var filtered = filter switch
        {
            "error" => _latestOutput.Where(item => item.Level == "error").ToArray(),
            "warning" => _latestOutput.Where(item => item.Level == "warning").ToArray(),
            "print" => _latestOutput.Where(item => item.Level is "print" or "info").ToArray(),
            _ => _latestOutput.ToArray(),
        };
        SyncCollection(_outputItems, filtered, item => item.Key);
    }

    private static void SyncCollection<T>(ObservableCollection<T> target, IReadOnlyList<T> desired, Func<T, string> keySelector)
    {
        var desiredKeys = desired.Select(keySelector).ToHashSet(StringComparer.Ordinal);
        for (var index = target.Count - 1; index >= 0; index--)
        {
            if (!desiredKeys.Contains(keySelector(target[index])))
            {
                target.RemoveAt(index);
            }
        }

        for (var index = 0; index < desired.Count; index++)
        {
            var key = keySelector(desired[index]);
            if (index < target.Count && keySelector(target[index]) == key)
            {
                continue;
            }
            var existingIndex = -1;
            for (var candidate = index + 1; candidate < target.Count; candidate++)
            {
                if (keySelector(target[candidate]) == key)
                {
                    existingIndex = candidate;
                    break;
                }
            }
            if (existingIndex >= 0)
            {
                target.Move(existingIndex, index);
            }
            else
            {
                target.Insert(index, desired[index]);
            }
        }
        while (target.Count > desired.Count)
        {
            target.RemoveAt(target.Count - 1);
        }
    }

    private void CategoryNavigation_SelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        var tag = (args.SelectedItemContainer as NavigationViewItem)?.Tag?.ToString() ?? "overview";
        OverviewPage.Visibility = tag == "overview" ? Visibility.Visible : Visibility.Collapsed;
        PlaytestPage.Visibility = tag == "playtest" ? Visibility.Visible : Visibility.Collapsed;
        IntelligencePage.Visibility = tag == "intelligence" ? Visibility.Visible : Visibility.Collapsed;
        OutputPage.Visibility = tag == "output" ? Visibility.Visible : Visibility.Collapsed;
        ScriptsPage.Visibility = tag == "scripts" ? Visibility.Visible : Visibility.Collapsed;
        CodePage.Visibility = tag == "code" ? Visibility.Visible : Visibility.Collapsed;
        AiPage.Visibility = tag == "ai" ? Visibility.Visible : Visibility.Collapsed;
        CommandsPage.Visibility = tag == "commands" ? Visibility.Visible : Visibility.Collapsed;
        SettingsPage.Visibility = tag == "settings" ? Visibility.Visible : Visibility.Collapsed;
        if (tag == "commands" && !_commandCatalogLoaded)
        {
            _ = DiscoverCommandsAsync();
        }
        if (tag == "code" && !_scriptExplorerLoaded)
        {
            _ = RefreshScriptExplorerAsync();
        }
        if (tag == "ai" && !_aiInitialized)
        {
            _ = RefreshAiModelsAsync();
        }
        else if (tag == "ai")
        {
            _ = ResolveAiProjectAsync();
        }
    }

    private async void RefreshAiModelsButton_Click(object sender, RoutedEventArgs e) => await RefreshAiModelsAsync();

    private async Task RefreshAiModelsAsync()
    {
        AiProviderStatusText.Text = "Connecting to Ollama";
        AiProviderDot.Fill = ThemeBrush("SystemFillColorCautionBrush");
        try
        {
            var selected = (AiModelPicker.SelectedItem as AiModel)?.Name;
            var discoveredModels = await _aiProvider.ListModelsAsync();
            var models = AiLocalModelsOnlyToggle.IsOn ? discoveredModels.Where(model => !model.IsRemote).ToArray() : discoveredModels.ToArray();
            AiModelPicker.ItemsSource = models;
            if (selected is not null) AiModelPicker.SelectedItem = models.FirstOrDefault(model => model.Name == selected);
            if (AiModelPicker.SelectedIndex < 0 && models.Length > 0) AiModelPicker.SelectedIndex = 0;
            _aiInitialized = true;
            AiProviderStatusText.Text = AiLocalModelsOnlyToggle.IsOn ? $"Ollama local • {models.Length} models" : $"Ollama connected • {models.Length} models";
            AiProviderDot.Fill = ThemeBrush("SystemFillColorSuccessBrush");
            await ResolveAiProjectAsync();
        }
        catch (Exception exception)
        {
            _aiInitialized = false;
            AiProviderStatusText.Text = "Ollama unavailable";
            AiProviderDot.Fill = ThemeBrush("SystemFillColorCriticalBrush");
            AiContextInfoBar.Severity = InfoBarSeverity.Error;
            AiContextInfoBar.Title = "Could not connect to Ollama";
            AiContextInfoBar.Message = exception.Message;
        }
    }

    private async void AiLocalModelsOnlyToggle_Toggled(object sender, RoutedEventArgs e)
    {
        if (!_initializing) await RefreshAiModelsAsync();
    }

    private async void SendAiMessageButton_Click(object sender, RoutedEventArgs e)
    {
        if (AiModelPicker.SelectedItem is not AiModel model)
        {
            ShowMessage("Choose an Ollama model", "Refresh the model list and select a model first.", InfoBarSeverity.Warning);
            return;
        }
        if (AiLocalModelsOnlyToggle.IsOn && model.IsRemote)
        {
            ShowMessage("Local model required", "Select a locally installed Ollama model or turn off Local models only.", InfoBarSeverity.Warning);
            return;
        }
        var prompt = AiPromptTextBox.Text.Trim();
        if (prompt.Length == 0) return;
        SendAiMessageButton.IsEnabled = false;
        CancelAiMessageButton.IsEnabled = true;
        AiPromptTextBox.IsEnabled = false;
        _aiCancellation?.Dispose();
        _aiCancellation = new CancellationTokenSource();
        try
        {
            var stopwatch = Stopwatch.StartNew();
            var context = await BuildAiContextAsync();
            var estimatedInputTokens = Math.Max(1, context.Length / 4);
            AiContextSizeText.Text = $"~{estimatedInputTokens:N0} input tokens • {model.Name}";
            _aiConversation.Add(new AiMessage("user", prompt));
            AiTranscriptTextBox.Text += $"{Environment.NewLine}{Environment.NewLine}You:{Environment.NewLine}{prompt}{Environment.NewLine}{Environment.NewLine}Ollama ({model.Name}):{Environment.NewLine}";
            AiPromptTextBox.Text = string.Empty;
            var messages = new[] { new AiMessage("system", context) }.Concat(_aiConversation).ToArray();
            var response = new StringBuilder();
            await foreach (var chunk in _aiProvider.StreamChatAsync(model.Name, messages, _aiCancellation.Token))
            {
                response.Append(chunk);
                AiTranscriptTextBox.Text += chunk;
                AiTranscriptTextBox.SelectionStart = AiTranscriptTextBox.Text.Length;
            }
            _aiConversation.Add(new AiMessage("assistant", response.ToString()));
            stopwatch.Stop();
            AiContextSizeText.Text = $"~{estimatedInputTokens:N0} input tokens • {response.Length / 4:N0} output tokens • {stopwatch.Elapsed.TotalSeconds:0.0}s";
            SaveAiProjectState();
        }
        catch (AiLoopDetectedException)
        {
            AiTranscriptTextBox.Text += $"{Environment.NewLine}[Generation stopped: repeated passage detected. Partial response preserved.]";
            AiProviderStatusText.Text = "Ollama connected • loop interrupted";
            AiProviderDot.Fill = ThemeBrush("SystemFillColorCautionBrush");
        }
        catch (OperationCanceledException)
        {
            AiTranscriptTextBox.Text += $"{Environment.NewLine}[Generation cancelled]";
        }
        catch (Exception exception)
        {
            AiTranscriptTextBox.Text += $"{Environment.NewLine}[Ollama error: {exception.Message}]";
            AiProviderStatusText.Text = "Ollama request failed";
            AiProviderDot.Fill = ThemeBrush("SystemFillColorCriticalBrush");
        }
        finally
        {
            SendAiMessageButton.IsEnabled = true;
            CancelAiMessageButton.IsEnabled = false;
            AiPromptTextBox.IsEnabled = true;
            _aiCancellation?.Dispose();
            _aiCancellation = null;
        }
    }

    private void CancelAiMessageButton_Click(object sender, RoutedEventArgs e) => _aiCancellation?.Cancel();

    private async void PreviewAiContextButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            var context = await BuildAiContextAsync();
            AiContextSizeText.Text = $"{context.Length:N0} context characters";
            var dialog = new ContentDialog { XamlRoot = (Content as FrameworkElement)?.XamlRoot, Title = "Context preview", Content = new TextBox { Text = context, IsReadOnly = true, AcceptsReturn = true, TextWrapping = TextWrapping.Wrap, FontFamily = new FontFamily("Consolas"), MinWidth = 620, MaxHeight = 520 }, CloseButtonText = "Close" };
            await dialog.ShowAsync();
        }
        catch (Exception exception) { ShowMessage("Could not build AI context", exception.Message, InfoBarSeverity.Error); }
    }

    private void ClearAiConversationButton_Click(object sender, RoutedEventArgs e)
    {
        _aiConversation.Clear();
        AiTranscriptTextBox.Text = "Conversation cleared. Context is rebuilt for every request.";
        SaveAiProjectState();
    }

    private async Task<string> BuildAiContextAsync()
    {
        var context = new StringBuilder();
        context.AppendLine("You are the read-only Abraxius Roblox Studio assistant. Provide concise, evidence-based Luau and Studio guidance. Do not claim to execute commands or change Studio. Suggest explicit previews and verification before mutations.");
        if (!string.IsNullOrWhiteSpace(AiProjectInstructionsTextBox.Text)) context.AppendLine($"\nPROJECT INSTRUCTIONS:\n{AiProjectInstructionsTextBox.Text.Trim()}");
        if (_aiMemories.Count > 0)
        {
            context.AppendLine("\nLONG-TERM PROJECT MEMORY:");
            foreach (var memory in _aiMemories) context.AppendLine($"- {memory.Text}");
        }
        context.AppendLine($"Abraxius host: {(_lastHealth?.Running == true ? "running" : "unavailable")}; companion: {(_lastHealth?.PluginConnected == true ? "connected" : "offline")}; tools: {_lastHealth?.ToolsLoaded ?? 0}.");
        if (AiStudioContextToggle.IsOn && _lastHealth?.PluginConnected == true)
        {
            try
            {
                var studio = await CallPluginAsync(new Dictionary<string, object?> { ["type"] = "get_assistant_context" });
                context.AppendLine("\nSTUDIO CONTEXT:\n" + LimitContext(JsonSerializer.Serialize(studio, new JsonSerializerOptions { WriteIndented = true }), 24000));
            }
            catch (Exception exception) { context.AppendLine($"\nSTUDIO CONTEXT UNAVAILABLE: {exception.Message}"); }
        }
        if (AiEditorContextToggle.IsOn && _editorReady && _editorLoadedPath is not null)
        {
            var source = await GetEditorValueAsync();
            context.AppendLine($"\nACTIVE EDITOR: {_editorLoadedPath}\n```luau\n{LimitContext(source, 24000)}\n```");
        }
        if (AiRuntimeContextToggle.IsOn)
        {
            context.AppendLine("\nRECENT RUNTIME OUTPUT:");
            foreach (var item in _latestOutput.Take(20)) context.AppendLine($"[{item.LevelLabel}] {item.Message} ({item.Location})");
        }
        return LimitContext(context.ToString(), 52000);
    }

    private static string LimitContext(string value, int maximum) => value.Length <= maximum ? value : value[..maximum] + "\n[context truncated]";

    private async Task ResolveAiProjectAsync()
    {
        var projectId = "local-workspace";
        if (_lastHealth?.PluginConnected == true)
        {
            try
            {
                var context = await CallPluginAsync(new Dictionary<string, object?> { ["type"] = "get_assistant_context" });
                if (FindPlaceId(context) is long placeId && placeId > 0) projectId = $"place-{placeId}";
            }
            catch { }
        }
        if (projectId == _aiProjectId && AiProjectIdentityText.Text != "Resolving Studio project…") return;
        _aiProjectId = projectId;
        AiProjectIdentityText.Text = projectId == "local-workspace" ? "Local workspace (connect Studio for per-place memory)" : projectId;
        LoadAiProjectState();
        LoadIntelligenceState();
    }

    private static long? FindPlaceId(JsonElement element)
    {
        if (element.ValueKind != JsonValueKind.Object) return null;
        if (element.TryGetProperty("place", out var place) && place.ValueKind == JsonValueKind.Object && place.TryGetProperty("id", out var id) && id.TryGetInt64(out var value)) return value;
        foreach (var property in element.EnumerateObject())
        {
            if (property.Value.ValueKind == JsonValueKind.Object && FindPlaceId(property.Value) is long found) return found;
        }
        return null;
    }

    private string AiProjectStatePath => Path.Combine(AppDataDirectory, "projects", _aiProjectId, "ai-state.json");

    private void LoadAiProjectState()
    {
        _aiConversation.Clear();
        _aiMemories.Clear();
        AiProjectInstructionsTextBox.Text = string.Empty;
        try
        {
            if (File.Exists(AiProjectStatePath))
            {
                var state = JsonSerializer.Deserialize<AiProjectState>(File.ReadAllText(AiProjectStatePath));
                AiProjectInstructionsTextBox.Text = state?.Instructions ?? string.Empty;
                foreach (var memory in state?.Memories ?? Array.Empty<AiMemoryItem>()) _aiMemories.Add(memory);
                foreach (var message in state?.Conversation ?? Array.Empty<AiMessage>()) _aiConversation.Add(message);
            }
        }
        catch { }
        RebuildAiTranscript();
    }

    private void SaveAiProjectState()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(AiProjectStatePath)!);
            var conversation = _aiConversation.TakeLast(40).Select(message => new AiMessage(message.Role, RedactSensitiveText(message.Content))).ToArray();
            var state = new AiProjectState(RedactSensitiveText(AiProjectInstructionsTextBox.Text), _aiMemories.ToArray(), conversation);
            File.WriteAllText(AiProjectStatePath, JsonSerializer.Serialize(state, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch (Exception exception) { ShowMessage("Could not save AI project state", exception.Message, InfoBarSeverity.Warning); }
    }

    private void RebuildAiTranscript()
    {
        if (_aiConversation.Count == 0) { AiTranscriptTextBox.Text = "Abraxius AI is ready. Project memory is loaded separately from conversation history."; return; }
        var transcript = new StringBuilder();
        foreach (var message in _aiConversation)
        {
            transcript.AppendLine(message.Role == "user" ? "You:" : "Ollama:");
            transcript.AppendLine(message.Content).AppendLine();
        }
        AiTranscriptTextBox.Text = transcript.ToString().TrimEnd();
    }

    private void SaveAiProjectInstructionsButton_Click(object sender, RoutedEventArgs e)
    {
        SaveAiProjectState();
        AiContextInfoBar.Severity = InfoBarSeverity.Success;
        AiContextInfoBar.Title = "Project instructions saved";
        AiContextInfoBar.Message = _aiProjectId;
    }

    private void AddAiMemoryButton_Click(object sender, RoutedEventArgs e)
    {
        var text = AiMemoryInputTextBox.Text.Trim();
        if (text.Length == 0) return;
        _aiMemories.Insert(0, new AiMemoryItem(DateTimeOffset.Now.ToString("yyyy-MM-dd"), RedactSensitiveText(text)));
        while (_aiMemories.Count > 100) _aiMemories.RemoveAt(_aiMemories.Count - 1);
        AiMemoryInputTextBox.Text = string.Empty;
        SaveAiProjectState();
    }

    private void DeleteAiMemoryButton_Click(object sender, RoutedEventArgs e)
    {
        if (AiMemoryList.SelectedItem is AiMemoryItem item) _aiMemories.Remove(item);
        SaveAiProjectState();
    }

    private async void CompactAiConversationButton_Click(object sender, RoutedEventArgs e)
    {
        if (_aiConversation.Count == 0 || AiModelPicker.SelectedItem is not AiModel model) return;
        if (model.IsRemote && AiLocalModelsOnlyToggle.IsOn) return;
        var cancellation = new CancellationTokenSource(TimeSpan.FromMinutes(3));
        try
        {
            var request = new[]
            {
                new AiMessage("system", "Compress this project conversation into durable factual memory. Preserve architecture, decisions, constraints, unresolved issues, and verified observations. Omit greetings and speculation. Return concise Markdown bullets only."),
                new AiMessage("user", string.Join("\n\n", _aiConversation.TakeLast(20).Select(message => $"{message.Role}: {message.Content}")))
            };
            var summary = new StringBuilder();
            await foreach (var chunk in _aiProvider.StreamChatAsync(model.Name, request, cancellation.Token)) summary.Append(chunk);
            if (summary.Length > 0)
            {
                _aiMemories.Insert(0, new AiMemoryItem(DateTimeOffset.Now.ToString("yyyy-MM-dd"), RedactSensitiveText(summary.ToString())));
                _aiConversation.Clear();
                RebuildAiTranscript();
                SaveAiProjectState();
                AiContextInfoBar.Severity = InfoBarSeverity.Success;
                AiContextInfoBar.Title = "Conversation compacted";
                AiContextInfoBar.Message = "The local model summary was added to project memory. Review or delete it at any time.";
            }
        }
        catch (Exception exception) { ShowMessage("Could not compact conversation", exception.Message, InfoBarSeverity.Error); }
        finally { cancellation.Dispose(); }
    }

    private async void DraftAiCommandPlanButton_Click(object sender, RoutedEventArgs e)
    {
        if (AiModelPicker.SelectedItem is not AiModel model || model.IsRemote && AiLocalModelsOnlyToggle.IsOn) return;
        var intention = AiPromptTextBox.Text.Trim();
        if (intention.Length == 0) intention = _aiConversation.LastOrDefault(message => message.Role == "user")?.Content ?? string.Empty;
        if (intention.Length == 0) { ShowMessage("Describe the task first", "Enter a request or send a chat message before drafting commands.", InfoBarSeverity.Warning); return; }
        try
        {
            await EnsureCommandSchemasAsync();
            var schemaCatalog = JsonSerializer.Serialize(_commandSchemas, new JsonSerializerOptions { WriteIndented = false });
            var messages = new[]
            {
                new AiMessage("system", "You draft Abraxius companion commands but never execute them. Return JSON only: {\"summary\":\"...\",\"commands\":[{\"type\":\"command_name\",\"arguments\":{}}]}. Use only provided schemas. Prefer read/inspect commands before mutations. Include required confirm fields. At most 20 commands."),
                new AiMessage("user", $"TASK:\n{intention}\n\nAVAILABLE COMMAND SCHEMAS:\n{LimitContext(schemaCatalog, 26000)}\n\nPROJECT CONTEXT:\n{LimitContext(await BuildAiContextAsync(), 18000)}")
            };
            using var cancellation = new CancellationTokenSource(TimeSpan.FromMinutes(4));
            var response = await CollectAiResponseAsync(model.Name, messages, cancellation.Token);
            using var document = JsonDocument.Parse(ExtractJsonObject(response));
            if (!document.RootElement.TryGetProperty("commands", out var commands) || commands.ValueKind != JsonValueKind.Array) throw new InvalidOperationException("The model did not return a commands array.");
            var added = 0;
            foreach (var proposed in commands.EnumerateArray().Take(20))
            {
                var type = proposed.TryGetProperty("type", out var typeValue) ? typeValue.GetString() : null;
                if (type is null || !_commandSchemas.ContainsKey(type)) continue;
                var arguments = proposed.TryGetProperty("arguments", out var argumentValue) && argumentValue.ValueKind == JsonValueKind.Object ? argumentValue.Clone() : JsonDocument.Parse("{}").RootElement.Clone();
                var fields = arguments.EnumerateObject().Select(property => property.Name).Take(4).ToArray();
                _approvalQueueItems.Add(new ApprovalQueueRow((_approvalQueueItems.Count + 1).ToString(), type, fields.Length == 0 ? "AI proposal • no arguments" : $"AI proposal • {string.Join(", ", fields)}", arguments));
                added++;
            }
            ExecuteApprovalQueueButton.IsEnabled = _approvalQueueItems.Count > 0;
            var summary = document.RootElement.TryGetProperty("summary", out var summaryValue) ? summaryValue.GetString() : null;
            AiTranscriptTextBox.Text += $"{Environment.NewLine}{Environment.NewLine}Command proposal:{Environment.NewLine}{summary ?? "Review the proposed commands."}{Environment.NewLine}{added} schema-valid commands were added to the approval queue.";
            var commandsItem = CategoryNavigation.MenuItems.OfType<NavigationViewItem>().FirstOrDefault(item => item.Tag?.ToString() == "commands");
            if (commandsItem is not null) CategoryNavigation.SelectedItem = commandsItem;
        }
        catch (Exception exception) { ShowMessage("Could not draft command plan", exception.Message, InfoBarSeverity.Error); }
    }

    private async Task EnsureCommandSchemasAsync()
    {
        if (_commandSchemas.Count > 0) return;
        var result = await CallPluginAsync(new Dictionary<string, object?> { ["type"] = "get_capabilities" });
        var catalog = FindCommandsElement(result);
        if (catalog is null || catalog.Value.ValueKind != JsonValueKind.Object) throw new InvalidOperationException("Companion command schemas are unavailable.");
        foreach (var property in catalog.Value.EnumerateObject()) _commandSchemas[property.Name] = property.Value.Clone();
        AddAppCommandSchemas();
    }

    private async void GenerateAiBriefingButton_Click(object sender, RoutedEventArgs e)
    {
        if (AiModelPicker.SelectedItem is not AiModel model || model.IsRemote && AiLocalModelsOnlyToggle.IsOn) return;
        try
        {
            var context = await BuildAiContextAsync();
            var messages = new[]
            {
                new AiMessage("system", "Create a compact handoff briefing for another coding agent. Use concise Markdown. Preserve verified architecture, active work, important Studio paths, errors, constraints, decisions, and next actions. Clearly label uncertainty. Do not include greetings."),
                new AiMessage("user", context + "\n\nRECENT CONVERSATION:\n" + string.Join("\n", _aiConversation.TakeLast(12).Select(message => $"{message.Role}: {message.Content}")))
            };
            using var cancellation = new CancellationTokenSource(TimeSpan.FromMinutes(4));
            var briefing = await CollectAiResponseAsync(model.Name, messages, cancellation.Token);
            Directory.CreateDirectory(AiProjectDirectory);
            var path = Path.Combine(AiProjectDirectory, "briefing.md");
            await File.WriteAllTextAsync(path, RedactSensitiveText(briefing));
            var package = new DataPackage(); package.SetText(briefing); Clipboard.SetContent(package);
            AiContextInfoBar.Severity = InfoBarSeverity.Success;
            AiContextInfoBar.Title = "Compact briefing generated and copied";
            AiContextInfoBar.Message = path;
        }
        catch (Exception exception) { ShowMessage("Could not generate project briefing", exception.Message, InfoBarSeverity.Error); }
    }

    private void ExportAiProjectButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            var export = new StringBuilder($"# Abraxius AI Export — {_aiProjectId}\n\n## Project instructions\n\n{AiProjectInstructionsTextBox.Text}\n\n## Long-term memory\n\n");
            foreach (var memory in _aiMemories) export.AppendLine($"- [{memory.CreatedAt}] {memory.Text}");
            export.AppendLine("\n## Conversation\n");
            foreach (var message in _aiConversation) export.AppendLine($"### {message.Role}\n\n{message.Content}\n");
            var redacted = RedactSensitiveText(export.ToString());
            Directory.CreateDirectory(AiProjectDirectory);
            var path = Path.Combine(AiProjectDirectory, "project-export.md");
            File.WriteAllText(path, redacted);
            var package = new DataPackage(); package.SetText(redacted); Clipboard.SetContent(package);
            AiContextInfoBar.Severity = InfoBarSeverity.Success;
            AiContextInfoBar.Title = "Project AI state exported and copied";
            AiContextInfoBar.Message = path;
        }
        catch (Exception exception) { ShowMessage("Could not export AI project state", exception.Message, InfoBarSeverity.Error); }
    }

    private async Task<string> CollectAiResponseAsync(string model, IReadOnlyList<AiMessage> messages, CancellationToken cancellationToken)
    {
        var response = new StringBuilder();
        await foreach (var chunk in _aiProvider.StreamChatAsync(model, messages, cancellationToken)) response.Append(chunk);
        return response.ToString();
    }

    private static string ExtractJsonObject(string response)
    {
        var start = response.IndexOf('{');
        var end = response.LastIndexOf('}');
        if (start < 0 || end <= start) throw new JsonException("The model response did not contain a JSON object.");
        return response[start..(end + 1)];
    }

    private string AiProjectDirectory => Path.Combine(AppDataDirectory, "projects", _aiProjectId);

    private static string RedactSensitiveText(string text) => System.Text.RegularExpressions.Regex.Replace(text, "(?i)(api[_-]?key|token|authorization|password)\\s*[:=]\\s*[^\\s,;]+", "$1=[redacted]");

    private void DismissIntelligenceSuggestionButton_Click(object sender, RoutedEventArgs e)
    {
        if (IntelligenceSuggestionList.SelectedItem is IntelligenceSuggestionRow item) _intelligenceSuggestions.Remove(item);
        SaveIntelligenceState();
    }

    private async void SummarizeIntelligenceSuggestionButton_Click(object sender, RoutedEventArgs e) => await ClassifyIntelligenceSuggestionAsync("qwen2.5-coder:1.5b", "Local classification");
    private async void EscalateIntelligenceSuggestionButton_Click(object sender, RoutedEventArgs e) => await ClassifyIntelligenceSuggestionAsync("qwen2.5-coder:7b", "7B escalation");

    private async Task ClassifyIntelligenceSuggestionAsync(string model, string label)
    {
        if (IntelligenceSuggestionList.SelectedItem is not IntelligenceSuggestionRow item) return;
        try
        {
            using var cancellation = new CancellationTokenSource(TimeSpan.FromMinutes(4));
            var messages = new[] { new AiMessage("system", "Classify this Roblox Studio monitoring signal. Return a concise severity assessment, likely cause, and one safe next diagnostic step. Do not claim certainty or execute anything."), new AiMessage("user", $"{item.Title}\nConfidence: {item.Confidence}\nEvidence:\n{item.Evidence}") };
            var summary = await CollectAiResponseAsync(model, messages, cancellation.Token);
            var index = _intelligenceSuggestions.IndexOf(item);
            if (index >= 0) _intelligenceSuggestions[index] = item with { Evidence = $"{item.Evidence}\n\n{label}:\n{summary}" };
            SaveIntelligenceState();
        }
        catch (Exception exception) { ShowMessage("Could not classify suggestion", exception.Message, InfoBarSeverity.Error); }
    }

    private void ClearIntelligenceTimelineButton_Click(object sender, RoutedEventArgs e)
    {
        _intelligenceTimeline.Clear();
        SaveIntelligenceState();
    }

    private string IntelligenceStatePath => Path.Combine(AiProjectDirectory, "intelligence-state.json");

    private void LoadIntelligenceState()
    {
        _intelligenceTimeline.Clear();
        _intelligenceSuggestions.Clear();
        try
        {
            if (!File.Exists(IntelligenceStatePath)) return;
            var state = JsonSerializer.Deserialize<IntelligenceProjectState>(File.ReadAllText(IntelligenceStatePath));
            foreach (var item in state?.Timeline ?? Array.Empty<IntelligenceEventRow>()) _intelligenceTimeline.Add(item);
            foreach (var item in state?.Suggestions ?? Array.Empty<IntelligenceSuggestionRow>()) _intelligenceSuggestions.Add(item);
        }
        catch { }
    }

    private void SaveIntelligenceState()
    {
        try
        {
            Directory.CreateDirectory(AiProjectDirectory);
            var state = new IntelligenceProjectState(_intelligenceTimeline.Take(250).ToArray(), _intelligenceSuggestions.Take(100).ToArray());
            File.WriteAllText(IntelligenceStatePath, JsonSerializer.Serialize(state, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch { }
    }

    private async void CodeEditorWebView_Loaded(object sender, RoutedEventArgs e)
    {
        if (_editorReady || _editorInitializing) return;
        _editorInitializing = true;
        try
        {
            await CodeEditorWebView.EnsureCoreWebView2Async();
            CodeEditorWebView.CoreWebView2.SetVirtualHostNameToFolderMapping("appassets.abraxius", Path.Combine(AppContext.BaseDirectory, "Editor"), CoreWebView2HostResourceAccessKind.DenyCors);
            CodeEditorWebView.Source = new Uri("https://appassets.abraxius/editor.html");
        }
        catch (Exception exception)
        {
            EditorInfoBar.Severity = InfoBarSeverity.Error;
            EditorInfoBar.Title = "Editor could not start";
            EditorInfoBar.Message = exception.Message;
        }
        finally { _editorInitializing = false; }
    }

    private void CodeEditorWebView_CoreWebView2Initialized(WebView2 sender, CoreWebView2InitializedEventArgs args)
    {
        if (args.Exception is not null)
        {
            EditorInfoBar.Severity = InfoBarSeverity.Error;
            EditorInfoBar.Title = "Editor runtime unavailable";
            EditorInfoBar.Message = args.Exception.Message;
            return;
        }
        sender.CoreWebView2.WebMessageReceived += (_, message) =>
        {
            try
            {
                using var document = JsonDocument.Parse(message.TryGetWebMessageAsString());
                var type = document.RootElement.GetProperty("type").GetString();
                if (type == "ready")
                {
                    _editorReady = true;
                    _styluaPath = FindExecutable("stylua.exe");
                    _luauAnalyzePath = FindExecutable("luau-analyze.exe");
                    UpdateEditorToolsStatus();
                    EditorInfoBar.Title = "Editor ready";
                    EditorInfoBar.Message = "Pull a script from Studio to begin editing.";
                    var restoreTask = RestoreEditorSessionAsync();
                }
                else if (type == "dirty") SetEditorDirty(true);
            }
            catch { }
        };
    }

    private async void PullEditorScriptButton_Click(object sender, RoutedEventArgs e)
    {
        var path = EditorScriptPathTextBox.Text.Trim();
        if (path.Length == 0) { ShowMessage("Script path required", "Enter a dotted Studio path first.", InfoBarSeverity.Warning); return; }
        if (!_editorReady) { ShowMessage("Editor is still loading", "Wait for the Monaco editor to finish initializing.", InfoBarSeverity.Warning); return; }
        await OpenEditorDocumentAsync(path, refresh: true);
    }

    private async Task OpenEditorDocumentAsync(string path, bool refresh)
    {
        try
        {
            if (!refresh && _editorDocuments.TryGetValue(path, out var existing))
            {
                EditorTabs.SelectedItem = EditorTabs.TabItems.OfType<TabViewItem>().FirstOrDefault(tab => Equals(tab.Tag, path));
                return;
            }
            if (refresh && _editorDocuments.TryGetValue(path, out var existingDocument) && existingDocument.Dirty)
            {
                if (path == _editorLoadedPath) existingDocument.Source = await GetEditorValueAsync();
                var dialog = new ContentDialog { XamlRoot = (Content as FrameworkElement)?.XamlRoot, Title = "Replace unsaved editor changes?", Content = $"Pulling {path} again will replace the recovered/local buffer with the current Studio source.", PrimaryButtonText = "Replace with Studio", CloseButtonText = "Keep local buffer", DefaultButton = ContentDialogButton.Close };
                if (await dialog.ShowAsync() != ContentDialogResult.Primary) return;
            }
            var result = await CallPluginAsync(new Dictionary<string, object?> { ["type"] = "read_source", ["path"] = path });
            var source = FindJsonString(result, "source") ?? throw new InvalidOperationException("Studio did not return script source.");
            var hash = FindJsonString(result, "hash") ?? FindJsonString(result, "sourceHash");
            if (_editorLoadedPath is not null && _editorDocuments.TryGetValue(_editorLoadedPath, out var current) && _editorReady)
            {
                current.Source = await GetEditorValueAsync();
                current.Dirty = _editorDirty;
            }
            if (!_editorDocuments.TryGetValue(path, out var document))
            {
                document = new EditorDocument(path, source, hash);
                _editorDocuments[path] = document;
                var tab = new TabViewItem { Header = ScriptName(path), Tag = path, IsClosable = true };
                EditorTabs.TabItems.Add(tab);
                EditorTabs.SelectedItem = tab;
            }
            else
            {
                document.Source = source;
                document.Hash = hash;
                document.Dirty = false;
                EditorTabs.SelectedItem = EditorTabs.TabItems.OfType<TabViewItem>().FirstOrDefault(tab => Equals(tab.Tag, path));
            }
            await SetEditorValueAsync(source);
            _editorLoadedPath = path;
            _editorSourceHash = hash;
            EditorHashText.Text = $"Source hash  {hash ?? "unavailable"}";
            EditorDiffTextBox.Text = "No preview yet.";
            PreviewEditorChangesButton.IsEnabled = true;
            PushEditorChangesButton.IsEnabled = true;
            SetEditorDirty(false);
            EditorInfoBar.Severity = InfoBarSeverity.Success;
            EditorInfoBar.Title = "Script loaded";
            EditorInfoBar.Message = path;
        }
        catch (Exception exception) { SetEditorError("Could not pull script", exception); }
    }

    private async void RefreshScriptExplorerButton_Click(object sender, RoutedEventArgs e) => await RefreshScriptExplorerAsync();

    private async Task RefreshScriptExplorerAsync()
    {
        try
        {
            var result = await CallPluginAsync(new Dictionary<string, object?> { ["type"] = "export_scripts" });
            var scripts = FindJsonArray(result, "scripts") ?? throw new InvalidOperationException("Studio did not return a script catalog.");
            _allExplorerScripts = scripts.EnumerateArray()
                .Select(item => FindJsonString(item, "path"))
                .Where(path => !string.IsNullOrWhiteSpace(path))
                .Select(path => new ScriptExplorerRow(path!, ScriptName(path!), path!.Split('.')[0]))
                .OrderBy(item => item.Path, StringComparer.Ordinal)
                .ToArray();
            _scriptExplorerLoaded = true;
            ApplyScriptExplorerFilter();
            EditorInfoBar.Severity = InfoBarSeverity.Success;
            EditorInfoBar.Title = $"{_allExplorerScripts.Count} Studio scripts";
            EditorInfoBar.Message = "Select a script from the explorer to open it in a tab.";
        }
        catch (Exception exception) { _scriptExplorerLoaded = false; SetEditorError("Could not synchronize scripts", exception); }
    }

    private static JsonElement? FindJsonArray(JsonElement element, string name)
    {
        if (element.ValueKind != JsonValueKind.Object) return null;
        if (element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Array) return value;
        foreach (var property in element.EnumerateObject())
        {
            if (property.Value.ValueKind == JsonValueKind.Object && FindJsonArray(property.Value, name) is JsonElement found) return found;
        }
        return null;
    }

    private void ScriptExplorerSearchTextBox_TextChanged(object sender, TextChangedEventArgs e) => ApplyScriptExplorerFilter();

    private void ApplyScriptExplorerFilter()
    {
        var search = ScriptExplorerSearchTextBox?.Text?.Trim() ?? string.Empty;
        var desired = _allExplorerScripts.Where(item => search.Length == 0 || item.Path.Contains(search, StringComparison.OrdinalIgnoreCase)).ToArray();
        SyncCollection(_scriptExplorerItems, desired, item => item.Path);
    }

    private async void OpenExplorerScriptButton_Click(object sender, RoutedEventArgs e)
    {
        if (ScriptExplorerList.SelectedItem is not ScriptExplorerRow script) return;
        EditorScriptPathTextBox.Text = script.Path;
        await OpenEditorDocumentAsync(script.Path, refresh: false);
    }

    private async void EditorTabs_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_switchingEditorTab || !_editorReady || EditorTabs.SelectedItem is not TabViewItem selected || selected.Tag is not string path) return;
        _switchingEditorTab = true;
        try
        {
            if (_editorLoadedPath is not null && _editorDocuments.TryGetValue(_editorLoadedPath, out var current))
            {
                current.Source = await GetEditorValueAsync();
                current.Dirty = _editorDirty;
                UpdateEditorTabHeader(current);
            }
            if (_editorDocuments.TryGetValue(path, out var next))
            {
                _editorLoadedPath = path;
                _editorSourceHash = next.Hash;
                EditorScriptPathTextBox.Text = path;
                await SetEditorValueAsync(next.Source);
                EditorHashText.Text = $"Source hash  {next.Hash ?? "unavailable"}";
                PreviewEditorChangesButton.IsEnabled = true;
                PushEditorChangesButton.IsEnabled = true;
                SetEditorDirty(next.Dirty);
            }
        }
        finally { _switchingEditorTab = false; }
    }

    private async void EditorTabs_TabCloseRequested(TabView sender, TabViewTabCloseRequestedEventArgs args)
    {
        if (args.Tab.Tag is not string path || !_editorDocuments.TryGetValue(path, out var document)) return;
        if (path == _editorLoadedPath)
        {
            document.Source = await GetEditorValueAsync();
            document.Dirty = _editorDirty;
        }
        if (document.Dirty)
        {
            var dialog = new ContentDialog { XamlRoot = (Content as FrameworkElement)?.XamlRoot, Title = "Discard unsaved editor changes?", Content = path, PrimaryButtonText = "Discard and close", CloseButtonText = "Keep open", DefaultButton = ContentDialogButton.Close };
            if (await dialog.ShowAsync() != ContentDialogResult.Primary) return;
        }
        _editorDocuments.Remove(path);
        sender.TabItems.Remove(args.Tab);
        if (sender.TabItems.Count == 0)
        {
            _editorLoadedPath = null;
            _editorSourceHash = null;
            await SetEditorValueAsync("-- Select a Studio script to begin.\n");
            PreviewEditorChangesButton.IsEnabled = false;
            PushEditorChangesButton.IsEnabled = false;
            SetEditorDirty(false);
        }
    }

    private static string ScriptName(string path) => path.Split('.').LastOrDefault() ?? path;

    private void UpdateEditorTabHeader(EditorDocument document)
    {
        var tab = EditorTabs.TabItems.OfType<TabViewItem>().FirstOrDefault(item => Equals(item.Tag, document.Path));
        if (tab is not null) tab.Header = document.Dirty ? $"{ScriptName(document.Path)} •" : ScriptName(document.Path);
    }

    private async void PreviewEditorChangesButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            var result = await PreviewEditorChangesAsync();
            EditorDiffTextBox.Text = JsonSerializer.Serialize(result, new JsonSerializerOptions { WriteIndented = true });
            EditorInfoBar.Severity = InfoBarSeverity.Informational;
            EditorInfoBar.Title = "Dry-run preview complete";
            EditorInfoBar.Message = "Studio source was not changed.";
        }
        catch (Exception exception) { SetEditorError("Could not preview changes", exception); }
    }

    private async Task<JsonElement> PreviewEditorChangesAsync()
    {
        if (_editorLoadedPath is null) throw new InvalidOperationException("Pull a Studio script first.");
        var source = await GetEditorValueAsync();
        return await CallPluginAsync(new Dictionary<string, object?> { ["type"] = "write_source", ["path"] = _editorLoadedPath, ["source"] = source, ["expectedHash"] = _editorSourceHash, ["dryRun"] = true });
    }

    private async void PushEditorChangesButton_Click(object sender, RoutedEventArgs e)
    {
        if (_editorLoadedPath is null) return;
        try
        {
            var preview = await PreviewEditorChangesAsync();
            EditorDiffTextBox.Text = JsonSerializer.Serialize(preview, new JsonSerializerOptions { WriteIndented = true });
            var dialog = new ContentDialog { XamlRoot = (Content as FrameworkElement)?.XamlRoot, Title = "Push source to Studio?", Content = $"Review the dry-run preview for {_editorLoadedPath}. The commit will use conflict detection and read the source back.", PrimaryButtonText = "Push source", CloseButtonText = "Cancel", DefaultButton = ContentDialogButton.Close };
            if (await dialog.ShowAsync() != ContentDialogResult.Primary) return;
            var source = await GetEditorValueAsync();
            await CallPluginAsync(new Dictionary<string, object?> { ["type"] = "write_source", ["path"] = _editorLoadedPath, ["source"] = source, ["expectedHash"] = _editorSourceHash, ["dryRun"] = false });
            var verification = await CallPluginAsync(new Dictionary<string, object?> { ["type"] = "read_source", ["path"] = _editorLoadedPath });
            var verifiedSource = FindJsonString(verification, "source") ?? throw new InvalidOperationException("Read-back did not return source.");
            if (!string.Equals(source, verifiedSource, StringComparison.Ordinal)) throw new InvalidOperationException("Studio read-back did not match the committed editor source.");
            _editorSourceHash = FindJsonString(verification, "hash") ?? FindJsonString(verification, "sourceHash");
            EditorHashText.Text = $"Source hash  {_editorSourceHash ?? "unavailable"}";
            if (_editorDocuments.TryGetValue(_editorLoadedPath, out var document))
            {
                document.Source = source;
                document.Hash = _editorSourceHash;
                document.Dirty = false;
                UpdateEditorTabHeader(document);
            }
            SetEditorDirty(false);
            EditorInfoBar.Severity = InfoBarSeverity.Success;
            EditorInfoBar.Title = "Source pushed and verified";
            EditorInfoBar.Message = _editorLoadedPath;
        }
        catch (Exception exception) { SetEditorError("Could not push source", exception); }
    }

    private async Task<JsonElement> CallPluginAsync(Dictionary<string, object?> command)
    {
        using var response = await _http.PostAsJsonAsync("plugin/call", new { command });
        var json = await response.Content.ReadAsStringAsync();
        response.EnsureSuccessStatusCode();
        using var document = JsonDocument.Parse(json);
        return document.RootElement.Clone();
    }

    private async Task<JsonElement> CallCommandAsync(string commandName, JsonElement arguments)
    {
        if (commandName == "multi_edit")
        {
            var mcpArguments = new Dictionary<string, object?>();
            foreach (var property in arguments.EnumerateObject()) mcpArguments[property.Name] = property.Value.Clone();
            mcpArguments["datamodel_type"] = "Edit";
            using var response = await _http.PostAsJsonAsync("call", new { name = commandName, arguments = mcpArguments });
            var json = await response.Content.ReadAsStringAsync();
            response.EnsureSuccessStatusCode();
            using var document = JsonDocument.Parse(json);
            return document.RootElement.Clone();
        }

        var command = new Dictionary<string, object?> { ["type"] = commandName };
        foreach (var property in arguments.EnumerateObject()) command[property.Name] = property.Value.Clone();
        return await CallPluginAsync(command);
    }

    private static string? FindJsonString(JsonElement element, string name)
    {
        if (element.ValueKind != JsonValueKind.Object) return null;
        if (element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String) return value.GetString();
        foreach (var property in element.EnumerateObject())
        {
            if (property.Value.ValueKind == JsonValueKind.Object && FindJsonString(property.Value, name) is string found) return found;
        }
        return null;
    }

    private async Task SetEditorValueAsync(string source)
    {
        await CodeEditorWebView.ExecuteScriptAsync($"window.abraxius.setValue({JsonSerializer.Serialize(source)})");
    }

    private async Task<string> GetEditorValueAsync()
    {
        var encoded = await CodeEditorWebView.ExecuteScriptAsync("window.abraxius.getValue()");
        return JsonSerializer.Deserialize<string>(encoded) ?? string.Empty;
    }

    private void SetEditorDirty(bool dirty)
    {
        _editorDirty = dirty;
        if (_editorLoadedPath is not null && _editorDocuments.TryGetValue(_editorLoadedPath, out var document))
        {
            document.Dirty = dirty;
            UpdateEditorTabHeader(document);
        }
        EditorDirtyText.Text = _editorLoadedPath is null ? "No script loaded" : dirty ? "Unsaved editor changes" : "In sync with pulled source";
        EditorDirtyText.Foreground = ThemeBrush(dirty ? "SystemFillColorCautionBrush" : "TextFillColorSecondaryBrush");
        if (dirty)
        {
            _editorRecoveryTimer.Stop();
            _editorRecoveryTimer.Start();
        }
    }

    private async Task SaveEditorSessionAsync()
    {
        try
        {
            if (_editorReady && _editorLoadedPath is not null && _editorDocuments.TryGetValue(_editorLoadedPath, out var active))
            {
                active.Source = await GetEditorValueAsync();
                active.Dirty = _editorDirty;
            }
            Directory.CreateDirectory(AppDataDirectory);
            var session = new EditorSession(_editorLoadedPath, _editorDocuments.Values.Select(document => new EditorSessionDocument(document.Path, document.Source, document.Hash, document.Dirty)).ToArray());
            await File.WriteAllTextAsync(EditorSessionPath, JsonSerializer.Serialize(session, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch { }
    }

    private async Task RestoreEditorSessionAsync()
    {
        try
        {
            if (!File.Exists(EditorSessionPath) || _editorDocuments.Count > 0) return;
            var session = JsonSerializer.Deserialize<EditorSession>(await File.ReadAllTextAsync(EditorSessionPath));
            if (session?.Documents is null || session.Documents.Count == 0) return;
            _switchingEditorTab = true;
            foreach (var saved in session.Documents)
            {
                if (string.IsNullOrWhiteSpace(saved.Path)) continue;
                var document = new EditorDocument(saved.Path, saved.Source ?? string.Empty, saved.Hash) { Dirty = saved.Dirty };
                _editorDocuments[saved.Path] = document;
                var tab = new TabViewItem { Header = saved.Dirty ? $"{ScriptName(saved.Path)} •" : ScriptName(saved.Path), Tag = saved.Path, IsClosable = true };
                EditorTabs.TabItems.Add(tab);
            }
            var activePath = session.ActivePath is not null && _editorDocuments.ContainsKey(session.ActivePath) ? session.ActivePath : _editorDocuments.Keys.FirstOrDefault();
            if (activePath is null) return;
            var activeTab = EditorTabs.TabItems.OfType<TabViewItem>().First(tab => Equals(tab.Tag, activePath));
            EditorTabs.SelectedItem = activeTab;
            var active = _editorDocuments[activePath];
            _editorLoadedPath = activePath;
            _editorSourceHash = active.Hash;
            EditorScriptPathTextBox.Text = activePath;
            await SetEditorValueAsync(active.Source);
            EditorHashText.Text = $"Source hash  {active.Hash ?? "unavailable"}";
            PreviewEditorChangesButton.IsEnabled = true;
            PushEditorChangesButton.IsEnabled = true;
            SetEditorDirty(active.Dirty);
            EditorInfoBar.Severity = active.Dirty ? InfoBarSeverity.Warning : InfoBarSeverity.Informational;
            EditorInfoBar.Title = $"Recovered {session.Documents.Count} editor tabs";
            EditorInfoBar.Message = active.Dirty ? "Unsaved buffers were restored locally. Preview before pushing." : "Your previous editor session was restored.";
        }
        catch (Exception exception) { SetEditorError("Could not restore editor session", exception); }
        finally { _switchingEditorTab = false; }
    }

    private void SetEditorError(string title, Exception exception)
    {
        EditorInfoBar.Severity = InfoBarSeverity.Error;
        EditorInfoBar.Title = title;
        EditorInfoBar.Message = exception.Message;
    }

    private async void EditorFindButton_Click(object sender, RoutedEventArgs e) => await CodeEditorWebView.ExecuteScriptAsync("window.abraxius.action('actions.find')");
    private async void EditorGoToLineButton_Click(object sender, RoutedEventArgs e) => await CodeEditorWebView.ExecuteScriptAsync("window.abraxius.action('editor.action.gotoLine')");
    private async void EditorCommandPaletteButton_Click(object sender, RoutedEventArgs e) => await CodeEditorWebView.ExecuteScriptAsync("window.abraxius.action('editor.action.quickCommand')");
    private async void EditorFormatButton_Click(object sender, RoutedEventArgs e)
    {
        if (!_editorReady) return;
        try
        {
            if (_styluaPath is null)
            {
                await CodeEditorWebView.ExecuteScriptAsync("window.abraxius.formatBasic()");
                EditorInfoBar.Severity = InfoBarSeverity.Warning;
                EditorInfoBar.Title = "Basic cleanup applied";
                EditorInfoBar.Message = "StyLua was not found on PATH, so only trailing whitespace was removed.";
                return;
            }
            var source = await GetEditorValueAsync();
            var path = await WriteEditorToolFileAsync(source);
            var result = await RunEditorToolAsync(_styluaPath, $"\"{path}\"");
            if (result.ExitCode != 0) throw new InvalidOperationException(result.Error.Length > 0 ? result.Error : result.Output);
            await SetEditorValueAsync(await File.ReadAllTextAsync(path));
            SetEditorDirty(true);
            EditorInfoBar.Severity = InfoBarSeverity.Success;
            EditorInfoBar.Title = "Formatted with StyLua";
            EditorInfoBar.Message = _editorLoadedPath ?? "Editor buffer";
        }
        catch (Exception exception) { SetEditorError("Formatting failed", exception); }
    }

    private async void EditorDiagnosticsButton_Click(object sender, RoutedEventArgs e)
    {
        if (!_editorReady) return;
        if (_luauAnalyzePath is null)
        {
            EditorDiagnosticsTextBox.Text = "luau-analyze.exe was not found on PATH. Install Roblox Luau tools and restart Abraxius to enable diagnostics.";
            return;
        }
        try
        {
            var path = await WriteEditorToolFileAsync(await GetEditorValueAsync());
            var result = await RunEditorToolAsync(_luauAnalyzePath, $"\"{path}\"");
            var output = string.Join(Environment.NewLine, new[] { result.Output, result.Error }.Where(value => !string.IsNullOrWhiteSpace(value)));
            EditorDiagnosticsTextBox.Text = output.Length == 0 ? "No diagnostics." : output;
            EditorInfoBar.Severity = result.ExitCode == 0 ? InfoBarSeverity.Success : InfoBarSeverity.Warning;
            EditorInfoBar.Title = result.ExitCode == 0 ? "Luau diagnostics clean" : "Luau diagnostics found issues";
            EditorInfoBar.Message = _editorLoadedPath ?? "Editor buffer";
        }
        catch (Exception exception) { SetEditorError("Diagnostics failed", exception); }
    }

    private void UpdateEditorToolsStatus()
    {
        EditorToolsStatusText.Text = $"StyLua: {(_styluaPath is null ? "not found" : "ready")}  •  luau-analyze: {(_luauAnalyzePath is null ? "not found" : "ready")}";
    }

    private static string? FindExecutable(string name)
    {
        foreach (var directory in (Environment.GetEnvironmentVariable("PATH") ?? string.Empty).Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries))
        {
            try { var candidate = Path.Combine(directory.Trim(), name); if (File.Exists(candidate)) return candidate; }
            catch { }
        }
        return null;
    }

    private static async Task<string> WriteEditorToolFileAsync(string source)
    {
        var directory = Path.Combine(AppDataDirectory, "editor-tools");
        Directory.CreateDirectory(directory);
        var path = Path.Combine(directory, "current.luau");
        await File.WriteAllTextAsync(path, source);
        return path;
    }

    private static async Task<EditorToolResult> RunEditorToolAsync(string executable, string arguments)
    {
        using var process = Process.Start(new ProcessStartInfo { FileName = executable, Arguments = arguments, UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true }) ?? throw new InvalidOperationException("Windows did not start the editor tool.");
        var outputTask = process.StandardOutput.ReadToEndAsync();
        var errorTask = process.StandardError.ReadToEndAsync();
        await process.WaitForExitAsync();
        return new EditorToolResult(process.ExitCode, (await outputTask).Trim(), (await errorTask).Trim());
    }

    private async void DiscoverCommandsButton_Click(object sender, RoutedEventArgs e) => await DiscoverCommandsAsync();

    private async Task DiscoverCommandsAsync()
    {
        CommandInfoBar.Severity = InfoBarSeverity.Informational;
        CommandInfoBar.Title = "Discovering Studio commands";
        CommandInfoBar.Message = "Reading the command catalog from the connected companion.";
        CommandPicker.IsEnabled = false;
        try
        {
            using var response = await _http.PostAsJsonAsync("plugin/call", new { command = new { type = "get_capabilities" } });
            var json = await response.Content.ReadAsStringAsync();
            response.EnsureSuccessStatusCode();
            using var document = JsonDocument.Parse(json);
            var root = document.RootElement;
            var catalog = FindCommandsElement(root);
            if (catalog is null || catalog.Value.ValueKind != JsonValueKind.Object)
            {
                throw new InvalidOperationException("The companion did not return a command schema catalog.");
            }

            _commandSchemas.Clear();
            foreach (var property in catalog.Value.EnumerateObject())
            {
                _commandSchemas[property.Name] = property.Value.Clone();
            }
            AddAppCommandSchemas();
            var names = _commandSchemas.Keys.OrderBy(name => name, StringComparer.Ordinal).ToArray();
            ApplyCommandFilters();
            _commandCatalogLoaded = names.Length > 0;
            CommandInfoBar.Severity = InfoBarSeverity.Success;
            CommandInfoBar.Title = $"{names.Length} commands available";
            CommandInfoBar.Message = "Select a command, review its schema, and supply a JSON argument object.";
            if (names.Length > 0 && CommandPicker.SelectedIndex < 0) CommandPicker.SelectedIndex = 0;
        }
        catch (Exception exception)
        {
            _commandCatalogLoaded = false;
            CommandInfoBar.Severity = InfoBarSeverity.Warning;
            CommandInfoBar.Title = "Command discovery unavailable";
            CommandInfoBar.Message = exception.Message;
        }
        finally
        {
            CommandPicker.IsEnabled = true;
        }
    }

    private static JsonElement? FindCommandsElement(JsonElement element)
    {
        if (element.ValueKind != JsonValueKind.Object) return null;
        if (element.TryGetProperty("commands", out var commands)) return commands;
        foreach (var name in new[] { "result", "response", "data" })
        {
            if (element.TryGetProperty(name, out var nested) && FindCommandsElement(nested) is JsonElement found) return found;
        }
        return null;
    }

    private void AddAppCommandSchemas()
    {
        using var document = JsonDocument.Parse("""
        {
          "type": "object",
          "description": "Atomically apply exact text replacements to one script. Edit mode is automatic.",
          "properties": {
            "file_path": { "type": "string", "description": "Dot path, for example game.ServerScriptService.Main" },
            "edits": {
              "type": "array",
              "description": "Ordered exact replacements",
              "items": {
                "type": "object",
                "properties": {
                  "old_string": { "type": "string" },
                  "new_string": { "type": "string" },
                  "replace_all": { "type": "boolean" }
                },
                "required": ["old_string", "new_string"]
              }
            },
            "className": { "type": "string", "description": "Only for creation: Script, LocalScript, or ModuleScript" }
          },
          "required": ["file_path", "edits"]
        }
        """);
        _commandSchemas["multi_edit"] = document.RootElement.Clone();
    }

    private void CommandPicker_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        var command = CommandPicker.SelectedItem?.ToString();
        RunCommandButton.IsEnabled = command is not null;
        QueueCommandButton.IsEnabled = command is not null;
        FavoriteCommandButton.IsEnabled = command is not null;
        FavoriteCommandButton.Content = command is not null && _favoriteCommands.Contains(command) ? "★ Favorite" : "☆ Favorite";
        CommandSchemaText.Text = command is not null && _commandSchemas.TryGetValue(command, out var schema)
            ? JsonSerializer.Serialize(schema, new JsonSerializerOptions { WriteIndented = true })
            : "Select a command to inspect its schema.";
        if (command is not null && _commandSchemas.TryGetValue(command, out schema))
        {
            CommandArgumentsTextBox.Text = GenerateArgumentTemplate(schema);
            BuildStructuredArgumentControls(schema);
        }
        else StructuredArgumentsPanel.Children.Clear();
    }

    private void BuildStructuredArgumentControls(JsonElement schema)
    {
        _syncingStructuredArguments = true;
        StructuredArgumentsPanel.Children.Clear();
        _structuredArgumentControls.Clear();
        if (!schema.TryGetProperty("properties", out var properties) || properties.ValueKind != JsonValueKind.Object || !properties.EnumerateObject().Any())
        {
            StructuredArgumentsPanel.Children.Add(new TextBlock { Text = "This command has no arguments.", Foreground = ThemeBrush("TextFillColorSecondaryBrush") });
            _syncingStructuredArguments = false;
            return;
        }
        var required = schema.TryGetProperty("required", out var requiredElement) && requiredElement.ValueKind == JsonValueKind.Array
            ? requiredElement.EnumerateArray().Select(item => item.GetString()).OfType<string>().ToHashSet(StringComparer.Ordinal)
            : new HashSet<string>(StringComparer.Ordinal);
        foreach (var property in properties.EnumerateObject())
        {
            var label = new TextBlock { Text = required.Contains(property.Name) ? $"{property.Name}  *" : property.Name, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold };
            FrameworkElement control;
            if (property.Value.TryGetProperty("enum", out var choices) && choices.ValueKind == JsonValueKind.Array)
            {
                var combo = new ComboBox { HorizontalAlignment = HorizontalAlignment.Stretch, ItemsSource = choices.EnumerateArray().Select(item => item.ToString()).ToArray(), SelectedIndex = 0 };
                combo.SelectionChanged += StructuredArgument_Changed;
                control = combo;
            }
            else
            {
                var type = property.Value.TryGetProperty("type", out var typeElement) ? typeElement.GetString() : "string";
                if (type == "boolean")
                {
                    var toggle = new ToggleSwitch { OffContent = "false", OnContent = "true" };
                    toggle.Toggled += StructuredArgument_Changed;
                    control = toggle;
                }
                else if (type is "number" or "integer")
                {
                    var number = new NumberBox { SpinButtonPlacementMode = NumberBoxSpinButtonPlacementMode.Compact };
                    number.ValueChanged += StructuredArgument_Changed;
                    control = number;
                }
                else
                {
                    var structuredJson = type is "array" or "object";
                    var box = new TextBox { PlaceholderText = structuredJson ? (type == "array" ? "[]" : "{}") : "Enter value", AcceptsReturn = structuredJson };
                    if (structuredJson) box.FontFamily = new FontFamily("Consolas");
                    box.TextChanged += StructuredArgument_Changed;
                    control = box;
                }
            }
            control.Tag = new StructuredArgumentTag(property.Name, property.Value.TryGetProperty("type", out var kind) ? kind.GetString() ?? "string" : "string", required.Contains(property.Name));
            _structuredArgumentControls[property.Name] = control;
            StructuredArgumentsPanel.Children.Add(new StackPanel { Spacing = 4, Children = { label, control } });
        }
        _syncingStructuredArguments = false;
        SyncStructuredArgumentsToJson();
    }

    private void StructuredArgument_Changed(object sender, object e)
    {
        if (!_syncingStructuredArguments) SyncStructuredArgumentsToJson();
    }

    private void SyncStructuredArgumentsToJson()
    {
        var values = new Dictionary<string, object?>();
        foreach (var control in _structuredArgumentControls.Values)
        {
            if (control.Tag is not StructuredArgumentTag tag) continue;
            object? value = control switch
            {
                ToggleSwitch toggle => toggle.IsOn,
                NumberBox number when !double.IsNaN(number.Value) => tag.Type == "integer" ? (int)number.Value : number.Value,
                ComboBox combo => combo.SelectedItem?.ToString(),
                TextBox box when tag.Type is "array" or "object" && !string.IsNullOrWhiteSpace(box.Text) => ParseStructuredJson(box.Text),
                TextBox box => box.Text,
                _ => null,
            };
            var emptyOptional = !tag.Required && value is string text && text.Length == 0;
            if (!emptyOptional && value is not null) values[tag.Name] = value;
        }
        CommandArgumentsTextBox.Text = JsonSerializer.Serialize(values, new JsonSerializerOptions { WriteIndented = true });
    }

    private static object? ParseStructuredJson(string text)
    {
        try { using var document = JsonDocument.Parse(text); return document.RootElement.Clone(); }
        catch { return text; }
    }

    private void CommandSearchTextBox_TextChanged(object sender, TextChangedEventArgs e) => ApplyCommandFilters();

    private void CommandCategoryPicker_SelectionChanged(object sender, SelectionChangedEventArgs e) => ApplyCommandFilters();

    private void ApplyCommandFilters()
    {
        if (CommandPicker is null) return;
        var selected = CommandPicker.SelectedItem?.ToString();
        var search = CommandSearchTextBox?.Text?.Trim() ?? string.Empty;
        var category = (CommandCategoryPicker?.SelectedItem as ComboBoxItem)?.Tag?.ToString() ?? "all";
        var filtered = _commandSchemas.Keys
            .Where(name => search.Length == 0 || name.Contains(search, StringComparison.OrdinalIgnoreCase))
            .Where(name => category == "all" || category == "favorites" && _favoriteCommands.Contains(name) || CommandCategory(name) == category)
            .OrderByDescending(name => _favoriteCommands.Contains(name))
            .ThenBy(name => name, StringComparer.Ordinal)
            .ToArray();
        CommandPicker.ItemsSource = filtered;
        if (selected is not null && filtered.Contains(selected)) CommandPicker.SelectedItem = selected;
        else if (filtered.Length > 0) CommandPicker.SelectedIndex = 0;
    }

    private static string CommandCategory(string command)
    {
        if (command.Contains("source", StringComparison.Ordinal) || command.Contains("script", StringComparison.Ordinal) || command is "export_scripts" or "multi_edit") return "scripts";
        if (command.Contains("instance", StringComparison.Ordinal) || command is "get_children" or "resolve_path" or "set_properties" or "get_properties") return "instances";
        if (command.Contains("play", StringComparison.Ordinal) || command is "execute_luau" or "subscribe" or "batch") return "runtime";
        return "read";
    }

    private void FavoriteCommandButton_Click(object sender, RoutedEventArgs e)
    {
        var command = CommandPicker.SelectedItem?.ToString();
        if (command is null) return;
        if (!_favoriteCommands.Add(command)) _favoriteCommands.Remove(command);
        SaveCommandWorkspaceState();
        ApplyCommandFilters();
    }

    private static string GenerateArgumentTemplate(JsonElement schema)
    {
        if (!schema.TryGetProperty("properties", out var properties) || properties.ValueKind != JsonValueKind.Object) return "{}";
        var required = schema.TryGetProperty("required", out var requiredElement) && requiredElement.ValueKind == JsonValueKind.Array
            ? requiredElement.EnumerateArray().Select(item => item.GetString()).OfType<string>().ToHashSet(StringComparer.Ordinal)
            : new HashSet<string>(StringComparer.Ordinal);
        var template = new Dictionary<string, object?>();
        foreach (var property in properties.EnumerateObject())
        {
            if (!required.Contains(property.Name)) continue;
            template[property.Name] = DefaultSchemaValue(property.Value);
        }
        if (template.Count == 0 && schema.TryGetProperty("anyOf", out var alternatives) && alternatives.ValueKind == JsonValueKind.Array)
        {
            var first = alternatives.EnumerateArray().FirstOrDefault();
            if (first.ValueKind == JsonValueKind.Object && first.TryGetProperty("required", out var alternativeRequired))
            {
                foreach (var item in alternativeRequired.EnumerateArray())
                {
                    var name = item.GetString();
                    if (name is not null && properties.TryGetProperty(name, out var propertySchema)) template[name] = DefaultSchemaValue(propertySchema);
                }
            }
        }
        return JsonSerializer.Serialize(template, new JsonSerializerOptions { WriteIndented = true });
    }

    private static object? DefaultSchemaValue(JsonElement schema)
    {
        if (schema.TryGetProperty("enum", out var choices) && choices.ValueKind == JsonValueKind.Array)
        {
            var first = choices.EnumerateArray().FirstOrDefault();
            if (first.ValueKind == JsonValueKind.String) return first.GetString();
        }
        var type = schema.TryGetProperty("type", out var typeElement) ? typeElement.GetString() : null;
        return type switch { "boolean" => false, "number" or "integer" => 0, "array" => Array.Empty<object>(), "object" => new Dictionary<string, object?>(), _ => string.Empty };
    }

    private async void SaveCommandPresetButton_Click(object sender, RoutedEventArgs e)
    {
        var command = CommandPicker.SelectedItem?.ToString();
        if (command is null) return;
        try { using var document = JsonDocument.Parse(CommandArgumentsTextBox.Text); if (document.RootElement.ValueKind != JsonValueKind.Object) throw new JsonException(); }
        catch { ShowMessage("Preset not saved", "Arguments must contain a valid JSON object.", InfoBarSeverity.Error); return; }
        var nameBox = new TextBox { Header = "Preset name", PlaceholderText = $"{command} preset" };
        var dialog = new ContentDialog { XamlRoot = (Content as FrameworkElement)?.XamlRoot, Title = "Save command preset", Content = nameBox, PrimaryButtonText = "Save", CloseButtonText = "Cancel", DefaultButton = ContentDialogButton.Primary };
        if (await dialog.ShowAsync() != ContentDialogResult.Primary || string.IsNullOrWhiteSpace(nameBox.Text)) return;
        _commandPresets[nameBox.Text.Trim()] = new CommandPreset(command, CommandArgumentsTextBox.Text);
        RefreshPresetPicker(nameBox.Text.Trim());
        SaveCommandWorkspaceState();
    }

    private void CommandPresetPicker_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        var name = CommandPresetPicker.SelectedItem?.ToString();
        if (name is null || !_commandPresets.TryGetValue(name, out var preset)) return;
        if (_commandSchemas.ContainsKey(preset.Command)) CommandPicker.SelectedItem = preset.Command;
        CommandArgumentsTextBox.Text = preset.Arguments;
    }

    private void DeleteCommandPresetButton_Click(object sender, RoutedEventArgs e)
    {
        var name = CommandPresetPicker.SelectedItem?.ToString();
        if (name is null || !_commandPresets.Remove(name)) return;
        RefreshPresetPicker();
        SaveCommandWorkspaceState();
    }

    private void RefreshPresetPicker(string? selected = null)
    {
        var names = _commandPresets.Keys.OrderBy(name => name, StringComparer.OrdinalIgnoreCase).ToArray();
        CommandPresetPicker.ItemsSource = names;
        if (selected is not null && names.Contains(selected)) CommandPresetPicker.SelectedItem = selected;
    }

    private void QueueCommandButton_Click(object sender, RoutedEventArgs e)
    {
        var command = CommandPicker.SelectedItem?.ToString();
        if (command is null) return;
        try
        {
            using var document = JsonDocument.Parse(CommandArgumentsTextBox.Text);
            if (document.RootElement.ValueKind != JsonValueKind.Object) throw new JsonException("Arguments must be an object.");
            var summary = document.RootElement.EnumerateObject().Select(property => property.Name).Take(4).ToArray();
            _approvalQueueItems.Add(new ApprovalQueueRow((_approvalQueueItems.Count + 1).ToString(), command, summary.Length == 0 ? "No arguments" : $"Fields: {string.Join(", ", summary)}", document.RootElement.Clone()));
            ExecuteApprovalQueueButton.IsEnabled = true;
        }
        catch (Exception exception) { ShowMessage("Command not queued", exception.Message, InfoBarSeverity.Error); }
    }

    private void ClearApprovalQueueButton_Click(object sender, RoutedEventArgs e)
    {
        _approvalQueueItems.Clear();
        ExecuteApprovalQueueButton.IsEnabled = false;
    }

    private async void ExecuteApprovalQueueButton_Click(object sender, RoutedEventArgs e)
    {
        if (_approvalQueueItems.Count == 0) return;
        var atomic = _approvalQueueItems.All(item => IsBatchSupportedCommand(item.Command));
        var dialog = new ContentDialog { XamlRoot = (Content as FrameworkElement)?.XamlRoot, Title = atomic ? "Execute atomic command batch?" : "Execute command queue?", Content = atomic ? $"{_approvalQueueItems.Count} mutations will commit as one Studio history recording and roll back together on failure." : $"{_approvalQueueItems.Count} commands will run sequentially. Each result will be recorded.", PrimaryButtonText = atomic ? "Commit batch" : "Run queue", CloseButtonText = "Cancel", DefaultButton = ContentDialogButton.Close };
        if (await dialog.ShowAsync() != ContentDialogResult.Primary) return;
        ExecuteApprovalQueueButton.IsEnabled = false;
        try
        {
            if (atomic)
            {
                var operations = _approvalQueueItems.Select(ToCommandDictionary).ToArray();
                var result = await CallPluginAsync(new Dictionary<string, object?> { ["type"] = "batch", ["name"] = "Abraxius approved workflow", ["operations"] = operations });
                CommandResultTextBox.Text = JsonSerializer.Serialize(result, new JsonSerializerOptions { WriteIndented = true });
                foreach (var item in _approvalQueueItems) AddCommandHistory(item.Command, "Completed in approved atomic batch");
            }
            else
            {
                foreach (var item in _approvalQueueItems)
                {
                    try { await CallCommandAsync(item.Command, item.Arguments); AddCommandHistory(item.Command, "Completed in approved queue"); }
                    catch (Exception exception) { AddCommandHistory(item.Command, $"Failed: {RedactSummary(exception.Message)}"); throw; }
                }
            }
            CommandInfoBar.Severity = InfoBarSeverity.Success;
            CommandInfoBar.Title = atomic ? "Atomic batch completed" : "Command queue completed";
            CommandInfoBar.Message = $"{_approvalQueueItems.Count} approved commands executed.";
            ClearApprovalQueueButton_Click(sender, e);
        }
        catch (Exception exception)
        {
            CommandInfoBar.Severity = InfoBarSeverity.Error;
            CommandInfoBar.Title = atomic ? "Atomic batch rolled back" : "Command queue stopped";
            CommandInfoBar.Message = exception.Message;
        }
        finally { ExecuteApprovalQueueButton.IsEnabled = _approvalQueueItems.Count > 0; }
    }

    private static Dictionary<string, object?> ToCommandDictionary(ApprovalQueueRow item)
    {
        var command = new Dictionary<string, object?> { ["type"] = item.Command };
        foreach (var property in item.Arguments.EnumerateObject()) command[property.Name] = property.Value.Clone();
        return command;
    }

    private static bool IsBatchSupportedCommand(string command) => command is "write_source" or "create_script" or "set_properties" or "create_instance" or "clone_instance" or "rename_instance" or "reparent_instance" or "transform_instance" or "delete_instance";

    private async void SaveWorkflowButton_Click(object sender, RoutedEventArgs e)
    {
        if (_approvalQueueItems.Count == 0) { ShowMessage("Workflow is empty", "Add commands to the approval queue first.", InfoBarSeverity.Warning); return; }
        var box = new TextBox { Header = "Workflow name", PlaceholderText = "My Studio workflow" };
        var dialog = new ContentDialog { XamlRoot = (Content as FrameworkElement)?.XamlRoot, Title = "Save command workflow", Content = box, PrimaryButtonText = "Save", CloseButtonText = "Cancel" };
        if (await dialog.ShowAsync() != ContentDialogResult.Primary || string.IsNullOrWhiteSpace(box.Text)) return;
        _commandWorkflows[box.Text.Trim()] = new CommandWorkflow(_approvalQueueItems.Select(item => new WorkflowCommand(item.Command, item.Arguments.GetRawText())).ToArray());
        RefreshWorkflowPicker(box.Text.Trim());
        SaveCommandWorkspaceState();
    }

    private void LoadWorkflowButton_Click(object sender, RoutedEventArgs e)
    {
        var name = WorkflowPicker.SelectedItem?.ToString();
        if (name is null || !_commandWorkflows.TryGetValue(name, out var workflow)) return;
        _approvalQueueItems.Clear();
        foreach (var item in workflow.Commands)
        {
            try { using var document = JsonDocument.Parse(item.Arguments); _approvalQueueItems.Add(new ApprovalQueueRow((_approvalQueueItems.Count + 1).ToString(), item.Command, "Saved workflow command", document.RootElement.Clone())); }
            catch { }
        }
        ExecuteApprovalQueueButton.IsEnabled = _approvalQueueItems.Count > 0;
    }

    private void RefreshWorkflowPicker(string? selected = null)
    {
        var names = _commandWorkflows.Keys.OrderBy(name => name, StringComparer.OrdinalIgnoreCase).ToArray();
        WorkflowPicker.ItemsSource = names;
        if (selected is not null && names.Contains(selected)) WorkflowPicker.SelectedItem = selected;
    }

    private void LoadCommandWorkspaceState()
    {
        try
        {
            var path = CommandWorkspaceStatePath;
            if (File.Exists(path))
            {
                var state = JsonSerializer.Deserialize<CommandWorkspaceState>(File.ReadAllText(path));
                foreach (var favorite in state?.Favorites ?? Array.Empty<string>()) _favoriteCommands.Add(favorite);
                foreach (var preset in state?.Presets ?? new Dictionary<string, CommandPreset>()) _commandPresets[preset.Key] = preset.Value;
                foreach (var workflow in state?.Workflows ?? new Dictionary<string, CommandWorkflow>()) _commandWorkflows[workflow.Key] = workflow.Value;
                _historyRetention = state?.HistoryRetention is 25 or 100 or 250 ? state.HistoryRetention : 100;
                foreach (var history in (state?.History ?? Array.Empty<CommandHistoryRow>()).Take(_historyRetention)) _commandHistoryItems.Add(history);
            }
        }
        catch { }
        RefreshPresetPicker();
        RefreshWorkflowPicker();
        if (HistoryRetentionPicker is not null)
        {
            HistoryRetentionPicker.SelectedIndex = _historyRetention == 25 ? 0 : _historyRetention == 250 ? 2 : 1;
        }
    }

    private void SaveCommandWorkspaceState()
    {
        try
        {
            Directory.CreateDirectory(AppDataDirectory);
            var state = new CommandWorkspaceState(_favoriteCommands.OrderBy(name => name).ToArray(), _commandPresets, _commandWorkflows, _commandHistoryItems.Take(_historyRetention).ToArray(), _historyRetention);
            File.WriteAllText(CommandWorkspaceStatePath, JsonSerializer.Serialize(state, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch (Exception exception) { ShowMessage("Could not save command workspace", exception.Message, InfoBarSeverity.Warning); }
    }

    private async void RunCommandButton_Click(object sender, RoutedEventArgs e)
    {
        var commandName = CommandPicker.SelectedItem?.ToString();
        if (commandName is null) return;
        JsonElement arguments;
        try
        {
            using var argumentDocument = JsonDocument.Parse(CommandArgumentsTextBox.Text);
            if (argumentDocument.RootElement.ValueKind != JsonValueKind.Object) throw new JsonException("Arguments must be a JSON object.");
            arguments = argumentDocument.RootElement.Clone();
        }
        catch (Exception exception)
        {
            ShowMessage("Invalid command arguments", exception.Message, InfoBarSeverity.Error);
            return;
        }

        var dryRunApproved = false;
        if (commandName == "write_source" && (!arguments.TryGetProperty("dryRun", out var requestedDryRun) || requestedDryRun.ValueKind != JsonValueKind.True))
        {
            try
            {
                var previewCommand = new Dictionary<string, object?> { ["type"] = commandName, ["dryRun"] = true };
                foreach (var property in arguments.EnumerateObject()) previewCommand[property.Name] = property.Value.Clone();
                previewCommand["dryRun"] = true;
                var preview = await CallPluginAsync(previewCommand);
                var formattedPreview = JsonSerializer.Serialize(preview, new JsonSerializerOptions { WriteIndented = true });
                CommandResultTextBox.Text = formattedPreview;
                var previewDialog = new ContentDialog { XamlRoot = (Content as FrameworkElement)?.XamlRoot, Title = "Review source dry-run", Content = new ScrollViewer { MaxHeight = 420, Content = new TextBlock { Text = formattedPreview, FontFamily = new FontFamily("Consolas"), TextWrapping = TextWrapping.Wrap } }, PrimaryButtonText = "Commit source", CloseButtonText = "Cancel", DefaultButton = ContentDialogButton.Close };
                if (await previewDialog.ShowAsync() != ContentDialogResult.Primary) return;
                dryRunApproved = true;
            }
            catch (Exception exception) { ShowMessage("Dry-run failed", exception.Message, InfoBarSeverity.Error); return; }
        }

        if (IsMutatingCommand(commandName) && !dryRunApproved)
        {
            var dialog = new ContentDialog { XamlRoot = (Content as FrameworkElement)?.XamlRoot, Title = $"Run {commandName}?", Content = "This command can change the open Studio place. Review the arguments before continuing.", PrimaryButtonText = "Run command", CloseButtonText = "Cancel", DefaultButton = ContentDialogButton.Close };
            if (await dialog.ShowAsync() != ContentDialogResult.Primary) return;
        }

        RunCommandButton.IsEnabled = false;
        CommandProgress.IsActive = true;
        CommandProgress.Visibility = Visibility.Visible;
        try
        {
            var result = await CallCommandAsync(commandName, arguments);
            CommandResultTextBox.Text = JsonSerializer.Serialize(result, new JsonSerializerOptions { WriteIndented = true });
            AddCommandHistory(commandName, "Completed successfully");
            CommandInfoBar.Severity = InfoBarSeverity.Success;
            CommandInfoBar.Title = $"{commandName} completed";
            CommandInfoBar.Message = "Abraxius returned a result.";
        }
        catch (Exception exception)
        {
            CommandResultTextBox.Text = exception.Message;
            AddCommandHistory(commandName, $"Failed: {RedactSummary(exception.Message)}");
            CommandInfoBar.Severity = InfoBarSeverity.Error;
            CommandInfoBar.Title = $"{commandName} failed";
            CommandInfoBar.Message = exception.Message;
        }
        finally
        {
            CommandProgress.IsActive = false;
            CommandProgress.Visibility = Visibility.Collapsed;
            RunCommandButton.IsEnabled = true;
        }
    }

    private static bool IsMutatingCommand(string command) => command is "write_source" or "create_script" or "multi_edit" or "axl" or "execute_luau" or "set_selection" or "set_properties" or "create_instance" or "clone_instance" or "rename_instance" or "reparent_instance" or "transform_instance" or "delete_instance" or "batch" or "set_play_data_enabled";

    private void AddCommandHistory(string command, string summary)
    {
        _commandHistoryItems.Insert(0, new CommandHistoryRow(DateTimeOffset.Now.ToString("yyyy-MM-dd h:mm:ss tt"), command, RedactSummary(summary)));
        while (_commandHistoryItems.Count > _historyRetention) _commandHistoryItems.RemoveAt(_commandHistoryItems.Count - 1);
        SaveCommandWorkspaceState();
    }

    private static string RedactSummary(string summary)
    {
        if (summary.Length > 240) summary = summary[..240] + "…";
        summary = System.Text.RegularExpressions.Regex.Replace(summary, "(?i)(api[_-]?key|token|authorization|password)\\s*[:=]\\s*[^\\s,;]+", "$1=[redacted]");
        return summary;
    }

    private void HistoryRetentionPicker_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if ((HistoryRetentionPicker?.SelectedItem as ComboBoxItem)?.Tag?.ToString() is string value && int.TryParse(value, out var retention))
        {
            _historyRetention = retention;
            while (_commandHistoryItems.Count > retention) _commandHistoryItems.RemoveAt(_commandHistoryItems.Count - 1);
            SaveCommandWorkspaceState();
        }
    }

    private void ClearCommandHistoryButton_Click(object sender, RoutedEventArgs e)
    {
        _commandHistoryItems.Clear();
        SaveCommandWorkspaceState();
    }

    private void OutputFilter_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (!_initializing) ApplyOutputFilter();
    }

    private void SetAnalyticsUnavailable(string status)
    {
        AnalyticsDot.Fill = ThemeBrush("SystemFillColorNeutralBrush");
        AnalyticsFreshnessText.Text = status;
        StudioMemoryText.Text = "Memory  --";
        StudioRoleText.Text = "Role  --";
        StudioPhysicsText.Text = "Physics  --";
        PlayerCountText.Text = "Players  --";
        InstanceCountText.Text = "Instances  --";
        ScriptCountText.Text = "Scripts  --";
        PartCountText.Text = "Parts  --";
    }

    private Process? TryGetProcess(int pid)
    {
        try
        {
            var process = Process.GetProcessById(pid);
            process.Refresh();
            return process.HasExited ? null : process;
        }
        catch
        {
            return null;
        }
    }

    private string FormatProcessResources(string label, Process? process)
    {
        if (process is null)
        {
            return $"{label}  --";
        }
        try
        {
            var now = DateTimeOffset.UtcNow;
            var cpuTime = process.TotalProcessorTime;
            var cpu = 0.0;
            if (_processSamples.TryGetValue(process.Id, out var previous))
            {
                var elapsedMs = (now - previous.CapturedAt).TotalMilliseconds;
                if (elapsedMs > 0)
                {
                    cpu = Math.Max(0, (cpuTime - previous.CpuTime).TotalMilliseconds /
                        elapsedMs / Environment.ProcessorCount * 100);
                }
            }
            _processSamples[process.Id] = new ProcessSample(now, cpuTime);
            return $"{label}  {process.WorkingSet64 / 1048576.0:0} MB  |  {cpu:0.0}% CPU";
        }
        catch
        {
            return $"{label}  unavailable";
        }
        finally
        {
            process.Dispose();
        }
    }

    private async Task<bool> StartServerAsync(bool showErrors = true)
    {
        await _serverLifecycle.WaitAsync();
        try
        {
            if (_quitting || _intentionalStop)
            {
                return false;
            }

            if (await IsServerRunningAsync())
            {
                _lastStartError = null;
                return true;
            }

            var daemon = Path.Combine(AppContext.BaseDirectory, "abraxius-daemon.exe");
            if (!File.Exists(daemon))
            {
                throw new FileNotFoundException("The Rust server executable was not found.", daemon);
            }

            Directory.CreateDirectory(AppDataDirectory);
            var log = new FileStream(LogPath, FileMode.Append, FileAccess.Write, FileShare.ReadWrite);
            var process = Process.Start(new ProcessStartInfo
            {
                FileName = daemon,
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
            });
            if (process is null)
            {
                log.Dispose();
                throw new InvalidOperationException("Windows did not start the Rust server process.");
            }
            _daemonProcess = process;
            process.BeginWriteTo(log);

            for (var attempt = 0; attempt < 30; attempt++)
            {
                if (_quitting)
                {
                    TryKillEmbeddedDaemon((uint)process.Id);
                    return false;
                }
                if (await IsServerRunningAsync())
                {
                    _lastStartError = null;
                    return true;
                }
                if (process.HasExited)
                {
                    throw new InvalidOperationException(
                        $"The Rust server exited with code {process.ExitCode}. Open logs for details.");
                }
                await Task.Delay(100);
            }
            throw new TimeoutException("The Rust server did not become healthy. Open logs for details.");
        }
        catch (Exception ex)
        {
            _lastStartError = ex.Message;
            if (showErrors)
            {
                ShowMessage("Could not start the server", ex.Message, Microsoft.UI.Xaml.Controls.InfoBarSeverity.Error);
            }
            return false;
        }
        finally
        {
            _serverLifecycle.Release();
        }
    }

    private async Task StopServerAsync()
    {
        _intentionalStop = true;
        await _serverLifecycle.WaitAsync();
        try
        {
            using var response = await _http.PostAsJsonAsync("shutdown", new { });
            response.EnsureSuccessStatusCode();
        }
        catch
        {
        }
        finally
        {
            _serverLifecycle.Release();
        }
    }

    private async Task RestartServerAsync()
    {
        await StopServerAsync();
        await Task.Delay(350);
        _intentionalStop = false;
        await StartServerAsync();
        await RefreshAsync();
    }

    private async Task<bool> IsServerRunningAsync()
    {
        try
        {
            using var response = await _http.GetAsync("health");
            return response.IsSuccessStatusCode;
        }
        catch
        {
            return false;
        }
    }

    private async void StartButton_Click(object sender, RoutedEventArgs e)
    {
        StartButton.IsEnabled = false;
        if (await IsServerRunningAsync())
        {
            await RestartServerAsync();
        }
        else
        {
            _intentionalStop = false;
            await StartServerAsync();
            await RefreshAsync();
        }
        StartButton.IsEnabled = true;
    }

    private async void StopButton_Click(object sender, RoutedEventArgs e)
    {
        await StopServerAsync();
        ShowMessage("Server stopped", "Abraxius remains open and monitoring is paused until you start the server again.", Microsoft.UI.Xaml.Controls.InfoBarSeverity.Informational);
        await RefreshAsync();
    }

    private async void ForceMcpButton_Click(object sender, RoutedEventArgs e)
    {
        ForceMcpButton.IsEnabled = false;
        try
        {
            var owner = await FindListeningPortOwnerAsync(13469);
            if (owner is null)
            {
                await RestartServerAsync();
                ShowMessage("MCP listener restarted", "Port 13469 was free. The Rust host restarted and attempted to claim it.", InfoBarSeverity.Success);
                return;
            }

            var currentDaemonPid = _lastHealth?.Pid;
            if (owner.Pid == Environment.ProcessId || owner.Pid == currentDaemonPid ||
                owner.ProcessName.Contains("Abraxius", StringComparison.OrdinalIgnoreCase))
            {
                ShowMessage("Port already belongs to Abraxius", $"{owner.ProcessName} (PID {owner.Pid}) owns port 13469. No process was terminated.", InfoBarSeverity.Informational);
                return;
            }
            if (owner.ProcessName.Contains("RobloxStudio", StringComparison.OrdinalIgnoreCase))
            {
                ShowMessage("Roblox Studio owns the MCP port", "Abraxius will not terminate Studio. Stop its active MCP session in Studio, then try again.", InfoBarSeverity.Warning);
                return;
            }

            var dialog = new ContentDialog
            {
                XamlRoot = (Content as FrameworkElement)?.XamlRoot,
                Title = "Release MCP port 13469?",
                Content = $"{owner.ProcessName} (PID {owner.Pid}) is listening on port 13469. Abraxius will terminate that process and restart its Rust host.",
                PrimaryButtonText = "Terminate and reconnect",
                CloseButtonText = "Cancel",
                DefaultButton = ContentDialogButton.Close,
            };
            if (await dialog.ShowAsync() != ContentDialogResult.Primary)
            {
                return;
            }

            using (var process = Process.GetProcessById(owner.Pid))
            {
                process.Kill(entireProcessTree: true);
                using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(5));
                await process.WaitForExitAsync(timeout.Token);
            }
            await RestartServerAsync();
            var replacement = await FindListeningPortOwnerAsync(13469);
            if (replacement is not null && replacement.ProcessName.Contains("abraxius-daemon", StringComparison.OrdinalIgnoreCase))
            {
                ShowMessage("MCP port reclaimed", $"Terminated {owner.ProcessName} and assigned port 13469 to the Abraxius Rust host.", InfoBarSeverity.Success);
            }
            else
            {
                ShowMessage("MCP reconnect incomplete", "The conflicting process was terminated, but the Rust host has not claimed port 13469 yet. Check the host logs.", InfoBarSeverity.Warning);
            }
        }
        catch (Exception exception)
        {
            ShowMessage("Could not force MCP connection", exception.Message, InfoBarSeverity.Error);
        }
        finally
        {
            ForceMcpButton.IsEnabled = true;
            await RefreshAsync();
        }
    }

    private static async Task<PortOwner?> FindListeningPortOwnerAsync(int port)
    {
        using var netstat = Process.Start(new ProcessStartInfo
        {
            FileName = "netstat.exe",
            Arguments = "-ano -p tcp",
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
        }) ?? throw new InvalidOperationException("Windows could not start netstat.");
        var output = await netstat.StandardOutput.ReadToEndAsync();
        await netstat.WaitForExitAsync();
        if (netstat.ExitCode != 0)
        {
            throw new InvalidOperationException("Windows could not inspect TCP port ownership.");
        }

        foreach (var line in output.Split('\n', StringSplitOptions.RemoveEmptyEntries))
        {
            var fields = line.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
            if (fields.Length < 5 || !fields[0].Equals("TCP", StringComparison.OrdinalIgnoreCase) ||
                !fields[1].EndsWith($":{port}", StringComparison.Ordinal) ||
                !fields[3].Equals("LISTENING", StringComparison.OrdinalIgnoreCase) ||
                !int.TryParse(fields[4], out var pid))
            {
                continue;
            }
            try
            {
                using var process = Process.GetProcessById(pid);
                return new PortOwner(pid, process.ProcessName);
            }
            catch
            {
                return new PortOwner(pid, "Unknown process");
            }
        }
        return null;
    }

    private void LogsButton_Click(object sender, RoutedEventArgs e)
    {
        Directory.CreateDirectory(AppDataDirectory);
        if (!File.Exists(LogPath))
        {
            File.WriteAllText(LogPath, string.Empty);
        }
        Process.Start(new ProcessStartInfo("notepad.exe", $"\"{LogPath}\"") { UseShellExecute = true });
    }

    private async void RefreshButton_Click(object sender, RoutedEventArgs e)
    {
        RefreshButton.IsEnabled = false;
        try
        {
            await RefreshAsync();
        }
        finally
        {
            RefreshButton.IsEnabled = true;
        }
    }

    private void CopyStatusButton_Click(object sender, RoutedEventArgs e)
    {
        var package = new DataPackage();
        package.SetText(BuildStatusSummary());
        Clipboard.SetContent(package);
        ShowMessage("Status copied", "The current Abraxius health summary is on the clipboard.", InfoBarSeverity.Success);
    }

    private string BuildStatusSummary()
    {
        var health = _lastHealth;
        return health is null
            ? "Abraxius server: offline"
            : string.Join(Environment.NewLine,
                "Abraxius server: running",
                $"Version: {health.Version ?? "0.1.0"}",
                $"PID: {health.Pid?.ToString() ?? "unknown"}",
                $"Uptime: {FormatDuration(health.Uptime)}",
                $"Legacy MCP: {(health.Connected ? "connected" : "waiting")}",
                $"Companion: {(health.PluginConnected ? "connected" : "waiting")}",
                $"Companion version: {health.PluginVersion ?? "unknown"}",
                $"Tools loaded: {health.ToolsLoaded}");
    }

    private async void ExportDiagnosticsButton_Click(object sender, RoutedEventArgs e)
    {
        var clickedButton = sender as Button;
        if (clickedButton is not null) clickedButton.IsEnabled = false;
        try
        {
            var healthJson = await TryReadEndpointAsync(_http, "health");
            var analyticsJson = await TryReadEndpointAsync(_analytics, "snapshot");
            var bundle = await AppDiagnostics.CreateBundleAsync(BuildStatusSummary(), healthJson, analyticsJson);
            Process.Start(new ProcessStartInfo("explorer.exe", $"/select,\"{bundle.Path}\"") { UseShellExecute = true });
            ShowMessage(
                "Diagnostics bundle created",
                $"Saved {bundle.EntryCount} privacy-filtered files ({bundle.SizeBytes / 1024.0:0} KB) to {bundle.Path}",
                InfoBarSeverity.Success);
        }
        catch (Exception exception)
        {
            ShowMessage("Could not create diagnostics bundle", exception.Message, InfoBarSeverity.Error);
        }
        finally
        {
            if (clickedButton is not null) clickedButton.IsEnabled = true;
        }
    }

    private static async Task<string?> TryReadEndpointAsync(HttpClient client, string path)
    {
        try
        {
            using var response = await client.GetAsync(path);
            return response.IsSuccessStatusCode ? await response.Content.ReadAsStringAsync() : null;
        }
        catch
        {
            return null;
        }
    }

    private void DataFolderButton_Click(object sender, RoutedEventArgs e)
    {
        Directory.CreateDirectory(AppDataDirectory);
        Process.Start(new ProcessStartInfo("explorer.exe", $"\"{AppDataDirectory}\"") { UseShellExecute = true });
    }

    private async void InstallPluginButton_Click(object sender, RoutedEventArgs e)
    {
        await InstallPluginAsync();
    }

    private async Task InstallPluginAsync()
    {
        InstallPluginButton.IsEnabled = false;
        PluginInstallStatusText.Text = "Installing...";
        try
        {
            var installer = Path.Combine(AppContext.BaseDirectory, "abraxius.exe");
            if (!File.Exists(installer))
            {
                throw new FileNotFoundException("The bundled plugin installer was not found.", installer);
            }

            using var process = Process.Start(new ProcessStartInfo
            {
                FileName = installer,
                Arguments = "install-plugin",
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
            }) ?? throw new InvalidOperationException("Windows did not start the plugin installer.");

            var outputTask = process.StandardOutput.ReadToEndAsync();
            var errorTask = process.StandardError.ReadToEndAsync();
            await process.WaitForExitAsync();
            var output = (await outputTask).Trim();
            var error = (await errorTask).Trim();
            if (process.ExitCode != 0)
            {
                throw new InvalidOperationException(string.IsNullOrWhiteSpace(error)
                    ? $"Plugin installer exited with code {process.ExitCode}."
                    : error);
            }

            _bundledPluginVersion = null;
            await RefreshPluginInstallStateAsync(_lastHealth?.PluginVersion);
            ShowMessage(
                "Roblox plugin installed",
                string.IsNullOrWhiteSpace(output)
                    ? "Restart Roblox Studio to load the Abraxius companion."
                    : $"Restart Roblox Studio to load the updated companion.{Environment.NewLine}{output}",
                InfoBarSeverity.Success);
        }
        catch (Exception exception)
        {
            PluginInstallStatusText.Text = "Install failed";
            ShowMessage("Could not install Roblox plugin", exception.Message, InfoBarSeverity.Error);
        }
        finally
        {
            InstallPluginButton.IsEnabled = true;
        }
    }

    private async Task RefreshPluginInstallStateAsync(string? runningVersion)
    {
        _bundledPluginVersion ??= await GetBundledPluginVersionAsync();
        var installedVersion = GetInstalledPluginVersion();

        if (installedVersion is null)
        {
            PluginInstallButtonText.Text = "Install Roblox plugin";
            PluginInstallStatusText.Text = _bundledPluginVersion is null
                ? "Not installed"
                : $"Not installed  |  v{_bundledPluginVersion} available";
            return;
        }

        if (IsOlderVersion(installedVersion, _bundledPluginVersion))
        {
            PluginInstallButtonText.Text = "Update Roblox plugin";
            PluginInstallStatusText.Text = $"v{installedVersion} installed  |  v{_bundledPluginVersion} available";
            await PromptForPluginUpdateAsync(installedVersion, _bundledPluginVersion!);
            return;
        }

        PluginInstallButtonText.Text = "Reinstall Roblox plugin";
        PluginInstallStatusText.Text = runningVersion is not null && IsOlderVersion(runningVersion, installedVersion)
            ? $"v{runningVersion} running  |  restart Studio for v{installedVersion}"
            : $"Up to date  |  v{installedVersion}";
    }

    private async Task PromptForPluginUpdateAsync(string installedVersion, string availableVersion)
    {
        if (_pluginUpdatePromptActive || _pluginUpdatePromptedVersion == availableVersion)
        {
            return;
        }

        _pluginUpdatePromptActive = true;
        _pluginUpdatePromptedVersion = availableVersion;
        try
        {
            var dialog = new ContentDialog
            {
                XamlRoot = (Content as FrameworkElement)?.XamlRoot,
                Title = "Update Roblox companion?",
                Content = $"Abraxius companion v{availableVersion} is available. You have v{installedVersion} installed. Install the update now?",
                PrimaryButtonText = "Install update",
                CloseButtonText = "Later",
                DefaultButton = ContentDialogButton.Primary,
            };
            if (await dialog.ShowAsync() == ContentDialogResult.Primary)
            {
                await InstallPluginAsync();
            }
        }
        finally
        {
            _pluginUpdatePromptActive = false;
        }
    }

    private static async Task<string?> GetBundledPluginVersionAsync()
    {
        var installer = Path.Combine(AppContext.BaseDirectory, "abraxius.exe");
        if (!File.Exists(installer))
        {
            return null;
        }

        try
        {
            using var process = Process.Start(new ProcessStartInfo
            {
                FileName = installer,
                Arguments = "plugin-version",
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
            });
            if (process is null)
            {
                return null;
            }
            var output = await process.StandardOutput.ReadToEndAsync();
            await process.WaitForExitAsync();
            return process.ExitCode == 0 ? output.Trim() : null;
        }
        catch
        {
            return null;
        }
    }

    private static string? GetInstalledPluginVersion()
    {
        var path = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Roblox", "Plugins", "AbraxiusCompanion.lua");
        try
        {
            foreach (var line in File.ReadLines(path))
            {
                foreach (var marker in new[] { "local PLUGIN_VERSION = \"", "payload.version = \"" })
                {
                    var start = line.IndexOf(marker, StringComparison.Ordinal);
                    if (start >= 0)
                    {
                        start += marker.Length;
                        var end = line.IndexOf('"', start);
                        return end > start ? line[start..end] : null;
                    }
                }
            }
        }
        catch
        {
        }
        return null;
    }

    private static bool IsOlderVersion(string current, string? available)
    {
        if (available is null) return false;
        if (Version.TryParse(current, out var currentVersion) &&
            Version.TryParse(available, out var availableVersion))
        {
            return currentVersion < availableVersion;
        }

        static (int Major, int Minor, int Patch, int Revision)? ParseRevision(string value)
        {
            var match = System.Text.RegularExpressions.Regex.Match(
                value,
                @"^(\d+)\.(\d+)\.(\d+)([a-zA-Z]?)$");
            if (!match.Success) return null;
            var suffix = match.Groups[4].Value;
            return (
                int.Parse(match.Groups[1].Value),
                int.Parse(match.Groups[2].Value),
                int.Parse(match.Groups[3].Value),
                suffix.Length == 0 ? 0 : char.ToLowerInvariant(suffix[0]) - 'a' + 1);
        }

        var currentRevision = ParseRevision(current);
        var availableRevision = ParseRevision(available);
        return currentRevision is not null && availableRevision is not null &&
            currentRevision.Value.CompareTo(availableRevision.Value) < 0;
    }

    private async Task InitializeStartupAsync()
    {
        try
        {
            _startupTask = await StartupTask.GetAsync("AbraxiusStartup");
            StartupToggle.IsOn = _startupTask.State is StartupTaskState.Enabled or StartupTaskState.EnabledByPolicy;
        }
        catch (Exception ex)
        {
            ShowMessage("Windows startup unavailable", ex.Message, InfoBarSeverity.Warning);
        }
        finally
        {
            _initializing = false;
        }
    }

    private async void StartupToggle_Toggled(object sender, RoutedEventArgs e)
    {
        if (_initializing || _startupTask is null)
        {
            return;
        }

        try
        {
            if (StartupToggle.IsOn)
            {
                var state = await _startupTask.RequestEnableAsync();
                if (state is not (StartupTaskState.Enabled or StartupTaskState.EnabledByPolicy))
                {
                    _initializing = true;
                    StartupToggle.IsOn = false;
                    _initializing = false;
                    ShowMessage("Start with Windows was not enabled", "Windows or the user account declined the startup request.", InfoBarSeverity.Warning);
                }
            }
            else
            {
                _startupTask.Disable();
            }
        }
        catch (Exception ex)
        {
            _initializing = true;
            StartupToggle.IsOn = !StartupToggle.IsOn;
            _initializing = false;
            ShowMessage("Could not update Windows startup", ex.Message, Microsoft.UI.Xaml.Controls.InfoBarSeverity.Error);
        }
    }

    private async void SupervisionToggle_Toggled(object sender, RoutedEventArgs e)
    {
        SupervisionStatusText.Text = SupervisionToggle.IsOn ? "Enabled" : "Paused";
        if (!_initializing && SupervisionToggle.IsOn)
        {
            _intentionalStop = false;
            await RefreshAsync();
        }
    }

    private void AppWindow_Closing(AppWindow sender, AppWindowClosingEventArgs args)
    {
        if (_allowClose)
        {
            return;
        }
        args.Cancel = true;
        _ = SaveEditorSessionAsync();
        _appWindow.Hide();
        ShowMessage("Still running", "Abraxius is active in the notification area.", Microsoft.UI.Xaml.Controls.InfoBarSeverity.Informational);
    }

    public void ShowWindow()
    {
        if (_quitting)
        {
            return;
        }
        _appWindow.Show();
        Activate();
    }

    public void StartHidden() => _appWindow.Hide();

    private async Task QuitAsync()
    {
        if (Interlocked.Exchange(ref _quitStarted, 1) != 0)
        {
            return;
        }

        _quitting = true;
        _allowClose = true;
        _intentionalStop = true;
        _timer.Stop();
        _editorRecoveryTimer.Stop();
        _aiCancellation?.Cancel();
        await SaveEditorSessionAsync();
        try
        {
            await ShutdownServerForExitAsync();
        }
        catch
        {
        }
        finally
        {
            try
            {
                _trayIcon.Dispose();
            }
            catch
            {
            }

            if (_aiProvider is IDisposable disposableProvider) disposableProvider.Dispose();

            try
            {
                Close();
            }
            catch
            {
            }

            Environment.Exit(0);
        }
    }

    private async Task ShutdownServerForExitAsync()
    {
        uint? daemonPid = null;
        try
        {
            daemonPid = (await _http.GetFromJsonAsync<Health>("health"))?.Pid;
        }
        catch
        {
        }

        if (daemonPid is null)
        {
            if (_daemonProcess is { HasExited: false } startingDaemon)
            {
                TryKillEmbeddedDaemon((uint)startingDaemon.Id);
            }
            return;
        }

        try
        {
            using var shutdownClient = new HttpClient
            {
                BaseAddress = ApiBase,
                Timeout = TimeSpan.FromSeconds(2),
            };
            using var response = await shutdownClient.PostAsJsonAsync("shutdown", new { });
        }
        catch
        {
        }

        if (daemonPid is uint pid)
        {
            for (var attempt = 0; attempt < 20 && IsProcessRunning(pid); attempt++)
            {
                await Task.Delay(100);
            }
            TryKillEmbeddedDaemon(pid);
        }

        if (_daemonProcess is { HasExited: false } knownDaemon &&
            (uint)knownDaemon.Id != daemonPid)
        {
            TryKillEmbeddedDaemon((uint)knownDaemon.Id);
        }
    }

    private static bool IsProcessRunning(uint pid)
    {
        try
        {
            return !Process.GetProcessById((int)pid).HasExited;
        }
        catch
        {
            return false;
        }
    }

    private static void TryKillEmbeddedDaemon(uint pid)
    {
        try
        {
            using var process = Process.GetProcessById((int)pid);
            if (process.HasExited || !process.ProcessName.Equals("abraxius-daemon", StringComparison.OrdinalIgnoreCase))
            {
                return;
            }

            var executable = process.MainModule?.FileName;
            if (executable is null ||
                !Path.GetDirectoryName(executable)!.Equals(
                    Path.TrimEndingDirectorySeparator(AppContext.BaseDirectory),
                    StringComparison.OrdinalIgnoreCase))
            {
                return;
            }

            process.Kill(entireProcessTree: true);
            process.WaitForExit(2000);
        }
        catch
        {
        }
    }

    private void HandleTrayCommandError(Exception exception)
    {
        if (!_quitting)
        {
            ShowMessage("Tray command failed", exception.Message, InfoBarSeverity.Error);
        }
    }

    private async Task SmokeQuitAsync()
    {
        await Task.Delay(1500);
        await QuitAsync();
    }

    private void ShowMessage(string title, string message, Microsoft.UI.Xaml.Controls.InfoBarSeverity severity)
    {
        MessageBar.Title = title;
        MessageBar.Message = message;
        MessageBar.Severity = severity;
        MessageBar.IsOpen = true;
    }

    private static Brush ThemeBrush(string key) => (Brush)Application.Current.Resources[key];

    private static string FormatDuration(ulong seconds)
    {
        var duration = TimeSpan.FromSeconds(seconds);
        return duration.TotalHours >= 1 ? $"{(int)duration.TotalHours}h {duration.Minutes}m" : $"{duration.Minutes}m {duration.Seconds}s";
    }

    private static string AppDataDirectory => AppPaths.DataDirectory;
    private static string LogPath => AppPaths.HostLog;
    private static string CommandWorkspaceStatePath => AppPaths.CommandWorkspaceState;
    private static string EditorSessionPath => AppPaths.EditorSession;

    private sealed record Health(
        [property: JsonPropertyName("running")] bool Running,
        [property: JsonPropertyName("connected")] bool Connected,
        [property: JsonPropertyName("pluginConnected")] bool PluginConnected,
        [property: JsonPropertyName("pluginVersion")] string? PluginVersion,
        [property: JsonPropertyName("toolsLoaded")] int ToolsLoaded,
        [property: JsonPropertyName("uptime")] ulong Uptime,
        [property: JsonPropertyName("pid")] uint? Pid,
        [property: JsonPropertyName("version")] string? Version);

    private sealed record AnalyticsSnapshot(
        [property: JsonPropertyName("connected")] bool Connected,
        [property: JsonPropertyName("ageMs")] long? AgeMs,
        [property: JsonPropertyName("studio")] StudioAnalytics? Studio);

    private sealed record StudioAnalytics(
        [property: JsonPropertyName("mode")] string? Mode,
        [property: JsonPropertyName("isClient")] bool IsClient,
        [property: JsonPropertyName("isServer")] bool IsServer,
        [property: JsonPropertyName("players")] int Players,
        [property: JsonPropertyName("latencyMs")] int LatencyMs,
        [property: JsonPropertyName("totalMemoryMb")] double? TotalMemoryMb,
        [property: JsonPropertyName("physicsFps")] double? PhysicsFps,
        [property: JsonPropertyName("counts")] StudioCounts? Counts,
        [property: JsonPropertyName("playtest")] StudioPlaytest? Playtest,
        [property: JsonPropertyName("scriptActivity")] IReadOnlyList<StudioScriptActivity>? ScriptActivity);

    private sealed record StudioCounts(
        [property: JsonPropertyName("instances")] int Instances,
        [property: JsonPropertyName("scripts")] int Scripts,
        [property: JsonPropertyName("parts")] int Parts);

    private sealed record StudioPlaytest(
        [property: JsonPropertyName("enabled")] bool Enabled,
        [property: JsonPropertyName("active")] bool Active,
        [property: JsonPropertyName("elapsedSec")] int ElapsedSec,
        [property: JsonPropertyName("prints")] int Prints,
        [property: JsonPropertyName("warnings")] int Warnings,
        [property: JsonPropertyName("errors")] int Errors,
        [property: JsonPropertyName("output")] IReadOnlyList<StudioOutput>? Output);

    private sealed record StudioOutput(
        [property: JsonPropertyName("time")] long Time,
        [property: JsonPropertyName("level")] string? Level,
        [property: JsonPropertyName("message")] string? Message,
        [property: JsonPropertyName("script")] string? Script,
        [property: JsonPropertyName("line")] int? Line,
        [property: JsonPropertyName("playtest")] bool Playtest);

    private sealed record StudioScriptActivity(
        [property: JsonPropertyName("time")] long Time,
        [property: JsonPropertyName("path")] string? Path,
        [property: JsonPropertyName("sourceLength")] int SourceLength);

    private sealed record OutputRow(string Key, string TimeLabel, string LevelLabel, string Message, string Location, string Level);
    private sealed record ScriptActivityRow(string Key, string TimeLabel, string Path, string Detail);
    private sealed record ScriptExplorerRow(string Path, string Name, string Service);
    private sealed record EditorToolResult(int ExitCode, string Output, string Error);
    private sealed record EditorSession(string? ActivePath, IReadOnlyList<EditorSessionDocument> Documents);
    private sealed record EditorSessionDocument(string Path, string? Source, string? Hash, bool Dirty);
    private sealed record AiMemoryItem(string CreatedAt, string Text);
    private sealed record AiProjectState(string? Instructions, IReadOnlyList<AiMemoryItem>? Memories, IReadOnlyList<AiMessage>? Conversation);
    private sealed record IntelligenceEventRow(string Time, string Title, string Detail);
    private sealed record IntelligenceSuggestionRow(string Key, string Time, string Title, string Evidence, string Confidence);
    private sealed record IntelligenceProjectState(IReadOnlyList<IntelligenceEventRow>? Timeline, IReadOnlyList<IntelligenceSuggestionRow>? Suggestions);
    private sealed class EditorDocument(string path, string source, string? hash)
    {
        public string Path { get; } = path;
        public string Source { get; set; } = source;
        public string? Hash { get; set; } = hash;
        public bool Dirty { get; set; }
    }
    private sealed record CommandHistoryRow(string Time, string Command, string Summary);
    private sealed record CommandPreset(string Command, string Arguments);
    private sealed record StructuredArgumentTag(string Name, string Type, bool Required);
    private sealed record ApprovalQueueRow(string Position, string Command, string Summary, JsonElement Arguments);
    private sealed record WorkflowCommand(string Command, string Arguments);
    private sealed record CommandWorkflow(IReadOnlyList<WorkflowCommand> Commands);
    private sealed record CommandWorkspaceState(
        IReadOnlyList<string>? Favorites,
        IReadOnlyDictionary<string, CommandPreset>? Presets,
        IReadOnlyDictionary<string, CommandWorkflow>? Workflows,
        IReadOnlyList<CommandHistoryRow>? History,
        int HistoryRetention);

    private sealed record ProcessSample(DateTimeOffset CapturedAt, TimeSpan CpuTime);
    private sealed record PortOwner(int Pid, string ProcessName);
}

internal sealed class RelayCommand(Action execute) : ICommand
{
    public event EventHandler? CanExecuteChanged { add { } remove { } }
    public bool CanExecute(object? parameter) => true;
    public void Execute(object? parameter) => execute();
}

internal sealed class AsyncRelayCommand(Func<Task> execute, Action<Exception> onError) : ICommand
{
    private int _running;

    public event EventHandler? CanExecuteChanged;

    public bool CanExecute(object? parameter) => Volatile.Read(ref _running) == 0;

    public async void Execute(object? parameter)
    {
        if (Interlocked.Exchange(ref _running, 1) != 0)
        {
            return;
        }

        CanExecuteChanged?.Invoke(this, EventArgs.Empty);
        try
        {
            await execute();
        }
        catch (Exception exception)
        {
            onError(exception);
        }
        finally
        {
            Interlocked.Exchange(ref _running, 0);
            CanExecuteChanged?.Invoke(this, EventArgs.Empty);
        }
    }
}

internal static class ProcessExtensions
{
    public static void BeginWriteTo(this Process process, Stream destination)
    {
        var writer = new StreamWriter(destination) { AutoFlush = true };
        var gate = new object();
        var closed = false;

        void WriteLine(string? line)
        {
            if (line is null)
            {
                return;
            }
            lock (gate)
            {
                if (!closed)
                {
                    writer.WriteLine(line);
                }
            }
        }

        process.OutputDataReceived += (_, args) => WriteLine(args.Data);
        process.ErrorDataReceived += (_, args) => WriteLine(args.Data);
        process.EnableRaisingEvents = true;
        process.Exited += async (_, _) =>
        {
            await Task.Delay(100);
            lock (gate)
            {
                closed = true;
                writer.Dispose();
            }
        };
        process.BeginOutputReadLine();
        process.BeginErrorReadLine();
    }
}
