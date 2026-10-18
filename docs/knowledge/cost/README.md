---
title: "Cost and spend"
summary: "Estimating, pricing and capping AVD and sandbox spend: the retail price API, auto shutdown and run-cost evidence"
topic: cost
status: partial
last_reviewed: 2026-10-18
---

# Cost and spend

What AVD and its test sandboxes cost and how spend stays capped: the retail price API, auto shutdown, budgets, and the estimate, run-cost and teardown evidence every sandbox run needs.

## Estimating

- Size in the portal, then validate and price in the preflight ([avd-landing-zone decision 0010](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/decisions/0010-sizing-and-cost.md)).
- The Azure Retail Prices API gains lookalike meters with the same SKU. Match the product name as well as the SKU and meter, and print product, SKU, meter and unit when a match fails ([lesson 0025](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0025-retail-price-lookalike-meters.md)).

## Capping

- One auto-shutdown runbook, started both by a schedule and by the budget ([avd-landing-zone decision 0011](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/decisions/0011-auto-shutdown.md)). *Unverified:* no lesson yet records the budget trigger in a real run.

## Sandbox runs

- Every sandbox run needs a cost estimate first, run-cost evidence, teardown evidence and a monthly reconciliation ([avd-swarm spend process](https://github.com/nickprignano/avd-swarm/blob/main/docs/spend.md)).
