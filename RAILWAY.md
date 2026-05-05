# Railway deployment — ARK Google Workspace MCP

This fork of `taylorwilsdon/google_workspace_mcp` deploys as a remote, multi-user, OAuth 2.1 MCP server on Railway. It powers the Cowork daily-Gmail-summary live artifact and serves Workspace tools to Claude clients across Gus's devices.

The upstream README (`README.md`) covers the server itself. This file documents only the Railway-specific setup so you can redeploy from scratch if the existing service ever dies.

## What you need before starting

1. **Railway account** with a project created (separate project per MCP — keep deploys, logs, and env vars isolated).
2. **GCP "Claude Workspace MCP" project** with a **Web application** OAuth client. (The legacy Desktop-type client cannot be used for a remote server.) The OAuth consent screen must be set to **Internal** with both `gus@arkrentalsaz.com` and `gus@arkrentals.co` in the same Google Workspace.
3. **GitHub access** to `ARKrentals/ark-google-workspace-mcp`.
4. **A 48-byte signing key** generated once with `python -c "import secrets; print(secrets.token_urlsafe(48))"`. Save it somewhere durable — losing it invalidates stored OAuth tokens.

## Deploy from scratch

1. Create a new Railway project. Link it to `ARKrentals/ark-google-workspace-mcp`, branch `main`. Railway will auto-detect `railway.toml` and build from `Dockerfile`.
2. Add a **Railway Volume** to the service:
   - Mount path: `/data` (NOT `/app/*` — see note below)
   - Size: 1 GB (free tier is fine; we'll use kilobytes)

   > Don't mount under `/app/`. Railway volumes contain a `lost+found` dir at
   > the mount root; setuptools' editable install scans the project root
   > (`/app`) for Python packages, finds `lost+found`, and crashes with
   > permission-denied trying to write `__init__.py` into the root-owned
   > volume contents. `/data` is outside the project tree and avoids this.
3. Set the env vars listed in `.env.example`. Specifically:
   - `GOOGLE_OAUTH_CLIENT_ID` and `GOOGLE_OAUTH_CLIENT_SECRET` from the GCP Web client
   - `FASTMCP_SERVER_AUTH_GOOGLE_JWT_SIGNING_KEY` from the random generation above
   - **Do NOT set `PORT`.** Railway auto-injects PORT and routes its edge to that
     same port; setting PORT explicitly causes 502s because the app and edge
     end up on different ports.
   - Leave `GOOGLE_OAUTH_REDIRECT_URI` and `WORKSPACE_EXTERNAL_URL` as placeholders for now
4. Deploy. Note the public URL Railway assigns (e.g. `https://ark-google-workspace-mcp-production.up.railway.app`).
5. Update **two** things with that URL:
   - GCP OAuth client → "Authorized redirect URIs" → add `https://<railway-url>/oauth2callback` (and remove the placeholder)
   - Railway env vars → `GOOGLE_OAUTH_REDIRECT_URI=https://<railway-url>/oauth2callback` and `WORKSPACE_EXTERNAL_URL=https://<railway-url>`
6. Redeploy (Railway will trigger this automatically on env-var change).
7. Verify `https://<railway-url>/health` returns 200.

## OAuth one-time per account

For each Google account (`gus@arkrentalsaz.com`, `gus@arkrentals.co`):

1. Open the MCP's OAuth init URL in a browser logged in to that account. (URL determined by the upstream server — typically `https://<railway-url>/auth/login` or hit by the MCP client during initial connector setup.)
2. Sign in, click through the consent screen.
3. Server stores the refresh token in `/app/store_creds/` keyed by email.
4. Bearer token is issued back to the client.

## Connect from Claude Cowork

Add the MCP as a Cowork connector via Cowork's **Connectors** UI:

- **MCP URL:** `https://<railway-url>/mcp`
- **Bearer:** the per-account token from the OAuth dance above

Repeat the connector add for the second account if you want both available simultaneously in Cowork.

## Conventions for downstream artifacts

- **Timezone:** all daily-summary date math defaults to **America/Phoenix** (Scottsdale; no DST). Bake this into artifact code.
- **Calling from a Cowork artifact:** use `window.cowork.callMcpTool('<tool_name>', { ... })` with the connector identifier matching the one Gus configured.
- **Useful tool names:**
  - `search_gmail_messages` — list/filter Gmail with date/label/from filters
  - `get_gmail_message_content` — read full message body + headers + thread
  - `draft_gmail_message` — create a draft tied to a specific thread (Extended tier)
  - `modify_gmail_message_labels` — apply/remove labels (e.g. mark "summarized")

For the canonical tool list with current names, hit `https://<railway-url>/mcp` with an MCP client and call `tools/list`, or check the upstream README.

## Updating from upstream

```bash
git fetch upstream
git merge upstream/main
git push origin main
```

Railway redeploys automatically. Pin to a tagged release if you want to avoid surprises.

## Decommissioning the local install

After the Railway deploy is verified working:

1. Disable the `WorkspaceMCP` Windows Scheduled Task.
2. Move `C:\Users\guske\workspace-mcp-start.ps1` and `C:\Users\guske\.google_workspace_mcp\` to an archive folder (don't delete — paper trail).
3. Move/shred the `client_secret_*.json` files from `C:\Users\guske\Downloads\`.
