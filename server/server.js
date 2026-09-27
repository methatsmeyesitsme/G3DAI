import http from "node:http";
import fs from "node:fs/promises";
import path from "node:path";
import crypto from "node:crypto";

const PORT = Number(process.env.PORT || 8787);
const DATA = path.resolve(process.env.G3DAI_DATA_DIR || "./data");
const DB = path.join(DATA, "state.json");
const uploads = path.join(DATA, "uploads");

async function ensure() {
  await fs.mkdir(uploads, { recursive: true });
  try { await fs.access(DB); } catch {
    await fs.writeFile(DB, JSON.stringify({ chats: [], projects: [], models: [], jobs: [] }, null, 2));
  }
}
async function readDB() { return JSON.parse(await fs.readFile(DB, "utf8")); }
async function writeDB(db) { await fs.writeFile(DB, JSON.stringify(db, null, 2)); }
function json(res, status, body) {
  res.writeHead(status, { "content-type": "application/json; charset=utf-8", "access-control-allow-origin": "*", "access-control-allow-headers": "content-type", "access-control-allow-methods": "GET,POST,PATCH,DELETE,OPTIONS" });
  res.end(JSON.stringify(body));
}
async function body(req) {
  let s = ""; for await (const c of req) s += c;
  return s ? JSON.parse(s) : {};
}
function id() { return crypto.randomUUID(); }

await ensure();

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === "OPTIONS") return json(res, 204, {});
    const u = new URL(req.url, "http://localhost");
    const db = await readDB();

    if (req.method === "GET" && u.pathname === "/api/health")
      return json(res, 200, { ok: true, service: "G3DAI", provider: "grok", providerConfigured: Boolean(process.env.G3DAI_PROVIDER_URL) });

    if (req.method === "GET" && u.pathname === "/api/state")
      return json(res, 200, db);

    if (req.method === "POST" && u.pathname === "/api/chats") {
      const b = await body(req), chat = { id: id(), title: b.title || "New Chat", messages: [], models: [], updated: Date.now() };
      db.chats.unshift(chat); await writeDB(db); return json(res, 201, chat);
    }

    const cm = u.pathname.match(/^\/api\/chats\/([^/]+)$/);
    if (cm && req.method === "GET") {
      const chat = db.chats.find(x => x.id === cm[1]); return chat ? json(res, 200, chat) : json(res, 404, { error: "Chat not found" });
    }
    if (cm && req.method === "PATCH") {
      const chat = db.chats.find(x => x.id === cm[1]); if (!chat) return json(res, 404, { error: "Chat not found" });
      Object.assign(chat, await body(req), { updated: Date.now() }); await writeDB(db); return json(res, 200, chat);
    }
    if (cm && req.method === "DELETE") {
      db.chats = db.chats.filter(x => x.id !== cm[1]); await writeDB(db); return json(res, 204, {});
    }

    if (req.method === "POST" && u.pathname === "/api/jobs") {
      const b = await body(req), job = { id: id(), status: "queued", prompt: b.prompt || "", chatId: b.chatId || null, created: Date.now(), cancelRequested: false };
      db.jobs.unshift(job); await writeDB(db);
      // The job remains queued until a real provider/CAD worker is configured.
      return json(res, 202, job);
    }

    const jm = u.pathname.match(/^\/api\/jobs\/([^/]+)$/);
    if (jm && req.method === "GET") {
      const job = db.jobs.find(x => x.id === jm[1]); return job ? json(res, 200, job) : json(res, 404, { error: "Job not found" });
    }
    if (jm && req.method === "DELETE") {
      const job = db.jobs.find(x => x.id === jm[1]); if (!job) return json(res, 404, { error: "Job not found" });
      job.cancelRequested = true; job.status = "cancelled"; await writeDB(db); return json(res, 200, job);
    }

    if (req.method === "POST" && u.pathname === "/api/provider/grok") {
      if (!process.env.G3DAI_PROVIDER_URL)
        return json(res, 503, { error: "No supported Grok provider bridge is configured. G3DAI will not accept or invent a consumer Grok session." });
      const b = await body(req);
      const r = await fetch(process.env.G3DAI_PROVIDER_URL, { method: "POST", headers: { "content-type": "application/json", ...(process.env.G3DAI_PROVIDER_AUTH ? { authorization: process.env.G3DAI_PROVIDER_AUTH } : {}) }, body: JSON.stringify(b) });
      return json(res, r.status, await r.json().catch(() => ({ error: "Provider returned non-JSON data" })));
    }

    return json(res, 404, { error: "Not found" });
  } catch (e) {
    return json(res, 500, { error: e?.message || "Server error" });
  }
});

server.listen(PORT, () => console.log("G3DAI server listening on " + PORT));