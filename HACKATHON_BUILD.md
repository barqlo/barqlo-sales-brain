# BARQLO Sales Brain — Hackathon Build & Public Evidence Map

> Updated 2026-11-10 to reflect the contents of this **public** repository. The production n8n exports, historical Supabase migrations, and internal deployment runbook were moved to a private BARQLO repository. The public branch remains a project overview and offline demo, not a production installation bundle.

## Project and scope

- **Project:** BARQLO — Arabic-first, multi-tenant AI business operating platform.
- **Event:** Meta Global AI Developer Hackathon 2026, Startup track, Build for Your World.
- **Architecture:** A central brain with a reply-preparation stage and deterministic verification; tenant-scoped data and policy checks; channel adapters for messaging.
- **Sectors described by the historical demo:** Real estate, clinic and restaurant.
- **Product claims and historical observations are not a blanket independent audit or guarantee of current production behavior.**

## Public evidence now available

| Public artifact | What it shows | Limit |
| --- | --- | --- |
| [README](README.md) | Overview and demonstration video link | Describes the platform; not a full source release |
| [Offline demo](demo/) | Reproducible illustration of the reply/check flow with synthetic data | No live Muse Spark call or live tenant data |
| [Architecture](docs/architecture.md) | Overview of architectural choices | Does not expose production implementation |
| [Historical verification report](docs/live-verification-2026-11-05.md) | Dated read-only inspection narrative and its stated limits | Historical observations, not an always-current live test |

## Private implementation boundary

The previously published workflow JSON exports (central brain versions, Telegram adapters and support workflows), 18 historical Supabase migration files, and the production setup runbook are kept in a private BARQLO repository. **They are not linked as public files** and cannot be inspected from the latest public branch. Private access, if ever granted to a reviewer, must be separately authorized by the repository owner.

No database rows or live customer messages were included in the documented migration package. The historical migration files did **not** contain the original database baseline and could not independently reconstruct the complete platform.

**History warning:** A file removed from the latest Git branch may remain reachable through old commits, forks and clones. This cleanup does not purge prior public history.

## Reviewer path

1. Read the [overview](README.md) and linked demo video.
2. Run the [offline demonstration](demo/demo.js) with Node.js 18+.
3. Review the [architecture](docs/architecture.md) and [historical evidence notes](docs/live-verification-2026-11-05.md).
4. Request authorized private source review separately if production-level verification is required.

The dated report documents a limited sample of historical executions; it does not claim population-scale usage, a clean-room install or uninterrupted current service operation.
