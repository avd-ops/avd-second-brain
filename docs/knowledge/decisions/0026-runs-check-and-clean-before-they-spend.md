---
status: accepted
date: 2026-10-21
decision-makers: [owner]
---

# 0026. Runs check and clean up before they spend, and the setup is the desired state

## Context and Problem Statement

The first unattended sandbox runs on 2026-10-21 failed for reasons outside the code under test.
One deploy stopped because the run identity couldn't write policy assignments. The next stopped
at the session host's Entra join because an earlier run had left a device with the same name. A
Cost Management 429 stopped a batch at its spend gate, and a PowerShell block failed in a Cloud
Shell that had opened in bash. Each one surfaced mid-run or mid-paste, after time or money was
spent. The owner asked how to make the runs and the GitHub-to-Azure path behind them durable
and self-healing. What does every run, workflow and operator command in the family do so that
drift is caught early and one failed run never blocks the next?

## Considered Options

- Fix each failure as it happens, with a lesson
- One family rule: a health check before any spend, clean up before every deploy, retry only what
  is transient, commands that run in either shell, and the setup script as the desired state that
  a daily check compares against
- Let the run identity repair its own permissions

## Decision Outcome

Chosen option: "One family rule", because the failures were drift, not bugs: fixing each one
leaves the next one to be found the same way. Letting an identity grant itself permissions
would make its write access unbounded, so a missing grant always ends in a command for a person.

1. **A health check before any spend.** A run's first step checks everything it will need: its
   Azure role assignments, each Microsoft Graph permission it uses (with a real read, such as
   `GET /devices`), the run store, the caps and the approval. A missing piece stops the run before
   it deploys and prints the one command that fixes it. The same check runs on a daily schedule
   and keeps one health issue current, so drift shows up before anyone approves a batch.
2. **Clean up first, every run.** A deploy starts by removing what an earlier run could have left
   behind: device objects, soft-deleted vaults (recovered by the preflight's `-Fix`), stale
   resource groups with the run's prefix. A failed or cancelled run then never blocks the next
   one. Clean-up removes only what carries the run's own names or tags, and never data that
   [decision 0016](0016-never-delete-the-last-copy.md) protects.
3. **Retry only what is transient.** Throttling (429), 5xx and timeouts are retried with backoff,
   a bounded number of times, and each retry prints a line. Everything else fails at once with
   the full error ([avd-landing-zone lesson 0012](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0012-diagnose-first.md)).
4. **Operator commands run in either shell.** Cloud Shell can open in bash or PowerShell. A block
   given to an operator is one `bash -c '...'` line, or a script run as `bash <file>` or
   `pwsh -File <file>`, which both shells accept. A block that needs one shell says so in its
   first line.
5. **The setup script is the desired state.** Everything outside the repo that a pipeline
   depends on is created by one idempotent setup script: the app registration, its federated
   credential, its role assignments, its Graph app roles with admin consent, the GitHub
   environment and its variables, the run store. Rerunning it repairs any of them. The daily
   check compares what exists with what the script would create and names the difference.
6. **Healing never widens access.** A check may recover, recreate or remove what its own run
   created. It never grants a role or a permission, never consents to an app and never raises a
   cap. Those end in the printed command and the owner's own run of it.
7. **No sign-in for routine work.** Anything that repeats runs as a workflow that signs in with
   OpenID Connect, approved from chat, so it needs no device code and no Cloud Shell. A person
   signs in only for what an identity must never do for itself (rule 6): a grant, a consent, a
   cap. In Cloud Shell, scripts reuse the session that is already there (Az, and Microsoft Graph
   through `Get-AzAccessToken -ResourceTypeName MSGraph`) before they ask for another sign-in.
   Setup steps come from public repos where possible, which clone without one. Cloud Shell's
   Graph token carries only some delegated rights, so admin consent still needs a real sign-in.

### Consequences

- Good, because a failed run's leftovers no longer cause the next failure.
- Good, because missing permissions cost seconds before a deploy instead of a 12-minute deploy.
- Good, because the GitHub-to-Azure path has one definition, and rebuilding it is one command.
- Bad, because every pipeline needs a health step and a daily check, which is code to keep up.
- Bad, because clean-up by name or tag only works while runs keep their naming conventions.

## More Information

**How the GitHub-to-Azure path stays durable.** The workflow signs in with OpenID Connect: the
app registration trusts tokens from one repository and one GitHub environment through a
federated credential, so there is no secret to expire or leak. What can still break, and what
covers it:

| Can break | Shows up as | Covered by |
|---|---|---|
| Repository or environment renamed | Sign-in fails (subject mismatch) | The daily check fails at sign-in; rerun the setup script |
| A role assignment or Graph app role removed | 403 on a write or a Graph call | The health check's role list and real reads |
| App registration deleted | Sign-in fails | Restorable from Entra deleted items for 30 days; else the setup script recreates it |
| Environment variables changed | Wrong subscription or caps | The health check prints what it read |
| Run store or its lock removed | Keep paths can't be copied | The group refuses to start (decision 0016) |
| Ledger branch rewritten | Lost run records | Branch protection on the ledger branch; jobs rebase and retry their pushes |

- Microsoft Learn: [Configure a federated identity credential on an app](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-create-trust),
  [Restore a deleted application](https://learn.microsoft.com/entra/identity/enterprise-apps/restore-application),
  [Persist files in Azure Cloud Shell](https://learn.microsoft.com/azure/cloud-shell/persisting-shell-storage)
  (an ephemeral session keeps nothing, so a `gh` sign-in lasts one session).
- Related: [decision 0016](0016-never-delete-the-last-copy.md) (the run store and keep paths),
  [decision 0017](0017-never-leave-the-meter-running.md) (teardown and the meter).
