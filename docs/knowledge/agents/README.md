---
title: "AI agents in the AVD repos"
summary: "How the AVD repos use Claude: the brain's agents, avd-swarm's agents, model access and their identities"
topic: agents
status: partial
last_reviewed: 2026-10-20
sources:
  - https://github.com/nickprignano/ai-brain/blob/main/docs/knowledge/privacy-and-safety/README.md
  - https://learn.microsoft.com/azure/ai-services/content-safety/concepts/jailbreak-detection
  - https://learn.microsoft.com/azure/developer/azure-mcp-server/tools/
  - https://learn.microsoft.com/azure/developer/azure-mcp-server/tools/azure-virtual-desktop
  - https://learn.microsoft.com/graph/mcp-server/overview
  - https://learn.microsoft.com/azure/sre-agent/user-roles
  - https://learn.microsoft.com/azure/sre-agent/permissions
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

## MCP in the AVD repos

Checked on 2026-10-20 for the v1 reviews ([brain](../../v1-review.md), [avd-swarm](https://github.com/nickprignano/avd-swarm/blob/main/docs/v1-review.md)). Proposed for v1: avd-swarm uses MCP as a client for reads, and neither repo builds an MCP server of its own; the brain's Concierge reaches operators as one of avd-swarm's tools.

- **Microsoft's Azure MCP Server is the AVD read tool.** Its `virtualdesktop` namespace lists host pools, session hosts and user sessions, and those tools are annotated read-only. `--read-only` refuses every write, and `--namespace` limits the services exposed ([tools](https://learn.microsoft.com/azure/developer/azure-mcp-server/tools/), [AVD tools](https://learn.microsoft.com/azure/developer/azure-mcp-server/tools/azure-virtual-desktop)).
- **A per-tool allowlist needs the right server mode.** The default `namespace` mode exposes one tool per namespace, so an allowlist by tool name sees one name for all of AVD. Name tools with `--tool` (which switches the server to `all` mode) or start it in `all` mode when an agent's allowlist lists individual tools ([start parameters](https://learn.microsoft.com/azure/developer/azure-mcp-server/tools/#azure-mcp-server-start-parameters)). avd-swarm's S1a spike already starts it with `--mode all --read-only --namespace virtualdesktop`, and its Q4 tests the allowlist.
- **The Graph MCP server is tenant-wide.** Microsoft's MCP Server for Enterprise reads Graph read-only with the signed-in user's delegated rights, so it isn't a fit for an agent that should see only AVD groups and users; avd-swarm's Users agent keeps a narrow tool of its own ([overview](https://learn.microsoft.com/graph/mcp-server/overview)).
- **Azure SRE Agent's own identity isn't read-only by default.** Whatever permission level is chosen, its managed identity always gets Reader, Log Analytics Reader and Monitoring Reader on its resource groups and **Monitoring Contributor on the subscription**, which can update monitoring settings and close alerts. Using it as a read-only investigator (avd-swarm spec §3a) means removing that assignment ([agent permissions](https://learn.microsoft.com/azure/sre-agent/permissions)).
- **SRE Agent roles:** only its Administrator can approve actions and authorize on-behalf-of requests; a Standard User can chat, manage scheduled tasks, upload knowledge and add code repository connectors ([user roles](https://learn.microsoft.com/azure/sre-agent/user-roles)). Its API reference names an "SRE Agent User" role that can approve, so check the tenant's role list before assigning one. Personal Microsoft accounts can't authorize on-behalf-of.
- **MCP approval is never the write approval.** An MCP or Foundry tool approval answers inside the conversation; every change still goes through avd-swarm's plan, gate and GitHub Environment.

## Securing the agents and AVD security signal

Checked on 2026-10-19 for [avd-swarm's security tooling proposal](https://github.com/nickprignano/avd-swarm/blob/main/docs/security-tooling.md) (avd-swarm PR #14, proposed). The tools themselves (Prompt Shields, PyRIT, garak, decoy MCP tools, Sentinel MCP, Canarytokens) are surveyed in the AI knowledge base's [Open-source AI tools for fighting bad actors](https://github.com/nickprignano/ai-brain/blob/main/docs/knowledge/privacy-and-safety/README.md#open-source-ai-tools-for-fighting-bad-actors); this section keeps only what applies to the AVD repos. Nothing was installed or run.

- **Foundry guardrails don't cover the Anthropic path.** avd-swarm's build steps 1 and 2 call Claude through Anthropic's API from a Container App, where Foundry's indirect-injection checks never run; and in Foundry, tool-response scanning is preview and document-attack detection is off by default ([Prompt Shields concepts](https://learn.microsoft.com/azure/ai-services/content-safety/concepts/jailbreak-detection)). Scan untrusted text in the model client instead, which works on any provider.
- **No upstream AVD hunts.** Azure/Azure-Sentinel (MIT) has no Azure Virtual Desktop solution and no hunting query on the `WVD*` tables (checked 2026-10-19). AVD hunts have to be written, and are a candidate to give back upstream once proven (decision 0011).
- **RDP transport is in `WVDConnections.TransportType`** (`Shortpath`, `TURN`, `Websocket`); there is no `UdpUse` column. The client address is `ClientSideIPAddress` ([table reference](https://learn.microsoft.com/azure/azure-monitor/reference/tables/wvdconnections)).
- **Run AVD hunts through Log Analytics first.** The agents' Log Analytics Reader on the AVD resource groups runs them keyless in any tenant. Sentinel MCP custom tools need the Sentinel data lake and Defender licenses, are preview and invite-only, and an unattended client can sign in keylessly only from a Logic App's managed identity; the other app option needs a client secret ([custom tools](https://learn.microsoft.com/azure/sentinel/datalake/sentinel-mcp-create-custom-tool), [connector](https://learn.microsoft.com/connectors/sentinelmcp/)).
- **The Canarytokens Entra ID login token can't be added to most tenants any more.** It relies on custom CSS in company branding, which tenants created after 2026-01-05 don't have and which tenants not already using it can't configure after 2026-07-21 ([company branding](https://learn.microsoft.com/entra/fundamentals/how-to-customize-branding)).
