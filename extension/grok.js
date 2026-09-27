const api = (typeof browser !== "undefined") ? browser : chrome;

api.runtime.sendMessage({type:"grok-ready"}).catch(()=>{});

let activePrompt = null;
let lastAnswer = "";
let lastMutation = Date.now();

function composer() {
  const selectors = [
    "textarea",
    '[contenteditable="true"]',
    'div[role="textbox"]'
  ];

  for (const selector of selectors) {
    const elements = [...document.querySelectorAll(selector)];
    const el = elements.find(x => x.offsetParent !== null);
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
    el.textContent = value;
  }

  el.dispatchEvent(new InputEvent("input", {
    bubbles:true,
    inputType:"insertText",
    data:value
  }));
  el.dispatchEvent(new Event("change", {bubbles:true}));
}

function sendButton() {
  const buttons = [...document.querySelectorAll("button")];

  return buttons.find(b => {
    if (b.offsetParent === null) return false;
    const label = (
      b.innerText ||
      b.getAttribute("aria-label") ||
      b.getAttribute("title") ||
      ""
    ).trim().toLowerCase();

    return label === "send" ||
      label.includes("send message") ||
      label === "submit";
  });
}

function latestAssistantText() {
  const selectors = [
    '[data-testid*="assistant"]',
    '[class*="assistant"]',
    '[class*="response"]',
    '[class*="message"]'
  ];

  const candidates = [];

  for (const selector of selectors) {
    for (const el of document.querySelectorAll(selector)) {
      if (el.offsetParent === null) continue;
      const text = (el.innerText || "").trim();
      if (text.length > 80) candidates.push(text);
    }
  }

  for (const el of [...document.querySelectorAll("article, main, section, div")]) {
    if (el.offsetParent === null) continue;
    const text = (el.innerText || "").trim();
    if (text.length > 120) candidates.push(text);
  }

  const unique = [...new Set(candidates)];
  unique.sort((a,b) => b.length - a.length);

  return unique.find(t => t !== lastAnswer) || "";
}

async function submitPrompt(prompt) {
  activePrompt = prompt;
  lastAnswer = "";
  lastMutation = Date.now();

  let el = composer();

  for (let i = 0; i < 20 && !el; i++) {
    await new Promise(r => setTimeout(r, 500));
    el = composer();
  }

  if (!el) return;

  setComposer(el, prompt);
  await new Promise(r => setTimeout(r, 350));

  const button = sendButton();
  if (button) {
    button.click();
  } else {
    el.dispatchEvent(new KeyboardEvent("keydown", {
      key:"Enter",
      code:"Enter",
      bubbles:true
    }));
  }
}

const observer = new MutationObserver(() => {
  lastMutation = Date.now();
});
observer.observe(document.documentElement, {
  subtree:true,
  childList:true,
  characterData:true
});

setInterval(() => {
  if (!activePrompt) return;

  const answer = latestAssistantText();
  if (!answer || answer === lastAnswer) return;

  lastAnswer = answer;

  setTimeout(() => {
    const stable = latestAssistantText();
    if (
      stable &&
      stable === answer &&
      Date.now() - lastMutation > 1500
    ) {
      activePrompt = null;
      api.runtime.sendMessage({
        type:"grok-reply",
        text:stable
      }).catch(()=>{});
    }
  }, 1800);
}, 1200);

api.runtime.onMessage.addListener((msg) => {
  if (msg?.type === "grok-prompt") {
    submitPrompt(String(msg.prompt || ""));
  }
});