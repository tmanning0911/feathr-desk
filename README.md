# Feathr Desk

Native macOS operator desk for Mid-Fairfield’s Feathr account. Look up people, manage tags, browse campaigns and gifts, and pause or resume the Salesforce sync webhook — without opening Feathr’s web UI for routine checks.

Email still sends from Feathr. Desk never invents donation amounts, campaign names, or outcomes that the API did not return.

## Requirements

- macOS 14+
- Swift 5.9+ (`xcode-select` / Command Line Tools)
- A Feathr API key (`fthr_…`) with the scopes you need

## Build

```bash
./scripts/build-app.sh
open "Feathr Desk.app"
```

Or:

```bash
swift build -c release
```

## Key storage

1. Prefer the in-app **key** button — the key is stored in the macOS Keychain (`com.mfccc.feathrdesk`).
2. On first launch, Desk can also read `~/Desktop/Feathr Control/.env` for `FEATHR_API_KEY` (and optional `FEATHR_API_BASE`) and copy the key into Keychain.

No secrets are written into the repo, logs, or error alerts (keys are scrubbed).

## What Desk talks to

Known Feathr Public API paths only:

| Area | Methods |
|------|---------|
| Account | `GET /me` |
| People | `GET /persons`, `GET /persons/{id}`, `POST /persons`, `PATCH /persons/{id}`, `POST /persons/{id}/tags` |
| Tags | `GET /tags`, `POST /tags`, `PATCH /tags/{id}` |
| Campaigns / projects / fields | `GET /campaigns`, `GET /projects`, `GET /custom-fields` |
| Activity | `GET /breadcrumbs` (flavors such as `donation`, `form_submission`, …) |
| Sync | `GET /webhooks`, `PATCH /webhooks/{id}` |

Writes always show a confirm dialog first.

## Operator map

- **Desk** — sync health, recent gifts, quick actions
- **People** — email search, edit name/phone, add/remove tags (confirmed), custom fields when present
- **Tags** — find, create, rename
- **Campaigns** — filter by status and type
- **Activity** — paginated breadcrumbs with **Load more**; donation amount/campaign only if Feathr included them
- **Webhooks** — Salesforce sync pause / turn on

## Read vs. write

- Reads work with any valid key.
- Writes need the matching scope on the key: `persons:write` (create/edit people), `tags:write` (create, rename, add or remove tags), `webhooks:write` (pause or turn on sync). Buttons stay disabled without the scope, and Desk shows which areas are read-only on the home screen.
- Removing a tag sends `PATCH /persons/{id}` with the remaining tag ids, then re-reads the person. If Feathr kept the tag, Desk says so and you remove it in Feathr. As of the August 2026 write-access check, Feathr had not confirmed that tag removal works through the API.

## Still done in Feathr

- Building, starting, stopping, or sending campaigns (the API returned 405 for campaign and project writes)
- Deleting tags or merging duplicate tags
- Editing custom field values on a person (Desk shows them read-only)
- Gift amounts and currency: donation breadcrumbs did not include them as of the last check, so amounts stay in the CSV export. Desk shows an amount only if Feathr includes one.
- Pausing sync when the key lacks `webhooks:write`

## Shortcuts

| Keys | Action |
|------|--------|
| ⌘R | Refresh from Feathr (also reloads Activity when open) |
| ⌘F | Jump to search (People, Tags, or Campaigns) |
| ⌘1–⌘8 | Go to a section |
| ⇧⌘G | Recent gifts |

## Version

App version **1.1** (`DeskInfo.version` and `scripts/build-app.sh`).
