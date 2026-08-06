using System.Net.Http.Json;
using System.Runtime.CompilerServices;
using System.Text.Json;

namespace Abraxius.App;

internal sealed class OllamaProvider : IAiProvider, IDisposable
{
    private readonly HttpClient _http = new() { BaseAddress = new Uri("http://127.0.0.1:11434/"), Timeout = Timeout.InfiniteTimeSpan };

    public string Name => "Ollama";

    public async Task<IReadOnlyList<AiModel>> ListModelsAsync(CancellationToken cancellationToken = default)
    {
        using var response = await _http.GetAsync("api/tags", cancellationToken);
        response.EnsureSuccessStatusCode();
        using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync(cancellationToken));
        if (!document.RootElement.TryGetProperty("models", out var models)) return Array.Empty<AiModel>();
        return models.EnumerateArray().Select(model =>
        {
            var name = model.TryGetProperty("name", out var nameValue) ? nameValue.GetString() ?? "unknown" : "unknown";
            var remote = model.TryGetProperty("remote_host", out var host) && host.ValueKind == JsonValueKind.String;
            var parameterSize = model.TryGetProperty("details", out var details) && details.TryGetProperty("parameter_size", out var size) ? size.GetString() : null;
            var contextLength = model.TryGetProperty("details", out details) && details.TryGetProperty("context_length", out var context) && context.TryGetInt64(out var length) ? length : 0;
            return new AiModel(name, parameterSize, contextLength, remote);
        }).OrderBy(model => model.IsRemote).ThenBy(model => model.Name, StringComparer.OrdinalIgnoreCase).ToArray();
    }

    public async IAsyncEnumerable<string> StreamChatAsync(string model, IReadOnlyList<AiMessage> messages, [EnumeratorCancellation] CancellationToken cancellationToken = default)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, "api/chat")
        {
            Content = JsonContent.Create(new { model, messages = messages.Select(message => new { role = message.Role, content = message.Content }), stream = true })
        };
        using var response = await _http.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        response.EnsureSuccessStatusCode();
        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        using var reader = new StreamReader(stream);
        while (!cancellationToken.IsCancellationRequested)
        {
            var line = await reader.ReadLineAsync(cancellationToken);
            if (line is null) yield break;
            if (string.IsNullOrWhiteSpace(line)) continue;
            using var document = JsonDocument.Parse(line);
            if (document.RootElement.TryGetProperty("error", out var error)) throw new InvalidOperationException(error.GetString());
            if (document.RootElement.TryGetProperty("message", out var message) && message.TryGetProperty("content", out var content))
            {
                var chunk = content.GetString();
                if (!string.IsNullOrEmpty(chunk)) yield return chunk;
            }
            if (document.RootElement.TryGetProperty("done", out var done) && done.ValueKind == JsonValueKind.True) yield break;
        }
    }

    public async Task<string> CompleteStructuredAsync(string model, IReadOnlyList<AiMessage> messages, JsonElement schema, CancellationToken cancellationToken = default)
    {
        using var response = await _http.PostAsJsonAsync("api/chat", new
        {
            model,
            messages = messages.Select(message => new { role = message.Role, content = message.Content }),
            stream = false,
            format = schema,
            options = new { temperature = 0 }
        }, cancellationToken);
        response.EnsureSuccessStatusCode();
        using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync(cancellationToken));
        if (document.RootElement.TryGetProperty("error", out var error)) throw new InvalidOperationException(error.GetString());
        if (document.RootElement.TryGetProperty("message", out var message)
            && message.TryGetProperty("content", out var content)
            && content.GetString() is string result)
        {
            return result;
        }
        throw new InvalidOperationException("Ollama returned no structured message content.");
    }

    public void Dispose() => _http.Dispose();
}
