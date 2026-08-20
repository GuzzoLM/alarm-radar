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

## Install with Homebrew

After the first release is published:

```bash
brew install --cask guzzolm/tap/alarm-radar
```

On first launch, enter the Grafana base URL, save it, and choose **Sign in to
Grafana…**. Complete SSO in the window that opens. Alarm Radar polls immediately
and then every 60 seconds by default.

## Build an application bundle

```bash
./create-dmg.sh 0.1.0
```

This creates `AlarmRadar-0.1.0.dmg` and its SHA-256 file. The bundle is ad-hoc
signed for local use.

## Publishing a release

1. Add a `TAP_GITHUB_TOKEN` Actions secret with `contents: write` access to
   `GuzzoLM/homebrew-tap`.
2. Create and push a semantic version tag, for example:

   ```bash
   git tag v0.1.0
   git push origin v0.1.0
   ```

The release workflow builds arm64 and Intel binaries, creates a universal DMG,
publishes the GitHub release, and updates `Casks/alarm-radar.rb` in the tap.

## Current POC behavior

- Persistent WebKit SSO session
- Green/orange/red connection feedback in the menu bar and menu
- Configurable polling interval (60 seconds by default, 15 seconds minimum)
- Optional free-text or Prometheus-style label filtering
- Firing, pending, error/no-data, and muted sections
- Separate firing and pending counters in the menu bar
- Sound notification when an alert newly transitions to firing (enabled by default)
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

All label matchers in a filter must match. The menu bar shows separate firing
and pending counters after filtering and muting. Error/no-data alerts remain
visible in their own menu section.

## Authentication caveat

Embedded SSO is intentionally a POC solution. Some identity providers reject
embedded browsers. A distributable version should use an organization-approved
OAuth/JWT flow, auth proxy, or read-only service account.
