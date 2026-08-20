# Alarm Radar

A native macOS menu-bar POC for monitoring Grafana alerts.

Alarm Radar uses a persistent WebKit session so you can complete your existing
Grafana SSO flow without registering an OAuth client or creating a service
account. API requests run in the authenticated Grafana web context; passwords,
tokens, and cookies are never copied into application preferences.

## Requirements

- macOS 13 or newer
- Grafana 13.0.1
- An SSO provider that permits login inside a WebKit browser view

## Run from source

```bash
swift run alarm-radar
```

On first launch, enter the Grafana base URL, save it, and choose **Sign in to
Grafana…**. Complete SSO in the window that opens. Alarm Radar polls immediately
and then every 60 seconds by default.

## Build an application bundle

```bash
chmod +x scripts/package-app.sh
scripts/package-app.sh
open AlarmRadar.app
```

The bundle is ad-hoc signed for local use.

## Current POC behavior

- Persistent WebKit SSO session
- Green/orange/red connection feedback in the menu bar and menu
- Configurable polling interval (60 seconds by default, 15 seconds minimum)
- Optional free-text or Prometheus-style label filtering
- Firing, pending, error/no-data, and muted sections
- Unseen indicator and actionable count in the menu bar
- Manual refresh and last-successful-refresh timestamp
- Open alerts in Grafana
- Persistent seen and mute state
- Keeps the last successful snapshot visible after errors

Example filters:

```text
payments
{team="payments"}
{environment="production", severity=~"critical|warning"}
{team!="platform", service!~"sandbox-.*"}
```

All label matchers in a filter must match. The menu-bar number counts firing
alerts after filtering; pending and error/no-data alerts remain visible in their
own menu sections but do not inflate the badge.

## Authentication caveat

Embedded SSO is intentionally a POC solution. Some identity providers reject
embedded browsers. A distributable version should use an organization-approved
OAuth/JWT flow, auth proxy, or read-only service account.
