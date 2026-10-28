# Exec Whispering: Copy-Paste Templates

Companion templates for Exec Whispering and the Joshua Tree. Fill in the `[BRACKETS]`, paste into Slack or email, send.

Every update uses the same four lines, so leadership learns to read line one and exhale:

| Line | What goes there |
| --- | --- |
| **Status** | Checking / Not affected / Affected, fixing / Fixed / Incident |
| **Exposure** | What's affected, in business terms ("the customer portal," not "php-fpm on web-03") |
| **Action** | What we're doing, and by when |
| **Next update** | Time and time zone |

Leave CVSS, CVE IDs, and exploit details out of the message body. Link them for anyone who asks.

---

## 1. Holding statement

Send within 30 minutes of the first exec ping, even if you know nothing yet.

```text
We're aware of [VULN NAME] in the news. We're checking whether it affects us now. Next update by [TIME, TIME ZONE]. No action needed from you.
```

## 2. Not affected

Only send this with receipts. "Pretty sure" is not an asset inventory.

```text
Status: Not affected
Exposure: None. We don't run [AFFECTED PRODUCT]. Verified by [METHOD, e.g., inventory scan / vendor confirmation].
Action: None needed. We'll watch for changes.
Next update: Only if something changes.
```

## 3. Affected, fixing

Covers the Normal cadence, This week, Mitigate, Tonight, and All hands outcomes. Adjust the action and cadence to match where you landed on the tree.

```text
Status: Affected, fixing
Exposure: [BUSINESS SYSTEM] runs the affected software. It [is / isn't] internet-facing. [No signs of compromise found / Investigating for signs of compromise].
Action: [Patching / mitigating] by [DATE/TIME]. [Expected downtime, if any.]
Next update: [TIME, TIME ZONE]
```

## 4. Escalated to incident

Once this goes out, comms follow your IR plan. Stop freelancing.

```text
Status: Security incident declared
Exposure: Under investigation. IR team engaged.
Action: Following our IR plan. Updates only in [CHANNEL]. Please don't forward or discuss outside it.
Next update: [TIME]
```

## 5. All clear

Closure is a deliverable too.

```text
Status: Fixed
Exposure: None remaining. [SYSTEMS] patched and verified on [DATE].
Action: Closed. Retro scheduled for [DATE] if you want to join.
Next update: Not needed. Go enjoy the 4 minutes of peace.
```

## 6. Vendor's problem

Use when the vendor is affected and handling it. Send once, then again when the vendor updates.

```text
Status: Vendor affected, tracking
Exposure: [VENDOR] is affected and handling it. Our exposure is [X, in business terms].
Action: Tracking their guidance. [Any interim step we've taken.]
Next update: When [VENDOR] updates.
```

---

See [`update-cadence.md`](update-cadence.md) for how often to send updates. Back to the [README](README.md).

*Not legal, financial, or incident response advice. Built by people who patch things for a living.*
