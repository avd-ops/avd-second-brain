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
  - https://learn.microsoft.com/azure/azure-monitor/reference/tables/wvdconnections
  - https://learn.microsoft.com/azure/sentinel/datalake/sentinel-mcp-create-custom-tool
  - https://learn.microsoft.com/connectors/sentinelmcp/
  - https://learn.microsoft.com/entra/fundamentals/how-to-customize-branding
  - https://learn.microsoft.com/style-guide/brand-voice-above-all-simple-human
  - https://learn.microsoft.com/style-guide/global-communications/writing-tips
  - https://styleguide.mailchimp.com/voice-and-tone/
  - https://www.nngroup.com/articles/tone-of-voice-dimensions/
  - https://www.anthropic.com/constitution
---

# AI agents in the AVD repos

How the AVD repos use AI: the brain's agents (triage, diagnose, critic, retro), avd-swarm's agents and judge, how they reach Claude, and the identities they run under. General research on Claude, the Claude API, prompting and evals is outside this project; this page keeps only how the AVD repos use them. The security section and avd-buddy's voice are written so far.

## Where it lives today

- [avd-swarm spec](https://github.com/nickprignano/avd-swarm/blob/main/docs/spec.md) and [identities](https://github.com/nickprignano/avd-swarm/blob/main/docs/identities.md)
- [An optional computer-use agent on an isolated VM](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/decisions/0015-foundry-cua.md) (avd-landing-zone decision 0015)

## Securing the agents and AVD security signal

Checked on 2026-10-19 for [avd-swarm's security tooling proposal](https://github.com/nickprignano/avd-swarm/blob/main/docs/security-tooling.md) (avd-swarm PR #14, proposed). The tools themselves are documented upstream: [Prompt Shields](https://learn.microsoft.com/azure/ai-services/content-safety/concepts/jailbreak-detection), [PyRIT](https://github.com/microsoft/PyRIT), [garak](https://github.com/NVIDIA/garak), decoy MCP tools such as [Beelzebub](https://github.com/beelzebub-labs/beelzebub), [Sentinel MCP custom tools](https://learn.microsoft.com/azure/sentinel/datalake/sentinel-mcp-create-custom-tool) and the [Canarytokens Entra ID token](https://docs.canarytokens.org/guide/entraid-token); this section keeps only what applies to the AVD repos. Nothing was installed or run.

- **Foundry guardrails don't cover the Anthropic path.** avd-swarm's build steps 1 and 2 call Claude through Anthropic's API from a Container App, where Foundry's indirect-injection checks never run; and in Foundry, tool-response scanning is preview and document-attack detection is off by default ([Prompt Shields concepts](https://learn.microsoft.com/azure/ai-services/content-safety/concepts/jailbreak-detection)). Scan untrusted text in the model client instead, which works on any provider.
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

