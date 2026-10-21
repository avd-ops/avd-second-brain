---
status: accepted
date: 2026-10-20
decision-makers: [owner]
---

# 0016. Never delete the last copy

## Context and Problem Statement

Every repo in the family has a teardown: the landing zone's cleanup, the Liquidware tier's
`Cleanup`, the Stratusphere appliances, the avd-swarm spike, the image build's template, the spend
runs. The sandbox rule says tear down right away, and the scripts did, together with whatever
held the run's data. The landing zone's cleanup deleted its Log Analytics workspace permanently,
the only copy of the run's AVD diagnostics. The run recorder's first draft removed itself and its
logs the same day (avd-landing-zone PR #72). The owner's rule (2026-10-20): never delete the last
copy of something. How does every script, workflow and agent in the family follow it?

## Considered Options

- A line in each repo's instructions only
- One family rule with the same switch, the same accepted copies and a guard in each repo
- Never delete data at all

## Decision Outcome

Chosen option: "One family rule", because the same mistake was in five repos and a line nobody
checks is how it got there. Never deleting at all fails the spend rule: a sandbox must still end
with nothing billing.

**The rule.** A script, workflow or agent step that deletes data or a resource holding data
first confirms that another durable copy exists and has been checked, or the person running it
explicitly opts in to destroying the last copy. Data means logs, diagnostics, evidence, reports,
ledgers, records, backups, assessment data, configuration and packages someone built, and user
data such as profiles.

1. **Disposable or data, decided in advance.** Each teardown lists what it removes in two groups.
   Disposable: compute, networks, private endpoints, role assignments, credentials, templates,
   anything a redeploy recreates. Data: the list above.
2. **One standard place for logs and teardown evidence, in every repo.** Every log a run
   produces (journal, transcripts, Activity Log, deployment operations, logs exported from the
   deployment's own workspaces before cleanup, the report, the hash manifest, large files) and
   its teardown evidence go into one run folder in a run store. The store lives outside the
   deployment's resource groups, so a teardown can't touch it unless the operator opts in. One
   preference, `-TeardownLogs Keep|Ask|Delete`, defaults to `Keep`, is set once on the store and
   can be overridden per teardown. `Delete` needs a checked copy first (rule 3); anything with no
   copy needs a typed confirmation. The avd-landing-zone run recorder spec (section 9.2 and R9)
   is the reference implementation.
3. **A copy counts when it is durable, outside what is being deleted, and checked.** Checked
   means the copy was read back and matched against a SHA-256 manifest (or row counts, for a
   table export) before the delete starts. Accepted copies:
   - the operator's **private companion repository**: a separate private GitHub repository the
     operator owns, never a public repo and never a product repo (scripts check its visibility
     and refuse a public one). Compressed first, each file under 50 MiB in git (GitHub warns at
     50 MiB and rejects files over 100 MiB), files up to 2 GiB each as release assets of that
     repository, with the manifest in git. The same repository can hold the operator's estate
     vault and anything else from avd-second-brain that should stay private to them;
   - a standing store outside the resource group being deleted, such as the run store (rule 2);
   - an archive downloaded to the operator's own machine, with its hashes.
   - any other target behind a copy hook that reads the copy back and returns its hashes, when
     every hash matches.
   **Files too big for free GitHub features stay where they are.** The free tooling never splits
   them. They stay in the run store (rule 2), so a teardown never removes them by accident,
   and `-TeardownLogs` decides at teardown; the default is keep.
   These never count: Cloud Shell's disk (the owner's sessions are ephemeral), anything inside the
   resource group or account being deleted, soft delete on its own, GitHub Actions artifacts
   (they expire), and public repositories or issues. Public places only ever get redacted
   output.
4. **Data inside a deployment has one opt-in, named the same everywhere: `-DiscardLastCopy`.**
   Profiles, backups, assessment data, configuration and packages live where the product puts
   them, inside what a teardown removes. Without the switch the teardown fails before it deletes
   anything and says what to copy. `-Force`, `-Yes` or a skipped prompt never imply it. An agent
   never sets it or `-TeardownLogs Delete`: an avd-swarm plan that would discard a last copy names
   it, and the person approving the plan approves that.
5. **Age moves data to a cheaper tier instead of deleting it.** Lifecycle rules go to cool, cold
   or archive, not delete. Soft delete stays on.
6. **Two exceptions, both recorded.** An erasure request for a person's data (avd-second-brain
   operations spec §9.4), and files a script regenerates from what stays in git, whose history is
   the copy.

### Consequences

- Good, because a sandbox run's evidence survives its teardown, and a lesson can be checked
  against what was actually returned.
- Good, because the preference and the switch read the same in every repo, so a reviewer can
  search for them.
- Bad, because a teardown can now fail and leave billing resources until the operator copies the
  data or opts in. Each refusal says exactly what to copy, and the disposable part of a teardown
  stays separate so it never waits on data.
- Bad, because a durable copy costs a little: cents a month for a run store on cool and cold
  tiers, and large files the operator keeps go on billing until they choose to delete them.

## More Information

In each repo:

- avd-landing-zone: the run recorder spec's R9 (PR #72) is the reference implementation, including
  the export of the Log Analytics AVD tables before cleanup and `-Remove` needing a checked
  `-CopyTo`. The image build keeps its template when the customization log could not be saved.
- avd-liquidware: `Cleanup` of the tier resource group and Stratusphere's Hub or Database need
  `-DiscardLastCopy`.
- avd-swarm: the spike's teardown and the `stop-spend` identity, which never deletes an evidence
  store.
- avd-second-brain: retention in the operations spec moves evidence and episodes to colder tiers
  instead of deleting them.
- avd-ops: the plain-language statement for operators.
- The private repos follow the same rule in their own PRs.
