# Requirements & Constraints

## Architectural Requirements
- **Melos Workspace:** Maintain package boundaries (`apps/` vs `packages/`).
- **Data Encapsulation:** All Supabase interactions must stay strictly in `swansport_data`.
- **Zero UI in Data:** No Flutter UI dependencies in `swansport_data`.
- **Deterministic Migrations:** Migrations must be sequential, idempotent, and include lock timeout guards (`set local lock_timeout = '15s'`).

## Privacy & Safety Requirements
- **Accountant Anonymity:** Strict isolation of athlete identities from accountant role.
- **Child Privacy:** Underage accounts default to restricted visibility (`followers`), external sharing disabled.
- **Health Gate:** Health blocks only removable by verified, active club medical officers.
