let g3daiTabId = null;
let grokTabId = null;

const api = (typeof browser !== "undefined") ? browser : chrome;

function sendResponseSafe(sendResponse, payload){
  try{ sendResponse(payload); }catch(_){}
}

api.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg?.type === "g3dai-ready") {
    g3daiTabId = sender.tab?.id ?? null;
    sendResponseSafe(sendResponse,{ok:true});
    return true;
  }

  if (msg?.type === "grok-ready") {
    if (sender.tab) grokTabId = sender.tab.id;
    sendResponseSafe(sendResponse,{ok:true});
    return true;
  }

  if (msg?.type === "g3dai-send") {
    g3daiTabId = sender.tab?.id ?? g3daiTabId;
    const prompt = String(msg.prompt || "").trim();
    const requestId = String(msg.requestId || "");

    if (!prompt) {
      sendResponseSafe(sendResponse,{ok:false,error:"Prompt is empty."});
      return true;
    }

    const finish = (payload) => sendResponseSafe(sendResponse,payload);

    Promise.resolve(api.tabs.query({url:"https://grok.com/*"}))
      .then((tabs) => {
        const tab = tabs && tabs[0];
        grokTabId = tab?.id ?? grokTabId;
        if (!grokTabId) throw new Error("No Grok tab is open. Open grok.com and sign in first.");
        return Promise.resolve(api.tabs.sendMessage(grokTabId,{
          type:"grok-prompt",
          prompt,
          requestId
        }));
      })
      .then(() => {
        if(g3daiTabId){
          Promise.resolve(api.tabs.sendMessage(g3daiTabId,{type:"g3dai-working"})).catch(()=>{});
        }
        finish({ok:true});
      })
      .catch((error) => {
        finish({ok:false,error:String(error?.message||"Could not send the prompt to Grok.")});
      });

    return true;
  }

  if (msg?.type === "grok-reply" && g3daiTabId) {
    Promise.resolve(api.tabs.sendMessage(g3daiTabId,{
      type:"g3dai-reply",
      requestId:String(msg.requestId || ""),
      text:String(msg.text || "")
    })).catch(()=>{});
    return true;
  }

  return false;
});

api.tabs.onRemoved.addListener((tabId) => {
  if (tabId === grokTabId) grokTabId = null;
  if (tabId === g3daiTabId) g3daiTabId = null;
});
