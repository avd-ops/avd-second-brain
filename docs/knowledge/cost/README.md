---
title: "Cost and spend"
summary: "Estimating, pricing and capping AVD and sandbox spend: the retail price API, auto shutdown and run-cost evidence"
topic: cost
status: partial
last_reviewed: 2026-10-20
---

# Cost and spend

What AVD and its test sandboxes cost and how spend stays capped: the retail price API, auto shutdown, budgets, and the estimate, run-cost and teardown evidence every sandbox run needs.

## Estimating

- Size in the portal, then validate and price in the preflight ([avd-landing-zone decision 0010](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/decisions/0010-sizing-and-cost.md)).
- The Azure Retail Prices API gains lookalike meters with the same SKU. Match the product name as well as the SKU and meter, and print product, SKU, meter and unit when a match fails ([lesson 0025](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0025-retail-price-lookalike-meters.md)).

## Capping

- One auto-shutdown runbook, started both by a schedule and by the budget ([avd-landing-zone decision 0011](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/decisions/0011-auto-shutdown.md)). *Unverified:* no lesson yet records the budget trigger in a real run.
- The landing zone's budget lives and dies with it: `Remove-AvdDemo.ps1 -IncludeLandingZone` deletes `budget-<prefix>-<environment>`, so a torn-down sandbox subscription has no spend alert at all ([Remove-AvdDemo.ps1](https://github.com/nickprignano/avd-landing-zone/blob/master/scripts/ops/Remove-AvdDemo.ps1)). Give a sandbox subscription a standing budget of its own that no teardown touches, and have the daily spend check flag a subscription without one.

## Sandbox runs

- Every sandbox run needs a cost estimate first, run-cost evidence, teardown evidence and a monthly reconciliation ([avd-swarm spend process](https://github.com/nickprignano/avd-swarm/blob/main/docs/spend.md)).
- A public lab must carry its own spend guard: a run that opens and closes through a private repo can't be run by anyone else. avd-swarm's [spend guard](https://github.com/nickprignano/avd-swarm/blob/main/spend/README.md) refuses before any deploy (unpriced line, over the run cap, month to date plus estimate over the monthly cap, a second open run) and keeps its records outside the repo.
- Azure has no hard stop on spend: a budget only alerts. Enforce caps before the run opens and check the run's due time on every resume; cap model tokens per call in the agent service, with the provider's workspace limit as the backstop.
- Cost Management lags the spend, so month to date for a cap check is billed cost plus the estimates of runs not yet settled, and a run's actual cost is settled no sooner than three days after teardown. Read it by the run's own resource group and day, so charges after the close day show up as a tail. *Unverified:* no settled run recorded yet.
