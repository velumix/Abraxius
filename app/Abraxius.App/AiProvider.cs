using System.Text.Json;

namespace Abraxius.App;

internal interface IAiProvider
{
    string Name { get; }
    Task<IReadOnlyList<AiModel>> ListModelsAsync(CancellationToken cancellationToken = default);
    Task<string> CompleteStructuredAsync(string model, IReadOnlyList<AiMessage> messages, JsonElement schema, CancellationToken cancellationToken = default);
    IAsyncEnumerable<string> StreamChatAsync(string model, IReadOnlyList<AiMessage> messages, CancellationToken cancellationToken = default);
}

internal sealed record AiModel(string Name, string? ParameterSize, long ContextLength, bool IsRemote)
{
    public string DisplayName => $"{Name}  •  {(IsRemote ? "cloud" : "local")}{(string.IsNullOrWhiteSpace(ParameterSize) ? string.Empty : $"  •  {ParameterSize}")}";
}
internal sealed record AiMessage(string Role, string Content);
