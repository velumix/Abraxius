(function () {
  if (globalThis.__ABRAXIUS_CONTENT_BRIDGE__) return;
  globalThis.__ABRAXIUS_CONTENT_BRIDGE__ = true;
  const MAX_TEXT = 12000;
  let activeComposer = null;

  function context() {
    const selection = String(window.getSelection?.() || "").trim();
    const root = document.querySelector("main, article, [role='main']") || document.body;
    const text = String(root?.innerText || document.body?.innerText || "")
      .replace(/\s+/g, " ").trim().slice(0, MAX_TEXT);
    return { title: document.title, url: location.href, selection: selection.slice(0, 8000), text };
  }

  function composer() {
    const visible = (node) => {
      if (!node) return false;
      const style = getComputedStyle(node);
      const rect = node.getBoundingClientRect();
      return style.visibility !== "hidden" && style.display !== "none" && rect.width > 0 && rect.height > 0;
    };
    if (visible(activeComposer)) return activeComposer;
    const selectors = [
      "#prompt-textarea",
      "textarea[placeholder*='Ask ChatGPT']",
      "textarea[placeholder*='Message']",
      "[contenteditable='true'][id*='prompt']",
      "[contenteditable='true'].ProseMirror",
      "[contenteditable='true']",
      "textarea",
    ];
    for (const selector of selectors) {
      const target = [...document.querySelectorAll(selector)].find(visible);
      if (target) return target;
    }
    return null;
  }

  function composerText(target) { return String(target?.value ?? target?.innerText ?? ""); }

  function insert(text) {
    const target = composer();
    if (!target) throw new Error("No chatbot message box found on this page");
    if (target.tagName === "TEXTAREA") {
      const setter = Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, "value")?.set;
      setter?.call(target, text);
      target.dispatchEvent(new Event("input", { bubbles: true }));
    } else {
      target.focus();
      target.dispatchEvent(new InputEvent("beforeinput", { bubbles: true, cancelable: false, inputType: "insertText", data: String(text) }));
      const selection = window.getSelection();
      const range = document.createRange();
      range.selectNodeContents(target);
      range.deleteContents();
      range.insertNode(document.createTextNode(String(text)));
      selection?.removeAllRanges();
      selection?.collapse(target, target.childNodes.length);
      target.dispatchEvent(new InputEvent("input", { bubbles: true, inputType: "insertText", data: text }));
      target.dispatchEvent(new Event("change", { bubbles: true }));
    }
    target.focus();
    return { ok: true, target: target.id || target.getAttribute("placeholder") || target.tagName, text: composerText(target) };
  }

  function lastAssistantReply() {
    const nodes = [
      ...document.querySelectorAll("[data-message-author-role='assistant']"),
      ...document.querySelectorAll("[data-role='assistant'], [data-author='assistant'], [data-speaker='assistant']"),
      ...document.querySelectorAll(".assistant-message, .message.assistant, .font-claude-message, .ds-markdown"),
      ...document.querySelectorAll("[class*='assistant'][class*='message'], [class*='assistant'][class*='response']"),
    ];
    // Only inspect the newest few bubbles; reading the entire conversation on
    // every bridge tick can stall large chatbot pages.
    const recent = nodes.slice(-12).reverse();
    // Chat UIs sometimes append status bubbles after the assistant message.
    // Prefer the newest bubble that actually contains a bridge marker.
    const marked = recent.find((node) => String(node.textContent || "").includes("ABRAXIUS_TOOL"));
    const node = marked || recent[0];
    return String(node?.innerText || node?.textContent || "").trim().slice(-16000);
  }

  function replyState() {
    const reply = lastAssistantReply();
    const normalized = reply.trim().replace(/\s+/g, " ");
    const transient = /^(pro thinking|thinking|generating|finalizing answer|answer now|working|searching|checking|loading|one moment|still working|i'm working on it|i’ll work on it)[.!… ]*$/i.test(normalized);
    return { reply, transient, complete: Boolean(reply && !transient && normalized.length > 20) };
  }

  async function waitForReply(previous = "", timeoutMs = 30000) {
    const started = Date.now();
    while (Date.now() - started < timeoutMs) {
      const reply = lastAssistantReply();
      const normalized = reply.trim().replace(/\s+/g, " ");
      const transient = /^(pro thinking|thinking|generating|finalizing answer|answer now|working|searching|checking|loading|one moment|still working|i'm working on it|i’ll work on it)[.!… ]*$/i.test(normalized);
      if (reply && reply !== previous && normalized.length > 20 && !transient) return { reply, waitedMs: Date.now() - started };
      await new Promise((resolve) => setTimeout(resolve, 750));
    }
    return { reply: lastAssistantReply(), timedOut: true, waitedMs: Date.now() - started };
  }

  async function submit() {
    const target = composer();
    const value = String(target?.value || target?.innerText || "").trim();
    if (/^\/?abraxius(?:\s|$)/i.test(value)) {
      const command = value.replace(/^\/?abraxius\s*/i, "").trim();
      const response = await chrome.runtime.sendMessage({ type: "ABRAXIUS_SLASH_SKILL", command });
      if (response?.error) throw new Error(response.error);
      const expanded = String(response?.skill || "");
      if (target.tagName === "TEXTAREA") {
        const setter = Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, "value")?.set;
        setter?.call(target, expanded);
        target.dispatchEvent(new Event("input", { bubbles: true }));
        target.dispatchEvent(new Event("change", { bubbles: true }));
      } else {
        target.focus();
        target.dispatchEvent(new InputEvent("beforeinput", { bubbles: true, cancelable: false, inputType: "insertText", data: expanded }));
        const selection = window.getSelection();
        const range = document.createRange();
        range.selectNodeContents(target);
        range.deleteContents();
        range.insertNode(document.createTextNode(expanded));
        selection?.removeAllRanges();
        selection?.collapse(target, target.childNodes.length);
        target.dispatchEvent(new InputEvent("input", { bubbles: true, inputType: "insertText", data: expanded }));
        target.dispatchEvent(new Event("change", { bubbles: true }));
      }
      // React/Lexical-style chatbot composers update asynchronously. Give the
      // framework a render turn before looking up its now-enabled send button.
      await new Promise((resolve) => setTimeout(resolve, 120));
    }
    const visible = (node) => {
      if (!node) return false;
      const style = getComputedStyle(node);
      const rect = node.getBoundingClientRect();
      return style.visibility !== "hidden" && style.display !== "none" && rect.width > 0 && rect.height > 0 && !node.disabled;
    };
    const selectors = [
      "button[data-testid='send-button']",
      "button[aria-label*='Send']",
      "form button[type='submit']",
      "button[aria-label*='Submit']",
    ];
    for (let attempt = 0; attempt < 8; attempt += 1) {
      for (const selector of selectors) {
        const button = [...document.querySelectorAll(selector)].find(visible);
        if (button) { button.click(); return { ok: true, target: button.getAttribute("aria-label") || button.dataset.testid || "button" }; }
      }
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    const form = target?.closest("form");
    const formButton = [...(form?.querySelectorAll("button, [role='button']") || [])].find((button) => visible(button) && /send|submit|ask|run|go/i.test(button.innerText || button.getAttribute("aria-label") || ""));
    if (formButton) { formButton.click(); return { ok: true, target: "focused-form-submit" }; }
    // Never scan arbitrary divs: reading innerText on every conversation node
    // forces layout for the whole page and was the source of freezes.
    const answerNow = [...document.querySelectorAll("button, [role='button'], [data-testid]")].find((button) =>
      visible(button) && /answer\s*now|send|submit|ask|run/i.test(button.innerText || button.getAttribute("aria-label") || button.getAttribute("data-testid") || ""));
    if (answerNow) { answerNow.click(); return { ok: true, target: "Answer now" }; }
    throw new Error("No visible chatbot send button found");
  }

  chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
    try {
      if (message.type === "ABRAXIUS_GET_PAGE_CONTEXT") sendResponse(context());
      else if (message.type === "ABRAXIUS_GET_LAST_REPLY") sendResponse({ reply: lastAssistantReply() });
      else if (message.type === "ABRAXIUS_GET_REPLY_STATE") sendResponse(replyState());
      else if (message.type === "ABRAXIUS_WAIT_FOR_REPLY") waitForReply(String(message.previous || ""), Math.min(600000, Math.max(1000, Number(message.timeoutMs) || 600000))).then(sendResponse);
      else if (message.type === "ABRAXIUS_INSERT_CONTEXT") sendResponse(insert(message.context));
      else if (message.type === "ABRAXIUS_INSERT_AND_SUBMIT") {
        (async () => {
          const inserted = insert(message.context);
          let target = composer();
          for (let attempt = 0; attempt < 20 && !composerText(target).includes("[ABRAXIUS_TOOL_RESULT]"); attempt += 1) {
            await new Promise((resolve) => setTimeout(resolve, 100));
            target = composer();
          }
          if (!composerText(target).includes("[ABRAXIUS_TOOL_RESULT]")) throw new Error("Chatbot composer did not accept the tool result");
          const submitted = await submit();
          sendResponse({ inserted, submitted });
        })().catch((error) => sendResponse({ error: error.message }));
      }
      else if (message.type === "ABRAXIUS_SUBMIT") submit().then(sendResponse, (error) => sendResponse({ error: error.message }));
    } catch (error) { sendResponse({ error: error.message }); }
    return true;
  });

  document.addEventListener("focusin", (event) => {
    const target = event.target;
    if (target instanceof HTMLTextAreaElement || target instanceof HTMLInputElement || target?.isContentEditable) activeComposer = target;
  }, true);
  document.addEventListener("keydown", (event) => {
    if (event.key !== "Enter" || event.shiftKey || event.isComposing) return;
    const eventComposer = event.target instanceof HTMLTextAreaElement || event.target instanceof HTMLInputElement || event.target?.isContentEditable ? event.target : null;
    if (eventComposer) activeComposer = eventComposer;
    const target = activeComposer || eventComposer;
    if (!target) return;
    const value = String(target.value || target.innerText || "").trim();
    if (!/^\/?abraxius(?:\s|$)/i.test(value)) return;
    event.preventDefault();
    event.stopPropagation();
    submit().catch(() => {});
  }, true);

  // Wake the bridge only when a chatbot actually adds a tool marker. This
  // gives the Brave console immediate call visibility without polling or
  // repeatedly scanning the whole conversation.
  let markerWakePending = false;
  let lastMarkerSignature = "";
  const markerObserver = new MutationObserver((mutations) => {
    if (markerWakePending) return;
    const found = mutations.some((mutation) => {
      const added = [...mutation.addedNodes].some((node) => String(node.textContent || "").includes("ABRAXIUS_TOOL"));
      const changed = mutation.type === "characterData" && String(mutation.target?.textContent || "").includes("ABRAXIUS_TOOL");
      return added || changed;
    });
    if (!found) return;
    const markerNode = mutations.flatMap((mutation) => [...mutation.addedNodes, mutation.target]).find((node) => String(node?.textContent || "").match(/ABRAXIUS_TOOL/i));
    const markerSource = String(markerNode?.textContent || "");
    const markerText = (markerSource.match(/(?:ABRAXIUS_TOOL|abraxius_tool)[\s\S]{0,1600}/i)?.[0] || "").trim();
    if (!markerText || markerText === lastMarkerSignature) return;
    lastMarkerSignature = markerText;
    markerWakePending = true;
    setTimeout(() => {
      markerWakePending = false;
      chrome.runtime.sendMessage({ type: "ABRAXIUS_AUTO_PROCESS" }).catch(() => {});
    }, 100);
  });
  if (document.body) markerObserver.observe(document.body, { childList: true, subtree: true, characterData: true });

  // Autonomous processing is owned by the extension worker. Do not run a
  // page-side heartbeat: content scripts share the chatbot renderer thread,
  // and periodic DOM scans can make large conversations visibly stall.
})();
