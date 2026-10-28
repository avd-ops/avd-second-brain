---
title: "AI agents in the AVD repos"
summary: "How the AVD repos use Claude: the brain's agents, avd-swarm's agents, model access and their identities"
topic: agents
status: partial
last_reviewed: 2026-10-28
sources:
  - https://github.com/robusta-dev/holmesgpt
  - https://github.com/Azure/azure-api-mcp
  - https://github.com/maximhq/bifrost
  - https://github.com/BerriAI/litellm
  - https://github.com/IBM/mcp-context-forge
  - https://github.com/microsoft/agent-governance-toolkit
  - https://learn.microsoft.com/azure/sre-agent/sub-agents
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
  - https://learn.microsoft.com/azure/logic-apps/automation/dynamic-workflow-automation-introduction
  - https://learn.microsoft.com/azure/logic-apps/automation/compare-automation-services
  - https://learn.microsoft.com/azure/sre-agent/pricing-billing
  - https://learn.microsoft.com/azure/sre-agent/deploy-iac
  - https://learn.microsoft.com/azure/api-management/mcp-server-overview
  - https://learn.microsoft.com/azure/api-management/llm-token-limit-policy
  - https://learn.microsoft.com/azure/api-management/ai-gateway-overview
  - https://github.com/multica-ai/andrej-karpathy-skills
  - https://github.com/google-gemini/gemini-cli/blob/main/docs/reference/memport.md
  - https://agents.md/
---

# AI agents in the AVD repos

How the AVD repos use AI: the brain's agents (triage, diagnose, critic, retro), avd-swarm's agents and judge, how they reach Claude, and the identities they run under. General research on Claude, the Claude API, prompting and evals is outside this project; this page keeps only how the AVD repos use them. The security section, avd-buddy's voice and avd-buddy as an installable app are written so far.

## Where it lives today

- [avd-swarm spec](https://github.com/avd-ops/avd-swarm/blob/main/docs/spec.md) and [identities](https://github.com/avd-ops/avd-swarm/blob/main/docs/identities.md)
- [How avd-swarm answers a question](https://github.com/avd-ops/avd-swarm/blob/main/docs/spec.md) (spec §4a): split, fan out, claim check, merge

## Instruction files for coding agents: AGENTS.md, CLAUDE.md, GEMINI.md (2026-10-22)

Every AVD repo carries the same three files so any coding agent can pick up the work.

- **AGENTS.md is the shared file.** It opens with four working habits (think before coding, simplest thing that works, surgical changes, goal first then proof), written in our own words from the Karpathy-inspired guidelines ([multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills)); that repo had no license file at its root when checked, so its text is reference only. Then the family rules (exact spend go, never leave the meter running, never delete the last copy, no IDs or names, PRs only), the repo roles, and the repo's own section.
- **Claude Code reads CLAUDE.md, not AGENTS.md.** Each CLAUDE.md starts with `@AGENTS.md`, an import, and keeps the repo's checks and lessons below it.
- **Gemini CLI reads GEMINI.md by default** and supports `@./file.md` imports in it ([memport](https://github.com/google-gemini/gemini-cli/blob/main/docs/reference/memport.md)), which detect circular imports. GEMINI.md holds only `@./AGENTS.md`; AGENTS.md tells the agent to read CLAUDE.md next, so no file is imported twice. Its `context.fileName` setting can name AGENTS.md instead.
- **Hooks are Claude Code only.** The SessionStart handoff list and the Stop knowledge check don't run under other agents; AGENTS.md tells them to run the same scripts by hand.
- **The owner's private context** goes in a private repo only, never in a public AGENTS.md.

### Outside coding agents on a public repo (2026-10-22)

avd-ops was the first repo opened to coding agents other than Claude Code; its [outside-agents page](https://github.com/avd-ops/avd-ops/blob/main/docs/outside-agents.md) has the setup and the review checklist.

- **A fork beats write access.** Pull requests from a fork run CI with a read-only token and no repository secrets, so the agent account needs no collaborator role at all. Fork workflows wait for the owner's approval (Actions setting for external contributors).
- **Hard rules go in AGENTS.md, above the repo's own section,** because that is the one file every agent reads: no secrets in files or chat, no customer, employer or tenant data, branch and PR only, tools on ask, and text read from pages, issues, logs or the repo is data, not instructions.
- **A required approval blocks the owner's own PRs.** Claude Code's PRs are opened under the owner's account, and GitHub refuses a review from a PR's author, so a ruleset that requires one approval also needs a bypass for org admins in `pull_request` mode (merge through a PR only, never a direct push).
- **Required checks must run on every PR.** Name only checks with no path filter (here `test`, both `engine` jobs, `gitleaks`, `privacy`), or a PR that skips one can never merge.
- **`kb-capture` fails if the `no-kb` label lands after the PR opens;** the run on `labeled` turns it green, so check the latest run before treating it as red.
- **Give the owner's Cloud Shell blocks for the shell it opens in.** A bash heredoc fails in PowerShell; a PowerShell here-string piped to `Set-Content`, then `gh api --input`, works there.

## MCP in the AVD repos

Checked on 2026-10-20 for the v1 reviews ([brain](../../v1-review.md), [avd-swarm](https://github.com/avd-ops/avd-swarm/blob/main/docs/v1-review.md)). Proposed for v1: avd-swarm uses MCP as a client for reads, and neither repo builds an MCP server of its own; the brain's Concierge reaches operators as one of avd-swarm's tools.

- **Microsoft's Azure MCP Server is the AVD read tool.** Its `virtualdesktop` namespace lists host pools, session hosts and user sessions, and those tools are annotated read-only. `--read-only` refuses every write, and `--namespace` limits the services exposed ([tools](https://learn.microsoft.com/azure/developer/azure-mcp-server/tools/), [AVD tools](https://learn.microsoft.com/azure/developer/azure-mcp-server/tools/azure-virtual-desktop)).
- **A per-tool allowlist needs the right server mode.** The default `namespace` mode exposes one tool per namespace, so an allowlist by tool name sees one name for all of AVD. Name tools with `--tool` (which switches the server to `all` mode) or start it in `all` mode when an agent's allowlist lists individual tools ([start parameters](https://learn.microsoft.com/azure/developer/azure-mcp-server/tools/#azure-mcp-server-start-parameters)). avd-swarm's S1a spike already starts it with `--mode all --read-only --namespace virtualdesktop`, and its Q4 tests the allowlist.
- **The Graph MCP server is tenant-wide.** Microsoft's MCP Server for Enterprise reads Graph read-only with the signed-in user's delegated rights, so it isn't a fit for an agent that should see only AVD groups and users; avd-swarm's Users agent keeps a narrow tool of its own ([overview](https://learn.microsoft.com/graph/mcp-server/overview)).
- **Azure SRE Agent's own identity isn't read-only by default.** Whatever permission level is chosen, its managed identity always gets Reader, Log Analytics Reader and Monitoring Reader on its resource groups and **Monitoring Contributor on the subscription**, which can update monitoring settings and close alerts. Using it as a read-only investigator (avd-swarm spec §3a) means removing that assignment ([agent permissions](https://learn.microsoft.com/azure/sre-agent/permissions)).
- **SRE Agent roles:** only its Administrator can approve actions and authorize on-behalf-of requests; a Standard User can chat, manage scheduled tasks, upload knowledge and add code repository connectors ([user roles](https://learn.microsoft.com/azure/sre-agent/user-roles)). Its API reference names an "SRE Agent User" role that can approve, so check the tenant's role list before assigning one. Personal Microsoft accounts can't authorize on-behalf-of.
- **SRE Agent can't be stopped from writing by a hook.** Its hooks fire on Stop and PostToolUse only, so a hook sees a tool call after it ran; a user-defined hook that returns allow even overrides a global deny. The deny that holds is its **tool access policy at global scope** (only the global scope can deny; custom-agent and thread scopes can only allow), and the control to rely on is still Azure RBAC on its identity ([tool access policies](https://learn.microsoft.com/azure/sre-agent/tool-access-policies), [agent hooks](https://learn.microsoft.com/azure/sre-agent/agent-hooks)).
- **Azure RBAC conditions don't limit control-plane deletes by tag.** Conditions apply to storage data actions and to role assignment management (delegation conditions can limit `roleAssignments/write` and `delete` to named principals or roles). A "delete only what is tagged" identity has to be scoped by resource group instead, and Azure Policy's `denyAction` on `delete` protects tagged resources ([ABAC conditions](https://learn.microsoft.com/azure/role-based-access-control/conditions-overview), [delegation conditions](https://learn.microsoft.com/azure/role-based-access-control/delegate-role-assignments-overview), [denyAction](https://learn.microsoft.com/azure/governance/policy/concepts/effect-deny-action)).
- **MCP approval is never the write approval.** An MCP or Foundry tool approval answers inside the conversation; every change still goes through avd-swarm's plan, gate and GitHub Environment.

## Native Azure automation services: Logic Apps Automation, SRE Agent, API Management

Checked on 2026-10-21 when the owner asked whether these native services could replace something we build. Prices are North Central US list prices from the Azure retail prices API. Nothing was deployed or run. Verdicts: SRE Agent stays the optional add-on in avd-swarm spec 3a (a 30-day sandbox pilot is proposed); Logic Apps Automation is reference only; API Management is watched until avd-swarm runs models from Azure.

- **Logic Apps Automation (auto.azure.com) is a preview with a standing meter.** Its environment bills $0.0504 an hour in North Central US (about $37 a month) whether or not anything runs, plus execution-seconds, connector actions and AI credits. Its model picks each next step at run time, and Microsoft points predictable processes at Logic Apps Standard or Consumption instead ([overview](https://learn.microsoft.com/azure/logic-apps/automation/dynamic-workflow-automation-introduction), [compare](https://learn.microsoft.com/azure/logic-apps/automation/compare-automation-services)).
- **Logic Apps Automation workflows can't be kept as code yet.** The docs show browser authoring only (chat assistant, designer, templates) and no Git, export or Bicep path, so a public repo can't hold what runs. Look again at GA or when an export appears. It isn't an AVD endpoint either: session hosts and clients never contact auto.azure.com.
- **SRE Agent bills until it is deleted.** Always-on is 4 AAU an hour per agent ($0.10 per AAU, about $292 a month), and a stopped agent still pays it; deleting is the only way to stop. New customers get a 30-day evaluation that waives always-on, though the pricing page's FAQ says otherwise, so check the meter on day one. Active use is tokens metered as AAU, for example 100 AAU per 1M input tokens on Claude Opus 4.6 and 35 on GPT 5.2 ([pricing](https://learn.microsoft.com/azure/sre-agent/pricing-billing)).
- **SRE Agent deploys as code.** Microsoft's microsoft/sre-agent templates deploy the `Microsoft.App/agents` resource, its identity and role assignments from Bicep; hooks, code repositories and knowledge files still go through the data plane ([deploy as code](https://learn.microsoft.com/azure/sre-agent/deploy-iac)). Its command guardrails always block delete and Key Vault commands.
- **API Management's MCP and token-limit features skip the Consumption tier.** Consumption gives 1M calls a month free and then $0.035 per 10K calls, but it can't expose MCP servers or run `llm-token-limit`. Developer (about $48 a month, no SLA), Basic v2 (about $150 a month) and up can. `llm-token-limit` handles Anthropic Messages only on the v2 tiers ([MCP servers](https://learn.microsoft.com/azure/api-management/mcp-server-overview), [llm-token-limit](https://learn.microsoft.com/azure/api-management/llm-token-limit-policy)).
- **The AI Gateway tier's runtime keys are secrets that reach everything.** The preview tier (East US 2 and Sweden Central, pricing not announced) authenticates clients with an `api-key` header, and each key can call every model and tool on the gateway. That conflicts with keyless identities and per-agent allowlists, so it isn't a fit until Entra client authentication arrives ([AI Gateway tier](https://learn.microsoft.com/azure/api-management/ai-gateway-overview)).

## Open-source core, optional adapters: what the prior-art check found (2026-10-21)

Checked on 2026-10-21 when the owner dropped the SRE Agent pilot as cost-prohibitive and asked for open-source alternatives inside avd-swarm, with paid Microsoft services as optional adapters ([avd-swarm core-and-adapters.md](https://github.com/avd-ops/avd-swarm/blob/main/docs/core-and-adapters.md), proposed; decision 0023 applied). Licenses were read from each repo's LICENSE file at source. Nothing was deployed or run. Verdict: none of the projects below does avd-swarm's job (keyless Entra identities end to end, the kill switch flag before every call, pseudonymized facts, no Kubernetes, Cloud Shell), so avd-swarm builds and they are the parity checklist.

- **HolmesGPT (Apache-2.0, CNCF sandbox) is the open-source investigator to measure against.** Read-only by design, toolsets declared in YAML with per-toolset instructions, any LLM provider, alert fetch and write-back, and an Operator mode (alpha) with `HealthCheck`, `ScheduledHealthCheck` and `TriggeredHealthCheck` as Kubernetes resources, each run costing at least one model call. It needs a Kubernetes cluster and a Helm chart, which fails the family's Cloud Shell and cost rules for one operator ([repo](https://github.com/robusta-dev/holmesgpt)).
- **Its Azure reads go through Azure's `azure-api-mcp` (MIT), not the Azure MCP Server.** A Go server that wraps the Azure CLI with a `--readonly` mode, read-only patterns and managed or workload identity sign-in. A second Microsoft-maintained Azure MCP server to know about; avd-swarm keeps the Azure MCP Server (`microsoft/mcp`, MIT) because its `virtualdesktop` namespace and per-tool `--read-only` annotations are what the allowlists already use ([repo](https://github.com/Azure/azure-api-mcp)).
- **LLM gateways with budgets exist, but their identity model is keys.** Bifrost (Apache-2.0) governs by virtual keys with hierarchical dollar budgets (customer, team, key, provider), rate limits and per-key MCP tool allowlists with default deny; LiteLLM's core is MIT while its `enterprise/` directory (SSO, JWT auth, audit logs) is separately licensed. A virtual key is a secret, which the family rules forbid, and neither does Anthropic workload identity federation or reads a kill switch flag, so avd-swarm's metered client stays its own and these are the checklist for budget hierarchy, default deny and audit ([Bifrost](https://github.com/maximhq/bifrost), [LiteLLM](https://github.com/BerriAI/litellm)).
- **IBM's MCP Context Forge (Apache-2.0) is the MCP gateway checklist:** federation of MCP servers, REST-to-MCP, per-server policy. avd-swarm's tool layer, published as an MCP server with Entra app-role auth, is measured against what it logs and refuses ([repo](https://github.com/IBM/mcp-context-forge)).
- **The Agent Governance Toolkit (MIT) is in public preview at v4.1.0** with a Rust policy core, YAML, OPA and Cedar policies, an MCP security gateway (tool poisoning, typosquatting, hidden instructions) and an in-process kill switch in its SRE package; avd-swarm uses it only as the gate's allow-or-deny evaluator, vendored and offline, within governance section 2.1's limits ([repo](https://github.com/microsoft/agent-governance-toolkit)).
- **SRE Agent's runbooks are Markdown or text knowledge files**, up to 50 MB each and 1,000 per custom agent, indexed for the agent to query; custom agents are YAML (name, system prompt, handoff description, tools, connectors) and get the whole conversation on handoff, and their mode (Review or Autonomous) is set per response plan or scheduled task, not in the YAML ([custom agents](https://learn.microsoft.com/azure/sre-agent/sub-agents)). avd-swarm's runbooks-as-code format keeps the steps fixed in front matter and treats the Markdown as untrusted text.
- **Logic Apps Automation stays reference only** (see the section above): its workflow chooses the next step at run time, and Microsoft points predictable, scheduled jobs at Logic Apps Standard or Consumption ([compare](https://learn.microsoft.com/azure/logic-apps/automation/compare-automation-services)). avd-swarm's scheduled checks run as GitHub Actions `schedule` jobs in the adopter's private repo with an OIDC read-only identity.

### Built: runbooks, the gateway and adapters (2026-10-21)

The owner said yes to the plan on 2026-10-21; work packages WP0, WP1, WP3 (library mode) and WP5 were built offline in [avd-swarm #39](https://github.com/avd-ops/avd-swarm/pull/39) ([decision 0009](https://github.com/avd-ops/avd-swarm/blob/main/docs/decisions/0009-open-source-core-optional-adapters.md)). Nothing ran against Azure. What building them taught:

- **A runbook's facts are checked in code before any model call, so a clear run costs no tokens.** The front matter names reads (tools by allowlist, KQL only by catalog ID), facts as `measure` (`rows`, `sum:`, `max:` or `min:` of a column), `op` and `value`, and `onFail: investigate` or `report`; only `investigate` facts reach the agent. A read that fails or a column that is missing gives `could-not-run`, never `clear` ([runbooks](https://github.com/avd-ops/avd-swarm/tree/main/runbooks)).
- **"No rows" is not "healthy" in AVD's agent table.** A query that keeps only hosts whose status isn't `Available` returns nothing when an agent stops reporting or the diagnostic setting is gone. Keep every host's latest report over a longer window, flag hosts that went silent while not `Shutdown`, and make "no reports at all" a finding of its own. *Unverified:* the two-hour silence threshold and the status a deallocated host last reports are to be confirmed on the first sandbox run ([WVDAgentHealthStatus](https://learn.microsoft.com/azure/azure-monitor/reference/tables/wvdagenthealthstatus)).
- **`WVDConnections.SessionHostName` is the host's FQDN** ([table reference](https://learn.microsoft.com/azure/azure-monitor/reference/tables/wvdconnections)); compare it with the agent table on the lowercased name before the first dot. `WVDErrors` carries `CodeSymbolic`, `Source` and `ServiceError`, so connection failures can be counted without any user name leaving the workspace ([WVDErrors](https://learn.microsoft.com/azure/azure-monitor/reference/tables/wvderrors)).
- **The Azure MCP Server's AVD tool names aren't on Learn.** Its page lists what the `virtualdesktop` tools do and their read-only annotations, not their names, so the allowlists stay drafts until the S1a run lists them with `list_mcp_tools.py` ([tools](https://learn.microsoft.com/azure/developer/azure-mcp-server/tools/azure-virtual-desktop)).
- **A spend counter shared by processes fits one Table Storage partition.** The day, the month and the caller-day rows share the month as partition key, so one entity group transaction with `IfNotModified` etags reserves on all three or none, and one partition query reads them. A counter that can't be read or written refuses the call.
- **Configuration that guards the kill switch must fail closed.** Reading `refuseModelCallsAt: halt-agents` (a string, not a list) with `list()` gives characters, and no position would refuse; a `.nan` cap makes every `>` comparison false. Validate the type, the members and finiteness when loading, and refuse to start otherwise.
- **An alert can start an investigation with no GitHub credential in Azure** (avd-swarm WP6, offline so far). GitHub has no inbound OIDC, so the path is alert rule, action group (common alert schema), Consumption Logic App, storage queue holding only the alert ID, Container Apps Job with the queue scaler: every hop a managed identity, shared key access off. The job reads the alert back from Azure Monitor and trusts nothing else in the message ([event-driven jobs](https://learn.microsoft.com/azure/container-apps/jobs#event-driven-jobs), [managed identity scale rules](https://learn.microsoft.com/azure/container-apps/managed-identity#use-managed-identity-for-scale-rules)).
- **A queue-triggered job can bill forever on one stuck message.** The scaler starts an execution every polling interval while a message is visible; a job that exits without touching it (an unreadable kill switch) restarts every minute. Receive first so the message is hidden for the visibility timeout and its dequeue count rises, drop it after a few tries, and keep the visibility timeout longer than the message's work and shorter than the replica timeout.
- **To confirm in the first sandbox run:** the scaler's identity likely needs Storage Queue Data Reader (queue length) besides Message Processor, and reading an alert by its subscription-scoped ID likely needs Monitoring Reader on the subscription, not on the target resource group. Both are granted that way in avd-swarm's `templates/alert-path/` until the run says otherwise.
- **azure-identity's async credentials need aiohttp, and nothing warns until start-up.** `azure.identity.aio.ManagedIdentityCredential` builds its default transport on aiohttp, which `azure-identity` doesn't install, so a service that pins only `azure-identity` fails at import with "aiohttp package is not installed" (found offline in avd-swarm's S1a agent API before any run). Pin aiohttp beside it, or use the sync credential ([azure-identity async](https://learn.microsoft.com/python/api/overview/azure/identity-readme)).
- **A synchronous endpoint behind Container Apps ingress needs one deadline under 240 seconds.** Ingress ends a request at 240 s, so avd-swarm's `POST /runbook` holds every token exchange, read and model call to one 200 s deadline and cancels what passes it: the caller always gets the finding the API kept, never a 504 while the work goes on. Long work belongs in a job the caller polls, as the S1a `/ask` does ([ingress](https://learn.microsoft.com/azure/container-apps/ingress-overview)).
- **A read only the agent uses doesn't decide a runbook's outcome.** A runbook's outcome rests on its facts: a failed read a fact needs is `could-not-run`, but a failed read kept only as context for the investigation (avd-swarm's `hosts` tool read) is listed in `failedReads` and leaves the outcome alone, so a draft tool parameter can't hide a real finding.
- **YAML 1.1 reads a bare `off` as `false`.** PyYAML's `safe_load` turns `default: off` into a boolean, so a check for the string `off` alone refuses a correct manifest; accept both and nothing else.

## Securing the agents and AVD security signal

Checked on 2026-10-19 for [avd-swarm's security tooling proposal](https://github.com/avd-ops/avd-swarm/blob/main/docs/security-tooling.md) (avd-swarm PR #14, merged; the first build, in the S1a spike, is proposed in avd-swarm PR #30). The tools themselves are documented upstream: [Prompt Shields](https://learn.microsoft.com/azure/ai-services/content-safety/concepts/jailbreak-detection), [PyRIT](https://github.com/microsoft/PyRIT), [garak](https://github.com/NVIDIA/garak), decoy MCP tools such as [Beelzebub](https://github.com/beelzebub-labs/beelzebub), [Sentinel MCP custom tools](https://learn.microsoft.com/azure/sentinel/datalake/sentinel-mcp-create-custom-tool) and the [Canarytokens Entra ID token](https://docs.canarytokens.org/guide/entraid-token); this section keeps only what applies to the AVD repos. Nothing has been deployed or run.

- **Foundry guardrails don't cover the Anthropic path.** avd-swarm's build steps 1 and 2 call Claude through Anthropic's API from a Container App, where Foundry's indirect-injection checks never run; and in Foundry, tool-response scanning is preview and document-attack detection is off by default ([Prompt Shields concepts](https://learn.microsoft.com/azure/ai-services/content-safety/concepts/jailbreak-detection)). Scan untrusted text in the model client instead, which works on any provider.
- **Prompt Shields limits and regions** (checked 2026-10-21): one call takes a `userPrompt` of up to 10K characters and up to five `documents` totaling 10K characters, and both fields are required (send an empty string or list). avd-swarm's client cuts long tool output into documents of 1,000 code points, each overlapping the next by 100, so an instruction of up to 100 characters that crosses a cut is seen whole by one document, five to a call; 1,000 code points stay under 2,000 UTF-16 units, so the 10K limit holds whichever unit the service counts ([service limits](https://learn.microsoft.com/azure/ai-services/content-safety/region-availability#service-limits), [quickstart](https://learn.microsoft.com/azure/ai-services/content-safety/quickstart-jailbreak)). Standalone Content Safety offers it in North Central US and East US 2, among others. Billing counts a text record per 1,000 characters, and the free tier (F0) gives 5,000 a month with one F0 resource of a kind per subscription.
- **Keyless Content Safety:** set `disableLocalAuth` and a custom subdomain (Entra tokens need it), and give the caller Cognitive Services User on that one resource, token scope `https://cognitiveservices.azure.com/.default`. The role also carries `listKeys`, which is moot once local auth is off.
- **No upstream AVD hunts.** Azure/Azure-Sentinel (MIT) has no Azure Virtual Desktop solution and no hunting query on the `WVD*` tables (checked 2026-10-19). AVD hunts have to be written, and are a candidate to give back upstream once proven (decision 0011).
- **RDP transport is in `WVDConnections.TransportType`** (`Shortpath`, `TURN`, `Websocket`); there is no `UdpUse` column. The client address is `ClientSideIPAddress` ([table reference](https://learn.microsoft.com/azure/azure-monitor/reference/tables/wvdconnections)).
- **Run AVD hunts through Log Analytics first.** The agents' Log Analytics Reader on the AVD resource groups runs them keyless in any tenant. Sentinel MCP custom tools need the Sentinel data lake and Defender licenses, are preview and invite-only, and an unattended client can sign in keylessly only from a Logic App's managed identity; the other app option needs a client secret ([custom tools](https://learn.microsoft.com/azure/sentinel/datalake/sentinel-mcp-create-custom-tool), [connector](https://learn.microsoft.com/connectors/sentinelmcp/)).
- **The Canarytokens Entra ID login token can't be added to most tenants any more.** It relies on custom CSS in company branding, which tenants created after 2026-01-05 don't have and which tenants not already using it can't configure after 2026-07-21 ([company branding](https://learn.microsoft.com/entra/fundamentals/how-to-customize-branding)).

## avd-buddy's voice: teaching, humor and calm

Checked on 2026-10-20 for [avd-swarm's voice spec](https://github.com/avd-ops/avd-swarm/blob/main/docs/buddy-voice.md) (proposed). The owner asked for a chat front end that teaches first, is witty but never risque or controversial, and helps in stressful moments. Nothing was run.

- **The published voice guides agree on the shape and leave the safety to us.** Microsoft's voice is warm and relaxed, crisp and clear, ready to lend a hand, and shifts tone from serious to lighthearted with the reader's state of mind ([brand voice](https://learn.microsoft.com/style-guide/brand-voice-above-all-simple-human)); Mailchimp puts clarity over entertainment and says to keep a straight face when unsure ([voice and tone](https://styleguide.mailchimp.com/voice-and-tone/)); Nielsen Norman Group's four dials (funny, formal, respectful, enthusiastic) give the vocabulary ([tone dimensions](https://www.nngroup.com/articles/tone-of-voice-dimensions/)); Claude's constitution names "a playful wit balanced with substance and depth" ([constitution](https://www.anthropic.com/constitution)). None says how to keep a model's humor away from approvals, plans or facts.
- **Let code pick the mode, not the model.** The tool layer already knows when a plan, an approval, a destructive step, the kill switch or a security finding is on screen, so a pure function can switch the voice to calm before the model writes a word. The model may only ask for the calmer mode.
- **Put the joke in its own field and make it unable to carry a fact.** One optional sentence, checked in code for banned topics and for digits, links, code, IDs and estate names, dropped silently on any finding and never kept in history, plans or evals. Plans and approval text stay rendered from the plan store, so no tone reaches them.
- **Wit doesn't translate.** Microsoft's global writing tips say to avoid idioms and culture-specific references ([writing tips](https://learn.microsoft.com/style-guide/global-communications/writing-tips)), so the aside is English-only and the answer stays plain in every language.

## avd-buddy as an installable web app

Checked on 2026-10-20 for [avd-swarm's app spec](https://github.com/avd-ops/avd-swarm/blob/main/docs/buddy-app.md) (proposed). The owner asked for a mobile app for the chatbot that can be an installable web app (PWA) for now. Nothing was built or run.

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
