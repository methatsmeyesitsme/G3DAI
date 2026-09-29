const api = (typeof browser !== "undefined") ? browser : chrome;

api.runtime.sendMessage({type:"g3dai-ready"}).catch(()=>{});

window.postMessage({type:"g3dai-extension-ready"}, "*");

window.addEventListener("message", (event) => {
  if (event.source !== window || !event.data) return;

  if (event.data.type === "g3dai-extension-ping") {
    window.postMessage({type:"g3dai-extension-ready"}, "*");
    return;
  }

  if (event.data.type === "g3dai-send-to-grok") {
    const prompt = String(event.data.prompt || "").trim();
    const requestId = String(event.data.requestId || "");

    api.runtime.sendMessage({
      type:"g3dai-send",
      prompt,
      requestId
    }).then((resp) => {
      if (resp && resp.ok === false) {
        window.postMessage({
          type:"g3dai-grok-error",
          requestId,
          error:String(resp.error || "Could not send the request to Grok.")
        }, "*");
      }
    }).catch((error) => {
      window.postMessage({
        type:"g3dai-grok-error",
        requestId,
        error:String(error?.message || "Could not contact the G3DAI Grok Connector.")
      }, "*");
    });
  }
});

api.runtime.onMessage.addListener((msg) => {
  if (msg?.type === "g3dai-working") {
    window.postMessage({type:"g3dai-grok-working"}, "*");
  }
  if (msg?.type === "g3dai-reply") {
    window.postMessage({
      type:"g3dai-grok-reply",
      requestId:String(msg.requestId || ""),
      text:String(msg.text || "")
    }, "*");
  }
});
