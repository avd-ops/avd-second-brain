---
title: "AI agents in the AVD repos"
summary: "How the AVD repos use Claude: the brain's agents, avd-swarm's agents, model access and their identities"
topic: agents
status: partial
last_reviewed: 2026-10-20
sources:
  - https://github.com/microsoft/PyRIT
  - https://github.com/NVIDIA/garak
  - https://github.com/beelzebub-labs/beelzebub
  - https://docs.canarytokens.org/guide/entraid-token
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
  - https://learn.microsoft.com/style-guide/brand-voice-above-all-simple-human
  - https://learn.microsoft.com/style-guide/global-communications/writing-tips
  - https://styleguide.mailchimp.com/voice-and-tone/
  - https://www.nngroup.com/articles/tone-of-voice-dimensions/
  - https://www.anthropic.com/constitution
  - https://learn.microsoft.com/azure/static-web-apps/authentication-custom
  - https://learn.microsoft.com/azure/static-web-apps/apis-overview
  - https://learn.microsoft.com/azure/static-web-apps/apis-functions
  - https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/
---

# AI agents in the AVD repos

How the AVD repos use AI: the brain's agents (triage, diagnose, critic, retro), avd-swarm's agents and judge, how they reach Claude, and the identities they run under. General research on Claude, the Claude API, prompting and evals is outside this project; this page keeps only how the AVD repos use them. The security section, avd-buddy's voice and avd-buddy as an installable app are written so far.

## Where it lives today

- [avd-swarm spec](https://github.com/nickprignano/avd-swarm/blob/main/docs/spec.md) and [identities](https://github.com/nickprignano/avd-swarm/blob/main/docs/identities.md)
- [How avd-swarm answers a question](https://github.com/nickprignano/avd-swarm/blob/main/docs/spec.md) (spec §4a): split, fan out, claim check, merge
- [An optional computer-use agent on an isolated VM](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/decisions/0015-foundry-cua.md) (avd-landing-zone decision 0015)

## MCP in the AVD repos

Checked on 2026-10-20 for the v1 reviews ([brain](../../v1-review.md), [avd-swarm](https://github.com/nickprignano/avd-swarm/blob/main/docs/v1-review.md)). Proposed for v1: avd-swarm uses MCP as a client for reads, and neither repo builds an MCP server of its own; the brain's Concierge reaches operators as one of avd-swarm's tools.

- **Microsoft's Azure MCP Server is the AVD read tool.** Its `virtualdesktop` namespace lists host pools, session hosts and user sessions, and those tools are annotated read-only. `--read-only` refuses every write, and `--namespace` limits the services exposed ([tools](https://learn.microsoft.com/azure/developer/azure-mcp-server/tools/), [AVD tools](https://learn.microsoft.com/azure/developer/azure-mcp-server/tools/azure-virtual-desktop)).
- **A per-tool allowlist needs the right server mode.** The default `namespace` mode exposes one tool per namespace, so an allowlist by tool name sees one name for all of AVD. Name tools with `--tool` (which switches the server to `all` mode) or start it in `all` mode when an agent's allowlist lists individual tools ([start parameters](https://learn.microsoft.com/azure/developer/azure-mcp-server/tools/#azure-mcp-server-start-parameters)). avd-swarm's S1a spike already starts it with `--mode all --read-only --namespace virtualdesktop`, and its Q4 tests the allowlist.
- **The Graph MCP server is tenant-wide.** Microsoft's MCP Server for Enterprise reads Graph read-only with the signed-in user's delegated rights, so it isn't a fit for an agent that should see only AVD groups and users; avd-swarm's Users agent keeps a narrow tool of its own ([overview](https://learn.microsoft.com/graph/mcp-server/overview)).
- **Azure SRE Agent's own identity isn't read-only by default.** Whatever permission level is chosen, its managed identity always gets Reader, Log Analytics Reader and Monitoring Reader on its resource groups and **Monitoring Contributor on the subscription**, which can update monitoring settings and close alerts. Using it as a read-only investigator (avd-swarm spec §3a) means removing that assignment ([agent permissions](https://learn.microsoft.com/azure/sre-agent/permissions)).
- **SRE Agent roles:** only its Administrator can approve actions and authorize on-behalf-of requests; a Standard User can chat, manage scheduled tasks, upload knowledge and add code repository connectors ([user roles](https://learn.microsoft.com/azure/sre-agent/user-roles)). Its API reference names an "SRE Agent User" role that can approve, so check the tenant's role list before assigning one. Personal Microsoft accounts can't authorize on-behalf-of.
- **SRE Agent can't be stopped from writing by a hook.** Its hooks fire on Stop and PostToolUse only, so a hook sees a tool call after it ran; a user-defined hook that returns allow even overrides a global deny. The deny that holds is its **tool access policy at global scope** (only the global scope can deny; custom-agent and thread scopes can only allow), and the control to rely on is still Azure RBAC on its identity ([tool access policies](https://learn.microsoft.com/azure/sre-agent/tool-access-policies), [agent hooks](https://learn.microsoft.com/azure/sre-agent/agent-hooks)).
- **Azure RBAC conditions don't limit control-plane deletes by tag.** Conditions apply to storage data actions and to role assignment management (delegation conditions can limit `roleAssignments/write` and `delete` to named principals or roles). A "delete only what is tagged" identity has to be scoped by resource group instead, and Azure Policy's `denyAction` on `delete` protects tagged resources ([ABAC conditions](https://learn.microsoft.com/azure/role-based-access-control/conditions-overview), [delegation conditions](https://learn.microsoft.com/azure/role-based-access-control/delegate-role-assignments-overview), [denyAction](https://learn.microsoft.com/azure/governance/policy/concepts/effect-deny-action)).
- **MCP approval is never the write approval.** An MCP or Foundry tool approval answers inside the conversation; every change still goes through avd-swarm's plan, gate and GitHub Environment.

## Securing the agents and AVD security signal

Checked on 2026-10-19 for [avd-swarm's security tooling proposal](https://github.com/nickprignano/avd-swarm/blob/main/docs/security-tooling.md) (avd-swarm PR #14, merged; first build in the S1a spike, 2026-10-21). The tools themselves are documented upstream: [Prompt Shields](https://learn.microsoft.com/azure/ai-services/content-safety/concepts/jailbreak-detection), [PyRIT](https://github.com/microsoft/PyRIT), [garak](https://github.com/NVIDIA/garak), decoy MCP tools such as [Beelzebub](https://github.com/beelzebub-labs/beelzebub), [Sentinel MCP custom tools](https://learn.microsoft.com/azure/sentinel/datalake/sentinel-mcp-create-custom-tool) and the [Canarytokens Entra ID token](https://docs.canarytokens.org/guide/entraid-token); this section keeps only what applies to the AVD repos. Nothing was installed or run.

- **Foundry guardrails don't cover the Anthropic path.** avd-swarm's build steps 1 and 2 call Claude through Anthropic's API from a Container App, where Foundry's indirect-injection checks never run; and in Foundry, tool-response scanning is preview and document-attack detection is off by default ([Prompt Shields concepts](https://learn.microsoft.com/azure/ai-services/content-safety/concepts/jailbreak-detection)). Scan untrusted text in the model client instead, which works on any provider.
- **Prompt Shields limits and regions** (checked 2026-10-21): one call takes a `userPrompt` of up to 10K characters and up to five `documents` totaling 10K characters, and both fields are required (send an empty string or list), so long tool output is chunked at 2K characters, five to a call ([service limits](https://learn.microsoft.com/azure/ai-services/content-safety/region-availability#service-limits), [quickstart](https://learn.microsoft.com/azure/ai-services/content-safety/quickstart-jailbreak)). Standalone Content Safety offers it in North Central US and East US 2, among others. Billing counts a text record per 1,000 characters, and the free tier (F0) gives 5,000 a month with one F0 resource of a kind per subscription.
- **Keyless Content Safety:** set `disableLocalAuth` and a custom subdomain (Entra tokens need it), and give the caller Cognitive Services User on that one resource, token scope `https://cognitiveservices.azure.com/.default`. The role also carries `listKeys`, which is moot once local auth is off. The model client logs a failed call by its status only, so no scanned text can reach a log through an error body.
- **No upstream AVD hunts.** Azure/Azure-Sentinel (MIT) has no Azure Virtual Desktop solution and no hunting query on the `WVD*` tables (checked 2026-10-19). AVD hunts have to be written, and are a candidate to give back upstream once proven (decision 0011).
- **RDP transport is in `WVDConnections.TransportType`** (`Shortpath`, `TURN`, `Websocket`); there is no `UdpUse` column. The client address is `ClientSideIPAddress` ([table reference](https://learn.microsoft.com/azure/azure-monitor/reference/tables/wvdconnections)).
- **Run AVD hunts through Log Analytics first.** The agents' Log Analytics Reader on the AVD resource groups runs them keyless in any tenant. Sentinel MCP custom tools need the Sentinel data lake and Defender licenses, are preview and invite-only, and an unattended client can sign in keylessly only from a Logic App's managed identity; the other app option needs a client secret ([custom tools](https://learn.microsoft.com/azure/sentinel/datalake/sentinel-mcp-create-custom-tool), [connector](https://learn.microsoft.com/connectors/sentinelmcp/)).
- **The Canarytokens Entra ID login token can't be added to most tenants any more.** It relies on custom CSS in company branding, which tenants created after 2026-01-05 don't have and which tenants not already using it can't configure after 2026-07-21 ([company branding](https://learn.microsoft.com/entra/fundamentals/how-to-customize-branding)).

## avd-buddy's voice: teaching, humor and calm

Checked on 2026-10-20 for [avd-swarm's voice spec](https://github.com/nickprignano/avd-swarm/blob/main/docs/buddy-voice.md) (proposed). The owner asked for a chat front end that teaches first, is witty but never risque or controversial, and helps in stressful moments. Nothing was run.

- **The published voice guides agree on the shape and leave the safety to us.** Microsoft's voice is warm and relaxed, crisp and clear, ready to lend a hand, and shifts tone from serious to lighthearted with the reader's state of mind ([brand voice](https://learn.microsoft.com/style-guide/brand-voice-above-all-simple-human)); Mailchimp puts clarity over entertainment and says to keep a straight face when unsure ([voice and tone](https://styleguide.mailchimp.com/voice-and-tone/)); Nielsen Norman Group's four dials (funny, formal, respectful, enthusiastic) give the vocabulary ([tone dimensions](https://www.nngroup.com/articles/tone-of-voice-dimensions/)); Claude's constitution names "a playful wit balanced with substance and depth" ([constitution](https://www.anthropic.com/constitution)). None says how to keep a model's humor away from approvals, plans or facts.
- **Let code pick the mode, not the model.** The tool layer already knows when a plan, an approval, a destructive step, the kill switch or a security finding is on screen, so a pure function can switch the voice to calm before the model writes a word. The model may only ask for the calmer mode.
- **Put the joke in its own field and make it unable to carry a fact.** One optional sentence, checked in code for banned topics and for digits, links, code, IDs and estate names, dropped silently on any finding and never kept in history, plans or evals. Plans and approval text stay rendered from the plan store, so no tone reaches them.
- **Wit doesn't translate.** Microsoft's global writing tips say to avoid idioms and culture-specific references ([writing tips](https://learn.microsoft.com/style-guide/global-communications/writing-tips)), so the aside is English-only and the answer stays plain in every language.

## avd-buddy as an installable web app

Checked on 2026-10-20 for [avd-swarm's app spec](https://github.com/nickprignano/avd-swarm/blob/main/docs/buddy-app.md) (proposed). The owner asked for a mobile app for the chatbot that can be an installable web app (PWA) for now. Nothing was built or run.

- **Static Web Apps' built-in sign-in keeps every token off the device.** The platform runs the Entra flow and gives the browser an HTTP-only cookie; the API reads the user from a header the platform adds. MSAL.js in the page would keep tokens in browser storage instead.
- **The Entra provider needs no client secret.** The app registration can trust a user-assigned managed identity as a federated credential (the `OVERRIDE_USE_MI_FIC_ASSERTION_CLIENTID` setting), workforce tenants only ([custom authentication](https://learn.microsoft.com/azure/static-web-apps/authentication-custom)). The provider's `openIdIssuer` holds the tenant ID, so a public repo generates `staticwebapp.config.json` at deploy time instead of committing it.
- **Static Web Apps APIs are HTTP only and stop at 45 seconds** ([API constraints](https://learn.microsoft.com/azure/static-web-apps/apis-overview)), so a long agent answer has to come back through short polls, not one request or a WebSocket.
- **Managed functions have no managed identity or Key Vault references** ([comparison](https://learn.microsoft.com/azure/static-web-apps/apis-functions)). An API that calls other Azure services without secrets needs a linked ("bring your own") Functions app, which needs the Standard plan.
- **Web push on iPhone and iPad works only after Add to Home Screen, on iOS and iPadOS 16.4 or later** ([WebKit](https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/)), needs a tap to opt in, and vendors report deliveries that stop silently. Treat push as a convenience with an empty payload, never the only signal for an approval.
- **Lighthouse no longer has a PWA category,** so installability needs its own tests (manifest fields, service worker offline behavior), for example in Playwright.

## Fan-out answers: split, fan out, verify, merge

Mapped on 2026-10-20 from the common goal, split, fan-out workers, fresh-context verifier, merge and final-answer pattern onto avd-swarm (spec §4a, proposed) and the brain (operations-spec §4.4). General facts about multi-agent patterns belong to the [AI research knowledge base](https://github.com/nickprignano/ai-brain/tree/main/docs/knowledge); this keeps only how the AVD repos apply it.

- **A verifier is only fresh if its input is narrow.** Passing a worker's whole output (reasoning plus answer) to a second model lets the reasoning argue the verifier into agreeing. The AVD repos pass claims only: a value, its unit and the tool call IDs it cites. The swarm's claim check, its eval judge and the brain's Critic all see claims and evidence, never the reasoning that produced them.
- **Most of the check is code, not a model.** A claim that reads one value from one tool output is checked by matching the value in that saved output, at no token cost; only an inference across several outputs needs a model verifier. That keeps the pattern affordable at one operator's volume.
- **Verify before the merge, then check the merge.** A merge done by a model can reintroduce what the check removed, so after the merge code checks that every factual sentence cites a supported claim.
- **Fan-out multiplies tokens.** avd-swarm caps it at 3 specialists and one round per question, each with its own share of the metered per-question reservation, and splits workers by domain rather than by angle; the "check" and "find gaps" angles are built into the claim check and each specialist's list of what it couldn't answer.
- **A verifier never approves a change.** Plans keep the deterministic gate, live re-reads and a person's approval; the claim check judges answers only.
