# ASX Project

Australian Securities Exchange stock data platform. Four core repos plus an optional Interactive Brokers gateway, two servers.

## Architecture

- [asx](https://github.com/billsegall/asx) — this repo (docs, crontab)
  - [asx-data](https://github.com/billsegall/asx-data) — stock data pipeline + REST API (port 8082)
  - [asx-web](https://github.com/billsegall/asx-web) — Flask web frontend (port 7000)
  - [asx-announcements](https://github.com/billsegall/asx-announcements) — ASX announcements scraper + FastAPI server (port 8081)
  - [asx-ib](https://github.com/billsegall/asx-ib) — Interactive Brokers gateway for live/EOD market data *(optional — core platform works without it, falling back to Yahoo Finance)*

## Machines

| Machine | Role |
|---------|------|
| server | Primary server; runs all core services + optional IB Gateway |
| realiti-wsl (local WSL2) | GPU analysis only (RTX 4070); runs `asx-data/analysis/sync.sh` |

## Services

| Service | Port | Repo | Managed by |
|---------|------|------|--------------|
| Stock data API | 8082 | asx-data | `asx-backend.service` |
| Announcements API | 8081 | asx-announcements | `asx-announcements.service` |
| Web frontend | 7000 | asx-web | `asx-web.service` |
| IB Gateway (live) | 4001 | asx-ib | Docker Compose *(optional)* |
| IB Gateway (paper) | 4002 | asx-ib | Docker Compose *(optional)* |

## Quick restart

```bash
# Backend API
sudo systemctl restart asx-backend

# Announcements
sudo systemctl restart asx-announcements

# Web frontend
sudo systemctl restart asx-web

# IB Gateway (optional — Docker, not systemd)
cd asx-ib && docker compose restart ib-gateway         # live
cd asx-ib && docker compose restart ib-gateway-paper   # paper trading
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
asx-web/asx.py           (port 7000, proxies to backend)
```

## Database summary

`stockdb/stockdb.db` (primary, ~1GB) — market data, no user auth:
- `symbols` — listed companies (name, industry, shares outstanding, `current` flag)
- `endofday`, `endofmonth` — daily OHLCV / monthly closes
- `shorts` — daily short positions (ASIC data, 2010–present)
- `dividends` — dividend history (Yahoo Finance)
- `fundamentals`, `financials_annual` — valuation/margin snapshots and annual statements (Yahoo Finance)
- `shares_history` — shares-on-issue over time
- `events` — earnings/ex-dividend/etc. dates (Yahoo Finance)
- `corporate_events` — splits/consolidations
- `symbol_changes` — ASX code renames (old → new), with the company's new name
- `symbol_history_migrations` — audit ledger for moving a renamed symbol's market-data history (endofday, dividends, fundamentals, etc.) from its old code to its new one
- `asx_options` — ASX-listed warrants (IB Gateway primary, Markit fallback)
- `kronos_predictions` — daily ML price-direction predictions
- `eod_fetch_failures` — tracks symbols with consecutive missed EOD fetches
- `commodity_meta`, `commodity_prices` — 25 tracked commodities, 4 sources (yfinance, Trading Economics, metals.dev, Jupiter Mines)
- `crypto_meta`, `crypto_prices` — top-100 cryptocurrencies (CoinGecko + yfinance)
- `currency_meta`, `currency_prices` — FX rates

`users.db` (asx-web only, gitignored) — auth, watchlists/portfolios, no market data:
- `users`, `list_groups`, `lists`, `watchlist_items`, `portfolio_items`
- `transactions`, `algorithms`, `recommendations`, `list_column_prefs`
- `research_reports`, `research_folders` — broker research with AI-extracted price targets
- `alerts`, `alert_conditions` — price and event alerts per user
- `fermi_reports`, `fermi_api_calls` — AI-generated Fermi analysis reports
- `dashboard_preferences` — per-user dashboard widget config
- `user_feature_changes` — audit log for admin feature toggling
- `portfolio_notices` — dismissible per-user notices (e.g. "your holding was consolidated/renamed")
- `processed_corporate_actions` — ledger of consolidations/splits/renames already applied to holdings
- `option_quotes_cache`, `warrant_notes` — cached warrant pricing + per-user notes
- `ib_trade_log` — audit trail of orders placed via the IB trading integration
- `symbol_changes` — **orphaned**: 581 rows, no code references it anymore. Leftover from before symbol-change tracking moved to `stockdb.db` (see `asx-data/CLAUDE.md`); not part of the current architecture, left in place rather than dropped without confirmation.
