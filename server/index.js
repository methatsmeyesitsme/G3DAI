import http from "node:http";
import { spawn } from "node:child_process";
import { mkdirSync, existsSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import { randomUUID } from "node:crypto";

const PORT = Number(process.env.PORT || 8787);
const HOST = process.env.HOST || "0.0.0.0";
const GROK_HOME = process.env.GROK_HOME || join(homedir(), ".grok");
const MAX_BODY = 2 * 1024 * 1024;
const sessions = new Map();

mkdirSync(GROK_HOME, { recursive: true });

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": process.env.CORS_ORIGIN || "*",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
    "Content-Type": "application/json; charset=utf-8"
  };
}

function send(res, status, body) {
  res.writeHead(status, corsHeaders());
  res.end(JSON.stringify(body));
}

function run(command, args, options = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: options.cwd || process.cwd(),
      env: { ...process.env, GROK_HOME },
      windowsHide: true
    });

    let stdout = "";
    let stderr = "";
    const timer = setTimeout(() => {
      child.kill("SIGTERM");
      reject(new Error("Grok command timed out."));
    }, options.timeout || 10 * 60 * 1000);

    child.stdout.on("data", b => { stdout += b.toString(); });
    child.stderr.on("data", b => { stderr += b.toString(); });

    child.on("error", err => {
      clearTimeout(timer);
      if (err.code === "ENOENT") {
        reject(new Error("The official Grok CLI is not installed on this server."));
      } else {
        reject(err);
      }
    });

    child.on("close", code => {
      clearTimeout(timer);
      if (code === 0) resolve({ stdout, stderr });
      else reject(new Error((stderr || stdout || `Grok exited with code ${code}.`).trim()));
    });
  });
}

async function readJson(req) {
  return new Promise((resolve, reject) => {
    let raw = "";
    req.on("data", chunk => {
      raw += chunk;
      if (raw.length > MAX_BODY) {
        req.destroy();
        reject(new Error("Request body is too large."));
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
  const urls = [...text.matchAll(/https?:\/\/[^\s]+/g)].map(m => m[0].replace(/[).,]+$/, ""));
  const code =
    text.match(/(?:code|user code|verification code)\s*[:=]?\s*([A-Z0-9-]{4,20})/i)?.[1] ||
    text.match(/\b[A-Z0-9]{4,8}-[A-Z0-9]{4,8}\b/)?.[0] ||
    null;
  return { output: text.trim(), url: urls[0] || null, code };
}

async function isAuthenticated() {
  try {
    await run("grok", ["models"], { timeout: 30_000 });
    return true;
  } catch {
    return false;
  }
}

let loginProcess = null;
let loginBuffer = "";

function startDeviceLogin(res) {
  if (loginProcess) {
    return send(res, 409, {
      error: "A Grok login is already in progress.",
      ...extractDeviceInfo(loginBuffer)
    });
  }

  loginBuffer = "";
  loginProcess = spawn("grok", ["login", "--device-auth"], {
    env: { ...process.env, GROK_HOME },
    windowsHide: true
  });

  const onOutput = chunk => {
    loginBuffer += chunk.toString();
  };
  loginProcess.stdout.on("data", onOutput);
  loginProcess.stderr.on("data", onOutput);

  loginProcess.on("error", error => {
    loginBuffer += "\n" + (error.message || "");
  });

  loginProcess.on("close", () => {
    loginProcess = null;
  });

  setTimeout(() => {
    const info = extractDeviceInfo(loginBuffer);
    send(res, 200, {
      authenticated: false,
      loginStarted: true,
      ...info
    });
  }, 1200);
}

async function chat(res, body) {
  const prompt = String(body.prompt || "").trim();
  const chatId = String(body.chatId || randomUUID());
  const effort = String(body.effort || "medium");

  if (!prompt) return send(res, 400, { error: "prompt is required." });

  if (!(await isAuthenticated())) {
    return send(res, 401, { error: "Grok is not connected. Connect your Grok account first." });
  }

  const sessionId = sessions.get(chatId) || randomUUID();
  sessions.set(chatId, sessionId);

  const designPrompt = [
    "You are G3DAI, a professional 3D model designer and 3D-printing engineering assistant.",
    `Reasoning effort: ${effort}.`,
    "Give practical, dimension-aware design guidance. When the user asks for a model, think in terms of manufacturable geometry and a future STL workflow.",
    "Do not claim an STL exists unless G3DAI has actually generated one.",
    "",
    prompt
  ].join("\n");

  try {
    const result = await run("grok", [
      "--no-auto-update",
      "-m", "grok-4.7",
      "-s", sessionId,
      "-p", designPrompt,
      "--output-format", "plain",
      "--no-alt-screen"
    ], { timeout: 15 * 60 * 1000 });

    send(res, 200, {
      chatId,
      sessionId,
      output: result.stdout.trim(),
      model: "grok-4.7"
    });
  } catch (error) {
    send(res, 500, { error: error.message || "Grok request failed." });
  }
}

async function route(req, res) {
  if (req.method === "OPTIONS") {
    res.writeHead(204, corsHeaders());
    return res.end();
  }

  if (req.url === "/api/health" && req.method === "GET") {
    return send(res, 200, { ok: true, provider: "Grok", apiKeyRequired: false });
  }

  if (req.url === "/api/grok/status" && req.method === "GET") {
    const authenticated = await isAuthenticated();
    return send(res, 200, {
      authenticated,
      apiKeyRequired: false,
      authMethod: "grok-cli-oauth"
    });
  }

  if (req.url === "/api/grok/login" && req.method === "POST") {
    return startDeviceLogin(res);
  }

  if (req.url === "/api/grok/logout" && req.method === "POST") {
    try {
      await run("grok", ["logout"], { timeout: 30_000 });
      sessions.clear();
      return send(res, 200, { authenticated: false });
    } catch (error) {
      return send(res, 500, { error: error.message || "Grok logout failed." });
    }
  }

  if (req.url === "/api/grok/chat" && req.method === "POST") {
    try {
      return chat(res, await readJson(req));
    } catch (error) {
      return send(res, 400, { error: error.message || "Invalid request." });
    }
  }

  send(res, 404, { error: "Not found." });
}

const server = http.createServer((req, res) => {
  route(req, res).catch(error => send(res, 500, { error: error.message || "Server error." }));
});

server.listen(PORT, HOST, () => {
  console.log(`G3DAI Grok bridge listening on http://${HOST}:${PORT}`);
  console.log(`GROK_HOME=${GROK_HOME}`);
});
