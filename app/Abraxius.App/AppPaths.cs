namespace Abraxius.App;

internal static class AppPaths
{
    public static string DataDirectory { get; } = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "Abraxius");

    public static string DiagnosticsDirectory => Path.Combine(DataDirectory, "diagnostics");
    public static string HostLog => Path.Combine(DataDirectory, "abraxius-host.log");
    public static string CrashLog => Path.Combine(DataDirectory, "abraxius-winui-error.log");
    public static string CommandWorkspaceState => Path.Combine(DataDirectory, "command-workspace.json");
    public static string EditorSession => Path.Combine(DataDirectory, "editor-session.json");
}
