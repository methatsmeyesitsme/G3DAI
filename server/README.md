# G3DAI Grok bridge

The G3DAI backend uses xAI's official Grok CLI instead of the xAI REST API.

Authentication is performed with the official Grok CLI's supported OAuth/device-code flow. The authenticated Grok session is then reused by headless Grok commands for inference.

## Endpoints

- GET /api/health
- GET /api/grok/status
- POST /api/grok/login
- POST /api/grok/logout
- POST /api/grok/chat

## Authentication

No xAI API key is required.

The login endpoint starts:

    grok login --device-auth

The server returns the device URL/code, and the G3DAI frontend guides the user through the official xAI sign-in. Authentication state is checked by the real Grok CLI, so G3DAI never claims a connection that does not exist.

## Inference

Chat requests use an authenticated Grok headless session with Grok 4.7:

    grok -m grok-4.7 -s <session-id> -p <prompt>

The Grok credential stays on the backend. G3DAI never asks for or stores a Grok password, browser cookie, or xAI API key.

## Hosting

GitHub Pages can host the frontend, but it cannot execute this Node server. Deploy this bridge separately on a Node-capable host.

For hosted use, the directory pointed to by GROK_HOME must be persistent so the OAuth session survives restarts.

For a public deployment, protect the bridge with an application-level pairing/authentication layer. Do not expose an authenticated single-owner Grok session as an unrestricted public endpoint.

## Official xAI documentation

https://docs.x.ai/build/cli/reference
https://docs.x.ai/build/cli/headless-scripting
https://docs.x.ai/build/enterprise
