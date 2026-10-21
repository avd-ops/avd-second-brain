# The brain as the estate's living RAID log and tracker

Status: **proposed** ([decision 0022](knowledge/decisions/0022-the-brain-keeps-the-raid-log.md)). Spec only: no schema, function or vault change lands until the owner says yes and C18 ([PR #45](https://github.com/avd-ops/avd-second-brain/pull/45)) is merged, because this builds on it.

## 1. What the owner asked for

The owner, 2026-10-20: the brain should be the living RAID log (risks, assumptions, issues, dependencies) plus the action and decision tracker for an AVD environment, in addition to its other jobs.

**Scope (owner, 2026-10-20):** the AVD environment itself, meaning each operated estate and its environments. The family's own project RAID log (risks and actions about building these repos) is kept privately, outside this repo. The two never share a store. They line up by row format only (section 4, `uid`), so a project row can name an estate row, or the reverse, without either copying the other.

The brain already holds most of the pieces, spread out:

| Piece | Where it is | What it lacks for a RAID log |
|---|---|---|
| Decisions, with alternatives and `whyNot`, drivers, evidence, watched facts, `reviewBy`, status | C18 lifecycle record (`lifecycle/<env>.json`, [#45](https://github.com/avd-ops/avd-second-brain/pull/45)) | Nothing: it **is** the decision log. No second decision store |
| Events (build, fix, drift, incident, review) | C18 | Nothing |
| A person's disposition of each finding (Fix, Accept, Defer, with a reason code) | C23 `review.json` ([avd-current-state assessment portal spec](https://github.com/avd-ops/avd-current-state/blob/claude/project-thread-pjk7l7/docs/assessment-portal-spec.md), proposed, owned by avd-assess) | An accepted risk has no owner, review date or link to the decision that accepted it |
| Ordered remediation items | C24 `plan.json` (same spec) | No owner, due date or status, so nothing says whether an item got done |
| Findings (check outcomes) | C21 assessment report | No issue lifecycle |
| Why a change is made | avd-swarm's plan `why` block ([swarm spec §6f](https://github.com/avd-ops/avd-swarm/pull/26)) and its C10 outcome | Nothing: the outcome is the evidence that closes an action |
| Facts that reopen a decision | C18 `watch` plus `Get-LifecycleReview` | Risks and assumptions need the same trigger |

What is missing is the **register around them**: risks with a strategy, assumptions to validate, issues to resolve, dependencies to meet, and actions with an owner, a due date and a status, each linked by ID to the decision, finding, plan or event it belongs to, with a review rhythm and a page a person reads.

## 2. Prior art (checked 2026-10-20)

The family's prior-art script couldn't reach GitHub search from this session (HTTP 403), so the check was done by hand: the family KBs on disk, Microsoft Learn and a web search.

- **CAF Govern, [Assess cloud risks](https://learn.microsoft.com/azure/cloud-adoption-framework/govern/assess-cloud-risks)** defines a risk register: ID (R01, R02, gaps left), management status (open or closed), category (regulatory compliance, security, cost, operations, AI, resource management), one-sentence description with its cause, probability, impact, priority (probability times impact, impact weighted higher), level, **management strategy (mitigate, accept, avoid, transfer)**, enforcement (controls, policies, monitoring, review cadence), owner (a role or a name), closure date. Reviews are **scheduled** (quarterly to yearly) and **event-based** (an incident, a new technology, a regulation change). We take its fields and strategies as they are.
- **Azure Advisor [recommendation states](https://learn.microsoft.com/azure/advisor/advisor-azure-state-management)**: Active, Postponed (comes back after a set time), Dismissed (with a reason), Completed, where Completed is either *marked by user* or *system verified*, and a system-verified item can't be reopened. We take the split between "a person says it's done" and "evidence says it's done".
- **Well-Architected, [implementing recommendations](https://learn.microsoft.com/azure/well-architected/design-guides/implementing-recommendations)**: put review recommendations into the workload's backlog with an owner, track each until resolved, review milestones on a cadence (every four months for brownfield). [WARP DevOps tooling](https://github.com/Azure/WellArchitected-Tools/tree/main/WARP/devops#readme) (MIT) imports the CSV into Azure DevOps or GitHub issues. A ticket system is a fine **view**, but it can't be the store here: an estate's items belong in its private vault, and the brain's agents read structured, pseudonymous data only.
- **MADR** is already how this KB writes its own decisions; C18 decisions are the estate-level equivalent, so nothing new is needed for decisions.
- **RAID logs** in general: common practice (PRINCE2 and PMI templates, spreadsheets) with no widely adopted open schema. One vendor pack with a JSON Schema exists but its license isn't stated, so it is reference only.

Nothing found joins a risk register to measured facts so that a changed fact reopens a risk, or closes an action from the evidence of the change that did it. That join is what the brain adds.

## 3. Decision: a sibling record, C25, linked by ID to C18

The owner confirmed R1 (2026-10-20): one RAID log for the estate, beside the lifecycle records.

**C25 `avd-raid-log/v1`**, one file per estate in its vault, `raid/raid.json`, beside `lifecycle/<env>.json`. Decisions stay in C18 and are referenced, never copied.

Why a sibling rather than more arrays inside C18:

- **Scope.** C18 is one environment. Risks, assumptions and dependencies are often estate-wide (identity, a shared hub, a licensing assumption). A RAID item names the environments and subjects it touches.
- **Churn.** C18 is history: decisions and events are added, rarely edited. A RAID log is a working list whose statuses change every week. Keeping them apart keeps C18's diffs readable and its checks simple.
- **Fail open.** A vault with lifecycle records and no RAID log, or the reverse, works. Each reads the other only through IDs.

The alternative, extending C18 to v2 with `raid[]` and `actions[]`, was considered: cheaper while #45 is still a draft, but it ties estate-wide items to one environment and mixes history with a to-do list.

## 4. What C25 holds

One document per estate: `schema`, `estate` (`est-`), `generatedUtc`, `pins` (fact register version, brain commit), `cadence`, `lastReview`, and `items[]`. Every item shares:

| Field | Meaning |
|---|---|
| `id` | `rsk-NNNN`, `asm-NNNN`, `iss-NNNN`, `dep-NNNN` or `act-NNNN`; never reused, gaps left (as CAF does). People and links use this |
| `uid` | A [ULID](https://github.com/ulid/spec) (26 characters, sortable by time, made offline with no counter to share), fixed for the row's life. It is what another ledger cites to crosswalk to this row. It is deliberately not a GUID: the family's leak checks treat any GUID as a possible tenant or object ID and refuse it |
| `xref` | Rows in another ledger that this row relates to, as `ledger:<ULID>`, plus public family work items as `gh:<repo>#<number>` (an estate issue waiting on a landing-zone fix). IDs only: a crosswalk never copies a title or note |
| `type` | `risk`, `assumption`, `issue`, `dependency`, `action` |
| `title` | One line, at most 120 characters of the C18 note alphabet: no names, IDs, addresses or links. Harvests drop it |
| `category` | CAF's list plus AVD's: `compliance`, `security`, `cost`, `operations`, `data`, `resource`, `identity`, `network`, `performance`, `user-experience`, `capacity`, `supportability`, `vendor`, `other` |
| `scope` | `environments` (`env-`), `subjects` (`hp-`, `st-`, `sub-`, `tp-`, `persona-`), `useCases` (`uc-NN`, from C18) |
| `owner` | A role from a fixed list (`owner`, `operator`, `approver`, `architect`, `security`, `finance`, `vendor`, `other`), plus an optional `ownerKey` (`p-NN`) that the vault's private people page resolves to a person. The JSON never holds a name; agents never read the people page |
| `status`, `opened`, `updated`, `closed` | Per type below; dates `YYYY-MM-DD` |
| `reviewBy` | When a person looks again |
| `links` | IDs only, in the grammar below |
| `source` | `operator`, `review` (from C23), `plan` (from C24), `assessment` (C21), `lifecycle` (C18 warning or review), `swarm` (C10), `brain-proposal` |
| `note` | C18's note rule: 200 characters, no links, dropped by harvests |

Per type:

| Type | Extra fields | Statuses |
|---|---|---|
| **Risk** | `probability`, `impact` (`low`, `medium`, `high`), `priority` (computed, impact weighted as CAF advises, never typed), `strategy` (`mitigate`, `accept`, `avoid`, `transfer`), `triggers` (C15 fact refs whose change reopens it, as C18 `watch`) | `open`, `mitigating`, `accepted`, `closed` |
| **Assumption** | `validateBy` (date), `validatedBy` (the facts or intake answers that would confirm it, C15 refs) | `open`, `validated`, `invalidated` |
| **Issue** | `severity` (`low` to `critical`), `raisedFrom` (a finding, an incident or drift event, an unexplained change) | `open`, `in-progress`, `resolved`, `closed` |
| **Dependency** | `direction` (`inbound`: we wait on it; `outbound`: someone waits on us), `on` (`contract`, `repo`, `platform-feature`, `quota`, `vendor`, `approval`, `team`, `other`), `needBy` | `open`, `at-risk`, `met`, `broken` |
| **Action** | `due`, `for` (the RAID items, decisions or findings it serves), `doneEvidence` | `open`, `in-progress`, `blocked`, `postponed` (with `until`), `done-marked`, `done-verified`, `dropped` (with a reason code) |

**Link grammar** (extends C18's evidence references, so one parser serves both):

- `lifecycle:<env>#dec-NNNN`, `lifecycle:<env>#evt-NNNN`, `lifecycle:<env>#uc-NN`: C18
- `finding:<first 12 hex of the C21 report's SHA-256>#<checkId>`: a C21 result
- `review:<12 hex of C23>#<checkId>`: a person's disposition
- `remediation:<12 hex of C24>#<order>`: a plan item
- `plan:<planId>`: an avd-swarm plan; its C10 outcome is evidence
- `run:<runId>`: a C17 run
- C15 fact refs, `rule:`, `doc:<repo>@<commit>:<path>`, `adr:ADR-NNNN`: as C18
- another item's ID

**Rules `Test-RaidLog` checks** beyond the schema: the C14 guard over the whole file; unique IDs; every link resolves (in the log, in the named lifecycle record, or to a pinned report hash the vault holds); every cited fact is registered; a risk with strategy `accept` links an **accepted C18 decision** that has a `reviewBy` (accepting a risk is a decision, made by a role, with a date to look again); `done-verified` needs `doneEvidence` that is an event, a run or a verified plan outcome, while `done-marked` needs nothing but stays visible as unverified; a `closed` or `resolved` item has a `closed` date; an action has `due` and an owner role. **Warnings**, which are the point: an open risk with no action and no accepted decision; an overdue action; an assumption past `validateBy`; a dependency past `needBy`; an `accept` decision past its `reviewBy`; a C23 Accept row with no risk item.

## 5. How items get in (a model never decides)

The brain proposes; a person accepts. Anything the brain drafts arrives with `source: brain-proposal` and status `open` only after the person keeps it; until then it is a proposal in the review, not an item.

| From | Becomes | Who confirms |
|---|---|---|
| C23 Accept row | A risk, strategy `accept`, plus the C18 decision that accepted it (decidedBy a role, reason from C23's code, `reviewBy`) | The reviewer, in the same review |
| C23 Defer row | An action, `postponed` until a date, `for` the finding | The reviewer |
| C24 item (from a Fix row) | An action, `for` the finding, `links` the remediation item; due date set by a person | The operator |
| C21 `fail` with no C23 row yet | A proposed issue | The operator |
| C18 warning: a change no decision explains | A proposed issue (`raisedFrom` the event) | The operator |
| `Get-LifecycleReview` notice (a watched fact changed) | The decision flagged, and a proposed action to revisit it | The operator |
| A risk trigger or an assumption's `validatedBy` fact changes | The risk reopened, or the assumption proposed `validated` or `invalidated` | The operator |
| avd-swarm C10 outcome `verified` for a plan an action links | The action proposed `done-verified` with the plan as evidence; `rolled-back` reopens it | Automatic proposal, person keeps it |
| The vault's `/capture` | Any item type, drafted from the operator's own words; the JSON keeps only structure, the words stay in the vault's Markdown | The operator |

## 6. Review rhythm

CAF's two kinds, both:

- **Scheduled.** `cadence` per estate (`weekly`, `fortnightly`, `monthly`, `quarterly`; default `monthly`). `Get-RaidReview -AsOf <date>` returns, in order: overdue actions; items past `reviewBy`; accepted risks whose decision is due; assumptions past `validateBy`; dependencies `at-risk` or near `needBy`; open risks with no response; actions `done-marked` but not verified; new proposals waiting. The review is recorded as a C18 `review` event per environment touched, and `lastReview` moves.
- **Event-based.** The same function with `-Changed <facts>` (two C11 snapshots or C12 windows), after an incident event, or after a new C21 report: only the items whose triggers, `validatedBy` facts or findings moved.

Each line is a Notice, never an action: the brain may propose an avd-swarm plan through C9; avd-swarm acts (decision 0003).

## 7. The page a person reads

`Get-RaidView` (pure, offline) renders `raid/RAID.md` in the vault, regenerated on every write and never edited by hand, so the vault's Obsidian view, `/brief` and avd-buddy read the same thing:

1. **Due now**: overdue and due-this-week actions, with owner role and what they serve.
2. **Risks** by priority, with strategy and the linked decision or actions.
3. **Assumptions** to validate, **issues** open, **dependencies** at risk.
4. **Decision log**: C18 decisions across the estate's environments, newest first, with status, alternatives count and `reviewBy`, each linking back to `lifecycle:<env>#dec-NNNN`.
5. **Closed since the last review**, marked verified or marked by a person.

Names come back only in the vault's own Markdown through `ownerKey` and the people page, which stays in the customer's private repo. A later ticket view (GitHub issues in the vault repo, as WARP does) is optional and one-way, from C25 out.

## 8. What it never does

- **The foundation never reads it.** avd-landing-zone, avd-current-state and avd-assess don't read, require or wait for a RAID log. It reads what they already write (C21, C23, C24, C17 run IDs, C11). Without a brain, `review.json` and `plan.json` are still the record.
- **avd-swarm needs no change.** The link from an action to a plan lives on the brain's side (`plan:<planId>` in the action's links); the C10 outcome already carries the plan ID. If owners later want a plan to name the action it serves, that is one optional field in the plan's `why` block, and a paired swarm PR then.
- **No customer data outside the vault.** Like C18 it lives in the estate vault, never in `knowledge/`; `Test-BrainKnowledge` refuses the new ID prefixes there. A harvest sees only counts by category and type (how many accepted cost risks, how long actions take), never titles, notes or owners.
- **No second decision store, no second findings store.** Decisions are C18, findings are C21, dispositions are C23, remediation items are C24; C25 is the register and the tracker around them.

## 9. Build steps, after the owner's yes and #45

1. `contracts/schemas/raid-log.schema.json`, an example, `Test-RaidLog`, the Connectors tests (refusals for each rule in §4), and the C25 row in `docs/contracts.md`.
2. `Get-RaidReview` and `Get-RaidView`, offline, with fixtures.
3. The importers from C23 and C24, once avd-assess publishes those schemas, and from C10 outcomes.
4. The vault: `raid/` in the template, `/capture` learns the item types, `/brief` leads with **Due now**.

## 10. Questions for the owner (each has a default the build follows)

| # | Question | Default |
|---|---|---|
| R1 | A sibling C25 per estate, or more arrays in C18 per environment? | **Decided** (owner, 2026-10-20): one per estate, for the AVD environment; the project's own log is private and elsewhere |
| R2 | Owners as roles plus a private key, or a person's name in the JSON? | Roles plus `ownerKey`; names only in the vault's people page |
| R3 | Default review cadence | Monthly, plus event-based |
| R4 | Can the brain mark an action `done-verified` from a C10 outcome without a person? | No: it proposes, a person keeps it |
| R5 | A GitHub issues view of actions in the vault repo | Later, one-way, optional |
| R6 | Row IDs for crosswalks: a GUID per row, or a ULID? | ULID (`uid`), because a GUID per row trips every family leak check; the private project ledger uses the same format |
