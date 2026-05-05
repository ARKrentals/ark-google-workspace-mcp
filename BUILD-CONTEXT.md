# BUILD-CONTEXT — Google Workspace MCP Server (Railway-hosted)

**Status:** New project, scaffolded 2026-05-05. Replacing the dead local taylorwilsdon/google_workspace_mcp install. Handed off to Claude Code from a Cowork session.

**Mission:** Re-establish the Google Workspace MCP server (Gmail / Calendar / Drive / Docs / Sheets / Slides / Tasks / Forms / Chat / Contacts) for Gus by deploying `taylorwilsdon/google_workspace_mcp` as a remote, multi-user, OAuth 2.1 server on Railway. Replace the dead local install; restore tools across all of Gus's devices including his laptop and Claude mobile.

## Who you're working with

Gus Kelly — sole operator of ARK Rentals (Scottsdale luxury short-term rental management, 7 properties). He is **new to developer tooling** (CLI, MCP internals, OAuth flows). Explain things in plain language, translate jargon, walk him through any console UI step-by-step. He has working knowledge of: Railway dashboard, GitHub web UI (private `ARKrentals` org), Obsidian, PowerShell at a copy-paste level. He does NOT yet have working knowledge of: Docker internals, OAuth 2.1 bearer flows, FastMCP. Don't make him paste long debug output if you can run things yourself.

Comms style: warm, direct, no hand-wringing. He notices unnecessary apology and over-explanation. State what you're doing, do it, say what changed.

## Primary use case — informs scope, OAuth scopes, and priorities

The headline reason Gus wants this MCP server back is to power a **Cowork live artifact that monitors his Gmail accounts daily and (a) presents a summary of important new emails, (b) auto-drafts responses for him to review.** He'll use the MCP for plenty of other things too (Drive access from his laptop and phone, ad-hoc Calendar/Docs work in Cowork chats), but the daily-summary artifact is the load-bearing feature.

What this means for the build:

- **OAuth scopes must include Gmail draft creation.** Verify the upstream repo requests `https://www.googleapis.com/auth/gmail.compose` (or `gmail.modify` which is broader). Without this, auto-draft is a non-starter and Gus loses the headline use case. If the upstream default doesn't include it, configure it.
- **Both accounts need full read + draft scope:** gus@arkrentalsaz.com AND gus@arkrentals.co. The artifact will pull from both.
- **Tool capability check before declaring done:** confirm tools are exposed for (1) search/list Gmail messages with filtering by date/label/from, (2) read full message body + headers + thread, (3) create a draft tied to a specific thread (replies, not just standalone drafts), (4) modify labels (so the artifact can mark "summarized" or similar). If the upstream repo names these differently, document the actual tool names in the project README.
- **Performance matters for daily summary.** A daily artifact will paginate through inboxes. Don't enable any tool that returns full message bodies in a list call by default — that bloats responses. Confirm whether the upstream repo's Gmail tools support a `fields` / `format=metadata` style projection, and document it.
- **Cowork artifact integration constraint:** the artifact will call this MCP via `window.cowork.callMcpTool('<tool_name>', { ... })`. That means the MCP must be registered as a Cowork connector (step 8 in the sequence below) — not just available via Claude Desktop or Claude Code. The bearer token + URL configured in Cowork's Connectors UI is what the artifact relies on.
- **Timezone:** all daily-summary date math should default to America/Phoenix (Gus is in Scottsdale, AZ — no DST). Document this in the README so the eventual artifact code doesn't have to rediscover it.

## Current state — what we just diagnosed (2026-05-05)

The local install is dead with three compounding failures:

1. **Server not actually running.** `WorkspaceMCP` Windows Scheduled Task is in state Ready, LastRunTime today 11:24 AM, LastTaskResult 0 (success). But `Get-NetTCPConnection -LocalPort 8000 -State Listen` returns nothing. The startup script at `C:\Users\guske\workspace-mcp-start.ps1` exits cleanly without keeping the Python HTTP server alive. Don't bother debugging this — we're abandoning it.

2. **Claude Desktop config wiped.** `%APPDATA%\Claude\claude_desktop_config.json` has an empty `mcpServers` object. The `workspace-mcp` stdio entry that pointed at the local server via `mcp-remote` is gone.

3. **OAuth credentials stale.** `C:\Users\guske\.google_workspace_mcp\credentials\` still contains `gus@arkrentals.co.json` and `gus@arkrentalsaz.com.json`, both last modified 2026-04-19. Almost certainly need re-auth regardless of path.

**Decision (made in Cowork on 2026-05-05):** stop fixing the local setup. Migrate to Railway. The local Scheduled Task, startup script, and credentials folder will be retired once the Railway version is live and verified.

## Repo to use — confirmed current

`taylorwilsdon/google_workspace_mcp` on GitHub. Last release published 2026-05-01 (4 days before this prompt was written). It's actively maintained and is now the only Workspace MCP that supports the architecture we want:

- **Remote OAuth 2.1 multi-user** — every request is auth'd independently by bearer token; the server validates bearer tokens against Google's userinfo API
- **`WORKSPACE_MCP_STATELESS_MODE=true`** — recently fixed to actually reach FastMCP's `stateless_http` runtime flag (was previously broken — server advertised stateless behavior but FastMCP kept in-memory sessions, breaking clients on pod restart). Required for clean Railway deployment.
- **External OAuth provider support** — your external system handles the OAuth flow and obtains Google access tokens; the MCP just validates bearer tokens
- **Docker-deployable** — official `docker run` instructions in the README; Railway runs Docker so this is straightforward

## Target architecture

| Piece | Decision | Why |
|---|---|---|
| Hosting | Railway, dedicated project for this MCP | Each MCP gets its own Railway project — keeps deploys, logs, and env vars isolated. |
| Container | Docker, image based on official Dockerfile in upstream repo | Don't reinvent. PR upstream if config changes are needed. |
| MCP transport | HTTP (streamable), `WORKSPACE_MCP_STATELESS_MODE=true` | Stateless required for Railway pod restarts. |
| Auth Claude→MCP | OAuth 2.1 with bearer token per request | Non-negotiable. Without it, anyone with the public Railway URL can drain Gus's Gmail. |
| OAuth refresh tokens (Google) | Encrypted at rest using Railway secret env vars | Default if you use Railway Variables — verify. |
| Google Cloud project | Likely existing project Gus already used for the local OAuth — needs new redirect URI for Railway domain. May also need consent screen review (currently "Internal" per old memory but worth re-verifying given multi-user remote use). | Confirm with Gus before creating a new GCP project. |
| Repo | New private repo under github.com/ARKrentals (name TBD — propose 2–3 options to Gus before creating) | Fork upstream OR thin wrapper — decide based on whether modifications are needed. Default to fork-and-stay-close-to-upstream so updates can be pulled cleanly. |
| Accounts to support | gus@arkrentalsaz.com AND gus@arkrentals.co | Both ARK Workspace accounts. Each gets its own OAuth flow → token stored against bearer. |

## Critical hard constraints

- **Do NOT modify the OneDrive vault from sandbox-style bash.** Vault is at `C:\Vaults\ARK Rentals Knowledge Base`. OneDrive corrupts `.git/config` when Linux processes touch it. Use the Obsidian Git plugin (running on Windows) for any vault commits. This shouldn't matter much for this project, but flagging in case you wander into the vault for context-reading.
- **Code projects do NOT live in OneDrive.** Same git-corruption trap. Stay in `C:\Code\`.
- **No throwaway secrets in git.** Bearer tokens, Google client secrets, OAuth refresh tokens all go in Railway Variables and `.env` (gitignored), never in repo content.
- **Don't auto-deploy without showing Gus the diff.** Before any `railway up`, show the env vars and Dockerfile changes so he understands what's about to run.
- **Gmail attachment bridge will need rethinking.** The old setup wrote attachments to `C:\Users\guske\OneDrive\Desktop\Email Attachments Inbox\` (mounted into the Cowork sandbox). On Railway there's no such folder. Options to discuss with Gus: (a) return base64 in the MCP response, (b) write to a Railway volume + serve via signed URL, (c) deprecate the bridge and use Drive instead. Don't decide unilaterally.

## Existing assets to read before designing

- `taylorwilsdon/google_workspace_mcp` upstream — canonical reference for codebase structure, Dockerfile, OAuth flow, env-var names, FastMCP conventions, and tool implementations. Mature, actively maintained, represents current best practice for Workspace MCP deployment. Default to "fork and modify minimally" so updates can be pulled cleanly. For anything not covered by upstream, apply general MCP server and production-deployment best practices — no internal "house style" to imitate.
- `C:\Code\ark-ai-ops\BUILD-CONTEXT.md` — the broader AI-ops architecture doc. Update it when this MCP goes live (add the new Railway service entry).
- `C:\Vaults\ARK Rentals Knowledge Base\_session-state\NEXT-SESSION.md` — session-handoff doc. The deferred USER ACTION about re-auth is in here. When you're done, the entry there should be replaced with a "DONE — workspace-mcp now lives on Railway" note for the next Cowork session.

## Sequence of work

1. **Set up the project skeleton** at `C:\Code\workspace-mcp-server\`. Initialize git. Create `BUILD-CONTEXT.md` at the root capturing the locked decisions from this prompt (so the next Claude Code session can pick up if you run out of context).
2. **Pull and read the upstream repo.** Specifically read its `README.md`, `Dockerfile`, deployment docs, and OAuth 2.1 / stateless-mode sections. Note any required env vars and the Docker entrypoint command.
3. **Verify the Google Cloud OAuth client.** With Gus driving the browser (he can use Cowork's Claude-in-Chrome for this), check the existing OAuth client at console.cloud.google.com: which project owns it, what redirect URIs are registered, whether the consent screen is Internal or External, what scopes are requested. Decide whether to update the existing client or create a new one for the Railway deployment.
4. **Design the deployment.** Decide fork vs thin-wrapper. Write the Dockerfile, env-var list (including the bearer auth token, Google client ID/secret, `WORKSPACE_MCP_STATELESS_MODE=true`), Railway config.
5. **Push to GitHub** under the ARKrentals org as a private repo.
6. **Deploy to Railway.** Walk Gus through creating the Railway project, linking the repo, and setting env vars. Don't paste actual secrets in chat — direct him to type them into the Railway UI.
7. **Auth the two accounts.** Run the OAuth flow once for gus@arkrentalsaz.com and once for gus@arkrentals.co. Verify bearer tokens are issued and validated correctly.
8. **Register as a Cowork connector.** The MCP URL (e.g. `https://workspace-mcp-production.up.railway.app/mcp`) plus bearer token gets added to Cowork's Connectors UI. Walk Gus through the UI; confirm the connector shows up green.
9. **Smoke test from Cowork** AND from a different device (Gus's laptop or Claude mobile) — confirm Gmail search, calendar list, drive list all work for both accounts.
10. **Decommission the local setup.** Disable the WorkspaceMCP Scheduled Task. Move `workspace-mcp-start.ps1` and `.google_workspace_mcp/` to an archive folder (don't delete — leave a paper trail). Update `BUILD-CONTEXT.md` and `_session-state/NEXT-SESSION.md`.

## What "done" looks like

- Cowork shows a "Workspace MCP" (or whatever name you pick) connector as connected
- `mcp__<...>__search_gmail_messages` (or equivalent) works in a fresh Cowork session for both accounts
- A draft can be created against a real Gmail thread via the MCP — verified by Gus seeing it in his Gmail "Drafts" folder
- The same connector works from Gus's laptop / mobile after he configures it there once
- Local Scheduled Task is disabled; no Python process listening on Gus's machine
- Repo has a clear README explaining how to redeploy from scratch (in case Railway dies in 2 years)
- README also documents: exact tool names exposed, the OAuth scopes granted, the timezone default (America/Phoenix), and how Cowork artifacts should call the MCP via `window.cowork.callMcpTool()`
- Memory file `project_workspace_mcp_remote_migration.md` in Cowork's memory dir gets a "RESOLVED 2026-MM-DD" line appended (Gus can do this from the Cowork side; you can't write to Cowork memory from Claude Code unless you happen to mount that path)

## Resources to verify (don't trust the prompt blindly)

- https://github.com/taylorwilsdon/google_workspace_mcp — README, Releases, Dockerfile
- https://github.com/taylorwilsdon/google_workspace_mcp/issues/287 — discussion on stateful mode and external OAuth (relevant to architecture choice)
- https://pypi.org/project/workspace-mcp/ — current version
- Existing Railway service `web-production-5fcaa.up.railway.app` (the Guesty MCP) — pattern to mirror, NOT the place to deploy this. Separate project.

## How to resume this project in a new Claude Code session

This file is auto-discoverable via the lightweight `CLAUDE.md` in the same directory. To kick things off in a fresh session, Gus's first message can be as short as:

> Resume here. Read `BUILD-CONTEXT.md` and tell me the first three concrete things you're going to do, in order, before I confirm to proceed.

That keeps the chat-side context spend small while loading the full brief deliberately.
