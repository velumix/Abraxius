using System.IO.Compression;
using System.Reflection;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Abraxius.App;

internal static partial class AppDiagnostics
{
    private const int MaximumCrashLogBytes = 1024 * 1024;
    private const int MaximumBundledLogBytes = 512 * 1024;
    private const int RetainedBundleCount = 10;
    private static readonly object LogLock = new();

    public static void RecordUnhandled(Exception exception)
    {
        try
        {
            Directory.CreateDirectory(AppPaths.DataDirectory);
            lock (LogLock)
            {
                RotateIfNeeded(AppPaths.CrashLog, MaximumCrashLogBytes);
                File.AppendAllText(
                    AppPaths.CrashLog,
                    $"{DateTimeOffset.Now:O}{Environment.NewLine}{exception}{Environment.NewLine}{Environment.NewLine}");
            }
        }
        catch
        {
            // Crash reporting must never hide the original exception.
        }
    }

    public static async Task<DiagnosticBundle> CreateBundleAsync(
        string statusSummary,
        string? healthJson,
        string? analyticsJson,
        CancellationToken cancellationToken = default)
    {
        Directory.CreateDirectory(AppPaths.DiagnosticsDirectory);
        var createdAt = DateTimeOffset.UtcNow;
        var fileName = $"abraxius-diagnostics-{createdAt:yyyyMMdd-HHmmss-fff}.zip";
        var destination = Path.Combine(AppPaths.DiagnosticsDirectory, fileName);
        var temporary = destination + ".tmp";
        var entries = new List<string>();

        try
        {
            await using (var output = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None, 65536, true))
            using (var archive = new ZipArchive(output, ZipArchiveMode.Create, leaveOpen: false))
            {
                var manifest = JsonSerializer.Serialize(new
                {
                    createdAt,
                    appVersion = Assembly.GetExecutingAssembly().GetName().Version?.ToString(),
                    operatingSystem = Environment.OSVersion.VersionString,
                    runtime = Environment.Version.ToString(),
                    processArchitecture = System.Runtime.InteropServices.RuntimeInformation.ProcessArchitecture.ToString(),
                    machineName = "redacted",
                    privacy = "Conversation, command history, source code, project memory, and editor buffers are excluded.",
                }, new JsonSerializerOptions { WriteIndented = true });

                await AddTextEntryAsync(archive, entries, "manifest.json", manifest, cancellationToken);
                await AddTextEntryAsync(archive, entries, "status.txt", statusSummary, cancellationToken);
                await AddOptionalJsonEntryAsync(archive, entries, "health.json", healthJson, cancellationToken);
                await AddOptionalJsonEntryAsync(archive, entries, "analytics.json", analyticsJson, cancellationToken);
                await AddLogTailAsync(archive, entries, AppPaths.HostLog, "logs/host.log", cancellationToken);
                await AddLogTailAsync(archive, entries, AppPaths.CrashLog, "logs/winui-errors.log", cancellationToken);

                var legacyCrashLog = Path.Combine(Path.GetTempPath(), "abraxius-winui-error.log");
                if (!Path.GetFullPath(legacyCrashLog).Equals(Path.GetFullPath(AppPaths.CrashLog), StringComparison.OrdinalIgnoreCase))
                {
                    await AddLogTailAsync(archive, entries, legacyCrashLog, "logs/legacy-winui-errors.log", cancellationToken);
                }
            }

            File.Move(temporary, destination, overwrite: false);
            PruneOldBundles(destination);
            return new DiagnosticBundle(destination, new FileInfo(destination).Length, entries.Count);
        }
        catch
        {
            try { File.Delete(temporary); } catch { }
            throw;
        }
    }

    private static async Task AddOptionalJsonEntryAsync(
        ZipArchive archive,
        List<string> entries,
        string name,
        string? json,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(json)) return;
        try
        {
            using var document = JsonDocument.Parse(json);
            json = JsonSerializer.Serialize(document.RootElement, new JsonSerializerOptions { WriteIndented = true });
        }
        catch (JsonException)
        {
            json = JsonSerializer.Serialize(new { unavailable = Redact(json) });
        }
        await AddTextEntryAsync(archive, entries, name, json, cancellationToken);
    }

    private static async Task AddLogTailAsync(
        ZipArchive archive,
        List<string> entries,
        string source,
        string entryName,
        CancellationToken cancellationToken)
    {
        if (!File.Exists(source)) return;
        await using var input = new FileStream(source, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete, 65536, true);
        if (input.Length > MaximumBundledLogBytes) input.Seek(-MaximumBundledLogBytes, SeekOrigin.End);
        using var reader = new StreamReader(input, Encoding.UTF8, detectEncodingFromByteOrderMarks: true, leaveOpen: false);
        var text = await reader.ReadToEndAsync(cancellationToken);
        await AddTextEntryAsync(archive, entries, entryName, text, cancellationToken);
    }

    private static async Task AddTextEntryAsync(
        ZipArchive archive,
        List<string> entries,
        string name,
        string value,
        CancellationToken cancellationToken)
    {
        var entry = archive.CreateEntry(name, CompressionLevel.SmallestSize);
        await using var stream = entry.Open();
        await using var writer = new StreamWriter(stream, new UTF8Encoding(false));
        await writer.WriteAsync(Redact(value).AsMemory(), cancellationToken);
        entries.Add(name);
    }

    private static string Redact(string value)
    {
        var userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        if (!string.IsNullOrWhiteSpace(userProfile))
        {
            value = value.Replace(userProfile, "%USERPROFILE%", StringComparison.OrdinalIgnoreCase);
        }
        value = value.Replace(Environment.UserName, "%USERNAME%", StringComparison.OrdinalIgnoreCase);
        return SecretPattern().Replace(value, "$1<redacted>");
    }

    private static void RotateIfNeeded(string path, int maximumBytes)
    {
        if (!File.Exists(path) || new FileInfo(path).Length < maximumBytes) return;
        var previous = path + ".1";
        File.Move(path, previous, overwrite: true);
    }

    private static void PruneOldBundles(string current)
    {
        foreach (var file in new DirectoryInfo(AppPaths.DiagnosticsDirectory)
            .EnumerateFiles("abraxius-diagnostics-*.zip")
            .OrderByDescending(file => file.LastWriteTimeUtc)
            .Skip(RetainedBundleCount))
        {
            if (!file.FullName.Equals(current, StringComparison.OrdinalIgnoreCase))
            {
                try { file.Delete(); } catch { }
            }
        }
    }

    [GeneratedRegex("(?i)(authorization\\s*[:=]\\s*(?:bearer\\s+)?|api[_-]?key\\s*[:=]\\s*|token\\s*[:=]\\s*)[^\\s,;\\\"]+")]
    private static partial Regex SecretPattern();
}

internal sealed record DiagnosticBundle(string Path, long SizeBytes, int EntryCount);
