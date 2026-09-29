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

## Grok connection

G3DAI supports a server-side xAI API connection as its primary hosted backend. The frontend never receives the API credential. The backend uses the current xAI API model configuration and can fall back to the local Grok CLI connection when no server API credential is configured.

xAI's public inference API currently authenticates with an API key and supports Grok 4.7. API billing is separate from the consumer Grok subscription. citeturn950273search0turn950273search2

For local-only use without an API credential, the existing Grok CLI connection remains available as a fallback.

## Geometry

The current browser-side geometry engine contains real parametric generators for supported starter designs and exports their actual Three.js meshes to STL. The architecture is intended to be extended with a server-side CAD/geometry worker and a supported Grok session provider.

## Deployment

GitHub Actions deploys `index.html` directly to GitHub Pages on pushes to `main`.


## Full-stack backend foundation

The repository now also contains a Node 20 backend under `server/`. It provides durable server-side state for chats and jobs, job cancellation, health checks, and an isolated Grok-provider adapter. The frontend can remain on GitHub Pages while the backend is deployed separately.

The provider adapter intentionally fails closed. No personal Grok password, browser cookie, scraped session, or API key is collected by G3DAI. A real xAI-supported third-party authentication/inference bridge can be connected to the adapter when xAI documents one.

## Current status

The project keeps the existing chat, model-preview, printer-settings, attachment, mobile-panel, cancellation, and UI fixes while allowing the Grok connection layer to use the newer server-side API architecture.