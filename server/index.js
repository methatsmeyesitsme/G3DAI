import http from "node:http";
import { spawn } from "node:child_process";
import { mkdirSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import { randomUUID } from "node:crypto";

const PORT = Number(process.env.PORT || 8787);
const HOST = process.env.HOST || "127.0.0.1";
const GROK_HOME = process.env.GROK_HOME || join(homedir(), ".grok");
const CORS_ORIGIN = process.env.CORS_ORIGIN || "https://methatsmeyesitsme.github.io";
const MAX_BODY = 2 * 1024 * 1024;

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

async function isAuthenticated() {
  try {
    await run("grok", ["models"], 30_000);
    return true;
  } catch {
    return false;
  }
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
  const designPrompt = [
    "You are G3DAI, a professional 3D model designer and 3D-printing engineering assistant.",
    `Reasoning effort: ${effort}.`,
    "Give practical, dimension-aware design guidance. When the user asks for a model, think in terms of manufacturable geometry and 3D-printing constraints.",
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
    ], 15 * 60 * 1000);

    send(res, 200, {
      chatId,
      sessionId,
      output: result.stdout.trim(),
      model: "grok-4.7"
    }, origin);
  } catch (error) {
    send(res, 500, { error: error.message || "Grok request failed." }, origin);
  }
}

async function route(req, res) {
  const origin = req.headers.origin || "";

  if (req.method === "OPTIONS") {
    res.writeHead(204, corsHeaders(origin));
    return res.end();
  }

  if (req.url === "/api/health" && req.method === "GET") {
    return send(res, 200, {
      ok: true,
      provider: "Grok",
      apiKeyRequired: false,
      mode: "local"
    }, origin);
  }

  if (req.url === "/api/grok/status" && req.method === "GET") {
    const authenticated = await isAuthenticated();

    return send(res, 200, {
      authenticated,
      apiKeyRequired: false,
      authMethod: "grok-cli-oauth",
      storage: GROK_HOME,
      mode: "local"
    }, origin);
  }

  if (req.url === "/api/grok/login" && req.method === "POST") {
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
