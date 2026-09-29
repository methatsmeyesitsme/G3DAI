const api = (typeof browser !== "undefined") ? browser : chrome;

api.runtime.sendMessage({type:"grok-ready"}).catch(()=>{});

let activePrompt = null;
let activeRequestId = null;
let knownAnswers = new Set();
let lastCandidate = "";
let candidateSince = 0;

function visible(el){
  return !!el && el.offsetParent !== null;
}

function normalizedText(value){
  return String(value || "").replace(/\s+/g," ").trim();
}

function composer() {
  const selectors = [
    "textarea",
    '[contenteditable="true"]',
    'div[role="textbox"]'
  ];
  for (const selector of selectors) {
    const elements = [...document.querySelectorAll(selector)];
    const el = elements.find(visible);
    if (el) return el;
  }
  return null;
}

function setComposer(el, value) {
  el.focus();
  if (el.tagName === "TEXTAREA" || el.tagName === "INPUT") {
    const proto = el.tagName === "TEXTAREA" ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
    const setter = Object.getOwnPropertyDescriptor(proto, "value")?.set;
    if (setter) setter.call(el, value);
    else el.value = value;
  } else {
    try {
      document.execCommand("selectAll", false);
      document.execCommand("insertText", false, value);
    } catch {
      el.textContent = value;
    }
  }
  el.dispatchEvent(new InputEvent("input", {
    bubbles:true,
    inputType:"insertText",
    data:value
  }));
  el.dispatchEvent(new Event("change", {bubbles:true}));
}

function sendButton() {
  const buttons = [...document.querySelectorAll("button")].filter(visible);
  return buttons.find(b => {
    const label = normalizedText(
      b.innerText || b.getAttribute("aria-label") || b.getAttribute("title") || ""
    ).toLowerCase();
    const testid = String(b.getAttribute("data-testid") || "").toLowerCase();
    return label === "send" ||
      label.includes("send message") ||
      label.includes("submit") ||
      testid.includes("send");
  });
}

function assistantCandidates(){
  const selectors = [
    '[data-message-author-role="assistant"]',
    '[data-testid*="assistant"]',
    'article',
    '[class*="assistant"]',
    '[class*="response"]',
    '[class*="prose"]',
    '[class*="message"]'
  ];
  const raw = [];
  for(const selector of selectors){
    for(const el of document.querySelectorAll(selector)){
      if(!visible(el)) continue;
      const text=normalizedText(el.innerText || el.textContent || "");
      if(text.length<2) continue;
      raw.push({el,text});
    }
  }

  const unique=[];
  const seen=new Set();
  for(const item of raw){
    if(seen.has(item.text))continue;
    seen.add(item.text);
    unique.push(item);
  }

  // Drop parent containers when a smaller descendant has the same/similar text.
  const filtered=unique.filter(item=>{
    return !unique.some(other=>other!==item && other.text.length<item.text.length &&
      item.text.includes(other.text) && item.text.length-other.text.length>20);
  });

  return filtered.map(x=>x.text);
}

function latestNewAssistant(){
  const candidates=assistantCandidates();
  const usable=candidates.filter(text=>{
    if(!text)return false;
    if(activePrompt && text===normalizedText(activePrompt))return false;
    if(knownAnswers.has(text))return false;
    return true;
  });
  if(!usable.length)return "";
  return usable[usable.length-1];
}

async function submitPrompt(prompt,requestId) {
  activePrompt = prompt;
  activeRequestId = requestId;
  knownAnswers = new Set(assistantCandidates());
  lastCandidate = "";
  candidateSince = 0;

  const el = composer();
  if(!el){
    api.runtime.sendMessage({type:"grok-reply",requestId,text:"Grok input box was not found."}).catch(()=>{});
    return;
  }

  setComposer(el, prompt);
  await new Promise(r => setTimeout(r, 300));

  const button = sendButton();
  if (button) {
    button.click();
  } else {
    el.dispatchEvent(new KeyboardEvent("keydown", {
      key:"Enter",
      code:"Enter",
      bubbles:true,
      cancelable:true
    }));
  }
}

const observer = new MutationObserver(() => {});
observer.observe(document.documentElement,{subtree:true,childList:true,characterData:true});

setInterval(() => {
  if (!activePrompt || !activeRequestId) return;

  const answer = latestNewAssistant();
  if(!answer)return;

  if(answer!==lastCandidate){
    lastCandidate=answer;
    candidateSince=Date.now();
    return;
  }

  if(Date.now()-candidateSince < 1200)return;

  const requestId=activeRequestId;
  activePrompt=null;
  activeRequestId=null;
  knownAnswers.clear();
  lastCandidate="";

  api.runtime.sendMessage({
    type:"grok-reply",
    requestId,
    text:answer
  }).catch(()=>{});
},700);

api.runtime.onMessage.addListener((msg) => {
  if (msg?.type === "grok-prompt") {
    submitPrompt(String(msg.prompt || ""),String(msg.requestId || ""));
  }
});
