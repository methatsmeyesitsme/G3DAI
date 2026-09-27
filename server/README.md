# G3DAI local Grok bridge

G3DAI now uses a **local** backend instead of Render for Grok.

Your computer runs the official xAI Grok CLI, your Grok login is stored in the CLI's local `.grok` directory, and the G3DAI GitHub Pages frontend talks to that local bridge.

No xAI API key is required.

## How it works

G3DAI GitHub Pages
→ http://127.0.0.1:8787
→ G3DAI local bridge
→ official Grok CLI
→ your signed-in Grok account

The local bridge listens on **127.0.0.1 only**, so it is not exposed to your LAN or the public internet.

xAI documents four Grok Build authentication methods, including Browser OIDC and device-code authentication. The CLI stores user settings under `~/.grok`, and headless sessions under `~/.grok/sessions`.

## Windows setup

Run `start-local.bat`.

The script checks for Node/npm, installs the official Grok CLI when necessary, and starts the bridge on port 8787.

Then open the local G3DAI window that the launcher opens automatically:

http://127.0.0.1:8787/

The GitHub Pages site is still available at https://methatsmeyesitsme.github.io/G3DAI/, but the local address is the one to use when you want Grok through the local bridge.

Open **Settings → Connect Grok** and complete the official Grok sign-in.

After you have authenticated once, the CLI keeps its authentication state locally in your user `.grok` directory. Headless Grok sessions are also stored locally. citeturn379989search3turn379989search4

## Running it

Keep the local bridge window open while G3DAI is using Grok.

Stop it by closing that window.

## Endpoints

- GET /api/health
- GET /api/grok/status
- POST /api/grok/login
- POST /api/grok/logout
- POST /api/grok/chat

## Security

- No `XAI_API_KEY`
- No Grok password collected by G3DAI
- No browser cookie scraping
- Grok credentials remain under the local Grok CLI directory
- Server binds to 127.0.0.1 only
- CORS allows the G3DAI GitHub Pages origin plus local origins

This architecture is intentionally single-user/local. The bridge should not be exposed through a public tunnel or proxy unless an additional authentication layer is added.
