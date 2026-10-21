# Working in this vault

This repository is the organisation's second brain for its Azure Virtual Desktop estate.
It holds real tenant data. Never copy its content into a public place.

## Where things are

- `README.md` — home page. The generated block lists every environment and recent activity.
- `environments/<name>/README.md` — overview of one subscription. Human notes live outside
  the `<!-- brain:generated -->` markers.
- `environments/<name>/timeline.md` — every ingested run, newest first.
- `environments/<name>/findings.md` — open validator FAIL/WARN findings with first-seen dates, and recently resolved ones.
- `environments/<name>/drift/` — what changed between two inventory snapshots.
- `environments/<name>/snapshots/` — condensed facts from each run (`.md` to read, `.json` for tooling).
- `decisions/`, `runbooks/`, `lessons/` — human knowledge. Front matter is defined in `_templates/`.
- `lifecycle/<environment>.json` — the environment's lifecycle record (`avd-lifecycle-record/v1`, avd-second-brain contract C18): its use cases, the decisions about it with their alternatives, and the events that carried them out, in pseudonyms. It is the "why" the brain's agents read; an ADR here is the same decision in full, with names.
- `.brain/` — ingest state. Do not edit by hand.

## Answering questions

1. Prefer evidence over recollection: check `findings.md`, the latest snapshot and the timeline before answering.
2. Always cite the note path and the snapshot date you relied on. Say when the newest evidence is old.
3. If a finding has a runbook (`resolves-checks` front matter), point to it.
4. If the vault cannot answer, say so and suggest which run or note would.
5. For "why is it like this?", start from the lifecycle record: the decision in force, what else was considered and why not, and the event that carried it out. Cite the decision (`lifecycle:<environment>#dec-NNNN`) and its ADR.

## Writing notes

- Never edit inside `<!-- brain:generated:start -->` / `<!-- brain:generated:end -->`, or any file under `drift/`, `snapshots/` or `.brain/`. The ingest script owns them and will overwrite your change.
- New notes start from `_templates/`. File names are kebab-case; decisions are `ADR-NNNN-short-title.md` with the next free number.
- Accepted decisions are immutable: supersede them with a new ADR.
- When you capture a decision, also draft its lifecycle record entry (`lifecycle-id` in the ADR's front matter): the chosen value, at least one alternative with a reason category, the drivers, and no names. A person reviews it before it is committed.
- Link the environment, finding or decision a note relates to.
- Add new terms to `glossary.md`.
