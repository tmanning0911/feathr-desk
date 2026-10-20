# Changelog

## 1.2 — What’s new

Feathr Desk 1.2 is a calmer, faster daily desk. You can reach everything from the keyboard, empty and loading screens look intentional, and the Salesforce sync now reads like an ops dashboard.

### Get anywhere fast
- **Command palette (⌘K).** Find a person by typing their full email, or jump to recent gifts, tags, campaigns, projects, sync, refresh, sections, and the key sheet. Results are ranked as you type; ↑↓ moves, Return opens, Esc closes.
- **Keyboard first.** ⌘R refresh, ⌘F search, Esc clears the selection (or leaves the text field you are in), ↑/↓ move through any list, Return or ⌘O opens the person behind a gift or activity row. ⌘[ goes back, ⌃⌘S collapses the sidebar, ⌘, opens the Feathr key, ⇧⌘Y opens sync.
- **Sidebar.** Collapses to icons and remembers that choice. Sections show live counts and a sync health dot. Hover a section to see its ⌘ shortcut.
- **Remembers where you were.** After a normal quit, Desk reopens on the section you last used. After a crash or force quit it opens on Desk.

### Desk home pulse
- Greeting, connection line, and tiles for gifts on record (with the latest gift’s time), people on the account, campaigns (how many are sending), tags, and projects. Every number comes from a total Feathr returned. A tile shows nothing rather than guessing.
- Sync card with delivered, failed, and success rate, plus Pause or Turn on (both ask first).
- **Worth a look:** a short, grounded list covering sync failing or paused, a rejected key, lists that did not load, low rate limit, a stale refresh, gifts today, and campaigns sending. When the list is empty it says “Nothing needs you right now.”
- Recent gifts open in the details rail; Return opens the person. A row shows what this key can and cannot change.

### People
- Search states that feel intentional: an idle guide with people opened this session, skeleton rows while searching, a clear no-match state that offers to add that email, and a duplicate-email callout when several Feathr records share one address (created date, last seen, tag count, short id).
- Person card: initials avatar, copy email, copy Feathr id, “in Feathr since,” and one-click jumps to their gifts, form fills, email clicks, and page views.
- Confirmed edits show exactly what changes (old → new). Remove tag uses a cautionary confirm and re-reads the person to verify. Custom fields show in a clean table with type on hover and copy per value.

### Activity
- Flavor chips with real per-flavor totals for the current scope (account or one person), only when Feathr reports a total.
- Grouped by day (“Today,” “Yesterday,” weekday), with time, campaign, project, and gift amount only when present.
- Sturdier pagination: dedupes by id, stops cleanly if Feathr’s list shifts, works when Feathr omits a total, retries inline on a failed page, and loads more when you arrow past the last rows.
- Person scope bar with Open person and Everyone. Inline “Try again” instead of modal errors.

### Campaigns
- Status, type, and **project** filters, each with counts that respect the other filters. Sort by name or newest start.
- Human schedule lines: “Running Oct 9 to Oct 24. Ends in 4 days,” “Ran Aug 20 to Sep 19, 4 weeks.” Status dots on each row.

### Sync (webhooks)
- Ops-style cards: running, failing, and paused summary; delivered, failed, success rate, and failures-in-a-row tiles; a failure-streak strip; last attempt as relative and exact time; destination and events in plain words.
- Friendlier delivery errors (credentials refused, address not found, receiving side down, TLS, DNS, refused, timeout) with Feathr’s exact words one click away.
- **Strong pause and resume confirms.** These explain what changes and what Desk cannot know, and require a checkbox before pausing, or before resuming while deliveries are still failing. After the change Desk re-reads the webhooks and flags any mismatch.

### Feathr API
- Moving to another section cancels its in-flight requests (activity, counts, search) through Swift task cancellation, so stale results never land.
- `Retry-After` is parsed as seconds or as an HTTP date. Reads retry once on a short 429 or a 502, 503, or 504; writes never retry.
- 401 shows a key-rejected banner with **Replace key**. 403 names the scope the write needs. A 429 banner counts down until requests open again, and a quiet banner appears when the remaining rate limit runs low.
- Each reference list loads on its own, so one failing endpoint no longer blanks the desk.
- Ephemeral URL session with no disk cache and no cookies. Error text scrubs `fthr_` keys and bearer tokens.
- The Keychain read moved off the main thread, so the window stays responsive while macOS asks for Keychain access.

### Look and feel
- Thin copper progress line under the top bar instead of spinners; skeleton rows and tiles while loading; dashed empty-state cards with one clear next step.
- Inline, dismissible error banners replace modal alerts.
- Custom copper-and-dark confirm sheet for every write (Return confirms, Esc cancels).
- Hover states throughout, a ⌘K search pill in the top bar, a breadcrumb such as “Activity › Gifts for …”, and a “refreshed 2 minutes ago” stamp.
- New app icon (copper quill), About panel credits, and a fuller Info.plist (copyright, category, principal class, build number). The app is ad-hoc signed.

### Version
- App **1.2** (build 3), user agent `mfccc-feathr-desk/1.2`.

## 1.1

- Split the monolithic `DeskView` into focused panes: home, people, tags, campaigns, activity, projects/fields/webhooks, plus shared desk controls. `DeskTheme` stays the copper/dark shell.
- Activity: page size 40, **Load more**, generation-safe reloads; donation amount and campaign labels shown only when present on the breadcrumb payload.
- People: remove a tag from a person with a confirm dialog; verify afterward that Feathr actually dropped it; surface custom fields when returned.
- Campaigns: filter by state and kind (from live campaign list values).
- Desk home: Salesforce sync health card (good / warning / problem), recent gifts, quick actions (find person, gifts, sending campaigns).
- `FeathrAPI`: clearer 401 / 403 / 429 (and network) messages, `Retry-After` + rate-limit header snapshots, short auto-retry on brief 429s, key scrubbing in error detail, `mfccc-feathr-desk/1.1` user agent.
- Activity rows: hover or right-click to open that person in People, or narrow Activity to just their records. The details rail shows every field Feathr sent on a breadcrumb, so new fields such as gift amount appear once Feathr adds them.
- Details rail: Copy email for people and activity rows; custom field values on people; campaign counts on projects.
- Tag chips wrap to fit the width and have a remove (×) button when the key can write tags.
- Shortcuts: ⌘R refresh, ⌘F jump to search, ⌘1–⌘8 sections, ⇧⌘G recent gifts.
- README, this changelog, app bundle version **1.1** (build 2).

## 1.0

- Initial Feathr Desk: Keychain key, people/tags/campaigns/projects/activity/fields/webhooks, confirmed writes, dark copper UI.
