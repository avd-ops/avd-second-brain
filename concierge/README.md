# Deterministic Concierge (`avd_concierge`)

Personal project, not for production, provided as is; not affiliated with the author's employer, Liquidware or Microsoft.

The v1 deterministic Concierge read service ([`docs/v1-review.md` section 4](../docs/v1-review.md#4-the-concierge-in-v1-proposed)). It runs with no model of its own and zero LLM tokens, serving cited knowledge passages and `C11` current-state facts by `C15` fact register ID to operators and to `avd-swarm`'s specialist agents.

## Operations

- **`search(question, top=10)`** — Searches the organizational knowledge base (`knowledge/catalog/apps.json`, `knowledge/rules/avd-sizing-rules.json`, `knowledge/runbooks/drain-and-reimage-host.md`), the family knowledge base (`docs/knowledge/README.md`), and any synced connected repositories (`sources/sources.json`) or local estate vault. Returns ranked passages with exact citations (app catalog IDs, versioned rule references, knowledge paths, and pinned source commits), matching `scripts/Find-BrainKnowledge.ps1`.
- **`facts(ids, snapshot=..., estate=...)`** — Reads a `C11` (`avd-current-state-facts/v1`) snapshot from a facts-only store outside the public repository, validates every requested ID against `contracts/fact-register.json` (`C15`), and returns **only the requested `built` fact IDs** alongside `estate` and `generatedUtc`. Unknown fact IDs and IDs still marked `proposed` or `specified` are refused (`UnknownFactError`, `UnbuiltFactError`).

## CLI and HTTP server

```bash
# Search the brain from the CLI
PYTHONPATH=concierge python3 -m avd_concierge search "sandbox rag cost floor"

# Query C11 facts by C15 register ID from a snapshot file
PYTHONPATH=concierge python3 -m avd_concierge facts --snapshot /path/to/facts.json c11.hostPool.count c11.hostPool.type

# Start the HTTP read service (GET /healthz, POST /search, POST /facts)
PYTHONPATH=concierge python3 -m avd_concierge serve --port 8081
```
