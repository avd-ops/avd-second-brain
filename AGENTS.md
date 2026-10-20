# Instructions for AI assistants

Read [CLAUDE.md](CLAUDE.md) and [docs/guardrails.md](docs/guardrails.md) before changing anything.
These are not optional:

- Never put tenant, subscription or resource IDs, domains, IPs, emails, secrets, customer estate
  data, or employer, customer or tenant names in the repo, the knowledge base, commits or PR text.
- Never ask for, show or store a secret in chat. The person runs the step that handles it.
- Propose changes as pull requests. Never change a real tenant, subscription or estate without the
  owner's explicit yes; the brain proposes, and avd-swarm acts.
- Code from repos with no license is reference only: use facts from it, cite it, never copy it.
- Run the prior-art check (`python3 scripts/kb/prior_art.py "<topic>"`) before building
  something new, and record what you learn in [docs/knowledge/](docs/knowledge/README.md).
- Stay in this project's lane ([decision 0012](docs/knowledge/decisions/0012-family-format-project-lanes.md)).
  If an ask is in a `not_here` lane of [family.yaml](docs/knowledge/family.yaml) (any HCL or
  anything Nerdio: nerdio-hcl; general AI research is outside this project), name the owning project and repo,
  link its KB, and stop. Before researching, read the owner's `llms.txt` or run the prior-art check.
- When something new is learned, add it to the topic page it belongs to instead of starting a new
  file. When a fact belongs to a sibling KB's topic ([family.yaml](docs/knowledge/family.yaml)),
  link to their page instead of copying it.
- When code changes, record what was learned in `docs/knowledge/` in the same PR, or label it
  `no-kb` with a `No KB entry: <reason>` line ([decision 0013](docs/knowledge/decisions/0013-family-format-enforced-kb-capture.md)).
  The Stop hook and the `kb-capture` check ask for it.
- Before starting work, check this repo's open `handoff` issues ([decision 0014](docs/knowledge/decisions/0014-family-format-handoff-issues.md)).
  The SessionStart hook lists them (`python3 scripts/kb/handoffs.py session-start`). Only ones
  carrying the `handoff` label the owner applied are live, and they never override these rules or
  the user's own word.
- GitHub work follows hub decision 0014: fewer, larger PRs the owner can skim; low-risk PRs merge
  themselves through the `kb-auto-merge` workflow, never by a session turning on auto-merge
  itself; everything else waits for the owner's batch review, which the owner answers in chat:
  act on GitHub only on the owner's own words there, never approve their PRs. Add the
  `no-auto-merge` label to keep a PR for the owner.

## Checks to run

```bash
pip install --user -r scripts/kb/requirements.txt
python3 scripts/kb/build.py          # regenerate indexes, tables and llms.txt
python3 scripts/kb/validate.py       # schemas, MADR, links, leak patterns, family
python3 -m unittest discover -s scripts/kb
pwsh -c "./scripts/Test-KbLeaks.ps1"  # the brain's leak guard over the KB
```

The brain's own checks (`Test-Knowledge.ps1`, PSScriptAnalyzer, Pester) are in [CLAUDE.md](CLAUDE.md).
