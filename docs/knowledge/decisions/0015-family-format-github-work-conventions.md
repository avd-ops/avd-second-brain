---
status: accepted
date: 2026-10-20
decision-makers: [owner]
---

# 0015. GitHub work follows the family conventions, with knowledge base PRs able to merge themselves

## Context and Problem Statement

Green PRs pile up waiting for the owner, most of them knowledge base pages that only need a skim. The family accepted a set of GitHub work conventions with auto-merge for a fixed class of low-risk PRs ([AI 0014](https://github.com/nickprignano/ai-brain/blob/main/docs/knowledge/decisions/0014-family-format-auto-merge-low-risk-prs.md)), and the owner approved its adoption in the AVD repos through handoff issues ([0014](0014-family-format-handoff-issues.md)). How do this repo and the AVD repos it feeds adopt it?

## Considered Options

- Adopt AI 0014 in each AVD repo, with auto-merge off until the owner's settings are in place
- Keep merging every PR by hand

## Decision Outcome

Chosen option: "Adopt AI 0014", because the low-risk class is decided by a workflow from the changed paths on the base branch, not by the thread that wrote the PR, and every other change still waits for the owner.

Also recorded in: [AI 0014](https://github.com/nickprignano/ai-brain/blob/main/docs/knowledge/decisions/0014-family-format-auto-merge-low-risk-prs.md), the source of truth for the low-risk class, the fixed deny list, the setup order and how to stop it.

In this repo:

- `.github/workflows/kb-auto-merge.yml` and `scripts/kb/auto_merge.py`, unchanged from ai-brain's template export. The brain has no `directives.py` yet, so the workflow skips the directive gate; `KB_PAUSED` still stops it.
- `auto_merge = "off"` and `auto_merge_paths = ["docs/knowledge/**", "llms.txt"]` in `docs/knowledge/kb.toml`. Only the family knowledge base qualifies; the brain's engine knowledge (`knowledge/**`), contracts, schemas, scripts and code never do.
- `kb-validate` runs on every PR, with no paths filter, so it can be a required check.
- The `AGENTS.md` conventions line.

In the AVD repos this KB feeds:

- avd-landing-zone takes the workflow and script unchanged, with its settings in `.claude/kb-capture.toml`. It has no knowledge base or `llms.txt`, so nothing there qualifies today; every PR still waits for the owner.
- avd-swarm takes the conventions line and the settings, but not the workflow: its Guard forbids `pull_request_target` in a public repo (`check_workflows.py`, rule W3), and it has no knowledge base for the paths to match.

### Consequences

- Good, because knowledge base PRs land on green without the owner, and the owner's review goes to decisions, contracts and code.
- Bad, because a wrong fact on a KB page can land without a human read; validation, the leak guard and gitleaks still run.
- Bad, because GitHub can't tell the owner's account from Claude's; "sessions never turn on auto-merge themselves" is a rule Claude keeps.
- Neutral, because the required checks differ by repo: only checks that run on every PR can be required, or a PR waits forever.

## More Information

Adopted through handoff issues avd-second-brain #27, avd-swarm #17 and avd-landing-zone #62. Auto-merge turns on with a separate PR per repo after the owner turns on "Allow auto-merge" and the branch ruleset.
