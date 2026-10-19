---
title: "AI agents in the AVD repos"
summary: "How the AVD repos use Claude: the brain's agents, avd-swarm's agents, model access and their identities"
topic: agents
status: partial
last_reviewed: 2026-10-19
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
- [An optional computer-use agent on an isolated VM](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/decisions/0015-foundry-cua.md) (avd-landing-zone decision 0015)

## Securing the agents and AVD security signal

Checked on 2026-10-19 for [avd-swarm's security tooling proposal](https://github.com/nickprignano/avd-swarm/blob/main/docs/security-tooling.md) (avd-swarm PR #14, proposed). The tools themselves (Prompt Shields, PyRIT, garak, decoy MCP tools, Sentinel MCP, Canarytokens) are surveyed in the AI knowledge base's [Open-source AI tools for fighting bad actors](https://github.com/nickprignano/ai-brain/blob/main/docs/knowledge/privacy-and-safety/README.md#open-source-ai-tools-for-fighting-bad-actors); this section keeps only what applies to the AVD repos. Nothing was installed or run.

- **Foundry guardrails don't cover the Anthropic path.** avd-swarm's build steps 1 and 2 call Claude through Anthropic's API from a Container App, where Foundry's indirect-injection checks never run; and in Foundry, tool-response scanning is preview and document-attack detection is off by default ([Prompt Shields concepts](https://learn.microsoft.com/azure/ai-services/content-safety/concepts/jailbreak-detection)). Scan untrusted text in the model client instead, which works on any provider.
- **No upstream AVD hunts.** Azure/Azure-Sentinel (MIT) has no Azure Virtual Desktop solution and no hunting query on the `WVD*` tables (checked 2026-10-19). AVD hunts have to be written, and are a candidate to give back upstream once proven (decision 0011).
- **RDP transport is in `WVDConnections.TransportType`** (`Shortpath`, `TURN`, `Websocket`); there is no `UdpUse` column. The client address is `ClientSideIPAddress` ([table reference](https://learn.microsoft.com/azure/azure-monitor/reference/tables/wvdconnections)).
- **Run AVD hunts through Log Analytics first.** The agents' Log Analytics Reader on the AVD resource groups runs them keyless in any tenant. Sentinel MCP custom tools need the Sentinel data lake and Defender licenses, are preview and invite-only, and an unattended client can sign in keylessly only from a Logic App's managed identity; the other app option needs a client secret ([custom tools](https://learn.microsoft.com/azure/sentinel/datalake/sentinel-mcp-create-custom-tool), [connector](https://learn.microsoft.com/connectors/sentinelmcp/)).
- **The Canarytokens Entra ID login token can't be added to most tenants any more.** It relies on custom CSS in company branding, which tenants created after 2026-01-05 don't have and which tenants not already using it can't configure after 2026-07-21 ([company branding](https://learn.microsoft.com/entra/fundamentals/how-to-customize-branding)).
