---
status: proposed
date: 2026-10-19
decision-makers: [owner]
---

# 0012. Family format: project lanes, referrals and a no-HCL guard for the AVD repos

## Context and Problem Statement

The owner runs separate Claude projects over one family of repos: AVD (avd-landing-zone and the
repos around it, native Azure, Entra and Microsoft 365 automation, with Liquidware as the only
upgrade), Nerdio (nerdio-hcl, everything Nerdio, built with Terraform, Packer and other
open-source tools), Liquidware (product knowledge and real-user assessments) and AI (ai-brain).
Much of the ground overlaps, and the hard line between AVD and Nerdio is the toolchain: no HCL in
the avd-landing-zone ecosystem. `family.yaml` says what each KB `owns`, but nothing says what a
project must not build, which Claude project an ask belongs to, or checks either. Two costs
follow: tokens spent building something in the wrong repo, and tokens spent re-researching what a
sibling already learned. The guardrails also still said "Azure-native, GitHub, HashiCorp and open
source first", which invites HCL into the AVD repos. How should each project recognize work that
belongs to another, refer it, and reuse the other's prior art?

## Considered Options

- A sentence in each project's instructions and CLAUDE.md only
- Lanes in `family.yaml` (`claude_project`, `not_here` with owner, keywords and file globs),
  generated into the KB README and `llms.txt`, checked by `validate.py`, `freshness.py` and
  `prior_art.py`, plus the sentence in each CLAUDE.md and project instructions
- One shared boundaries document every repo vendors

## Decision Outcome

Chosen option: "Lanes in `family.yaml`", because the family already reads each other's
`family.yaml`, so lanes kept there are one source the checks and the assistants both read, with no
new file to keep in sync.

- **Fields (optional, format v1 compatible).** `claude_project` names the Claude project doing a
  project's work. `builds_in` lists the repos it builds in. `not_here` lists work it never does,
  each with `topic`, `owner` (a family id), optional `keywords` and optional `files` globs.
- **Refer, don't build.** An assistant whose ask falls in a `not_here` lane stops, says which
  project and repo own it (link the owner's KB page), and does nothing else on it. Shared ground,
  such as AVD itself, stays in both lanes; the toolchain decides where it is built.
- **Read before researching.** Before researching a topic, read the owner's `llms.txt` (one file
  that lists every page) or run `prior_art.py`, which now prints the owning project first when the
  query matches a lane's keywords. Reuse what is there by linking it; record only what is new.
- **No HCL in the AVD repos.** `validate.py` fails on a tracked file matching a `files` glob of
  this KB's own lanes (`*.tf`, `*.tfvars`, `*.tf.json`, `*.hcl`, `*.pkr.json`).
  avd-landing-zone and avd-swarm run the same check in CI; avd-liquidware adds it with its own
  copy of the family code. Guardrail 5 now reads "Azure-native, GitHub and open source", and for
  the AVD repos means Bicep, PowerShell and native Azure, Entra and Microsoft 365 tooling.
- **Agreement.** `freshness.py --family` flags when our row for a sibling differs from the
  sibling's own row, when the sibling's row for us differs from ours (`repo`, `kb_path`, `owns`,
  `claude_project`), and when two KBs both claim to own the same topic.

### Consequences

- Good, because a wrong-repo ask is caught by the assistant reading CLAUDE.md, by the prior-art
  check, and by CI if HCL slips in anyway.
- Good, because each project's prior art is one `llms.txt` read away, not a fresh research pass.
- Bad, because keywords are coarse: a lane hint is a prompt to check, never a verdict.
- Neutral, because the siblings adopt the fields through the usual family-format path; until they
  do, the freshness check lists their rows as differing.

## More Information

- Owner's rule (2026-10-18): Liquidware is the only partner; Nerdio is a separate project built on
  HCL and open-source tools, connected through shared interfaces, never a dependency.
- The AVD project builds avd-liquidware's deployment tooling; Liquidware product knowledge and
  assessments with real users belong to the Liquidware project.
- Format source: ai-brain (its decision 0007) adopts this first; nerdio-hcl and avd-liquidware
  follow, then every `family.yaml` bumps `format_version` together.
- Separate from ai-brain's knowledge-capture closeout decision.
