# G3DAI backend

This is the server-side foundation for persistent chats, projects/jobs, cancellation, and a provider adapter.

Run with Node 20+:

    npm start

The server stores durable state under `G3DAI_DATA_DIR` (default `./data`). It exposes:

- GET /api/health
- GET /api/state
- POST/PATCH/DELETE /api/chats
- POST/GET/DELETE /api/jobs
- POST /api/provider/grok

The Grok endpoint is deliberately disabled unless a real provider bridge is supplied. The frontend must never receive a private provider credential.

GitHub Pages remains a static frontend and cannot run this server. Deploy this server separately and point the frontend at its HTTPS API URL.

Do not configure this server with a personal grok.com password, browser cookie, or scraped consumer session. The provider adapter is intentionally fail-closed until xAI documents a supported authentication/inference mechanism for third-party applications.
