---
status: accepted
date: 2026-10-19
decision-makers: [owner]
---

# 0014. Handoffs between Claude projects go through a `handoff` issue in the receiving repo

## Context and Problem Statement

Work that starts in one Claude project often has to continue in another, and until now the owner pasted the prompt across and remembered what it waited on. The family accepted handoff issues (the 2ndbrain format). Does this repo receive handoffs that way?

## Considered Options

- Receive handoffs as `handoff` issues, with the session-start hook and a daily check
- Keep pasting prompts by hand

## Decision Outcome

Chosen option: "Receive handoffs as `handoff` issues", because this repo is where the AVD project already looks, and an issue carries the prompt, what it waits on and the report back.

The issue shape is the 2ndbrain format's [handoff template](https://github.com/nickprignano/2ndbrain/blob/main/.github/ISSUE_TEMPLATE/handoff.md).

In this repo:

- `.github/ISSUE_TEMPLATE/handoff.md`, unchanged from [2ndbrain](https://github.com/nickprignano/2ndbrain). It applies `handoff-proposed`; a handoff is live only when the owner adds `handoff` by hand, and projects never add it themselves.
- The `handoff` and `handoff-proposed` labels, created by `kb-freshness`.
- A `SessionStart` hook in `.claude/settings.json` runs `scripts/kb/handoffs.py session-start`, which lists the open handoff issues the owner's account opened. It never fails a session.
- The `AGENTS.md` line: check open `handoff` issues before starting work.
- One daily scheduled task in the AVD project, "AVD handoff check", lists the open `handoff` issues in avd-second-brain, avd-swarm and avd-landing-zone, for days no session opens a repo.

### Consequences

- Good, because a handoff no longer depends on the owner relaying it.
- Bad, because GitHub can't tell the owner's label from a project's; approval rests on Claude keeping the rule.
- Neutral, because a handoff never overrides this repo's guardrails, its `AGENTS.md` or the owner's word.

## More Information

First use: the handoff that adopted [0013](0013-family-format-enforced-kb-capture.md) and this decision (issue #22).
