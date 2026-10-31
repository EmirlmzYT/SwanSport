# Web metadata and deployment

- Preserve `web/index.html`, `web/manifest.json`, `_redirects`, page titles, deep links, and share metadata unless requested.
- Do not apply news-site SEO conventions to this app without a specific feature request.
- Keep console web builds under `/konsol/` with the existing base-href and redirect order.
- Do not change Cloudflare Pages Functions, `wrangler` commands, or deployment workflows without explicit approval.
- Build or open the affected local web entrypoint after web-shell changes.
- Do not deploy to Cloudflare Pages or publish a release unless explicitly authorized.
