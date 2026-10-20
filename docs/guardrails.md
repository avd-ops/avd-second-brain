# Guardrails

The rules every change to this repo follows, whoever makes it: a person, a workflow or an AI
assistant. They're the same in every knowledge base of the family
([family.yaml](knowledge/family.yaml)), worded for this one's topic, and they sit alongside the
brain's own rules in [CLAUDE.md](../CLAUDE.md). CI enforces the ones it can (marked **CI**).
Reviewers check the rest.

## 1. Nothing public identifies a real tenant, customer or estate (**CI**: gitleaks, validate.py, Test-Knowledge.ps1, Test-KbLeaks.ps1)

The repo is public. Never commit:

- tenant, subscription, object, client or resource IDs
- domains, emails, hostnames, UNC paths, real IP ranges
- secrets, keys, tokens or Terraform/ARM state
- data from a customer's estate: inventories, user and machine names, line-of-business apps
- employer, customer or tenant names

Use placeholders such as `<tenant-id>`, `<storage-account>`, `contoso.com` and `10.x`, and write
lessons as general advice. A customer's estate data lives in their own private vault
([vault.md](vault.md)), never here.

## 2. Secrets never pass through chat, the repo or the KB

Secrets live in Key Vault, GitHub secrets or the platform's own store. Scripts never print them. A
chat assistant never asks for, shows or stores a secret; the person runs the step that handles it.

## 3. Every change through a PR; nothing touches a real environment without a yes

Changes land through reviewed pull requests with green CI. Nothing changes a real tenant,
subscription or estate without the owner's explicit yes. The brain never holds a write credential:
every change to an estate goes through avd-swarm's approval and kill switch ([decision 0003](knowledge/decisions/0003-brain-thinks-swarm-acts.md)).

## 4. Respect licenses: unlicensed code is reference only

Code from repos with no license is reference only. Use facts from it, cite the source, and never
copy, adapt, fork or redistribute it. Check the license of every vendor repo or sample before using
it. This repo is MIT ([LICENSE](../LICENSE)); the knowledge base tooling in `scripts/kb/` is adapted
from Apache-2.0 sources and keeps that license ([scripts/kb/NOTICE](../scripts/kb/NOTICE)).

## 5. Azure-native, GitHub and open source first

Prefer Azure-native, GitHub and open-source tooling. For the AVD repos that means Bicep,
PowerShell and native Azure, Entra and Microsoft 365 tooling; Terraform, Packer and any other HCL
belong to nerdio-hcl and fail the KB check here
([decision 0012](knowledge/decisions/0012-family-format-project-lanes.md)). A paid third-party service needs a
decision record saying why the free options fell short. The knowledge base's own tooling spends no
LLM tokens.

## 6. Works from Azure Cloud Shell

Every step works from Azure Cloud Shell in a browser, on an iPad included, with no local installs.

## 7. Every decision and lesson goes into the KB

Decisions get a record, lessons go on the topic page they belong to (or stay in the repo where
they happened, linked from here), and these guardrails stay visible here, in
[AGENTS.md](../AGENTS.md) and in the README.

## 8. Never delete the last copy

A script, workflow or agent step that deletes data (logs, evidence, reports, ledgers, backups,
assessment data, configuration, user data) first checks that another durable copy exists, or the
person running it opts in. Every run's logs and teardown evidence go to one run store outside the
deployment, kept by default (`-TeardownLogs Keep|Ask|Delete`); data inside a deployment needs
`-DiscardLastCopy`, which `-Force` never implies. Old data moves to a colder tier instead of being
deleted, and soft delete stays on
([decision 0016](knowledge/decisions/0016-never-delete-the-last-copy.md)).

## 9. Never leave the meter running without an opt-in

Anything that bills by time or use is removed, stopped or on a schedule at the end of a run. It
keeps billing only with `-KeepRunning <until>` (an expiry or a reason, recorded), which `-Force`
never implies. Microsoft 365 licenses, Marketplace SaaS offers and other recurring commitments
are recorded with their renewal date and cancel path, and no script buys one
([decision 0017](knowledge/decisions/0017-never-leave-the-meter-running.md)).

## When a guardrail gets in the way

Don't work around it quietly. Open an issue or a decision record that says which guardrail, why,
and what the safer alternative is. A guardrail changes only by a new decision record, and a change
to the shared rules is a family format change
([curation.md](knowledge/curation.md#staying-aligned-with-the-family)).
