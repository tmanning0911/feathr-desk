# Feathr Desk

The daily operator desk for Mid-Fairfield’s Feathr account, built as a native macOS app. Look someone up, check a tag, see who gave, and keep an eye on the Salesforce sync, without opening Feathr’s web app for routine checks.

Email still sends from Feathr. Desk never invents donation amounts, campaign names, counts, or outcomes that the API did not return. If Feathr does not send a number, Desk leaves it blank.

**What’s new in 1.2:** a ⌘K command palette, keyboard-first navigation, a Desk home pulse, ops-style sync health, a clearer duplicate-match view in People, sturdier Activity paging, and request cancellation when you change sections. See [CHANGELOG.md](CHANGELOG.md).

## Requirements

- macOS 14+
- Swift 5.9+ (`xcode-select` / Command Line Tools)
- A Feathr API key (`fthr_…`) with the scopes you need

## Build

```bash
./scripts/build-app.sh
open "Feathr Desk.app"
```

The script runs `swift build -c release`, draws the app icon (`scripts/make-icon.swift`), writes `Info.plist`, and ad-hoc signs the bundle. A plain `swift build -c release` also works.

After each rebuild macOS may ask whether Feathr Desk can use the key in the Keychain. Choose **Always Allow**. The prompt appears because a locally built app gets a new signature each time. Desk shows a “Waiting for Keychain access” line while it waits.

## Key storage

1. Use **Feathr Key…** (⌘,) or the key button. The key is stored in the macOS Keychain under `com.mfccc.feathrdesk`.
2. On first launch, Desk can also read `~/Desktop/Feathr Control/.env` for `FEATHR_API_KEY` (and optional `FEATHR_API_BASE`) and copy the key into Keychain.

No secrets are written to the repo, logs, or error banners: `fthr_` keys and bearer tokens are scrubbed. Requests use an ephemeral session, so person records are never cached on disk.

## What Desk talks to

Known Feathr Public API paths only:

| Area | Methods |
|------|---------|
| Account | `GET /me` |
| People | `GET /persons`, `GET /persons/{id}`, `POST /persons`, `PATCH /persons/{id}`, `POST /persons/{id}/tags` |
| Tags | `GET /tags`, `POST /tags`, `PATCH /tags/{id}` |
| Campaigns, projects, fields | `GET /campaigns`, `GET /projects`, `GET /custom-fields` |
| Activity | `GET /breadcrumbs` (flavors such as `donation`, `form_submission`, …) |
| Sync | `GET /webhooks`, `PATCH /webhooks/{id}` |

Every write opens a confirm sheet first. Pausing sync, or turning it back on while deliveries are still failing, also requires a checkbox.

## Operator map

- **Desk:** greeting, pulse tiles (gifts on record, people, campaigns, tags, projects), sync card, *Worth a look* next actions, recent gifts, and what this key can change
- **People:** email or id lookup, a duplicate-email callout, a person card with copy email and copy id, jumps to their activity, confirmed edits, add and remove tags, and custom fields (read-only)
- **Tags:** find, create, rename
- **Campaigns:** status, type, and project filters with counts; sort by name or newest; human schedule lines
- **Activity:** flavor chips with totals, grouped by day, person scope, Load more, and gift amount or campaign only when Feathr includes them
- **Projects and Fields:** reference lists with campaign counts and field types
- **Webhooks:** sync health dashboard with failure streak, friendly errors, and confirmed pause and resume

## Read vs. write

- Reads work with any valid key.
- Writes need the matching scope on the key: `persons:write` (create and edit people), `tags:write` (create, rename, add, or remove tags), `webhooks:write` (pause or turn on sync). Without the scope, Desk hides or disables the control. A 403 tells you which scope the change needed.
- Removing a tag sends `PATCH /persons/{id}` with the remaining tag ids, then re-reads the person. If Feathr kept the tag, Desk says so and you remove it in Feathr. As of the August 2026 write-access check, Feathr had not confirmed that tag removal works through the API.

## Rate limits and errors

- Desk reads `X-RateLimit-Limit`, `X-RateLimit-Remaining`, and `Retry-After` (seconds or an HTTP date). A banner counts down when Feathr asks Desk to wait, and a quieter one appears when requests run low.
- Reads retry once after a short 429 or a 502, 503, or 504. Writes never retry on their own.
- Changing sections cancels that section’s in-flight requests.

## Still done in Feathr

- Building, starting, stopping, or sending campaigns (the API returned 405 for campaign and project writes)
- Deleting tags or merging duplicate people or tags
- Editing custom field values on a person (Desk shows them read-only)
- Gift amounts and currency: donation breadcrumbs did not include them as of the last check, so amounts stay in the CSV export. Desk shows an amount only if Feathr includes one.
- Pausing sync when the key lacks `webhooks:write`

## Shortcuts

| Keys | Action |
|------|--------|
| ⌘K | Command palette: people, gifts, tags, campaigns, projects, actions |
| ⌘R | Refresh from Feathr (also reloads the open Activity list or person) |
| ⌘F | Jump to search (People, Tags, or Campaigns) |
| ↑ / ↓ | Move through the current list (↓ from a search field enters the results) |
| Return, ⌘O | Open the person behind the selected gift or activity row |
| Esc | Close the palette, leave a text field, or clear the selection |
| ⌘[ | Back to the previous section |
| ⌘1–⌘8 | Go to a section |
| ⇧⌘G | Recent gifts |
| ⇧⌘Y | Salesforce sync |
| ⌃⌘S | Collapse or expand the sidebar |
| ⌘, | Feathr key |

## Version

App version **1.2**, build 3 (`DeskInfo` in `FeathrAPI.swift` and `scripts/build-app.sh`).
