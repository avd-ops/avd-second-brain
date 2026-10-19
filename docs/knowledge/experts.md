---
title: "Experts we follow"
summary: "How we choose which AVD, FSLogix and Entra experts the KB follows: the method, the scores and the list"
topic: curation
status: verified
last_reviewed: 2026-10-18
---

# Experts we follow

The weekly digest ([curation.md](curation.md#weekly-digest-kb-curator)) watches a set of people
who write about Azure Virtual Desktop, FSLogix, Entra for AVD and the tooling around them. This page explains how that
list is chosen, so anyone can check it, re-run it or challenge it. The data is in
[experts.yaml](experts.yaml), and the tables below are generated from it. The method is the same in
every KB of the family; each KB scores people against its own topic.

<!-- BEGIN GENERATED: experts-balance (from experts.yaml; run scripts/kb/build.py) -->
Last scored 2026-10-18: 14 tracked (4 other-vendor, 4 unknown, 3 independent, 2 microsoft, 1 partner), 17 on the watch list, 4 declined, 0 nominated and waiting to be scored.
<!-- END GENERATED: experts-balance -->

## The method

It works like a small systematic review: the rules are fixed before anyone is scored, they're
applied the same way to everyone, and every score points at evidence.

### 1. Find candidates in several places

One list brings its author's blind spots with it, so candidates come from several channels, and
each entry records which ones found it (`found_via`):

- Microsoft's channels: the AVD and FSLogix product teams' blogs, docs authors, and the MVP
  program's Azure Virtual Desktop and Windows 365 categories
- Speakers at EUC and Azure conferences, community events and webinars
- GitHub: maintainers of AVD tools and modules people use, and the KB's prior-art searches
- Blogs and newsletters that post on these topics more than once
- Snowballing: who the people already on the list link to, cite or present with
- The sibling KBs' expert lists ([family.yaml](family.yaml)); use the same `id` for the same person
- Nominations through the **Suggest an expert to follow** issue form

### 2. Apply the gates

A candidate must pass all four gates to be tracked. Organizations go through the same gates and
scores as people. Failing identity or originality declines them; failing only recency or feed puts
them on the watch list if their score is high enough.

| Gate | Passes when |
|---|---|
| Original | They publish their own technical content, not just reshares or marketing |
| Recent | They've posted on the topic in the last 12 months |
| Feed | A free, machine-readable feed exists: blog RSS or Atom, a YouTube channel or a GitHub account. X isn't one, because its API is paid |
| Identity | We know who's behind every account we'd watch: one of their own profiles links the others, or we watch only one account |

### 3. Score five things from 0 to 3

| Score | 0 | 1 | 2 | 3 |
|---|---|---|---|---|
| Relevance | Rarely on topic | Occasionally | A regular topic | Their main topic |
| Depth | Announcements only | Overviews | How-tos with steps | Code, evals or gotchas others can reuse |
| Recency | Nothing on topic in 12 months | Within 12 months | Within 6 months | Within 3 months |
| Track record | Unknown | Some engagement | Cited or reused by others | Widely cited, or maintainer of a tool people use |
| Feedability | No free feed | A feed, mostly off topic | A feed that keyword filters can fix | A clean, on-topic feed |

The total is out of 15.

- **Tracked:** all gates pass and the total is 10 or more. They get a `[[source]]` in
  [sources.toml](sources.toml) with `expert = "<id>"`.
- **Watch:** identity and originality pass and the total is 6 or more. Re-checked each review, not
  in the digest.
- **Declined:** everything else, with the reason, so the same person isn't re-researched for
  nothing.

`scripts/kb/validate.py` enforces these rules: an entry's status must match its gates and scores,
every tracked expert must have a source, and every source with an `expert` must be tracked.

**Affiliation is recorded but not scored.** Microsoft staff and partners often know the product
best, so they aren't marked down. The summary above shows the mix, so a list that's all one company's voices is
visible.

### 4. Measure and review

- **Yield:** the monthly freshness check reads recent digest issues and counts, per tracked
  expert, how many of their items were ticked as worth adding. A source that lists nothing, or
  only items nobody ticks, is flagged to re-score or narrow with `keywords`.
- **Cadence:** everyone is re-scored every 90 days. The freshness check lists anyone not re-scored
  in 90 days and any nomination waiting to be scored.
- **Nominations:** the issue form adds the person as `nominated`. When a maintainer labels it
  `kb-accepted`, the feedback workflow opens a PR, and the maintainer scores them in that PR.

### What's recorded about people

Only what they publish professionally: the name they use, their public links, and their
affiliation if they state it. No emails, locations or other personal details. Anyone listed can
ask to be removed by opening an issue.

## Tracked

<!-- BEGIN GENERATED: experts-tracked (from experts.yaml; run scripts/kb/build.py) -->
| Name | Affiliation | Links | Score (rel/depth/recency/record/feed) | Latest AVD post | Notes |
|---|---|---|---|---|---|
| Dean Cefola (Azure Academy) | independent | [YouTube](https://www.youtube.com/channel/UC-MXgaFhsYU8PkqgKBdnusQ), [GitHub](https://github.com/DeanCefola) | 14 (3/2/3/3/3) | [2026-10-01](https://www.youtube.com/shorts/Z-F4fqsIzQc) | Former Microsoft principal engineer, now Azure Academy LLC. Recent Shorts cover Entra Kerberos, FSLogix and Azure Files errors; the sibling missed them because it didn't check Shorts. The channel feed couldn't be fetched (YouTube blocks robots), so the feed URL is built from the verified channel ID. |
| Marcel Meurer | other-vendor | [blog](https://blog.itprocloud.de/), [GitHub](https://github.com/MarcelMeurer) | 14 (3/3/3/3/2) | [2026-09-02](https://blog.itprocloud.de/Azure-Virtual-Desktop-Hybrid-With-Hydra-IS-GA-General-Available/) | Makes WVDAdmin and Hydra, now owned by a vendor, so he's other-vendor here (the sibling has independent). Filter out product and event posts. |
| Wayne Bellows | other-vendor | [blog](https://modern-euc.com/), [GitHub](https://github.com/WayneBellows) | 14 (3/3/3/2/3) | [2026-10-08](https://modern-euc.com/2026/10/08/how-to-update-an-avd-golden-image-to-windows-11-26h2-without-a-bad-monday/) | Nerdio TAM, but most of the feed is AVD images, AVD platform news and Entra, plus FSLogix scripts on GitHub. Only about one post in ten is Nerdio-specific. |
| Justin Verstijnen | unknown | [blog](https://justinverstijnen.nl/), [GitHub](https://github.com/JustinVerstijnen) | 13 (3/3/3/1/3) | [2026-10-11](https://justinverstijnen.nl/fix-windows-app-grey-screen-windows-11-26h2-webview2/) | Step-by-step AVD, FSLogix and Entra Kerberos guides and fixes, about one a month. The feed is his AVD category only, so it needs no keywords; no evidence yet of others citing him. |
| Microsoft Azure Virtual Desktop blog | microsoft | [blog](https://techcommunity.microsoft.com/category/azure/blog/azurevirtualdesktopblog) | 13 (3/1/3/3/3) | [2026-10-01](https://techcommunity.microsoft.com/t5/azure-virtual-desktop-blog/now-generally-available-regional-resiliency-for-azure-virtual/ba-p/4540458) | Official AVD announcements by the product team, roughly monthly. Already watched in sources.toml; that entry gets expert = "microsoft-avd-blog" rather than a second source. |
| Neil McLoughlin | other-vendor | [blog](https://virtualmanc.co.uk/), [YouTube](https://www.youtube.com/channel/UCS5W4f_rZexpCnBF1tSh1XA), [GitHub](https://github.com/virtualmanc) | 13 (3/2/2/3/3) | [2026-07-15](https://www.virtualmanc.co.uk/2026/07/15/context-based-redirection-in-avd-windows-365-guide/) | Nerdio TAM and Microsoft MVP; his blog is AVD-general and rarely Nerdio. Posts only a few times a year; his newer blog, virtualdesktops.community, still wasn't checked. |
| Aaron Parker | other-vendor | [blog](https://stealthpuppy.com/), [GitHub](https://github.com/aaronparker) | 12 (2/3/2/3/2) | [2026-05-11](https://stealthpuppy.com/dynamic-groups-azure-virtual-desktop/) | Nerdio employee. Evergreen is widely used to build session host images; the blog posts on AVD and Entra a few times a year. The sibling's sources.toml uses /feed.xml while this uses /feed/, which was fetched and works. |
| Cristian Schmitt Nieto | partner | [blog](https://schmitt-nieto.com/), [GitHub](https://github.com/schmittnieto) | 12 (2/3/3/2/2) | [2026-09-22](https://schmitt-nieto.com/blog/azure-local-avd-entra-join/) | Nerdio NVP who maintains the awesome-azure-virtual-desktop list. Writes mostly about Azure Local now, with AVD-on-Azure-Local and Entra join posts, so the feed is filtered to AVD. |
| Duo Infernale (Michele Blum and Flavio Meyer) | unknown | [blog](https://duo-infernale.ch/) | 12 (3/2/3/1/3) | [2026-10-14](https://duo-infernale.ch/azure-virtual-desktop-now-available-in-your-region-ga/) | Frequent AVD and Entra-for-AVD how-tos, several a month. Accounts aren't cross-linked, so only the blog is watched. |
| Microsoft FSLogix blog | microsoft |  | 12 (3/2/1/3/3) | [2026-03-27](https://techcommunity.microsoft.com/t5/s/gxcuf89792/rss/board?board.id=FSLogix-Blog) | Release, known-issue and action-required posts from the FSLogix product team, mostly by Jason Parker; latest was the RC4 Kerberos hardening notice. No post for release 26.08 was in the feed; latest.url is the feed because the post URL wasn't captured. Already in sources.toml; add expert there. |
| Wayne Markovich | independent | [blog](https://markovich.io/), [GitHub](https://github.com/wmarkovich) | 12 (3/2/3/1/3) | [2026-10-13](https://markovich.io/windows-11-image-versioning-avd-copilot-fslogix/) | Posts almost daily on AVD, FSLogix and Entra without saying how the posts are written; keep the sibling's probation and spot-check a sample for accuracy at the next review. |
| ModernWorkspaceHub | unknown | [blog](https://modernworkspacehub.com/), [GitHub](https://github.com/durrante) | 11 (2/3/3/1/2) | [2026-09-09](https://modernworkspacehub.com/expand-azure-vm-os-disk/) | Session host disk sizing with Bicep and an AVD monitoring baseline, useful for landing zone and operations. Low volume (about one post a month) and the author signs only as Alex. |
| Ryan Mangan | independent | [blog](https://www.democratising-clouds.com/) | 11 (2/2/2/3/2) | [2026-06-21](https://www.democratising-clouds.com/blog/native-msix-or-app-attach-avd-decision-study) | Microsoft MVP and author of Mastering Azure Virtual Desktop. Writes on app attach, MSIX and AVD versus Windows 365; quiet since June, so re-check recency at the next review. |
| Travis Roberts (Ciraltos) | unknown | [blog](https://www.ciraltos.com/), [YouTube](https://www.youtube.com/channel/UCuB24cID6NnypDWSLe4gfqA) | 11 (2/2/3/2/2) | [2026-09-09](https://www.ciraltos.com/azure-virtual-desktop-hybrid-is-now-ga-6-reasons-to-use-it-and-2-reasons-to-reconsider/) | AVD, FSLogix storage and Entra explainers with video walkthroughs, mixed with AI exam posts, so the blog is filtered to AVD. Only the blog is watched. |
<!-- END GENERATED: experts-tracked -->

## Watch list

<!-- BEGIN GENERATED: experts-watch (from experts.yaml; run scripts/kb/build.py) -->
| Name | Affiliation | Links | Score (rel/depth/recency/record/feed) | Latest AVD post | Notes |
|---|---|---|---|---|---|
| Alex ter Neuzen | unknown | [blog](https://www.gettothe.cloud/), [GitHub](https://github.com/GetToThe-Cloud) | 9 (1/3/3/1/1) | [2026-09-24](https://www.gettothe.cloud/azure-virtual-desktop-sessionhost-monitoring-2-0/) | Deep AVD monitoring work, but one post in ten is AVD; the rest is Azure Local. Re-score if AVD on Azure Local becomes a regular topic. |
| Johan Vanneuville | partner | [blog](https://johanvanneuville.com/) | 9 (2/2/1/2/2) | [2026-03-02](https://johanvanneuville.com/avd/get-avd-hosts-outbound-internet-access-in-2026-using-a-nat-gateway/) | Nerdio NVP. Half the feed is AVD-general (networking, managed identities, ephemeral disks), the rest Nerdio; last AVD-general post was March 2026. |
| Marius Sandbu | unknown | [blog](https://msandbu.org/) | 9 (1/3/1/3/1) | [2026-10-16](https://msandbu.org/getting-started-with-azure-sre-agent-and-some-success-stories/) | Writes on Azure, security and AI now; his latest post uses an AVD and FSLogix outage as an SRE agent example. Only the blog is watched. |
| Mobile Jon | partner | [blog](https://mobile-jon.com/), [YouTube](https://www.youtube.com/channel/UCJBM-j8va7lrwTZBWSXt7vw), [GitHub](https://github.com/mobilejon) | 9 (1/3/2/2/1) | [2026-05-14](https://mobile-jon.com/) | Nerdio NVP. Mostly Intune and Entra; his two AVD posts this year are about vendor tools. |
| Nerdio (YouTube channel) | other-vendor | [YouTube](https://www.youtube.com/channel/UClzdOrR9o0I05hnnByEKIKA), [GitHub](https://github.com/Get-Nerdio) | 9 (1/1/3/3/1) | none found | Product webinars and release walkthroughs; Nerdio Manager belongs to nerdio-hcl, which tracks it. Recency reused from the sibling's study, not re-checked. |
| Bas van Kaam | other-vendor | [blog](https://www.basvankaam.com/) | 8 (2/2/0/3/1) | [2023-04-11](https://www.basvankaam.com/) | Fails: recent. Nerdio employee. The feed still works but has nothing since the AVD security cheat sheet of April 2023. |
| Fabian Rodrigues | unknown | [blog](https://fabssolutions.co.uk/blog) | 8 (2/2/3/1/0) | [2026-10-13](https://fabssolutions.co.uk/index.php/blog/detail/microsoft-global-secure-access-for-avd-windows-365-external-identities-token-protection-and-zero-trust-architecture) | Fails: feed. Found this time: AVD, FSLogix and Windows 365 guides with commands on fabssolutions.co.uk. No RSS feed was found, and several posts share one date, so check how they're written before tracking. |
| Jim Moyle | microsoft | [GitHub](https://github.com/JimMoyle) | 8 (2/3/0/2/1) | none found | Fails: recent. Microsoft, formerly FSLogix; maintains Community.AppAttach for app attach lifecycle. Recent activity couldn't be dated without the GitHub API, so recency is scored 0 until checked. |
| John Savill | microsoft | [YouTube](https://www.youtube.com/channel/UCpIn7ox7j7bH_OFj7tYouOQ) | 8 (1/3/0/3/1) | none found | Fails: recent. Microsoft employee whose personal channel does deep Azure explainers, AVD only occasionally. No AVD video in the last 12 months could be verified (YouTube blocks fetching), so recency is 0. |
| Shabaz Darr | partner | [YouTube](https://www.youtube.com/channel/UCt5sNdu14RterwDfEDEJidQ) | 8 (2/2/0/3/1) | [2025-07-22](https://www.youtube.com/watch?v=k27nZcv7sew) | Fails: recent. Microsoft MVP and Nerdio NVP. Reused from the sibling: newest video found is July 2025, and the channel moved to a new ID that wasn't found. |
| Thomas Marcussen | independent | [blog](https://blog.thomasmarcussen.com/) | 8 (1/2/2/2/1) | [2026-07](https://blog.thomasmarcussen.com/enhanced-host-pool-management-azure-virtual-desktop-ga-setup/) | Microsoft MVP and freelance consultant writing mostly on Intune and Entra; occasional AVD how-tos. The AVD post's exact date wasn't shown; July 2026 is when the feature went GA. |
| Aresh Sarkari | unknown | [blog](https://askaresh.com/) | 7 (1/3/0/2/1) | [2026-10-08](https://askaresh.com/2026/10/08/windows-365-local-admin-cloud-pc-configurations-vs-user-settings-powershell-graph-rest-api/) | Fails: recent. Writes on Windows 365 now (latest is Windows 365, not AVD); no AVD post in the last 12 months was found in the feed's short window. |
| Christiaan Brinkhoff | other-vendor | [blog](https://christiaanbrinkhoff.com/), [YouTube](https://www.youtube.com/channel/UCP894c8_Rgop-qANoVK6Vkg) | 7 (1/1/1/3/1) | [2026-02-26](https://www.youtube.com/watch?v=ETbS-R4n4bw) | Joined Nerdio in 2026 from Microsoft's Windows 365 and AVD team. The blog is now mostly speaking dates and books; one AVD episode in 2026. |
| Dominiek Verham | partner | [blog](https://dominiekverham.com/) | 7 (1/2/1/2/1) | [2026-07-23](https://dominiekverham.com/nerdio-manager-showdown-enterprise-vs-msp/) | Microsoft MVP and Nerdio NVP. Every recent post is Nerdio Manager, which nerdio-hcl tracks; AVD-general posts are older. |
| Sander Rozemuller | unknown | [blog](https://rozemuller.com/), [GitHub](https://github.com/srozemuller) | 7 (0/3/0/3/1) | none found | Fails: recent. Strong AVD automation history; the last ten posts are all Intune. |
| Stefan Dingemanse | partner | [blog](https://www.stefandingemanse.com/) | 6 (2/2/0/2/0) | [2024-03-26](https://www.stefandingemanse.com/2024/03/26/simplify-virtual-desktop-management-with-intune-filters-for-windows-365-and-avd/) | Fails: recent, feed. Microsoft MVP and Nerdio NVP who co-founded the AVD Community; still speaks on AVD with Intune, but the blog stopped in 2024 and its feed couldn't be fetched. |
| azureArchetype (Frametype Solutions) | unknown | [blog](https://azurearchetype.com/), [GitHub](https://github.com/azurearchetype) | 6 (1/3/1/0/1) | [2026-02-11](https://azurearchetype.com/2026/02/11/avd-observations-part-1.html) | Cloud-native AVD with Entra Kerberos and FSLogix, deployed by IaC, plus landing zone Bicep repos. The GitHub account is the feed; no blog feed was found and the post is the only AVD one seen. |
<!-- END GENERATED: experts-watch -->

## Declined

<!-- BEGIN GENERATED: experts-declined (from experts.yaml; run scripts/kb/build.py) -->
| Name | Affiliation | Links | Score (rel/depth/recency/record/feed) | Latest AVD post | Notes |
|---|---|---|---|---|---|
| AVD Community Newsletter | independent | [blog](https://avdcommunity.com/category/newsletter/) | 11 (3/0/3/2/3) | [2026-10-02](https://avdcommunity.com/avd-community-newsletter-2nd-october-2026/) | Fails: original. A curated roundup, not original content. Use it to find new people at each review; this study found Dean Cefola's Shorts through it. |
| AVD Punks | unknown | [blog](https://avdpunks.com/) | 6 (3/2/0/1/0) | none found | Fails: recent, feed, identity. AVD and Windows 365 posts by an unnamed group; the site shows no authors, dates or feed. |
| Patrick Coble | unknown | [blog](https://vdihacker.com/) | 6 (1/2/0/3/0) | none found | Fails: recent, feed, identity. Reused from the sibling without a new check: the site couldn't be read and no feed was confirmed. |
| Dane Young | partner | [blog](https://blog.youngtech.com/) | 5 (0/2/0/2/1) | none found | Fails: recent. Nerdio NVP. Current posts are about other VDI platforms; nothing on AVD. |
<!-- END GENERATED: experts-declined -->

## Nominated, not scored yet

<!-- BEGIN GENERATED: experts-nominated (from experts.yaml; run scripts/kb/build.py) -->
None waiting.
<!-- END GENERATED: experts-nominated -->
