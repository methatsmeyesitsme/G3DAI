# G3DAI

G3DAI is a 3D-design-focused web application for creating and iterating printable geometry.

## Current deployment

The GitHub Pages deployment now serves the real application directly from `index.html`. It includes:

- Persistent chat history in browser storage
- Real Three.js model preview with orbit controls
- Model versions tied to conversations
- Real binary STL export from generated geometry
- Printer/material/nozzle settings
- File selection UI
- Project/chat navigation
- Honest connection status when a Grok inference backend is unavailable

## Grok authentication

The app deliberately does **not** ask for or store an `XAI_API_KEY`, and it does not pretend that a grok.com account is connected.

Current xAI documentation exposes API inference authenticated by API key and interactive session authentication for Grok Build/CLI. It does not document a public OAuth flow for arbitrary third-party web apps to consume a user's personal grok.com inference session. The GitHub Pages frontend therefore fails closed instead of collecting credentials or faking an AI connection.

A real Grok-powered deployment needs a supported server-side session/inference integration. GitHub Pages alone cannot provide that backend.

## Geometry

The current browser-side geometry engine contains real parametric generators for supported starter designs and exports their actual Three.js meshes to STL. The architecture is intended to be extended with a server-side CAD/geometry worker and a supported Grok session provider.

## Deployment

GitHub Actions deploys `index.html` directly to GitHub Pages on pushes to `main`.
