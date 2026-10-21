# AVD handbook (retired)

The handbook that used to be generated here is retired ([decision 0024](../docs/knowledge/decisions/0024-the-brain-is-the-estate-brain.md)). Its pages were built from each repo's own docs, so nothing was lost: the repos stay the source of truth, and the last generated copy is in this repo's history.

Read each repo's page on the front door instead:

| Repo | Page |
|---|---|
| avd-assess | [avd-ops.dev/docs/repos/avd-assess.html](https://avd-ops.dev/docs/repos/avd-assess.html) |
| avd-current-state | [avd-ops.dev/docs/repos/avd-current-state.html](https://avd-ops.dev/docs/repos/avd-current-state.html) |
| avd-landing-zone | [avd-ops.dev/docs/repos/avd-landing-zone.html](https://avd-ops.dev/docs/repos/avd-landing-zone.html) |
| avd-swarm | [avd-ops.dev/docs/repos/avd-swarm.html](https://avd-ops.dev/docs/repos/avd-swarm.html) |
| avd-second-brain | [avd-ops.dev/docs/repos/avd-second-brain.html](https://avd-ops.dev/docs/repos/avd-second-brain.html) |
| avd-liquidware | [its README on GitHub](https://github.com/nickprignano/avd-liquidware) |

Agents search the connected repos' lessons and decisions with `./scripts/Find-BrainKnowledge.ps1 '<query>'` after `./scripts/Sync-BrainSources.ps1`, which cites each hit as `<repo>@<commit>:<path>`. The docs consistency check (decision 0004, contract C13) stays here as part of the sweep plumbing.
