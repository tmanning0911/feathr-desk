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

## Version

App version **1.1** (`DeskInfo.version` and `scripts/build-app.sh`).
