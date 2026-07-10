using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.Windows.AppLifecycle;

namespace Abraxius.App;

public partial class App : Application
{
    private const string InstanceMutexName = @"Local\Velumix.Abraxius.App";
    private const string ActivationEventName = @"Local\Velumix.Abraxius.Activate";

    public static MainWindow MainWindow { get; private set; } = null!;
    private DispatcherQueue? _dispatcherQueue;
    private Mutex? _instanceMutex;
    private EventWaitHandle? _activationEvent;
    private RegisteredWaitHandle? _activationWait;

    public App()
    {
        InitializeComponent();
        UnhandledException += (_, args) =>
        {
            System.Diagnostics.Debug.WriteLine(args.Exception);
            File.AppendAllText(
                Path.Combine(Path.GetTempPath(), "abraxius-winui-error.log"),
                $"{DateTimeOffset.Now:O}\r\n{args.Exception}\r\n\r\n");
            args.Handled = false;
        };
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        var currentInstance = AppInstance.GetCurrent();
        _instanceMutex = new Mutex(false, InstanceMutexName);
        var isPrimaryInstance = false;
        try
        {
            isPrimaryInstance = _instanceMutex.WaitOne(0);
        }
        catch (AbandonedMutexException)
        {
            isPrimaryInstance = true;
        }

        if (!isPrimaryInstance)
        {
            try
            {
                EventWaitHandle.OpenExisting(ActivationEventName).Set();
            }
            catch (WaitHandleCannotBeOpenedException)
            {
            }
            Environment.Exit(0);
            return;
        }

        _activationEvent = new EventWaitHandle(false, EventResetMode.AutoReset, ActivationEventName);
        _dispatcherQueue = DispatcherQueue.GetForCurrentThread();
        MainWindow = new MainWindow();
        _activationWait = ThreadPool.RegisterWaitForSingleObject(
            _activationEvent,
            (_, _) => _dispatcherQueue.TryEnqueue(MainWindow.ShowWindow),
            null,
            Timeout.Infinite,
            false);
        MainWindow.Activate();
        var activationKind = currentInstance.GetActivatedEventArgs().Kind;
        if (Environment.GetCommandLineArgs().Any(arg => arg == "--background") ||
            activationKind == ExtendedActivationKind.StartupTask)
        {
            MainWindow.StartHidden();
        }
    }
}
