---
status: accepted
date: 2026-10-20
decision-makers: [owner]
---

# 0017. Never leave the meter running without an opt-in

## Context and Problem Statement

The sandboxes are paid for out of pocket. Teardown stops most of the bill, but not all of it.
The demo host pool isn't covered by the landing zone's auto shutdown. A NAT Gateway, a Premium
file share, Bastion, a Stratusphere Hub with its Marketplace meter, and Defender plans bill
whether anyone is using them or not. Some charges are outside any resource group: Microsoft 365
licenses and trials, and Marketplace SaaS offers billed through the subscription, which deleting
resources doesn't cancel. The owner's rule (2026-10-20): never leave the meter running without
an explicit opt-in. How does every script, workflow and agent in the family follow it, alongside
[decision 0016](0016-never-delete-the-last-copy.md)?

## Considered Options

- Rely on the budget alert and the monthly statement
- One family rule: stopped or removed by default, an opt-in with an expiry to keep anything
  billing, a check that lists what still bills, and a record of every recurring commitment
- Block anything that bills between runs

## Decision Outcome

Chosen option: "One family rule", because a budget alert fires after the money is spent, and
blocking everything between runs would also stop the run store, which decision 0016 keeps on
purpose.

**The rule.** Anything that bills by time or use is removed, stopped or on an automatic shutdown
by default at the end of a run. It keeps billing only if the operator opts in, with an expiry or
a recorded reason.

1. **Three classes, decided in advance.**
   - *Run resources*: VMs, hosts, Bastion, firewalls, gateways, NAT, Premium shares, appliances,
     agents. Teardown removes them, or a schedule stops them, by default.
   - *Standing resources* that are kept on purpose because they are cheap and hold what decision
     0016 protects: the run store, the subscription budget. Each is recorded with its monthly cost
     and why it stays.
   - *Recurring commitments* that teardown can't reach: Microsoft 365 licenses and trials (billed
     in the Microsoft 365 admin center), Marketplace SaaS offers (billed through the subscription
     and cancelled under Marketplace, not by deleting a resource group), reservations, plans that
     renew. Marketplace VM images and managed applications bill with their resource, so they are
     run resources.
2. **One opt-in, the same everywhere: `-KeepRunning <until>`.** It takes an expiry (a date and
   time) or a reason, written to the run's record. Without it, the end of a run removes or stops
   what bills. `-Force` never implies it. An agent never sets it: an avd-swarm plan that keeps
   something billing past its run names it, and the approving person accepts it.
3. **Every run resource that keeps running has a timer.** Hosts and VMs get a daily shutdown or
   the landing zone's auto shutdown. A time-boxed appliance, like the Stratusphere assessment
   window, carries its end date as a tag, and checks fail after it.
4. **A check lists what still bills.** At teardown, and in the daily spend check, list every
   resource still billing in the sandbox with its cost per day, and every recurring commitment
   with its renewal or trial-end date. An opt-in that has expired is a failure.
5. **A backstop that doesn't depend on anyone remembering.** Every sandbox subscription has a
   standing budget with alerts. The landing zone's budget action locks and stops its hosts. A
   preflight warns when a sandbox has no budget.
6. **Recurring commitments are recorded when they start, and no script ever buys one.** The
   record has what it is, where it's billed, the price, the renewal or trial-end date and the
   exact cancel path, including any cancel window. Microsoft 365 business subscriptions give a
   prorated refund only within 7 days of the start or renewal on an MCA billing account, and
   turning off recurring billing ends a subscription only at the end of its term. A trial converts
   to paid unless recurring billing is off. Marketplace SaaS gives a full refund only within 72
   hours, and an auto-renew switch doesn't pause a trial. Checks warn before each date.
7. **Estimates and evidence go through the spend ledger.** The run's estimate counts the standing
   and recurring lines separately from the run, and the teardown evidence lists what was left
   billing and why.

### Consequences

- Good, because nothing bills by accident between runs, and what bills on purpose has a reason
  and an end.
- Good, because Microsoft 365 and Marketplace charges show up in the same place as Azure ones.
- Bad, because the operator has to opt in to keep a long assessment window or a host up overnight.
- Bad, because the commitment record is kept by hand: no API in this family reads the Microsoft
  365 admin center's billing.

## More Information

- Microsoft Learn: [Cancel your subscription in the Microsoft 365 admin center](https://learn.microsoft.com/microsoft-365/commerce/subscriptions/cancel-your-subscription),
  [Manage recurring billing](https://learn.microsoft.com/microsoft-365/commerce/subscriptions/renew-your-subscription),
  [SaaS subscription lifecycle management](https://learn.microsoft.com/marketplace/saas-subscription-lifecycle-management),
  [Cancel and delete your Azure subscription](https://learn.microsoft.com/azure/cost-management-billing/manage/cancel-azure-subscription)
  (SaaS offers must be cancelled by hand).
- In each repo: the landing zone (demo pool outside auto shutdown, budget optional, Defender plans
  left on after teardown unless reset), avd-liquidware (Stratusphere appliances run until the
  window ends, Bastion on by default when standalone), avd-swarm (spend plans and the spike), and
  the spend ledger's daily check.
