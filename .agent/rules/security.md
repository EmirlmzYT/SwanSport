# Security and data

- Treat all client input, route values, URLs, JSON, and remote payloads as untrusted.
- Do not build SQL with string concatenation; pass typed RPC parameters instead.
- Keep authorization in RLS or guarded `security definer` functions, never only in UI.
- Add or preserve RLS and grants when adding a database object.
- Do not expose private IDs, credentials, medical data, child data, or service-role secrets.
- Do not edit `env/`, `.env*`, Supabase URLs/keys, Firebase configs, signing files, or production settings.
- Do not connect, link, push migrations, deploy, or call production systems without explicit permission.
- Escape user-controlled text and URLs; do not inject raw HTML or interpolated JavaScript.
- Preserve least privilege; revoke `PUBLIC`, `anon`, and `authenticated` access where required.
