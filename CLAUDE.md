# CLAUDE.md — Google Workspace MCP Server

This project deploys `taylorwilsdon/google_workspace_mcp` as a remote, multi-user, OAuth 2.1 server on Railway, replacing a dead local install. The headline downstream use case is a Cowork live artifact that monitors Gus's Gmail accounts daily, surfaces important new mail, and auto-drafts responses.

**Read `BUILD-CONTEXT.md` in this same folder before doing anything substantive.** It contains the full brief: locked architecture decisions, the diagnostic findings that justified the migration, OAuth scope requirements, the implementation sequence, and the definition of done.

**About Gus:** sole operator of ARK Rentals (Scottsdale luxury STR management). New to developer tooling — explain in plain language, translate jargon. Comms style: warm, direct, no over-apology. State what you're doing, do it, say what changed.

**Hard rules carried over from his other projects:**
- Code lives in `C:\Code\<project>\`, never in OneDrive (`.git/` corruption trap).
- No secrets in git. Bearer tokens, OAuth client secrets, refresh tokens go in Railway Variables and a gitignored `.env`.
- Don't auto-deploy. Show Gus the diff and the env vars before any `railway up`.

**Reference: the upstream `taylorwilsdon/google_workspace_mcp` repo.** It's mature, actively maintained, and represents current best practice for Workspace MCP deployment (Docker, OAuth 2.1, stateless mode). Stay close to upstream so future updates can be pulled cleanly — default to "fork and modify minimally", not "rewrite."

For everything not covered by upstream, apply general MCP server and production-deployment best practices. There is no internal "house style" to imitate — the hard rules below are the only constraints; otherwise, build it the right way.

When resuming, the canonical way to pick up state is to read `BUILD-CONTEXT.md`, then check git log for what's been done since.
