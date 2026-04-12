# ASX Project

Australian Securities Exchange stock data platform. Four repos, two servers.

## Architecture

```
asx/                        ← this repo (docs, crontab)
├── asx-data/               ← stock data pipeline + REST API (port 8082)
├── asx-web/                ← Flask web frontend (port 5000)
└── asx-announcements/      ← ASX announcements scraper + FastAPI server (port 8081)
```

## Machines

| Machine | Role |
|---------|------|
| server | Primary server; runs all three services |
| realiti-wsl (local WSL2) | GPU analysis only (RTX 4070); runs `asx-data/analysis/sync.sh` |

## Services

| Service | Port | Repo | Systemd unit |
|---------|------|------|--------------|
| Stock data API | 8082 | asx-data | `asx-backend.service` |
| Announcements API | 8081 | asx-announcements | `asx-announcements.service` |
| Web frontend | 5000 | asx-web | (started manually) |

## Quick restart

```bash
# Backend API
sudo systemctl restart asx-backend

# Announcements
sudo systemctl restart asx-announcements

# Web frontend
lsof -ti:5000 | xargs kill -9 2>/dev/null; true
cd $HOME/code/asx/asx-web && ./asx >> /tmp/asx-web.log 2>&1 &
```

## Crontab

The unified crontab lives at `asx/crontab`. Install on your server:

```bash
crontab $HOME/code/asx/crontab
```

## Data flow

```
asx-data/stockdb/stockdb.db  ←─ fetch_shorts, fetch_eod_daily, fetch_symbols (server cron)
                             ←─ fetch_symbol_changes, fetch_options          (server cron)
                             ←─ fetch_commodities, fetch_trading_economics    (server cron)
                             ←─ fetch_metals_dev, fetch_manganese             (server cron)
                             ←─ analysis/sync.sh                             (realiti-wsl)
        ↓
asx-data/backend/api.py  (port 8082)
        ↓
asx-web/asx.py           (port 5000, proxies to backend)
```

## Database summary

`stockdb/stockdb.db` (primary, ~1GB):
- `symbols` — listed companies (name, industry, shares outstanding)
- `endofday` — daily OHLCV prices
- `endofmonth` — monthly closes
- `shorts` — daily short positions (ASIC data, 2010–present)
- `corporate_events` — splits etc.
- `symbol_changes` — ASX code renames (old → new)
- `asx_options` — listed options (from rosser.com.au)
- `commodity_meta` — 25 tracked commodities with units and source info
- `commodity_prices` — daily/weekly commodity prices (4 sources: yfinance, Trading Economics, metals.dev, Jupiter Mines)

`users.db` (asx-web only, gitignored):
- `users`, `list_groups`, `lists`, `watchlist_items`, `portfolio_items`
- `transactions`, `algorithms`, `recommendations`, `list_column_prefs`
