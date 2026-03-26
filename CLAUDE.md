# ASX Project — Claude Guidance

This is the parent repo for the ASX stock data platform. See `README.md` for architecture overview.

## Repos

| Repo | Path | Purpose |
|------|------|---------|
| `asx-data` | `asx-data/` | Stock data pipeline + REST API (port 8082) |
| `asx-web` | `asx-web/` | Flask web frontend (port 5000) |
| `asx-announcements` | `asx-announcements/` | ASX announcements scraper + FastAPI (port 8081) |

## Pre-approved actions (run without asking)

File edits and writes to these paths need no confirmation:
- `asx-web/templates/`
- `asx-web/asx.py`
- `asx-data/scripts/`
- `asx-data/backend/api.py`

All read-only Bash commands are pre-approved: sqlite3 SELECT queries, grep, curl GET requests, log reads, ps/lsof, wc.

sqlite3 UPDATE/DELETE on stockdb.db or users.db is pre-approved when it's a targeted fix I've just diagnosed (not bulk deletes or DROP TABLE).

`pip3 *` commands are pre-approved — run without asking.

curl-based API tests (GET and POST to localhost) are pre-approved.

Never ask permission because a Bash command contains newlines.

## Service restarts (pre-approved, run without asking)

```bash
# Backend
sudo systemctl restart asx-backend

# Announcements
sudo systemctl restart asx-announcements

# Web frontend
bash $HOME/code/asx/asx-web/restart.sh
```

## Crontab

Canonical crontab: `asx/crontab`. Install: `crontab $HOME/code/asx/crontab`

## Key files

- `asx-data/backend/api.py` — REST API
- `asx-data/stockdb/stockdb.db` — primary database (~1GB)
- `asx-data/scripts/` — data-fetching scripts (symbol changes, options)
- `asx-web/asx.py` — Flask frontend
- `asx-announcements/server.py` — FastAPI announcements server

## Architecture rules

- `asx-web` never imports stockdb or touches stockdb.db directly — always calls the backend API
- `asx-data` has no user auth — serves stock market data only
- Market data (symbol_changes, asx_options) lives in stockdb.db, not users.db
- `asx-web/algo_runner.py` is a legitimate exception: it needs both stockdb.db (via API) and users.db

## Deployment

After pushing asx-data changes to GitHub, deploy to the server:
```bash
bash $HOME/code/asx/asx-data/deploy.sh
```
(`deploy.sh` = `git pull --ff-only` + `sudo systemctl restart asx-backend`)

## Documentation requirements

When adding or significantly changing a feature, update documentation in two places:

**1. README.md in the affected repo** — developer-facing, kept in git:
- New scripts: purpose, usage, CLI flags, cron schedule if applicable
- New DB tables or API endpoints: schema/signature and what they contain
- New extraction types: trigger pattern, source form, fields extracted
- Architectural decisions worth preserving (why, not just what)

**2. `/docs` page in asx-web** — user-facing, explains what the platform does:
- New data shown on stock pages (director activity, NTA, events)
- New calendar features
- New extraction capabilities visible to the user

If there is no `/docs` page yet, create one when the first user-facing feature warrants it.

## Notes

- Restarting the server is required after ALL Python/template changes (Flask runs with `debug=False`)
- Frontend restarts after template/Python edits are pre-approved — do them automatically, no confirmation needed
- Ring a terminal bell (`printf '\a'`) before any message that needs user input
