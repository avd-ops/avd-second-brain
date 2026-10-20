# Decision records

Short records of choices that shape this knowledge base and the work it covers. One file per
decision, numbered in order, in [MADR 4](https://adr.github.io/madr/) format. Copy
[template.md](template.md) to add one. A decision stays `proposed` until the maintainer says yes.
A reversed decision gets a new record, and the old one is marked *Superseded by NNNN*. Each KB in
the family numbers its own decisions; refer to a sibling's as `<project> 0012`, with a link.

This repo's earlier decisions (0001 to 0005) were moved here from `docs/decisions/` and converted
to MADR 4 without changing what they decided. Decisions paired with avd-swarm keep a "Pair:" line
under More Information, and decisions shared with a sibling KB say "Also recorded in".

<!-- BEGIN GENERATED: decision-index (from front matter; run scripts/kb/build.py) -->
| # | Decision | Status |
|---|---|---|
| [0001](0001-one-brain-for-the-avd-lifecycle.md) | One brain for the AVD lifecycle, in its own repository | Accepted |
| [0002](0002-knowledge-base.md) | The knowledge base: reviewed knowledge in Git, no customer data | Accepted |
| [0003](0003-brain-thinks-swarm-acts.md) | The brain is the intelligence layer; avd-swarm is the actor and control layer | Accepted |
| [0004](0004-docs-consistency.md) | Docs consistency: the brain checks and generates, avd-swarm drafts | Proposed |
| [0005](0005-one-schema-registry-and-fact-register.md) | One schema registry and one fact register for every repo | Proposed |
| [0006](0006-family-kb-format.md) | Adopt the family KB format at docs/knowledge/, beside the engine's knowledge/ | Accepted |
| [0007](0007-python-family-layer-powershell-engine.md) | Python for the family layer, PowerShell for the engine | Accepted |
| [0008](0008-learned-knowledge-stays-where-it-happened.md) | Learned knowledge stays where it happened; this KB links and watches | Accepted |
| [0009](0009-family-format-stronger-leak-check.md) | Family format: a stronger leak check and reviewed model-drafted entries | Proposed |
| [0010](0010-family-model-selection-convention.md) | Follow the family's model-selection convention, as one of its four pilot projects | Proposed |
| [0011](0011-family-format-upstream-sources.md) | Family format: link to upstream sources of truth, check against them, and give back | Proposed |
| [0012](0012-family-format-project-lanes.md) | Family format: project lanes, referrals and a no-HCL guard for the AVD repos | Proposed |
| [0013](0013-family-format-enforced-kb-capture.md) | Enforce knowledge capture with a thread closeout, a Stop hook and a PR check, as an AVD pilot | Accepted |
| [0014](0014-family-format-handoff-issues.md) | Handoffs between Claude projects go through a `handoff` issue in the receiving repo | Accepted |
| [0015](0015-family-format-github-work-conventions.md) | GitHub work follows the family conventions, with knowledge base PRs able to merge themselves | Accepted |
| [0019](0019-recovery-runs-through-the-swarm.md) | Basic recovery testing and failover run through avd-swarm; the brain judges what the results mean | Proposed |
| [0022](0022-the-brain-keeps-the-raid-log.md) | The brain keeps each estate's RAID log and action tracker, beside the lifecycle record | Proposed |
| [0023](0023-family-format-best-open-source-or-build.md) | Adopt an outside tool only when it is the best and open source; otherwise build our own | Accepted |
<!-- END GENERATED: decision-index -->
