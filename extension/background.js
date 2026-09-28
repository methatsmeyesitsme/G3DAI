let g3daiTabId = null;
let grokTabId = null;

const api = (typeof browser !== "undefined") ? browser : chrome;

api.runtime.onMessage.addListener(async (msg, sender) => {
  if (msg?.type === "g3dai-ready") {
    g3daiTabId = sender.tab?.id ?? null;
    return;
  }
  if (msg?.type === "grok-ready") {
    if (sender.tab) grokTabId = sender.tab.id;
    return;
  }
  if (msg?.type === "g3dai-send") {
    g3daiTabId = sender.tab?.id ?? g3daiTabId;

    if (!grokTabId) {
      const tabs = await api.tabs.query({url: "https://grok.com/*"});
      grokTabId = tabs[0]?.id ?? null;
    }

    if (!grokTabId) {
      const tab = await api.tabs.create({url: "https://grok.com/"});
      grokTabId = tab.id;
      const listener = (id, change) => {
        if (id === tab.id && change.status === "complete") {
          api.tabs.onUpdated.removeListener(listener);
          setTimeout(() => {
            api.tabs.sendMessage(tab.id, {type:"grok-prompt", prompt:msg.prompt}).catch(()=>{});
          }, 1200);
        }
      };
      api.tabs.onUpdated.addListener(listener);
    } else {
      await api.tabs.update(grokTabId, {active:true});
      await api.tabs.sendMessage(grokTabId, {type:"grok-prompt", prompt:msg.prompt});
    }

    if (g3daiTabId) {
      api.tabs.sendMessage(g3daiTabId, {type:"g3dai-working"}).catch(()=>{});
    }
  }

  if (msg?.type === "grok-reply" && g3daiTabId) {
    api.tabs.sendMessage(g3daiTabId, {type:"g3dai-reply", text:msg.text}).catch(()=>{});
  }
});

api.tabs.onRemoved.addListener((tabId) => {
  if (tabId === grokTabId) grokTabId = null;
  if (tabId === g3daiTabId) g3daiTabId = null;
});
