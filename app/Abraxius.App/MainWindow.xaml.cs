using System.Diagnostics;
using System.Net.Http.Json;
using System.Text.Json.Serialization;
using System.Windows.Input;
using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using Windows.ApplicationModel;
using WinRT.Interop;

namespace Abraxius.App;

public sealed partial class MainWindow : Window
{
    private static readonly Uri ApiBase = new("http://127.0.0.1:13470/");

    private readonly HttpClient _http = new() { BaseAddress = ApiBase, Timeout = TimeSpan.FromSeconds(1) };
    private readonly DispatcherTimer _timer = new() { Interval = TimeSpan.FromSeconds(2) };
    private readonly SemaphoreSlim _serverLifecycle = new(1, 1);
    private readonly AppWindow _appWindow;
    private readonly H.NotifyIcon.TaskbarIcon _trayIcon;
    private StartupTask? _startupTask;
    private bool _allowClose;
    private bool _quitting;
    private bool _intentionalStop;
    private bool _initializing = true;

    public MainWindow()
    {
        InitializeComponent();
        _trayIcon = new H.NotifyIcon.TaskbarIcon();
        Title = "Abraxius";
        ExtendsContentIntoTitleBar = true;
        SetTitleBar(AppTitleBar);

        var hwnd = WindowNative.GetWindowHandle(this);
        var windowId = Win32Interop.GetWindowIdFromWindow(hwnd);
        _appWindow = AppWindow.GetFromWindowId(windowId);
        _appWindow.Resize(new Windows.Graphics.SizeInt32(760, 600));
        _appWindow.Closing += AppWindow_Closing;

        var trayMenu = new MenuFlyout();
        var openItem = new MenuFlyoutItem { Text = "Open Abraxius", Icon = new SymbolIcon(Symbol.OpenFile) };
        openItem.Click += TrayOpen_Click;
        var restartItem = new MenuFlyoutItem { Text = "Restart server", Icon = new SymbolIcon(Symbol.Refresh) };
        restartItem.Click += TrayRestart_Click;
        var quitItem = new MenuFlyoutItem { Text = "Quit Abraxius" };
        quitItem.Click += TrayQuit_Click;
        trayMenu.Items.Add(openItem);
        trayMenu.Items.Add(restartItem);
        trayMenu.Items.Add(new MenuFlyoutSeparator());
        trayMenu.Items.Add(quitItem);
        _trayIcon.IconSource = new BitmapImage(new Uri("ms-appx:///Assets/Tray.ico"));
        _trayIcon.ToolTipText = "Abraxius";
        _trayIcon.ContextFlyout = trayMenu;
        _trayIcon.DoubleClickCommand = new RelayCommand(ShowWindow);
        _trayIcon.ForceCreate();

        _ = InitializeStartupAsync();
        _timer.Tick += async (_, _) => await RefreshAsync();
        _timer.Start();
        Activated += async (_, _) => await RefreshAsync();
        if (Environment.GetCommandLineArgs().Any(arg => arg == "--smoke-quit"))
        {
            _ = SmokeQuitAsync();
        }
    }

    private async Task RefreshAsync()
    {
        if (_quitting)
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
            ServerDot.Fill = ThemeBrush("SystemFillColorCriticalBrush");
            StudioStatus.Text = "Offline";
            StudioDot.Fill = ThemeBrush("SystemFillColorNeutralBrush");
            PluginStatus.Text = "Offline";
            PluginDot.Fill = ThemeBrush("SystemFillColorNeutralBrush");
            DetailText.Text = "The local Abraxius API is not available.";
            StartButtonText.Text = "Start server";
            StopButton.IsEnabled = false;
            _trayIcon.ToolTipText = "Abraxius - server stopped";

            if (SupervisionToggle.IsOn && !_intentionalStop)
            {
                await StartServerAsync(showErrors: false);
            }
        }
    }

    private async Task StartServerAsync(bool showErrors = true)
    {
        await _serverLifecycle.WaitAsync();
        try
        {
            if (_quitting || _intentionalStop)
            {
                return;
            }

            if (await IsServerRunningAsync())
            {
                return;
            }

            var daemon = Path.Combine(AppContext.BaseDirectory, "abraxius-daemon.exe");
            if (!File.Exists(daemon))
            {
                throw new FileNotFoundException("The Rust server executable was not found.", daemon);
            }

            Directory.CreateDirectory(AppDataDirectory);
            var log = new FileStream(LogPath, FileMode.Append, FileAccess.Write, FileShare.ReadWrite);
            Process.Start(new ProcessStartInfo
            {
                FileName = daemon,
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
            })?.BeginWriteTo(log);

            for (var attempt = 0; attempt < 30 && !await IsServerRunningAsync(); attempt++)
            {
                await Task.Delay(100);
            }
        }
        catch (Exception ex)
        {
            if (showErrors)
            {
                ShowMessage("Could not start the server", ex.Message, Microsoft.UI.Xaml.Controls.InfoBarSeverity.Error);
            }
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

    private void LogsButton_Click(object sender, RoutedEventArgs e)
    {
        Directory.CreateDirectory(AppDataDirectory);
        if (!File.Exists(LogPath))
        {
            File.WriteAllText(LogPath, string.Empty);
        }
        Process.Start(new ProcessStartInfo("notepad.exe", $"\"{LogPath}\"") { UseShellExecute = true });
    }

    private void TrayOpen_Click(object sender, RoutedEventArgs e) => ShowWindow();

    private async void TrayRestart_Click(object sender, RoutedEventArgs e) => await RestartServerAsync();

    private async void TrayQuit_Click(object sender, RoutedEventArgs e) => await QuitAsync();

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
        _appWindow.Hide();
        ShowMessage("Still running", "Abraxius is active in the notification area.", Microsoft.UI.Xaml.Controls.InfoBarSeverity.Informational);
    }

    public void ShowWindow()
    {
        _appWindow.Show();
        Activate();
    }

    public void StartHidden() => _appWindow.Hide();

    private async Task QuitAsync()
    {
        if (_quitting)
        {
            return;
        }

        _quitting = true;
        _allowClose = true;
        _intentionalStop = true;
        _timer.Stop();
        await StopServerAsync();
        _trayIcon.Dispose();
        Close();
        await Task.Delay(100);
        Environment.Exit(0);
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

    private static string AppDataDirectory => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Abraxius");
    private static string LogPath => Path.Combine(AppDataDirectory, "abraxius-host.log");

    private sealed record Health(
        [property: JsonPropertyName("running")] bool Running,
        [property: JsonPropertyName("connected")] bool Connected,
        [property: JsonPropertyName("pluginConnected")] bool PluginConnected,
        [property: JsonPropertyName("uptime")] ulong Uptime,
        [property: JsonPropertyName("pid")] uint? Pid,
        [property: JsonPropertyName("version")] string? Version);
}

internal sealed class RelayCommand(Action execute) : ICommand
{
    public event EventHandler? CanExecuteChanged { add { } remove { } }
    public bool CanExecute(object? parameter) => true;
    public void Execute(object? parameter) => execute();
}

internal static class ProcessExtensions
{
    public static void BeginWriteTo(this Process process, Stream destination)
    {
        _ = process.StandardOutput.BaseStream.CopyToAsync(destination);
        _ = process.StandardError.BaseStream.CopyToAsync(destination);
        process.EnableRaisingEvents = true;
        process.Exited += (_, _) => destination.Dispose();
    }
}
