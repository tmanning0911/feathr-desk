# Changelog

## 1.1

- Split the monolithic `DeskView` into focused panes: home, people, tags, campaigns, activity, projects/fields/webhooks, plus shared desk controls. `DeskTheme` stays the copper/dark shell.
- Activity: page size 40, **Load more**, generation-safe reloads; donation amount and campaign labels shown only when present on the breadcrumb payload.
- People: remove a tag from a person with a confirm dialog; verify afterward that Feathr actually dropped it; surface custom fields when returned.
- Campaigns: filter by state and kind (from live campaign list values).
- Desk home: Salesforce sync health card (good / warning / problem), recent gifts, quick actions (find person, gifts, sending campaigns).
- `FeathrAPI`: clearer 401 / 403 / 429 (and network) messages, `Retry-After` + rate-limit header snapshots, short auto-retry on brief 429s, key scrubbing in error detail, `mfccc-feathr-desk/1.1` user agent.
- README, this changelog, Cmd+R refresh, app bundle version **1.1** (build 2).

## 1.0

- Initial Feathr Desk: Keychain key, people/tags/campaigns/projects/activity/fields/webhooks, confirmed writes, dark copper UI.
