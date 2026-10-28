---
title: "Cost and spend"
summary: "Estimating, pricing and capping AVD and sandbox spend: the retail price API, auto shutdown and run-cost evidence"
topic: cost
status: partial
last_reviewed: 2026-10-28
---

# Cost and spend

What AVD and its test sandboxes cost and how spend stays capped: the retail price API, auto shutdown, budgets, and the estimate, run-cost and teardown evidence every sandbox run needs.

## Estimating

- Size in the portal, then validate and price in the preflight ([avd-landing-zone decision 0010](https://github.com/avd-ops/avd-landing-zone/blob/master/docs/decisions/0010-sizing-and-cost.md)).
- The Azure Retail Prices API gains lookalike meters with the same SKU. Match the product name as well as the SKU and meter, and print product, SKU, meter and unit when a match fails ([lesson 0025](https://github.com/avd-ops/avd-landing-zone/blob/master/docs/lessons/0025-retail-price-lookalike-meters.md)).

## Capping

- One auto-shutdown runbook, started both by a schedule and by the budget ([avd-landing-zone decision 0011](https://github.com/avd-ops/avd-landing-zone/blob/master/docs/decisions/0011-auto-shutdown.md)). *Unverified:* no lesson yet records the budget trigger in a real run.
- The landing zone's budget lives and dies with it: `Remove-AvdDemo.ps1 -IncludeLandingZone` deletes `budget-<prefix>-<environment>`, so a torn-down sandbox subscription has no spend alert at all ([Remove-AvdDemo.ps1](https://github.com/avd-ops/avd-landing-zone/blob/master/scripts/ops/Remove-AvdDemo.ps1)). Give a sandbox subscription a standing budget of its own that no teardown touches, and have the daily spend check flag a subscription without one.

## Sandbox runs

- Every sandbox run needs a cost estimate first, run-cost evidence, teardown evidence and a monthly reconciliation ([avd-swarm spend process](https://github.com/avd-ops/avd-swarm/blob/main/docs/spend.md)).
- A public lab must carry its own spend guard: a run that opens and closes through a private repo can't be run by anyone else. avd-swarm's [spend guard](https://github.com/avd-ops/avd-swarm/blob/main/spend/README.md) refuses before any deploy (unpriced line, over the run cap, month to date plus estimate over the monthly cap, a second open run) and keeps its records outside the repo.
- Azure has no hard stop on spend: a budget only alerts. Enforce caps before the run opens and check the run's due time on every resume; cap model tokens per call in the agent service, with the provider's workspace limit as the backstop.
- Cost Management lags the spend, so month to date for a cap check is billed cost plus the estimates of runs not yet settled, and a run's actual cost is settled no sooner than three days after teardown. Read it by the run's own resource group and day, so charges after the close day show up as a tail. *Unverified:* no settled run recorded yet.
- The sandbox run method (spend gate, batches, approvals, teardown evidence) ships with the landing zone and runs from Azure Cloud Shell alone ([avd-landing-zone decision 0020](https://github.com/avd-ops/avd-landing-zone/blob/master/build/decisions/0020-sandbox-runs-in-the-package.md), [operator guide](https://github.com/avd-ops/avd-landing-zone/blob/master/docs/sandbox-runs.md)). Cloud Shell ends idle sessions after about 20 minutes and its home folder is not a durable copy, so records live in the run store's `records` container, written with conditional writes (If-Match on the last ETag seen, If-None-Match for a new file), and a group's first results write is its claim: a second shell starting the same group gets a conflict before spending.
- A run ID made from the start minute (`yyyyMMdd-HHmm-<kind>`) collides when two runs start in the same minute, which a resume or a scripted batch makes likely, and the second record overwrites the first. Add a letter after the minute when the ID is taken, and order runs by their start time, not file name: PowerShell's culture-aware sort ignores hyphens, so `1705-liquidware` and `1705b-liquidware` sort the wrong way round. Found by the landing zone's SandboxBatch offline scenario, before a real run lost a record.
- A group runs once per approval: a second start would spend its estimate twice. Resuming replays finished steps from the results and reruns the interrupted one, so item steps must be safe to run twice.
- Check the sandbox before a group spends, read-only and before its claim, so a failure costs nothing and the same command runs again once fixed ([Test-AvdSandboxHealth.ps1](https://github.com/avd-ops/avd-landing-zone/blob/master/scripts/ops/Test-AvdSandboxHealth.ps1)). The leftover a new run can't get past by itself is an Entra device named exactly like a host (`<prefix><e>sh-<n>`, or a blue/green generation's ten-character prefix plus `a` or `b`): a new host of that name can't join. Call a device stale only when no VM in any subscription the identity can read carries the name (Resource Graph with no subscription list, by VM name and computer name), and report it rather than delete it. `Invoke-AzRestMethod -Uri https://graph.microsoft.com/...` reads Graph on the same Cloud Shell sign-in, with no Graph module or second sign-in.
- An unattended teardown that runs as an app identity (GitHub Actions with a federated credential) needs more than Contributor. Deleting the landing zone's policy assignments needs Resource Policy Contributor. Deleting the session hosts' Entra devices needs the Graph app role `Device.ReadWrite.All`, and the cleanup has to use the app's own Graph token (`Get-AzAccessToken -ResourceTypeName MSGraph`, then `Connect-MgGraph -AccessToken`), because there is no user to sign in. Without it, the next run's host fails to join with `0x801c0083` ([avd-landing-zone lesson 0033](https://github.com/avd-ops/avd-landing-zone/blob/master/build/lessons/0033-app-identity-graph-cleanup.md)). Found on the first unattended round trips, 2026-10-21.
- Records that several jobs commit to one git branch need a rebase-and-retry push loop. A plain `git push` after another job's commit fails with `fetch first`, and the run's results and spend record were lost that way once. Pull with `--rebase` and push again, a few times with a short wait, then fail loudly.
- Keep one sandbox's queue where its records are: in the owner's private companion repo, as one item file per waiting run plus an index generated from them that people and agents read first. A fresh Cloud Shell or any coding agent can read a file with no GitHub CLI sign-in, which issues don't allow, and git keeps the history. Before saying a run left no record, check the companion repo's copy of the run store: a 2026-10-28 run was first reported as unrecorded when its records were there all along.
