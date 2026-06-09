---
title: Operators
slug: operators
menu_order: 20
---

# Operators

Operators are trusted community members who manage official IPNet repeater nodes. This page covers how to become an operator, manage your nodes, and the rules that apply.

## Repeater Configuration

All official IPNet repeaters should be configured as follows using the Repeater CLI:

### Regions

Repeaters should be configured with `gb` and `gb-est` regions, with `gb-est` as a child of `gb`.
The repeater's home region should be set to `gb-est`.
Unscoped region flooding should be kept enabled for the foreseeable future.

```
region put gb
region put gb-est gb
region allowf gb
region allowf gb-est
region home gb-est
region save
```

### Advertisements

Set flood adverts to **50 hours or more** and zero-hop adverts to **0** (disabled).

```
set flood.advert.interval 50
set advert.interval 0
```

### Duty Cycle / Multi-Byte Support / Loop Detection

```
set dutycycle 10
set path.hash.mode 1
set loop.detect minimal
```

### Flooding

Repeater firmware from **v1.16 onwards** introduced options for managing flood
hop limits for messages (scoped and unscoped) and advertisements:

```
set flood.max 10
set flood.max.unscoped 6
set flood.max.advert 10
```

## Becoming an Operator

To become an official IPNet operator, you must submit a request for review. You can do this by:

- Reaching out on **Discord**
- Sending an email to [operators@ipnt.uk](mailto:operators@ipnt.uk?subject=Operator%20Request)

Once your request has been reviewed and approved by an admin, you will be granted operator permissions on your account.

## Adopting & Managing Nodes

After you have been granted operator status:

1. **Log in** to the IPNet website
2. Navigate to the **Node detail page** for the repeater you operate
3. Click **Adopt** to claim the node as your own

Once adopted, you can manage **custom tags** for that node to provide additional context or metadata.

## Monitoring & Alerts

Adopted nodes are automatically monitored for downtime. If an adopted node goes offline, an alert will be posted to the **#alerts** channel on Discord.

You are not required to take action on every alert, but sustained or repeated downtime may be reviewed by admins.

## Operator Rules

All IPNet operators are expected to follow these rules:

### Uptime & Maintenance

- Ensure **reasonable uptime** for your repeater node
- Keep your node **up-to-date** with the latest firmware — outdated nodes that fail to maintain reliable infrastructure will be reviewed
- **24/7 uptime is not required**, but you must make best efforts to keep the node running at all times
- Periodic downtime is acceptable, but only repeaters that are intended to run **permanently** should be adopted

### Node Naming Convention

_To be confirmed._

## Admin Rights

Admins reserve the right to:

- **Remove node adoptions** if the above rules are not complied with
- **Revoke operator permissions** in cases of sustained non-compliance

If you have any questions about these rules, please reach out on Discord or email [operators@ipnt.uk](mailto:operators@ipnt.uk?subject=Operator%20Question).
