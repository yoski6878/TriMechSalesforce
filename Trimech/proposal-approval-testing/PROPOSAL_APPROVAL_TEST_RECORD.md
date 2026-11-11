# Proposal approval rules - UAT test record

Prepared 2026-10-26 in TrimechUAT (sandbox, full copy of production). All test records are named **ZZ TEST** and belong to the account **ZZ TEST Approval Rules Account**. Owner of every opportunity: **Yoseph Kinfu**. Approver: **Jeremy (JJ) Jobin** (your Manager was set to him temporarily; his UAT email is scrambled, so no email goes out).

Before testing, all 27 proposals were run through the evaluation flow in Apex and matched the expected result in the table below (rolled-back checks, no data changed). The D1, D4 cases need the state change described in section 4 before the real submit.

## 1. One-time prerequisites (your manual steps)

1. Grant field-level security (read and edit) on: User > Hire Date, Product2 > Approval Trigger, Quote > Approval Required, Quote > Approval Reason. Add the two Quote fields to the Proposal page layout, and Hire Date to the User layout (or tell me and I will set the hire date for you).
2. Open a proposal and confirm you can see the **Submit for Review** action (the existing quick action).
3. Setup > Public Groups: confirm **Proposal Approval High Offenders** exists and is empty.

## 2. Baseline state (what "Baseline state" means)

- Your user: Hire Date blank; not a member of Proposal Approval High Offenders; not a member of the exempt group.
- Thresholds unchanged: discount over 10 percent, GP 50,000 or more, new hire 6 months.
- Renewal flag is set on only two products: SOLIDWORKS Design Premium - 1 Year Renewal and 1 Month Renewal. The full list of 1,968 flags is not loaded yet.

## 3. Test data

Each proposal can be submitted once. If you need to repeat a test, reject or recall it (it returns to Draft) or ask me for a fresh copy.

| ID | Proposal (link) | Opportunity | Lines | Before you submit | Action | Expected result | Expected Approval Reason |
|---|---|---|---|---|---|---|---|
| A1 | [A1 No rule matches](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Quote/0Q0Ot0000094dnBKAQ/view) | Rule Scenarios | Std Global Network w/ Cloud Services (not flagged) 9,558 | Baseline state (section 2) | Submit for Review | Toast 'This proposal was automatically approved'. Status Approved, Approval Status Approved, Is Submitted unchecked, Approval Required unchecked. | No approval criteria met - auto-approved |
| A2 | [A2 No lines](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Quote/0Q0Ot0000094dnCKAQ/view) | Rule Scenarios | (no lines) | Baseline state | Submit for Review | Toast 'This proposal was automatically approved'. Status Approved, Approval Status Approved, Is Submitted unchecked, Approval Required unchecked. | No approval criteria met - auto-approved (empty proposal; open question for the business) |
| B1 | [B1 Upgrade item](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Quote/0Q0Ot0000094dnDKAQ/view) | Rule Scenarios | Upgrade SOLIDWORKS Office Network to Professional Network 708.80 | Baseline state | Submit for Review | Toast 'Your request has been submitted for approval'. Status In Review, Approval Status In Process, Approval Required checked. | License change - upgrade |
| B2 | [B2 Conversion item](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Quote/0Q0Ot0000094dnEKAQ/view) | Rule Scenarios | Conversion SOLIDWORKS Professional Package to Professional Network 2,883 | Baseline state | Submit for Review | Toast 'Your request has been submitted for approval'. Status In Review, Approval Status In Process, Approval Required checked. | License change - conversion |
| B3 | [B3 Renewal item](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Quote/0Q0Ot0000094dnFKAQ/view) | Rule Scenarios | SOLIDWORKS Design Premium - 1 Year Renewal 1,995 (flagged Renewal) | Baseline state | Submit for Review | Toast 'Your request has been submitted for approval'. Status In Review, Approval Status In Process, Approval Required checked. | Renewal item |
| B4 | [B4 Discount 15 pct App Solutions](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Quote/0Q0Ot0000094donKAA/view) | Rule Scenarios | Not-flagged App Solutions product 9,558 with 15% discount | Baseline state | Submit for Review | Toast 'Your request has been submitted for approval'. Status In Review, Approval Status In Process, Approval Required checked. | Discount over threshold |
| B5 | [B5 Discount exactly 10 pct](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Quote/0Q0Ot0000094dooKAA/view) | Rule Scenarios | Same product with 10% discount | Baseline state | Submit for Review | Toast 'This proposal was automatically approved'. Status Approved, Approval Status Approved, Is Submitted unchecked, Approval Required unchecked. | No approval criteria met - auto-approved (exactly 10 percent is not over) |
| B6 | [B6 Discount 15 pct non-App Solutions](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Quote/0Q0Ot0000094dopKAA/view) | Rule Scenarios | Non-App-Solutions product 200 with 15% discount | Baseline state | Submit for Review | Toast 'This proposal was automatically approved'. Status Approved, Approval Status Approved, Is Submitted unchecked, Approval Required unchecked. | No approval criteria met - auto-approved (non-Application-Solutions product ignored) |
| B7 | [B7 Plain plus Upgrade](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Quote/0Q0Ot0000094doqKAA/view) | Rule Scenarios | Not-flagged product + Upgrade item | Baseline state | Submit for Review | Toast 'Your request has been submitted for approval'. Status In Review, Approval Status In Process, Approval Required checked. | License change - upgrade |
| C1 | [C1 GP 49999](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Quote/0Q0Ot0000094dorKAA/view) | Rule Scenarios | Not-flagged product, price 49,999, purchase cost 0 (GP 49,999) | Baseline state | Submit for Review | Toast 'This proposal was automatically approved'. Status Approved, Approval Status Approved, Is Submitted unchecked, Approval Required unchecked. | No approval criteria met - auto-approved (GP 49,999) |
| C2 | [C2 GP 50000](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Quote/0Q0Ot0000094dqPKAQ/view) | Rule Scenarios | Same, price 50,000 (GP 50,000) | Baseline state | Submit for Review | Toast 'Your request has been submitted for approval'. Status In Review, Approval Status In Process, Approval Required checked. | Gross profit at or over threshold (GP exactly 50,000) |
| C3 | [C3 GP 60000 non-App Solutions](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Quote/0Q0Ot0000094dqQKAQ/view) | Rule Scenarios | Non-App-Solutions product, price 60,000, cost 0 | Baseline state | Submit for Review | Toast 'Your request has been submitted for approval'. Status In Review, Approval Status In Process, Approval Required checked. | Gross profit at or over threshold (any item, not just Application Solutions) |
| D1 | [D1 New hire](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Quote/0Q0Ot0000094dqRKAQ/view) | Rule Scenarios | Not-flagged product 9,558 | Set YOUR Hire Date to 3 months ago (section 4) | Submit for Review | Toast 'Your request has been submitted for approval'. Status In Review, Approval Status In Process, Approval Required checked. | New hire (within 6 months) |
| D2 | [D2 Hired 7 months ago](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Quote/0Q0Ot0000094dqSKAQ/view) | Rule Scenarios | Same | Set YOUR Hire Date to 7 months ago | Submit for Review | Toast 'This proposal was automatically approved'. Status Approved, Approval Status Approved, Is Submitted unchecked, Approval Required unchecked. | No approval criteria met - auto-approved |
| D3 | [D3 Hire date blank](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Quote/0Q0Ot0000094dqTKAQ/view) | Rule Scenarios | Same | Clear YOUR Hire Date | Submit for Review | Toast 'This proposal was automatically approved'. Status Approved, Approval Status Approved, Is Submitted unchecked, Approval Required unchecked. | No approval criteria met - auto-approved (blank date is not a new hire) |
| D4 | [D4 High offender](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Quote/0Q0Ot0000094e3JKAQ/view) | Rule Scenarios | Same | Add yourself to public group Proposal Approval High Offenders | Submit for Review | Toast 'Your request has been submitted for approval'. Status In Review, Approval Status In Process, Approval Required checked. | High-offender rep |
| D5 | [D5 Removed from offender group](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Quote/0Q0Ot0000094ds1KAA/view) | Rule Scenarios | Same | Remove yourself from that group | Submit for Review | Toast 'This proposal was automatically approved'. Status Approved, Approval Status Approved, Is Submitted unchecked, Approval Required unchecked. | No approval criteria met - auto-approved |
| D6 | [D6 Exempt owner with Upgrade](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Quote/0Q0Ot0000094e6XKAQ/view) | D6 Exempt owner | Not-flagged product + Upgrade item | Opportunity is pre-flagged exempt (nothing to do) | Submit for Review | Toast 'This proposal was automatically approved'. Status Approved, Approval Status Approved, Is Submitted unchecked, Approval Required unchecked. | Exempt owner - approval not required (even though it has an Upgrade line) |
| E1 | [E1 All rules at once](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Quote/0Q0Ot0000094ds3KAA/view) | Rule Scenarios | Upgrade + Renewal + Not-flagged product 60,000 (cost 0) | Set YOUR Hire Date to 3 months ago again (and not in the group) | Submit for Review | Toast 'Your request has been submitted for approval'. Status In Review, Approval Status In Process, Approval Required checked. | New hire (within 6 months); Gross profit at or over threshold; Renewal item; License change - upgrade |
| E2 | [E2 Manager approves](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Quote/0Q0Ot0000094ds4KAA/view) | Rule Scenarios | Upgrade item | Baseline state | Submit for Review, then APPROVE (section 5) | Toast 'Your request has been submitted for approval'. Status In Review, Approval Status In Process, Approval Required checked. | License change - upgrade. After approval: Approval Status Approved, Is Submitted unchecked, Status still In Review |
| E3 | [E3 Manager rejects](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Quote/0Q0Ot0000094dvFKAQ/view) | Rule Scenarios | Upgrade item | Baseline state | Submit for Review, then REJECT | Toast 'Your request has been submitted for approval'. Status In Review, Approval Status In Process, Approval Required checked. | After rejection: Status Draft, Approval Status Rejected. Then submit again and confirm it is re-evaluated |
| E4 | [E4 Recall](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Quote/0Q0Ot0000094dvGKAQ/view) | Rule Scenarios | Upgrade item | Baseline state | Submit for Review, then RECALL | Toast 'Your request has been submitted for approval'. Status In Review, Approval Status In Process, Approval Required checked. | After recall: Status Draft, Is Submitted unchecked |
| E5 | [E5 Edit lock while pending](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Quote/0Q0Ot0000094dvHKAQ/view) | Rule Scenarios | Upgrade item | Baseline state | Submit for Review, then try to edit Expected Close Date while pending | Toast 'Your request has been submitted for approval'. Status In Review, Approval Status In Process, Approval Required checked. | Edit is blocked: proposal cannot be edited after it has been submitted for approval |
| F1 | [F1 Auto-approved primary](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Quote/0Q0Ot0000094dvIKAQ/view) | F1 Auto-approved gating | Not-flagged product 9,558 | Baseline state; this proposal is the opportunity primary | Submit for Review, then move the opportunity to Send To Order Management | Toast 'This proposal was automatically approved'. Status Approved, Approval Status Approved, Is Submitted unchecked, Approval Required unchecked. | No approval-related error (other Send to OM required-field errors may appear and are not part of this test) |
| F2 | [F2 Pending primary](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Quote/0Q0Ot0000094dvJKAQ/view) | F2 Pending gating | Upgrade item | Baseline state; primary | Submit for Review (leave pending), then move opportunity stage | Toast 'Your request has been submitted for approval'. Status In Review, Approval Status In Process, Approval Required checked. | Blocked: This opportunity has no approved proposal |
| F3 | [F3 Approved but In Review primary](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Quote/0Q0Ot0000094dyTKAQ/view) | F3 Approved but In Review gating | Upgrade item | Baseline state; primary | Submit, approve, leave Status In Review, then move opportunity stage | Toast 'Your request has been submitted for approval'. Status In Review, Approval Status In Process, Approval Required checked. | Blocked: no approved proposal (Status is not Approved yet) |
| F4 | [F4 Approved status primary](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Quote/0Q0Ot0000094dyUKAQ/view) | F4 Approved status gating | Upgrade item | Baseline state; primary | Submit, approve, then set proposal Status to Approved, then move opportunity stage | Toast 'Your request has been submitted for approval'. Status In Review, Approval Status In Process, Approval Required checked. | Approval check passes (other Send to OM errors, if any, are separate) |

Opportunities: [ZZ TEST Approval Rules - Rule Scenarios](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Opportunity/006Ot00000m7egDIAQ/view), [ZZ TEST Approval Rules - D6 Exempt owner](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Opportunity/006Ot00000m7XbXIAU/view), [ZZ TEST Approval Rules - F1 Auto-approved gating](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Opportunity/006Ot00000m7egEIAQ/view), [ZZ TEST Approval Rules - F2 Pending gating](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Opportunity/006Ot00000m7egFIAQ/view), [ZZ TEST Approval Rules - F3 Approved but In Review gating](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Opportunity/006Ot00000m7egGIAQ/view), [ZZ TEST Approval Rules - F4 Approved status gating](https://trimech12345--uat.sandbox.lightning.force.com/lightning/r/Opportunity/006Ot00000m7egHIAQ/view).

## 4. Steps to run each test

For every test:
1. Open the proposal from the table, confirm it is **Draft** and has the lines listed.
2. Do the "Before you submit" change, if any.
3. Click **Submit for Review**, add a comment, and Submit.
4. Compare to the Expected columns and record the result in section 7.

**Recommended order** (it minimises state changes): A, B, C, E2-E5, F first at baseline. Then D1, D2, D3, D4, D5, D6 in order. Then E1 last.

**D1 - D3 (hire date):** Setup > Users > Yoseph Kinfu > Edit > Hire Date. D1: today minus 3 months. D2: today minus 7 months. D3: blank. Wait a few seconds after saving before you submit.

**D4 - D5 (high offender):** Setup > Public Groups > Proposal Approval High Offenders > Edit, add yourself under Users (D4); remove yourself (D5).

**D6 (exempt):** nothing to change. The opportunity is pre-flagged exempt. Do not change its owner (changing the owner re-syncs the flag).

**E1:** put yourself back to Hire Date = 3 months ago and not in the group; then submit E1. All four reasons should appear, separated by semicolons.

## 5. Approving, rejecting and recalling

- Routed proposals go to JJ Jobin's queue. As a System Administrator you can act for him: open the proposal, scroll to **Approval History**, and use **Approve / Reject** (or **Reassign** to yourself first, then approve from Items to Approve).
- **E2 approve:** Approve with a comment. Check Approval Status = Approved and Is Submitted is unchecked. Status stays In Review (existing behaviour: it must be set to Approved by hand).
- **E3 reject:** Reject. Status goes to Draft and Approval Status to Rejected. Submit again to confirm it is re-evaluated.
- **E4 recall:** In Approval History click **Recall Approval Request**.
- **E5 lock:** while pending, edit **Expected Close Date**; expect the lock error.

## 6. Opportunity gating tests (F1 - F4)

For each, after the proposal step, open the opportunity and change Stage to **Send To Order Management**, then Save. Look only for the approval-related message:
- Blocked message: "This opportunity has no approved proposal. Submit the primary proposal (Quote) for approval and wait for it to be Approved ..."
- Other Send to OM required-field errors are not part of this test; they can be ignored.

## 7. Result log

| ID | Pass / Fail | Actual result | Notes / screenshot |
|---|---|---|---|
| A1 | | | |
| A2 | | | |
| B1 | | | |
| B2 | | | |
| B3 | | | |
| B4 | | | |
| B5 | | | |
| B6 | | | |
| B7 | | | |
| C1 | | | |
| C2 | | | |
| C3 | | | |
| D1 | | | |
| D2 | | | |
| D3 | | | |
| D4 | | | |
| D5 | | | |
| D6 | | | |
| E1 | | | |
| E2 | | | |
| E3 | | | |
| E4 | | | |
| E5 | | | |
| F1 | | | |
| F2 | | | |
| F3 | | | |
| F4 | | | |

## 8. Cleanup (when finished)

1. Run `cleanup-1-data.apex` and then, as a separate run, `cleanup-2-user-and-group.apex` (both in this folder; Developer Console > Debug > Open Execute Anonymous Window) - or ask me to run them. Together they delete the ZZ TEST account (and its opportunities and proposals), remove the two test Renewal flags, clear your Hire Date, empty the high-offender group and clear your Manager.
2. Recall any approvals still pending first.

## 9. Changes made to UAT for this test (so it can be undone)

| Change | Original value |
|---|---|
| Your user: Manager | blank (set to Jeremy (JJ) Jobin) |
| Product2 Approval Trigger = Renewal | blank on 01tPZ000003NdoYYAS and 01tPZ000003b25xYAA |
| Public group Proposal Approval High Offenders | new, empty |
| ZZ TEST account, 6 opportunities, 27 proposals | new |
