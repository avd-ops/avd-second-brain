---
title: "AI agents in the AVD repos"
summary: "How the AVD repos use Claude: the brain's agents, avd-swarm's agents, model access and their identities"
topic: agents
status: partial
last_reviewed: 2026-10-20
sources:
  - https://github.com/nickprignano/ai-brain/blob/main/docs/knowledge/privacy-and-safety/README.md
  - https://learn.microsoft.com/azure/ai-services/content-safety/concepts/jailbreak-detection
  - https://learn.microsoft.com/azure/azure-monitor/reference/tables/wvdconnections
  - https://learn.microsoft.com/azure/sentinel/datalake/sentinel-mcp-create-custom-tool
  - https://learn.microsoft.com/connectors/sentinelmcp/
  - https://learn.microsoft.com/entra/fundamentals/how-to-customize-branding
---

# AI agents in the AVD repos

How the AVD repos use AI: the brain's agents (triage, diagnose, critic, retro), avd-swarm's agents and judge, how they reach Claude, and the identities they run under. General facts about Claude, the Claude API, prompting and evals belong to the [AI research knowledge base](https://github.com/nickprignano/ai-brain/tree/main/docs/knowledge); this page keeps only how the AVD repos use them. Only the security section below is written so far.

## Where it lives today

- [avd-swarm spec](https://github.com/nickprignano/avd-swarm/blob/main/docs/spec.md) and [identities](https://github.com/nickprignano/avd-swarm/blob/main/docs/identities.md)
- [How avd-swarm answers a question](https://github.com/nickprignano/avd-swarm/blob/main/docs/spec.md) (spec §4a): split, fan out, claim check, merge
- [An optional computer-use agent on an isolated VM](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/decisions/0015-foundry-cua.md) (avd-landing-zone decision 0015)

## Securing the agents and AVD security signal

Checked on 2026-10-19 for [avd-swarm's security tooling proposal](https://github.com/nickprignano/avd-swarm/blob/main/docs/security-tooling.md) (avd-swarm PR #14, proposed). The tools themselves (Prompt Shields, PyRIT, garak, decoy MCP tools, Sentinel MCP, Canarytokens) are surveyed in the AI knowledge base's [Open-source AI tools for fighting bad actors](https://github.com/nickprignano/ai-brain/blob/main/docs/knowledge/privacy-and-safety/README.md#open-source-ai-tools-for-fighting-bad-actors); this section keeps only what applies to the AVD repos. Nothing was installed or run.

- **Foundry guardrails don't cover the Anthropic path.** avd-swarm's build steps 1 and 2 call Claude through Anthropic's API from a Container App, where Foundry's indirect-injection checks never run; and in Foundry, tool-response scanning is preview and document-attack detection is off by default ([Prompt Shields concepts](https://learn.microsoft.com/azure/ai-services/content-safety/concepts/jailbreak-detection)). Scan untrusted text in the model client instead, which works on any provider.
- **No upstream AVD hunts.** Azure/Azure-Sentinel (MIT) has no Azure Virtual Desktop solution and no hunting query on the `WVD*` tables (checked 2026-10-19). AVD hunts have to be written, and are a candidate to give back upstream once proven (decision 0011).
- **RDP transport is in `WVDConnections.TransportType`** (`Shortpath`, `TURN`, `Websocket`); there is no `UdpUse` column. The client address is `ClientSideIPAddress` ([table reference](https://learn.microsoft.com/azure/azure-monitor/reference/tables/wvdconnections)).
- **Run AVD hunts through Log Analytics first.** The agents' Log Analytics Reader on the AVD resource groups runs them keyless in any tenant. Sentinel MCP custom tools need the Sentinel data lake and Defender licenses, are preview and invite-only, and an unattended client can sign in keylessly only from a Logic App's managed identity; the other app option needs a client secret ([custom tools](https://learn.microsoft.com/azure/sentinel/datalake/sentinel-mcp-create-custom-tool), [connector](https://learn.microsoft.com/connectors/sentinelmcp/)).
- **The Canarytokens Entra ID login token can't be added to most tenants any more.** It relies on custom CSS in company branding, which tenants created after 2026-01-05 don't have and which tenants not already using it can't configure after 2026-07-21 ([company branding](https://learn.microsoft.com/entra/fundamentals/how-to-customize-branding)).

## Fan-out answers: split, fan out, verify, merge

Mapped on 2026-10-20 from the common goal, split, fan-out workers, fresh-context verifier, merge and final-answer pattern onto avd-swarm (spec §4a, proposed) and the brain (operations-spec §4.4). General facts about multi-agent patterns belong to the [AI research knowledge base](https://github.com/nickprignano/ai-brain/tree/main/docs/knowledge); this keeps only how the AVD repos apply it.

- **A verifier is only fresh if its input is narrow.** Passing a worker's whole output (reasoning plus answer) to a second model lets the reasoning argue the verifier into agreeing. The AVD repos pass claims only: a value, its unit and the tool call IDs it cites. The swarm's claim check, its eval judge and the brain's Critic all see claims and evidence, never the reasoning that produced them.
- **Most of the check is code, not a model.** A claim that reads one value from one tool output is checked by matching the value in that saved output, at no token cost; only an inference across several outputs needs a model verifier. That keeps the pattern affordable at one operator's volume.
- **Verify before the merge, then check the merge.** A merge done by a model can reintroduce what the check removed, so after the merge code checks that every factual sentence cites a supported claim.
- **Fan-out multiplies tokens.** avd-swarm caps it at 3 specialists and one round per question, each with its own share of the metered per-question reservation, and splits workers by domain rather than by angle; the "check" and "find gaps" angles are built into the claim check and each specialist's list of what it couldn't answer.
- **A verifier never approves a change.** Plans keep the deterministic gate, live re-reads and a person's approval; the claim check judges answers only.
