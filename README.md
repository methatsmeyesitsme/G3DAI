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

G3DAI's primary user connection is the **G3DAI Grok Connector browser extension**. You sign into your normal Grok account at `grok.com`, keep the Grok tab open, and G3DAI sends prompts to that signed-in browser session through the extension.

G3DAI does not ask for your Grok password and does not require an xAI API key in the browser. The Windows local launcher is not required for this browser-session connection.

The connector depends on the Grok website's current page controls. If Grok changes those controls, the extension may need an update.

## Geometry

The current browser-side geometry engine contains real parametric generators for supported starter designs and exports their actual Three.js meshes to STL. The architecture is intended to be extended with a server-side CAD/geometry worker and a supported Grok session provider.

## Deployment

GitHub Actions deploys `index.html` directly to GitHub Pages on pushes to `main`.


## Full-stack backend foundation

The repository now also contains a Node 20 backend under `server/`. It provides durable server-side state for chats and jobs, job cancellation, health checks, and an isolated Grok-provider adapter. The frontend can remain on GitHub Pages while the backend is deployed separately.

The provider adapter intentionally fails closed. No personal Grok password, browser cookie, scraped session, or API key is collected by G3DAI. A real xAI-supported third-party authentication/inference bridge can be connected to the adapter when xAI documents one.

## Current status

The project keeps the existing chat, model-preview, printer-settings, attachment, mobile-panel, cancellation, editing, retry, and UI fixes while using the signed-in Grok browser-session connection.
