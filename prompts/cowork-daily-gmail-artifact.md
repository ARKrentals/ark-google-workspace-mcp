# Cowork prompt — ARK Daily Gmail Mission Control (rough draft)

> Open a fresh Cowork chat. Make sure these three connectors are enabled in the chat:
> - **Workspace MCP — gus@arkrentalsaz.com** (or whatever you named the first one)
> - **Workspace MCP — gus@arkrentals.co** (or whatever you named the second one)
> - **ARK Vault MCP** (your Obsidian vault MCP)
>
> Then paste everything below the line into the chat as a single message.

---

Build me a persistent live artifact that serves as a unified daily mission control for my two Gmail accounts. This is a rough draft — get the MVP working, show me, we iterate.

## Who I am and what I do

I'm Gus, sole operator of ARK Rentals — Scottsdale, AZ luxury short-term rental property management (7 properties). My two Workspace accounts are:

- **`gus@arkrentalsaz.com`** — primary; guest comms, ops vendors, accountant, Guesty platform notifications, owner reports
- **`gus@arkrentals.co`** — secondary; financial (Stripe payouts, Relay banking, invoices), some vendor and shipping mail

All times in **America/Phoenix** (Scottsdale; no DST — never adjust for daylight saving).

## What the artifact should do

### Daily briefing (top section, always visible)

- Total new mail in the last 24h across both accounts (counts per account)
- "What needs your attention today" — the 3–5 most important threads I haven't responded to, with a one-line summary each. Importance signals: from a guest currently mid-stay, from an owner, from a vendor with an action ("payment due", "approval needed"), from accountant, replies to threads I started.
- "Quick wins" — threads that just need a one-liner reply (confirmations, thanks, "got it"), with a draft already prepared

### Per-account inbox feeds

Two columns side-by-side on desktop, swipeable tabs on mobile. Each column shows the last 48h of threads. For each thread row, display:

- Sender + subject (bold if unread)
- One-line summary (you generate this; not the snippet from Gmail)
- Time received (relative: "12 min ago", "yesterday 3pm")
- Inline action buttons: **View thread** · **Draft reply** · **Save to KB** · **Mark read** · **Archive**

### AI-suggested drafts queue

A separate panel listing threads where you've already pre-drafted a suggested reply. Each card shows:

- The original sender + thread context
- Your suggested draft (editable inline)
- Buttons: **Save as draft to Gmail** · **Edit** · **Discard**

When I click "Save as draft to Gmail", call `draft_gmail_message` on the appropriate account's connector, threaded to the original message. The draft must show up in my actual Gmail Drafts folder, properly nested in the original conversation.

### Save-to-KB integration

When a thread contains information that's worth keeping in my long-term knowledge base — a vendor's contact info, a property-specific quirk, an owner's preference, a recurring billing detail — give me a "Save to KB" button. Clicking it should:

1. Generate a clean Markdown note: title, source thread link, key extracted info
2. Use the **ARK Vault MCP** connector to write it to the appropriate folder in my Obsidian vault
3. Confirm in the UI

You decide which folder makes sense; if you're unsure, ask me before writing.

### Refresh behavior

- Manual refresh button (top right)
- Auto-refresh every 5 minutes
- Show "Last refreshed: X minutes ago" timestamp

## Technical constraints (these matter — don't skip)

- **Data only via MCP tools.** No `fetch()` to non-MCP origins. All Gmail/Drive/Vault data goes through `window.cowork.callMcpTool(...)`.
- **Don't pull full message bodies on list calls.** Use the search/list tools' metadata projection (e.g. `format=metadata` if available). Only pull full bodies when I open a thread.
- **Don't paginate the world.** Last 48h, top ~30 threads per account is enough for the MVP.
- **Be careful with rate limits.** Throttle the auto-refresh; don't fan out parallel calls per-thread for summaries — batch them.
- **Errors should be visible.** If an MCP call fails, show a small inline error on the affected component, not a full-page failure.

## Design

Apply my Claude Design system styles: **https://api.anthropic.com/v1/design/h/iolZxvO43m-m7LnkyGJ-Ow**

Use the design tokens for color, typography, spacing, and component styling. The artifact should feel like an extension of my brand identity, not a generic Tailwind dashboard. If the design system has a specific button/card/badge component pattern, use those.

## Useful MCP tool names (from the Workspace MCP)

- `search_gmail_messages` — list with filters (date, label, from, query)
- `get_gmail_message_content` — full body + headers + thread context
- `draft_gmail_message` — create a draft tied to a specific thread (this is what powers the suggested-replies queue)
- `modify_gmail_message_labels` — apply/remove labels (useful for marking "summarized" or "triaged")

For the vault, check the ARK Vault MCP's tool list — likely something like `write_note` or `append_to_file`.

## What I want back from you in this first pass

1. Build the MVP with the daily briefing, two inbox columns, and the suggested drafts queue. Save-to-KB can be a stub for v1 if you need to scope down.
2. Show me the artifact. We'll iterate from there.
3. **Don't ask me 20 setup questions before starting.** Make reasonable defaults; I'll redirect if anything's wrong.
4. If something is genuinely ambiguous and blocks progress (e.g. "which folder should KB notes go in"), ask once, in one clear question, then keep going.

Start.
