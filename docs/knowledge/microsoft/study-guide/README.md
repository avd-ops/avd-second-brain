---
title: "AZ-140 and AZ-104 study guide"
summary: "A free, public study guide for the Azure Virtual Desktop Specialty (AZ-140) and Azure Administrator (AZ-104) exams"
topic: microsoft
status: verified
last_reviewed: 2026-10-28
sources:
  - https://learn.microsoft.com/credentials/certifications/azure-virtual-desktop-specialty/
  - https://learn.microsoft.com/credentials/certifications/azure-administrator/
---

# AZ-140 and AZ-104 study guide

**Bottom line:** study from Microsoft's own skills outline, use these pages to learn what each
objective means in practice and where it trips people up, then prove it with Microsoft's free
practice assessment. Book the exam once you score 80% or more on a cold run.

- [AZ-140: Azure Virtual Desktop Specialty](az-140.md): the exam the AVD family is built around.
- [AZ-104: Azure Administrator](az-104.md): the Azure platform underneath it.

Neither exam requires the other. If you build Azure Virtual Desktop already, AZ-140 first is the
shorter path; AZ-104 then fills in what AVD work rarely touches (App Service, containers, load
balancers, Site Recovery, self-service password reset).

## What this guide is, and isn't

- Every note and practice question here is original, written for this guide. None comes from an
  exam, and none is a "dump". Real exam questions are under NDA; don't share or ask for them.
- The objectives belong to Microsoft. Each page names the domain and links the official study
  guide instead of copying it, so the outline you study is always the current one.
- Where the [avd-landing-zone](https://github.com/avd-ops/avd-landing-zone) builds an objective,
  the page links the file, so you can read real Bicep and PowerShell for it.
- Personal project, not for production, as is. Not affiliated with Microsoft, the author's
  employer or Liquidware.

## Exam facts

Checked on Microsoft Learn on 2026-10-28. Facts change: confirm on the certification page before
you book.

| | AZ-140 | AZ-104 |
|---|---|---|
| Certification | [Azure Virtual Desktop Specialty](https://learn.microsoft.com/credentials/certifications/azure-virtual-desktop-specialty/) | [Azure Administrator Associate](https://learn.microsoft.com/credentials/certifications/azure-administrator/) |
| Skills outline | [AZ-140 study guide](https://learn.microsoft.com/credentials/certifications/resources/study-guides/az-140), updated 2026-07-20 | [AZ-104 study guide](https://learn.microsoft.com/credentials/certifications/resources/study-guides/az-104), updated 2026-04-17 |
| Passing score | 700 on a 1 to 1000 scale | 700 on a 1 to 1000 scale |
| Exam time | 100 minutes (120 if the exam has labs) | 100 minutes (120 if the exam has labs) |
| Seat time | Plan 20 minutes more, for the agreement and comments | Same |
| Renewal | Free online assessment on Learn, every 12 months | Same |

Times come from Microsoft's [exam duration](https://learn.microsoft.com/credentials/support/exam-duration-exam-experience)
page, which also explains breaks. The price varies by country; it shows at checkout.

## How to use it

1. Take Microsoft's free practice assessment cold, before studying, to find your weak domains.
   It is linked from each certification page; you sign in to start it.
2. Work the weakest domain first. For each objective, read the **Know** and **Trap** lines, then
   the Learn module the official study guide links for it.
3. Answer the practice questions on the exam's page without peeking. Each answer explains why the
   other options are wrong, which is where most of the learning is.
4. Build it. Microsoft publishes free step-by-step lab guides in the
   [MicrosoftLearning](https://github.com/MicrosoftLearning) GitHub organization, and the
   [landing zone's demo](https://github.com/avd-ops/avd-landing-zone/blob/master/docs/demo.md)
   deploys a small AVD estate you can study. Both run in your own subscription and cost money:
   price them first, use the smallest sizes and delete everything the same day.
5. Book when a cold practice run scores 80% or more, 7 to 10 days out, and use the time to fix
   your weakest domain. Under 70%, study another week and test again.

## On exam day

- Microsoft Learn is open inside the exam in a split pane, but the clock keeps running. Use it for
  one or two lookups, not as a crutch.
- Case studies lock once you leave them, so finish each before moving on.
- Try Microsoft's exam sandbox once, so drag-and-drop, hot area and yes/no series questions are not
  a surprise.
- Questions use current product names: Microsoft Entra ID (not Azure AD), Entra Domain Services,
  App Control for Business (not WDAC), Azure Local (not Azure Stack HCI).

## Help improve it

Found a wrong fact or an outdated answer? Open a [knowledge base feedback
issue](https://github.com/avd-ops/avd-second-brain/issues/new?template=kb-feedback.yml) with the question number and the Learn page
that disagrees. Please don't post anything from a real exam.
