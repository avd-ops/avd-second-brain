# avd-second-brain v1 completeness review

- **Date:** 2026-10-20. Reviewed `main` at `6f0a199` and the open drafts that change the specs: #29 (claims on every edge), #34 (Well-Architected sources), #37 (decisions 0016 and 0017), #40 (C17 recovery use case), #41 (decision 0018), the recovery decision 0019 and the "why layer" work (C18, decision 0020). Paired with [avd-swarm's v1 review](https://github.com/nickprignano/avd-swarm/blob/main/docs/v1-review.md).
- **Status:** Proposed, ready to lock once the owner answers §7 (each decision has a default the work follows). Red-teamed on 2026-10-20: findings V1-1 to V1-38, with where each landed, in [avd-swarm's v1 review §8](https://github.com/nickprignano/avd-swarm/blob/main/docs/v1-review.md#8-red-team-of-the-v1-specs-2026-10-20). Offline review only: nothing was deployed, run or spent.
- **The brain's purpose** (the why layer: use cases and decisions over an environment's whole life) is being written by the "why layer" work (C18, decision 0020). This review doesn't restate it; it checks that the rest of the specs are complete and consistent around it.

## 1. What v1 is (proposed)

| Already built (offline) | v1 adds | After v1 |
|---|---|---|
| The knowledge base and its guard, the family KB, the vault, C1 to C7, C11 importer, C13 docs check, C14 checks, C15 register, C17 schemas | **Tier 1 (Notice):** detections, the scheduled preflight job, pseudonymized episode issues, a Claude Code diagnosis, the weekly digest, its budget | Tier 3 (episodic memory, vector search, Foundry agents, Retro and Evolve) |
| | **A deterministic Concierge** that avd-swarm's agents call as a read tool (§4) | C9 proposals, and C8 exports from avd-swarm's Improve |
| | **C10's switch read:** Tier 1's diagnosis workflow reads avd-swarm's flag first and stops (or the brain's own flag without a swarm, D13) | C10's outcomes, standing exceptions (EX-0003), if they survive decision 0003 (D5) |
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

avd-swarm's build step 2 gives its agents one link to the brain: the Concierge as a read tool. The operations spec makes the Concierge a Tier 3 Foundry agent, which v1 doesn't build. So in v1 the Concierge is **a deterministic read service, with no model of its own, and it is brain code** (red team V1-11):

- `search(question)` returns passages from the knowledge base, the family KB and the connected repos' docs (C6, C7), each with its citation (`knowledge/...#id`, `<repo>@<commit>:<path>`), the same results `Find-BrainKnowledge.ps1` gives a person, served from a synced `.sources/`.
- `facts(ids)` returns C11 (later C12) facts by register ID, with their `generatedUtc`, and only the facts asked for (C12's rule). It refuses unknown IDs and IDs the register still marks `proposed`.
- It returns claims and citations, never prose, which is what avd-swarm's claim check (#18) expects on every edge. The swarm's specialist does the reasoning; the brain's Concierge agent can replace this service at Tier 3 without changing the interface.
- **Where it runs and what it reads.** It lives in this repo and runs in the brain's deployable (a small HTTP function) with the brain's identity. `facts` reads a **facts-only store** (a blob container, or a separate private repo, that holds `facts/<estate>/` only, written by `Import-CurrentStateFacts.ps1`), never the estate repo, whose raw C1 packages hold names, IDs and IPs. avd-swarm's tool layer calls it over HTTPS with Entra auth and holds no GitHub or storage credential for any brain store (avd-swarm spec §6d).
- **Step 2 exit test:** `facts(ids)` returns only the IDs asked for, refuses unknown and `proposed` IDs, and no swarm identity can read the estate repo or the facts store.

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
| B11 | Public text names private repos and links an outside AI knowledge base | Owner decision D17; default: apply decision 0018's cleanup now, in that cleanup's PR set | Owner decision D17 |
| B12 | C10 said the switch read applies from v1 while avd-swarm's step 2 said "no C10" (V1-7) | The switch read is v1 (step 2); outcomes, C8 and C9 are step 4 | Fixed here (C10) |
| B13 | C10 said the brain's model calls use avd-swarm's metered client, but Tier 1's Diagnose is Claude Code in Actions (V1-8) | Diagnose's first step reads the flag and exits; capped by max turns and a workspace limit; the shared client comes at Tier 3 as a pinned package | Fixed here (C10) |
| B14 | C10 outcomes would bring resource IDs, parameters and approvers into pseudonym-only stores (V1-12) | The subscriber filters on ingest: pseudonymized `targets`, no parameters or approvers; GQ4 closed (never UPNs) | Fixed here (C10) |
| B15 | Five lines told Tier 1 to build the brain's own switch, watchdog and `halt-all` budget (V1-19) | Tier 1 reads the swarm's flag; its budget calls `trip`, or notifies without a swarm | Fixed here (operations spec §3.1, §4.1, §5, §11, §12) |
| B16 | C8's grading `window` was finer than its period; SQ9 had no owner (V1-31) | Counts per period; this repo owns the topic vocabulary | Fixed here (C8) |

| # | Gap | Default |
|---|---|---|
| G1 | **Adopter repos.** One adopter could end up with four private repos: a landing zone fork (if the runtime stays there), avd-swarm's adopter repo, the vault, and the run-record companion (#37) | Two: an **estate** repo (vault, run records, episode issues; read-mostly) and avd-swarm's **adopter** repo (the write path). Keeping them apart means no drafting App with `contents:write` on the write path ever sees the vault. Owner decision D3 |
| G2 | **Tier 1 has no cost estimate**, and its exit needs 30 days of real data (V1-34) | Priced from the meters in spend.md format (Container Apps job, alert rules, Blob, the diagnosis workflow's tokens) before its first deploy, against the owner's sandbox landing zone at a pinned commit; the 30 days run only on the owner's go |
| G3 | **Diagnose's eval set** (red team M10) exists as a design only | Start with redacted fixtures from the landing zone's lessons, append-only |
| G4 | **The docs check is a CI dependency upward:** avd-landing-zone's and avd-current-state's `docs.yml` call this repo's reusable workflow | Pinned by SHA already; keep it advisory there, never a required check, so a brain outage can't block their PRs. Owner decision D9 |
| G5 | **General agent memory is commodity** (prior art: agent memory products, ADR tools) | Keep the brain narrow: AVD decisions with cited evidence over an estate's life. Tier 3's vector memory stays after v1 and is re-checked against what exists before it is built |
| G6 | **avd-assess methodology.** avd-assess is *what it should be, and why*, beside the landing zone (*how it is built and changed from here*) and avd-current-state (*what is there now*) (operations spec §3.0). The owner wants the brain to ingest the assessment methodology from avd-assess (free, MIT), which another thread is specifying, and avd-current-state to use it offline | Placeholder only: the brain will read it as a connected source (C7) and, if it carries rules or checks, through a contract of its own once avd-assess defines its format. Not specified here |

## 6. The base pair check

| Where | What depends on what | Verdict |
|---|---|---|
| C11 | avd-current-state produces it offline with its own key; the importer is here | Down only; the collector and validator work without it |
| ARI (D18) | avd-current-state wraps ARI as an opt-in step for inventory and diagrams | Down only: ARI is a tool the pair calls, never required by the collector, the validator or C11 |
| C14 | The landing zone's reader takes an approved manifest as optional input; the files are vendored byte copies | Down only |
| C17 | The landing zone produces run records against a vendored schema | Down only |
| C4, C5 | C4's landing zone producer is the brain's Tier 1 job; C5 tags are written by the factory's renderer | Moves with the runtime (D1); tags are inert to the landing zone |
| C6 | "Sizing defaults can start from" the knowledge base | Keep it optional: the landing zone's own defaults stay in its parameter files |
| Docs check | CI only, pinned | Advisory (G4) |
| Runtime | In avd-landing-zone today | Upward (B7, D1) |
| Network | Two `/27` subnets in the spoke's range; hub firewall rules for the job (V1-20) | Upward. Default: the brain's own VNet or a peering; firewall needs documented as the pair's own optional feature (D14) |
| Monitoring | "Extend the DCR with FSLogix event IDs" (V1-20) | Upward. Default: the brain deploys its own DCR and an additional association (D14) |
| Pseudonym key | Two secrets in the landing zone's Key Vault (V1-13, V1-20) | Upward. Default: the brain's own Key Vault (D12) |
| State line | `stage: playbook` added to the landing zone's state line and `portal-core.js` (V1-20) | Upward. Default: no change there; the brain writes its own run records |
| Parameter and repo | `AVD_BRAIN_TIER` as a landing zone parameter; the brain run from a private fork of the landing zone (V1-20) | Upward. Default: the brain deployable's own parameter; the adopter's estate repo (G1, D3) |
| Pair CI | Docs check and `kb-capture` follow this repo (V1-23) | Advisory, never required (D9, D15) |
| Kill switch role removal | avd-swarm's switch could remove the landing zone's deploy identity's roles (V1-15) | Down only once limited to agent principals (avd-swarm governance §2.3) |

## 7. Decisions only the owner can make

One list for both repos. Each has a default that the work follows until answered. D11 to D17 came from the red team; D18 came later and is decided.

1. **D1 Where the brain's Tier 1 runtime lives.** Default: shipped from avd-second-brain as an opt-in deployable, not from avd-landing-zone. Needs a landing zone PR that moves decision 0012's runtime out and keeps `docs/second-brain.md` as a pointer.
2. **D2 What v1 is.** Default: avd-swarm build steps 1 to 3; the brain's Tier 1, the deterministic Concierge and the switch read.
3. **D3 Adopter repos.** Default: two private repos per adopter, estate and swarm.
4. **D4 MCP.** Default: no MCP server of our own in v1; Microsoft's Azure MCP Server for reads.
5. **D5 Self-healing (EX-0003).** Default: none in v1; revisit as an avd-swarm catalog setting after v1.
6. **D6 Policy engine.** Default: spike Microsoft's Agent Governance Toolkit offline before writing our own gate; keep observers, the layered switch and "only a person resets" on top.
7. **D7 Language.** Default: Python for avd-swarm's agent service, tool layer and guard; PowerShell for the brain's engine, Run Command scripts and everything an operator runs.
8. **D8 Well-Architected review.** Answered by the owner on 2026-10-20: consume WARA and the AVD review checklist; avd-swarm #21 and #34 here are being revised.
9. **D9 The docs check in the base pair.** Default: advisory, never required.
10. **D10 Azure SRE Agent.** The owner said on 2026-10-20 to use it for what it covers (investigations, scheduled health checks) while avd-buddy is still built. Designed in avd-swarm spec §3a: an optional add-on, never a dependency of the free repos; avd-buddy calls it over MCP as a Standard User; its own identity is made read-only (its default Monitoring Contributor removed); its fixes come back as avd-swarm plans approved in the GitHub Environment, never through its Approve button. Still open: its cost (unpriced, a sandbox trial waits on an estimate and the owner's go) and whether the kill switch also stops it.
11. **D11 Azure SRE Agent's residual risk** (V1-1, V1-2). The kill switch stops our calls to it, not SRE Agent itself. Default: accept that, with its identity held read-only by an Azure Policy deny on role assignments, `halt-all` on any write by it, and its Administrator role on a break-glass account only. The alternative is keeping it out of any subscription avd-swarm manages.
12. **D12 Where the pseudonym key lives** (V1-13). Default: the brain's own Key Vault; avd-swarm's gate reads the `resources` secret only, to check a C9 proposal's targets. Nothing goes into the landing zone's Key Vault.
13. **D13 The brain without avd-swarm** (V1-9). Default: the brain creates its own switch flag that a person sets from Cloud Shell; the swarm's flag wins when both exist. The alternative is that a brain without a swarm never calls a model.
14. **D14 Take the brain out of the landing zone** (V1-20, with D1). Default: retire decision 0012's placement and, with it, `AVD_BRAIN_TIER`, the DCR edit, the spoke subnets, the Key Vault secrets and `stage: playbook` in the pair.
15. **D15 Brain-dependent checks in the pair's repos** (V1-23). Default: never required.
16. **D16 The failover identity's role-assignment write** (V1-27, avd-swarm recovery Q1). Default: failover stays a Cloud Shell block, and the identity stays out of identities.md, until answered. Recovery is after v1 either way.
17. **D17 Public text naming a private project** (V1-35, B11). Default: apply decision 0018's cleanup now, rather than after v1.
18. **D18 Inventory, diagrams and ARI in avd-current-state.** Decided by the owner on 2026-10-20, in steps, ending here:
    - **Inventory is our own.** avd-current-state's collector reads Azure Resource Graph, saves the full objects, and rebuilds its existing datasets from the same rows, keeping their file names and columns, so the validator and C11 keep reading what they read today. No outside inventory tool is a dependency. The neighbors checked ([microsoft/ARI](https://github.com/microsoft/ARI), the AzureScout AVD module, documenter-azure-azurevirtualdesktop) produce Excel, HTML or PDF with real names, and none produces a redacted, contract-shaped snapshot. If a better one turns up, it is weighed against the same bar.
    - **Diagrams are Mermaid with Azure icons,** written by avd-current-state from the pseudonymized rows. Still to check: the Azure icon set's terms of use, and whether GitHub's Mermaid renderer loads an icon pack (if not, icons show only where avd-ops renders the diagram).
    - **The rule behind it** is now a family convention, [decision 0023](knowledge/decisions/0023-family-format-best-open-source-or-build.md): adopt an outside tool only when it is the best at our job and open source; otherwise build our own.
    - **ARI is prior art, not a dependency.** Its per-type coverage is the parity checklist the collector and diagram have to meet, and what we add (redaction that keeps every `/` segment of an ARM ID, an AVD overlay, stable output) can be offered upstream, only with the owner's yes. The collector, the validator and C11 never require it.
