# Security Principles

- Row Level Security is mandatory for sensitive tables.
- Secrets must not be committed to source control.
- Authorization must support multiple roles per user and context-based role assignments.
- Organizations, clubs, teams, and child relationships must isolate private data from unrelated users.
- Child accounts must be private by default.
- Sensitive documents must not be public. Use signed and time-limited access when document access is implemented.
- Important review and permission actions must be written to audit logs.
- Apply the minimum privilege principle in the UI and in database policies.
- Hiding a button or route is not sufficient authorization.
