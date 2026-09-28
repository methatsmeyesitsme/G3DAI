const api = (typeof browser !== "undefined") ? browser : chrome;

api.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg?.type === "g3dai-ready") {
    sendResponse({ok: true});
    return true;
  }

  if (msg?.type === "g3dai-send") {
    const prompt = String(msg.prompt || "").trim();
    if (!prompt) {
      sendResponse({ok: false, error: "empty prompt"});
      return true;
    }

    api.tabs.query({url: ["https://grok.com/*"]}, (tabs) => {
      const tab = tabs && tabs[0];
      if (!tab?.id) {
        sendResponse({ok: false, error: "No open Grok tab found. Sign in at grok.com and keep a tab open."});
        return;
      }

      api.tabs.sendMessage(tab.id, {type: "g3dai-forward", prompt}, (resp) => {
        if (api.runtime.lastError) {
          sendResponse({ok: false, error: api.runtime.lastError.message});
          return;
        }
        sendResponse(resp || {ok: true});
      });
    });
    return true;
  }
});
