---
name: web-metadata-check
description: Review SwanSport web metadata, manifests, redirects, and deep-link behavior without applying unrelated news-site SEO patterns.
---

# Check web metadata

1. Inspect `apps/swansport_app/web/index.html`, `web/manifest.json`, and `web/_redirects` before editing.
2. Inspect the matching files in `apps/swansport_console/web/` when the console is in scope.
3. Preserve titles, descriptions, icons, manifests, canonical behavior, and social-preview metadata unless the request changes them.
4. Preserve `/konsol/` base-href and put its redirect before the general SPA redirect.
5. Do not add article, RSS, author, or news SEO markup; this repository is not a news CMS.
6. Check legacy deep links and the affected local web entrypoint after a shell change.
7. Do not deploy; report the exact local validation performed.
