# G3DAI

G3DAI is a 3D-design-focused web application for creating and iterating printable geometry.

## Current deployment

The GitHub Pages deployment now serves the real application directly from `index.html`. It includes:

- Persistent chat history in browser storage
- Real Three.js model preview with orbit controls
- Model versions tied to conversations
- Real binary STL export from generated geometry
- Printer/material/nozzle settings
- Working file attachments (text inlined, images as design reference, model/PDF by name)
- Mobile-friendly model panel (right slide-over, not hidden)
- Project/chat navigation
- Abortable generation (Stop cancels the in-flight request)
- Honest connection status when a Grok inference backend is unavailable

## Grok authentication

The app deliberately does **not** ask for or store an `XAI_API_KEY`, and it does not pretend that a grok.com account is connected.

Current xAI documentation exposes API inference authenticated by API key and interactive session authentication for Grok Build/CLI. It does not document a public OAuth flow for arbitrary third-party web apps to consume a user's personal grok.com inference session. The GitHub Pages frontend therefore fails closed instead of collecting credentials or faking an AI connection.

A real Grok-powered deployment needs a supported server-side session/inference integration. GitHub Pages alone cannot provide that backend.

## Geometry

The current browser-side geometry engine contains real parametric generators for supported starter designs and exports their actual Three.js meshes to STL. The architecture is intended to be extended with a server-side CAD/geometry worker and a supported Grok session provider.

## Deployment

GitHub Actions deploys `index.html` directly to GitHub Pages on pushes to `main`.


## Full-stack backend foundation

The repository now also contains a Node 20 backend under `server/`. It provides durable server-side state for chats and jobs, job cancellation, health checks, and an isolated Grok-provider adapter. The frontend can remain on GitHub Pages while the backend is deployed separately.

The provider adapter intentionally fails closed. No personal Grok password, browser cookie, scraped session, or API key is collected by G3DAI. A real xAI-supported third-party authentication/inference bridge can be connected to the adapter when xAI documents one.

## Current honest status

The application and backend foundations are real. The remaining external dependency is the provider authorization mechanism: xAI's current public documentation does not expose a consumer-grok.com OAuth flow that lets an arbitrary third-party website consume the user's Grok subscription for inference. xAI documents shared xAI/Grok accounts but separate API billing, and its non-key interactive authentication documentation is for Grok Build/CLI rather than a generic third-party web-app inference API.
