const api = (typeof browser !== "undefined") ? browser : chrome;

api.runtime.sendMessage({type:"g3dai-ready"}).catch(()=>{});
window.postMessage({type:"g3dai-extension-ready"}, "*");

window.addEventListener("message", (event) => {
  if (event.source !== window || !event.data) return;

  if (event.data.type === "g3dai-extension-ping") {
    window.postMessage({type:"g3dai-extension-ready"}, "*");
  }

  if (event.data.type === "g3dai-send-to-grok") {
    api.runtime.sendMessage({
      type:"g3dai-send",
      prompt:String(event.data.prompt || "")
    }).catch(()=>{});
  }
});

api.runtime.onMessage.addListener((msg) => {
  if (msg?.type === "g3dai-working") {
    window.postMessage({type:"g3dai-grok-working"}, "*");
  }
  if (msg?.type === "g3dai-reply") {
    window.postMessage({
      type:"g3dai-grok-reply",
      text:String(msg.text || "")
    }, "*");
  }
});