using System.Runtime.CompilerServices;
using System.Text;
using System.Text.Json;

namespace Abraxius.App;

internal sealed class GuardedAiProvider(IAiProvider inner) : IAiProvider, IDisposable
{
    public string Name => inner.Name;

    public Task<IReadOnlyList<AiModel>> ListModelsAsync(CancellationToken cancellationToken = default) => inner.ListModelsAsync(cancellationToken);

    public Task<string> CompleteStructuredAsync(string model, IReadOnlyList<AiMessage> messages, JsonElement schema, CancellationToken cancellationToken = default)
        => inner.CompleteStructuredAsync(model, messages, schema, cancellationToken);

    public async IAsyncEnumerable<string> StreamChatAsync(string model, IReadOnlyList<AiMessage> messages, [EnumeratorCancellation] CancellationToken cancellationToken = default)
    {
        var guard = new AiLoopGuard();
        await foreach (var chunk in inner.StreamChatAsync(model, messages, cancellationToken))
        {
            guard.Append(chunk);
            yield return chunk;
            if (guard.DetectedLoop is { } loop) throw new AiLoopDetectedException(loop);
        }
    }

    public void Dispose()
    {
        if (inner is IDisposable disposable) disposable.Dispose();
    }
}

internal sealed class AiLoopGuard(int repetitions = 4, int minimumSpanLength = 60, int maximumSpanLength = 512)
{
    private readonly StringBuilder _output = new();
    public string? DetectedLoop { get; private set; }

    public void Append(string chunk)
    {
        if (DetectedLoop is not null || chunk.Length == 0) return;
        _output.Append(chunk);
        var retainedLength = maximumSpanLength * repetitions;
        if (_output.Length > retainedLength) _output.Remove(0, _output.Length - retainedLength);
        var text = _output.ToString();
        var maximum = Math.Min(maximumSpanLength, text.Length / repetitions);
        for (var spanLength = minimumSpanLength; spanLength <= maximum; spanLength++)
        {
            var repeatedLength = spanLength * repetitions;
            var start = text.Length - repeatedLength;
            var candidate = text.AsSpan(start, spanLength);
            if (!IsMeaningful(candidate)) continue;
            var matches = true;
            for (var repetition = 1; repetition < repetitions; repetition++)
            {
                if (!candidate.SequenceEqual(text.AsSpan(start + repetition * spanLength, spanLength)))
                {
                    matches = false;
                    break;
                }
            }
            if (!matches) continue;
            DetectedLoop = candidate.ToString();
            return;
        }
    }

    private static bool IsMeaningful(ReadOnlySpan<char> text)
    {
        var lettersOrDigits = 0;
        foreach (var character in text)
        {
            if (char.IsLetterOrDigit(character) && ++lettersOrDigits >= 12) return true;
        }
        return false;
    }
}

internal sealed class AiLoopDetectedException(string repeatedSpan)
    : InvalidOperationException("Generation stopped after the same passage repeated four times. The partial response was preserved.")
{
    public string RepeatedSpan { get; } = repeatedSpan;
}
