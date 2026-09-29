import http from "node:http";
import { spawn } from "node:child_process";
import { mkdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import { randomUUID } from "node:crypto";

const PORT = Number(process.env.PORT || 8787);
const HOST = process.env.HOST || "127.0.0.1";
const GROK_HOME = process.env.GROK_HOME || join(homedir(), ".grok");
const CORS_ORIGIN = process.env.CORS_ORIGIN || "https://methatsmeyesitsme.github.io";
const MAX_BODY = 2 * 1024 * 1024;
const XAI_API_KEY = process.env.XAI_API_KEY || "";
const XAI_BASE_URL = (process.env.XAI_BASE_URL || "https://api.x.ai/v1").replace(/\/+$/, "");
const XAI_MODEL = process.env.XAI_MODEL || "grok-4.7";
const API_MODE = !!XAI_API_KEY;

mkdirSync(GROK_HOME, { recursive: true });

function corsHeaders(origin) {
  const allowed = CORS_ORIGIN.split(",").map(x => x.trim()).filter(Boolean);
  const isLocal = /^https?:\/\/(localhost|127\.0\.0\.1)(?::\d+)?$/.test(origin || "");
  const allow = allowed.includes("*") || allowed.includes(origin) || isLocal
    ? (origin || allowed[0] || "null")
    : "null";

  return {
    "Access-Control-Allow-Origin": allow,
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
    "Content-Type": "application/json; charset=utf-8"
  };
}

function send(res, status, body, origin = "") {
  res.writeHead(status, corsHeaders(origin));
  res.end(JSON.stringify(body));
}

function run(command, args, timeout = 10 * 60 * 1000) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      env: { ...process.env, GROK_HOME },
      windowsHide: true,
      stdio: ["ignore", "pipe", "pipe"]
    });

    let stdout = "";
    let stderr = "";

    const timer = setTimeout(() => {
      child.kill("SIGTERM");
      reject(new Error("Grok command timed out."));
    }, timeout);

    child.stdout.on("data", chunk => { stdout += chunk.toString(); });
    child.stderr.on("data", chunk => { stderr += chunk.toString(); });

    child.on("error", error => {
      clearTimeout(timer);
      if (error.code === "ENOENT") {
        reject(new Error("The official Grok CLI is not installed. Run the local setup script first."));
      } else {
        reject(error);
      }
    });

    child.on("close", code => {
      clearTimeout(timer);
      if (code === 0) {
        resolve({ stdout, stderr });
      } else {
        reject(new Error((stderr || stdout || `Grok exited with code ${code}.`).trim()));
      }
    });
  });
}

async function readJson(req) {
  return new Promise((resolve, reject) => {
    let raw = "";

    req.on("data", chunk => {
      raw += chunk.toString();
      if (raw.length > MAX_BODY) {
        reject(new Error("Request body is too large."));
        req.destroy();
      }
    });

    req.on("end", () => {
      try {
        resolve(raw ? JSON.parse(raw) : {});
      } catch {
        reject(new Error("Invalid JSON request."));
      }
    });

    req.on("error", reject);
  });
}

function extractDeviceInfo(output) {
  const text = output.replace(/\r/g, "");
  const urls = [...text.matchAll(/https?:\/\/[^\s]+/g)]
    .map(m => m[0].replace(/[).,]+$/, ""));

  const code =
    text.match(/(?:code|user code|verification code)\s*[:=]?\s*([A-Z0-9-]{4,20})/i)?.[1] ||
    text.match(/\b[A-Z0-9]{4,8}-[A-Z0-9]{4,8}\b/)?.[0] ||
    null;

  return { output: text.trim(), url: urls[0] || null, code };
}

async function isApiAuthenticated() {
  if (!XAI_API_KEY) return false;
  try {
    const r = await fetch(XAI_BASE_URL + "/models", {
      headers: { Authorization: "Bearer " + XAI_API_KEY }
    });
    return r.ok;
  } catch {
    return false;
  }
}

async function isAuthenticated() {
  if (API_MODE) return isApiAuthenticated();
  try {
    await run("grok", ["models"], 30_000);
    return true;
  } catch {
    return false;
  }
}

async function runApiChat(messages) {
  const r = await fetch(XAI_BASE_URL + "/chat/completions", {
    method: "POST",
    headers: {
      Authorization: "Bearer " + XAI_API_KEY,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model: XAI_MODEL,
      messages,
      stream: false
    })
  });
  const data = await r.json().catch(() => ({}));
  if (!r.ok) {
    throw new Error(data?.error?.message || "Grok API request failed (" + r.status + ").");
  }
  const text = data?.choices?.[0]?.message?.content;
  if (typeof text !== "string") throw new Error("Grok API returned no text response.");
  return text.trim();
}

let loginProcess = null;
let loginBuffer = "";

function startDeviceLogin(res, origin) {
  if (loginProcess) {
    return send(res, 409, {
      error: "A Grok login is already in progress.",
      ...extractDeviceInfo(loginBuffer)
    }, origin);
  }

  loginBuffer = "";

  try {
    loginProcess = spawn("grok", ["login", "--device-auth"], {
      env: { ...process.env, GROK_HOME },
      windowsHide: true,
      stdio: ["ignore", "pipe", "pipe"]
    });
  } catch (error) {
    return send(res, 500, { error: error.message || "Could not start Grok login." }, origin);
  }

  const collect = chunk => { loginBuffer += chunk.toString(); };
  loginProcess.stdout.on("data", collect);
  loginProcess.stderr.on("data", collect);
  loginProcess.on("error", error => { loginBuffer += "\n" + (error.message || ""); });
  loginProcess.on("close", () => { loginProcess = null; });

  setTimeout(() => {
    send(res, 200, {
      authenticated: false,
      loginStarted: true,
      ...extractDeviceInfo(loginBuffer)
    }, origin);
  }, 1000);
}

async function chat(res, body, origin) {
  const prompt = String(body.prompt || "").trim();
  const chatId = String(body.chatId || randomUUID());
  const effort = String(body.effort || "medium");

  if (!prompt) {
    return send(res, 400, { error: "prompt is required." }, origin);
  }

  if (!(await isAuthenticated())) {
    return send(res, 401, {
      error: "Grok is not connected. Connect your Grok account first."
    }, origin);
  }

  const sessionId = /^[0-9a-f-]{36}$/i.test(chatId) ? chatId : randomUUID();
  const attachments = Array.isArray(body.attachments) ? body.attachments : [];
  const attachmentParts = [];
  for (const att of attachments) {
    const name = String(att?.name || "file");
    if (att?.text) {
      const clip = String(att.text).slice(0, 12000);
      attachmentParts.push(`Attached text file '${name}':\n${clip}`);
    } else if (att?.kind === "image" && att?.dataUrl) {
      attachmentParts.push(`Attached image '${name}' provided as design reference.`);
    } else if (att?.note) {
      attachmentParts.push(`Attached file '${name}': ${att.note}`);
    } else {
      attachmentParts.push(`Attached file '${name}'.`);
    }
  }
  const attachmentBlock = attachmentParts.length
    ? "\n\nUser attachments:\n" + attachmentParts.join("\n\n")
    : "";

  const designPrompt = [
    "You are G3DAI, a professional 3D model designer and 3D-printing engineering assistant.",
    `Reasoning effort: ${effort}.`,
    "Give practical, dimension-aware design guidance. When the user asks for a model, think in terms of manufacturable geometry and 3D-printing constraints.",
    "Do not claim an STL exists unless G3DAI has actually generated one.",
    "",
    prompt + attachmentBlock
  ].join("\n");

  try {
    if (API_MODE) {
      const history = Array.isArray(body.history) ? body.history.slice(-12) : [];
      const messages = [
        { role: "system", content: "You are G3DAI, a professional 3D model designer and 3D-printing engineering assistant. Give concrete, dimension-aware, printable design guidance. Do not claim an STL exists unless G3DAI actually generated one." },
        ...history
          .filter(x => x && (x.role === "user" || x.role === "assistant") && String(x.text || "").trim())
          .map(x => ({ role: x.role, content: String(x.text).slice(0, 12000) })),
        { role: "user", content: designPrompt }
      ];
      const output = await runApiChat(messages);
      return send(res, 200, {
        chatId,
        sessionId,
        output,
        model: XAI_MODEL,
        connection: "xai-api"
      }, origin);
    }

    const result = await run("grok", [
      "--no-auto-update",
      "-m", "grok-4.7",
      "-s", sessionId,
      "-p", designPrompt,
      "--output-format", "plain",
      "--no-alt-screen"
    ], 15 * 60 * 1000);

    send(res, 200, {
      chatId,
      sessionId,
      output: result.stdout.trim(),
      model: "grok-4.7",
      connection: "grok-cli"
    }, origin);
  } catch (error) {
    send(res, 500, { error: error.message || "Grok request failed." }, origin);
  }
}

function serveLocalSite(res) {
  try {
    const html = readFileSync(join(process.cwd(), "..", "index.html"), "utf8");
    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    res.end(html);
  } catch (error) {
    send(res, 500, { error: "Could not load G3DAI frontend: " + error.message });
  }
}

async function route(req, res) {
  const origin = req.headers.origin || "";

  if (req.method === "OPTIONS") {
    res.writeHead(204, corsHeaders(origin));
    return res.end();
  }

  if (req.method === "GET" && (req.url === "/" || req.url === "/index.html")) {
    return serveLocalSite(res);
  }

  if (req.url === "/api/health" && req.method === "GET") {
    return send(res, 200, {
      ok: true,
      provider: "Grok",
      apiKeyRequired: API_MODE,
      mode: API_MODE ? "xai-api" : "local",
      connection: API_MODE ? "xai-api" : "grok-cli"
    }, origin);
  }

  if (req.url === "/api/grok/status" && req.method === "GET") {
    const authenticated = await isAuthenticated();

    return send(res, 200, {
      authenticated,
      apiKeyRequired: API_MODE,
      authMethod: API_MODE ? "xai-api-server-secret" : "grok-cli-oauth",
      storage: API_MODE ? "server-env" : GROK_HOME,
      mode: API_MODE ? "xai-api" : "local",
      connection: API_MODE ? "xai-api" : "grok-cli"
    }, origin);
  }

  if (req.url === "/api/grok/login" && req.method === "POST") {
    if (API_MODE) {
      const authenticated = await isApiAuthenticated();
      return send(res, authenticated ? 200 : 503, {
        authenticated,
        connection: "xai-api",
        message: authenticated
          ? "Grok API is configured on the server."
          : "The server does not have a working xAI API key."
      }, origin);
    }
    return startDeviceLogin(res, origin);
  }

  if (req.url === "/api/grok/logout" && req.method === "POST") {
    try {
      await run("grok", ["logout"], 30_000);
      return send(res, 200, { authenticated: false }, origin);
    } catch (error) {
      return send(res, 500, {
        error: error.message || "Grok logout failed."
      }, origin);
    }
  }

  if (req.url === "/api/grok/chat" && req.method === "POST") {
    try {
      const body = await readJson(req);
      return chat(res, body, origin);
    } catch (error) {
      return send(res, 400, {
        error: error.message || "Invalid request."
      }, origin);
    }
  }

  return send(res, 404, { error: "Not found." }, origin);
}

const server = http.createServer((req, res) => {
  route(req, res).catch(error => {
    send(res, 500, { error: error.message || "Server error." }, req.headers.origin || "");
  });
});

server.listen(PORT, HOST, () => {
  console.log(`G3DAI local Grok bridge listening on http://${HOST}:${PORT}`);
  console.log(`GROK_HOME=${GROK_HOME}`);
});
