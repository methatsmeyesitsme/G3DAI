# G3D AI

Static GitHub Pages deployment of the uploaded G3D AI prototype.

## GitHub Pages

The repository includes a GitHub Actions workflow that builds the supplied `G3D AI.html` into `index.html` and deploys it with GitHub Pages.

The prototype was originally built around Claude's hosted `claude.use(...)` runtime. GitHub Pages can host the interface, but it does not provide that Claude runtime or a server-side AI key, so the AI/chat backend will not operate on Pages until a separate backend/API integration is added.

