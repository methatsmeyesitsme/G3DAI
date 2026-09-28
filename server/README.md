# G3DAI server

Node 20 backend for durable chat/job state, cancellation, health, and a fail-closed Grok provider adapter.

## Run locally

```bash
cd server
cp .env.example .env   # optional
npm start
```

Or use the Windows helpers from the repo root:

- `Start-G3DAI.bat` (downloads current start-easy.ps1 and runs setup)
- `server/start-local.bat` / `server/start-local.ps1`

## Environment

See `.env.example`. Do not put personal Grok passwords, cookies, or API keys here unless xAI documents a supported bridge for this project.

## Docker

```bash
docker build -f server/Dockerfile -t g3dai-server .
docker run --rm -p 8787:8787 -v g3dai-data:/data g3dai-server
```
