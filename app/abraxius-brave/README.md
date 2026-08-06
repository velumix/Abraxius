# Abraxius Context Bridge for Brave

This Manifest V3 extension gives a browser chatbot page relevant webpage and
Abraxius/Studio context without copy-pasting. Open the side panel, refresh the
context, then use **Insert context into chatbot**. The extension finds a normal
`textarea` or `contenteditable` composer and inserts a bounded context packet.

The extension uses the local AI tool WebSocket at `ws://127.0.0.1:13473/ai`
for tool discovery, context retrieval, and calls. The normal HTTP bridge remains
available at `http://127.0.0.1:13470`. Abraxius must be running. Studio
mutations remain behind explicit approval; the extension does not execute
arbitrary page JavaScript or hide its activity.

## Install

1. Open `brave://extensions`.
2. Enable **Developer mode**.
3. Select **Load unpacked**.
4. Choose this directory: `app/abraxius-brave`.
5. Pin the Abraxius extension, open its side panel, and refresh context.

The current bridge intentionally starts with visible context insertion. A future
provider adapter can add model calls. For webpage chatbot tool use today, ask the
model to emit a request in this form:

```text
ABRAXIUS_TOOL {"name":"get_studio_state","arguments":{}}
```

Then select **Check latest reply for Abraxius tool request**. The extension
shows the exact arguments, requires approval, calls `/smart-call`, and inserts
the result back into the chatbot composer. You still press Send, so a webpage
cannot silently mutate Studio.
