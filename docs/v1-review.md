# avd-second-brain v1 completeness review

- **Date:** 2026-10-20. Reviewed `main` at `6f0a199` and the open drafts that change the specs: #29 (claims on every edge), #34 (Well-Architected sources), #37 (decisions 0016 and 0017), #40 (C17 recovery use case), #41 (decision 0018), the recovery decision 0019 and the "why layer" work (C18, decision 0020). Paired with [avd-swarm's v1 review](https://github.com/nickprignano/avd-swarm/blob/main/docs/v1-review.md).
- **Status:** Proposed. Offline review only: nothing was deployed, run or spent.
- **The brain's purpose** (the why layer: use cases and decisions over an environment's whole life) is being written by the "why layer" work (C18, decision 0020). This review doesn't restate it; it checks that the rest of the specs are complete and consistent around it.

## 1. What v1 is (proposed)

| Already built (offline) | v1 adds | After v1 |
|---|---|---|
| The knowledge base and its guard, the family KB, the vault, C1 to C7, C11 importer, C13 docs check, C14 checks, C15 register, C17 schemas | **Tier 1 (Notice):** detections, the scheduled preflight job, pseudonymized episode issues, a Claude Code diagnosis, the weekly digest, its budget | Tier 3 (episodic memory, vector search, Foundry agents, Retro and Evolve) |
| | **A deterministic Concierge** that avd-swarm's agents call as a read tool (§4) | C9 proposals, and C8 exports from avd-swarm's Improve |
| | **C10's switch read:** the brain's model calls and proposals stop with avd-swarm's switch | Standing exceptions (EX-0003), if they survive decision 0003 (D5) |
| | The why layer (C18), as its own work defines it | C12's schema (waits on a real Hub), avd-assess ingestion (§5, G6) |

Tier 2 (approved fixes) is no longer the brain's: avd-swarm executes every change (decision 0003).

## 2. Does the brain need an MCP?

No. The brain builds no MCP server (operations spec §3.1 now says so). Its Concierge reaches operators as one of avd-swarm's tools, and avd-swarm uses Microsoft's Azure MCP Server for its own reads and builds no MCP server of its own in v1 ([avd-swarm spec §3](https://github.com/nickprignano/avd-swarm/blob/main/docs/spec.md#3-architecture)). People and coding agents read the brain through what already exists: `llms.txt`, the family KB and `Find-BrainKnowledge.ps1`.

## 3. What is decided

| Area | Decision | Where |
|---|---|---|
| Roles | The brain thinks (the why), avd-swarm acts (the how); changes in pairs | Decision 0003 |
| Base pair | avd-landing-zone and avd-current-state stand alone; the brain depends down only | Operations spec §3.0 (new, owner's rule 2026-10-20) |
| Three stores | Knowledge (public, generalized), estate vault (private), operations memory (in the tenant) | Architecture §3 |
| How knowledge enters | Only by a PR a person merges, after the guard | Decision 0002, knowledge spec |
| Facts | C11 current state, C12 forensic, both by C15 register ID; facts propose, live reads decide | Contracts C11, C12, C15 |
| Models never decide | A model drafts and flags; verdicts need evidence, rules need a reason | CLAUDE.md, operations spec §4.4 |
| Pseudonyms | Two subkeys, `users` rotates, `resources` doesn't; the brain keeps no mapping | Operations spec §9.4 |
| Kill switch | avd-swarm's, one for both; the brain reads it and obeys | Operations spec §4.5.1, C10 |
| Solo mode | 72-hour time-lock in place of a second person | Operations spec §9.3 |
| Grading | One judge and auditor design, shared with avd-swarm | Operations spec §4.6 |
| Runs | One run record shape for every repo | C17 |
| Upstream | Link upstream, never restate it | Decision 0011 |

## 4. The Concierge in v1 (proposed)

avd-swarm's build step 2 gives its agents one link to the brain: the Concierge as a read tool. The operations spec makes the Concierge a Tier 3 Foundry agent, which v1 doesn't build. So in v1 the Concierge is **a deterministic read tool, with no model of its own**:

- `search(question)` returns passages from the knowledge base, the family KB and the connected repos' docs (C6, C7), each with its citation (`knowledge/...#id`, `<repo>@<commit>:<path>`), the same results `Find-BrainKnowledge.ps1` gives a person.
- `facts(ids)` returns C11 (later C12) facts by register ID from the adopter's vault, with their `generatedUtc`, and only the facts asked for (C12's rule).
- It returns claims and citations, never prose, which is what avd-swarm's claim check (#18) expects on every edge. The swarm's specialist does the reasoning; the brain's Concierge agent can replace this tool at Tier 3 without changing the interface.
- It reads with a read-only identity: the public KB needs none; the vault is read through a GitHub App with `contents:read` on the vault repo only. It never reads a package or a snapshot that isn't filed.

## 5. Contradictions and gaps

| # | What | Settled as | State |
|---|---|---|---|
| B1 | The operations spec still specifies the brain's executor (`brain-execute.yml`, `brain-standing.yml`, executor identities, Tier 2, §8 levels, §10 and §11's kill switch and watchdog) behind a "superseded in part" banner | Rewrite §3.1, §4.1, §4.5, §5, §7, §10 and §11 once the why layer lands, so a later session can't build the executor from them. Until then the banner and the section notes stand | Open (after C18 merges) |
| B2 | §3.1 said "no custom MCP server", while avd-swarm keeps one open | The brain builds none; avd-swarm decides for its tool layer | Fixed here |
| B3 | §5 said the brain's budget trips `halt-all`, and listed its own watchdog Logic App | The brain's budget stops it through avd-swarm's switch (`halt-actions` for resources, `halt-agents` for tokens); no brain watchdog | Fixed here |
| B4 | §9.3 resumed after a 60-minute wait timer on a resume environment | avd-swarm's Cloud Shell reset block; no resume workflow (R6) | Fixed here |
| B5 | C9's table row said "targets as resource IDs", while the brain's agents reason over pseudonyms | Target hints from the in-tenant runtime, re-resolved live by avd-swarm | Fixed here (C9 section) |
| B6 | C8, C9 and C10 had a table row each and no section | Sections with shape and rules; each schema and its test land with the producer, as C12's do | Fixed here |
| B7 | The brain's runtime (`brain.bicep`, `brain/`, its workflows) is placed in avd-landing-zone (operations spec §4.1 and §7, landing zone decision 0012) | Conflicts with the base pair rule and with avd-landing-zone being deployment only. Default: an opt-in deployable shipped from this repo that finds the landing zone by its naming convention | Owner decision D1 |
| B8 | The Concierge is a Tier 3 agent, but avd-swarm needs it at Tier 1 | §4: deterministic read tool in v1 | Proposed here |
| B9 | EX-0003 (self-healing as a standing exception) is still written as the brain's, and second red team AX-5 is open | None in v1; afterwards, if kept, a standing exception is an avd-swarm catalog setting under its time-lock | Owner decision D5 |
| B10 | Architecture §6 listed two schemas | Lists every cross-repo format | Fixed here |
| B11 | Public text names private repos and links an outside AI knowledge base | Left to the public cleanup that owns it | Not touched here |

| # | Gap | Default |
|---|---|---|
| G1 | **Adopter repos.** One adopter could end up with four private repos: a landing zone fork (if the runtime stays there), avd-swarm's adopter repo, the vault, and the run-record companion (#37) | Two: an **estate** repo (vault, run records, episode issues; read-mostly) and avd-swarm's **adopter** repo (the write path). Keeping them apart means no drafting App with `contents:write` on the write path ever sees the vault. Owner decision D3 |
| G2 | **Tier 1 has no cost estimate**, and its exit needs 30 days of real data | Priced from the meters in spend.md format before its first deploy; the 30 days run only on the owner's go |
| G3 | **Diagnose's eval set** (red team M10) exists as a design only | Start with redacted fixtures from the landing zone's lessons, append-only |
| G4 | **The docs check is a CI dependency upward:** avd-landing-zone's and avd-current-state's `docs.yml` call this repo's reusable workflow | Pinned by SHA already; keep it advisory there, never a required check, so a brain outage can't block their PRs. Owner decision D9 |
| G5 | **General agent memory is commodity** (prior art: agent memory products, ADR tools) | Keep the brain narrow: AVD decisions with cited evidence over an estate's life. Tier 3's vector memory stays after v1 and is re-checked against what exists before it is built |
| G6 | **avd-assess methodology.** The owner wants the brain to ingest the assessment methodology from avd-assess (free, MIT), which another thread is specifying, and avd-current-state to use it offline | Placeholder only: the brain will read it as a connected source (C7) and, if it carries rules or checks, through a contract of its own once avd-assess defines its format. Not specified here |

## 6. The base pair check

| Where | What depends on what | Verdict |
|---|---|---|
| C11 | avd-current-state produces it offline with its own key; the importer is here | Down only; the collector and validator work without it |
| C14 | The landing zone's reader takes an approved manifest as optional input; the files are vendored byte copies | Down only |
| C17 | The landing zone produces run records against a vendored schema | Down only |
| C4, C5 | C4's landing zone producer is the brain's Tier 1 job; C5 tags are written by the factory's renderer | Moves with the runtime (D1); tags are inert to the landing zone |
| C6 | "Sizing defaults can start from" the knowledge base | Keep it optional: the landing zone's own defaults stay in its parameter files |
| Docs check | CI only, pinned | Advisory (G4) |
| Runtime | In avd-landing-zone today | Upward (B7, D1) |

## 7. Decisions only the owner can make

One list for both repos. Each has a default that the work follows until answered.

1. **D1 Where the brain's Tier 1 runtime lives.** Default: shipped from avd-second-brain as an opt-in deployable, not from avd-landing-zone. Needs a landing zone PR that moves decision 0012's runtime out and keeps `docs/second-brain.md` as a pointer.
2. **D2 What v1 is.** Default: avd-swarm build steps 1 to 3; the brain's Tier 1, the deterministic Concierge and the switch read.
3. **D3 Adopter repos.** Default: two private repos per adopter, estate and swarm.
4. **D4 MCP.** Default: no MCP server of our own in v1; Microsoft's Azure MCP Server for reads.
5. **D5 Self-healing (EX-0003).** Default: none in v1; revisit as an avd-swarm catalog setting after v1.
6. **D6 Policy engine.** Default: spike Microsoft's Agent Governance Toolkit offline before writing our own gate; keep observers, the layered switch and "only a person resets" on top.
7. **D7 Language.** Default: Python for avd-swarm's agent service, tool layer and guard; PowerShell for the brain's engine, Run Command scripts and everything an operator runs.
8. **D8 Well-Architected review.** Answered by the owner on 2026-10-20: consume WARA and the AVD review checklist; avd-swarm #21 and #34 here are being revised.
9. **D9 The docs check in the base pair.** Default: advisory, never required.
10. **D10 Azure SRE Agent.** The owner said on 2026-10-20 that it can cover what it covers (incident investigation, scheduled health checks, audit trail) while avd-buddy is still built. It is paid and closed, so it is an optional add-on, never a dependency of the free repos. Still open: whose approval its actions use. Default: Review mode, writes blocked by its tool access policy, and any change it suggests becomes an avd-swarm plan approved in the GitHub Environment (avd-swarm SQ11). Wiring would be both ways over MCP (avd-buddy asks it to investigate; it calls avd-swarm's read and propose tools), which is the second reason avd-swarm might publish its tool layer as MCP. Risk first: its SRE Agent Administrator role can also change its hooks and skills, so a narrower role is needed, or that role stays with a person.
