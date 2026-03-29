# CLAUDE.md — Bloomberg Terminal for Hype Culture

## Project Overview

A paper trading simulator for sneakers and hype culture assets. Users invest fake money in sneakers and streetwear, track category indexes, and speculate on upcoming drops — all wrapped in a financial terminal aesthetic. Think StockX price charts with candlestick views, order book depth, category indexes, and a full paper trading simulation layer.

**Elevator pitch:** "A Bloomberg Terminal for hype culture — Investopedia for sneakers."

---

## Architecture

```
hype-terminal/
├── frontend/          # React app (Vercel)
├── backend/           # FastAPI or Express (Railway/Render)
├── database/          # PostgreSQL via Supabase
└── CLAUDE.md
```

---

## Tech Stack

| Layer     | Choice                                      |
|-----------|---------------------------------------------|
| Database  | PostgreSQL via Supabase (free tier)         |
| Backend   | FastAPI (Python) or Express (Node.js)       |
| Frontend  | React                                       |
| Charts    | Recharts or TradingView Lightweight Charts  |
| Auth      | Supabase Auth or simple JWT                 |
| Hosting   | Vercel (frontend) + Railway or Render (backend) |
| Cost      | $0 — fully free tier                        |

---

## Database Schema

Design for extensibility from day one. Use a `category` field, not sneaker-specific tables. This is what lets us extend to streetwear, cards, and collectibles in V2.

### Core Tables

```sql
-- Items table: sneakers today, streetwear/cards tomorrow
CREATE TABLE items (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  brand       TEXT NOT NULL,
  category    TEXT NOT NULL,          -- 'sneaker', 'streetwear', 'card'
  subcategory TEXT,                   -- 'jordan', 'yeezy', 'nike-sb'
  colorway    TEXT,
  retail_price NUMERIC(10,2),
  image_url   TEXT,
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- Price history: one row per item per day
CREATE TABLE price_history (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id    UUID REFERENCES items(id),
  date       DATE NOT NULL,
  open       NUMERIC(10,2),
  high       NUMERIC(10,2),
  low        NUMERIC(10,2),
  close      NUMERIC(10,2),
  volume     INTEGER,
  UNIQUE(item_id, date)
);

-- Users: managed by Supabase Auth, extended here
CREATE TABLE users (
  id           UUID PRIMARY KEY REFERENCES auth.users(id),
  username     TEXT UNIQUE NOT NULL,
  cash_balance NUMERIC(10,2) DEFAULT 10000.00,
  created_at   TIMESTAMPTZ DEFAULT now()
);

-- Portfolio holdings
CREATE TABLE holdings (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id   UUID REFERENCES users(id),
  item_id   UUID REFERENCES items(id),
  quantity  INTEGER NOT NULL DEFAULT 0,
  avg_cost  NUMERIC(10,2),
  UNIQUE(user_id, item_id)
);

-- Trade history
CREATE TABLE trades (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID REFERENCES users(id),
  item_id    UUID REFERENCES items(id),
  trade_type TEXT NOT NULL,           -- 'buy' or 'sell'
  quantity   INTEGER NOT NULL,
  price      NUMERIC(10,2) NOT NULL,
  executed_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes (Jordan Index, Yeezy Index, Top 10 Hype)
CREATE TABLE indexes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  slug        TEXT UNIQUE NOT NULL,
  description TEXT,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE index_components (
  index_id UUID REFERENCES indexes(id),
  item_id  UUID REFERENCES items(id),
  weight   NUMERIC(5,4),             -- weights sum to 1.0
  PRIMARY KEY (index_id, item_id)
);

CREATE TABLE index_history (
  id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  index_id UUID REFERENCES indexes(id),
  date     DATE NOT NULL,
  value    NUMERIC(10,2),
  UNIQUE(index_id, date)
);
```

---

## API Endpoints

### Items
```
GET  /items                    # List all items (supports ?category=sneaker&subcategory=jordan)
GET  /items/:id                # Single item detail
GET  /items/:id/prices         # Price history for an item
```

### Indexes
```
GET  /indexes                  # List all indexes
GET  /indexes/:slug            # Index detail + component weights
GET  /indexes/:slug/history    # Index price history
```

### Trading (auth required)
```
GET  /portfolio                # Current holdings + account value
POST /trades/buy               # Buy an item { item_id, quantity }
POST /trades/sell              # Sell an item { item_id, quantity }
GET  /trades/history           # User's trade log
```

### Auth
```
POST /auth/signup              # Create account, seed $10,000 balance
POST /auth/login               # Return JWT
```

---

## Frontend Pages

```
/                    # Homepage — index dashboard + top movers grid
/market              # Full item grid with filters (category, brand, price)
/item/:id            # Item detail — price chart, stats, buy/sell panel
/indexes             # Index dashboard — Jordan, Yeezy, Top 10 Hype
/portfolio           # Holdings, P&L, trade history (auth required)
/login               # Auth page
```

---

## UI / Design Rules

This is a financial terminal, not a sneaker store. Every design decision should reinforce that aesthetic.

- **Background:** Near-black (`#0a0a0a` or `#0d1117`)
- **Primary text:** Terminal green (`#00ff41`) or white
- **Positive/up:** Green (`#00c853`)
- **Negative/down:** Red (`#ff1744`)
- **Font:** Monospace for data, numbers, tickers (`JetBrains Mono`, `Fira Code`, or `monospace`)
- **Grid layout:** Dense information layout — no whitespace-heavy consumer design
- **Charts:** Dark background, green lines, candlestick support
- **Numbers:** Always right-aligned, fixed decimal places
- **Price changes:** Always show `+$X.XX (+X.XX%)` format with color coding

Reference aesthetic: Bloomberg Terminal, TradingView dark mode, CRT green phosphor displays.

---

## Month 1 Milestones

### Week 1 — Foundation
- [ ] Supabase project created, schema applied
- [ ] 20–30 sneakers seeded with historical price data (Kaggle or manual StockX)
- [ ] `GET /items` and `GET /items/:id/prices` returning real data
- [ ] API verified in Postman or browser
- **Deliverable:** Working data pipeline — no frontend needed yet

### Week 2 — Visual Layer
- [ ] React app scaffolded and deployed to Vercel
- [ ] Homepage grid of sneakers
- [ ] Item detail page with price history chart (Recharts or TradingView)
- [ ] Terminal aesthetic applied — dark, monospace, green
- **Deliverable:** Live URL with real sneaker price charts

### Week 3 — Simulation Layer
- [ ] Supabase Auth wired up (signup/login)
- [ ] New users seeded with $10,000 on signup
- [ ] Buy/sell flow: deducts cash, creates holding record
- [ ] Portfolio page: holdings, quantity, current value, total account value
- **Deliverable:** Working paper trading simulator end to end

### Week 4 — Indexes + Polish
- [ ] Jordan Index, Yeezy Index, Top 10 Hype Index calculated and stored
- [ ] Index dashboard on homepage
- [ ] Bug fixes, loading states, error handling
- [ ] Clean demo flow: signup → browse → buy → check portfolio
- **Deliverable:** Complete MVP, demo-ready for interviews

---

## Data Seeding

Start with these sneakers across the major subcategories:

**Jordan:**
- Air Jordan 1 Retro High OG "Chicago" (2015)
- Air Jordan 1 Retro High OG "Bred Toe"
- Air Jordan 4 Retro "Fire Red"
- Air Jordan 11 Retro "Concord"

**Yeezy:**
- Yeezy Boost 350 V2 "Zebra"
- Yeezy Boost 350 V2 "Beluga"
- Yeezy Foam Runner "Sand"
- Yeezy Slide "Pure"

**Nike SB / Collab:**
- Nike SB Dunk Low "Strangelove"
- Nike SB Dunk Low "Paris"
- Nike Air Force 1 Travis Scott

**New Balance / Other:**
- New Balance 550 "White Green"
- Salehe Bembury x New Balance 2002R

Pull historical price data from:
- [Kaggle Sneaker Datasets](https://www.kaggle.com/search?q=sneaker+resale+prices)
- Manual export from StockX price history charts
- Static JSON seed files are fine for MVP

---

## Index Calculation

Indexes are recalculated daily as a weighted average of component sneaker closing prices.

```python
def calculate_index_value(components: list[dict]) -> float:
    """
    components: [{ "close_price": 350.00, "weight": 0.25 }, ...]
    weights must sum to 1.0
    """
    return sum(c["close_price"] * c["weight"] for c in components)
```

Normalize to a base value of 1000 on the index inception date for readability (like the S&P 500).

### Initial Index Composition

**Jordan Index** — Equal weight across 4 Jordan silhouettes
**Yeezy Index** — Equal weight across 4 Yeezy models
**Top 10 Hype Index** — Market-cap weighted top 10 by resale volume

---

## Paper Trading Rules

- Starting balance: **$10,000 fake money** per user
- No margin, no leverage (V1)
- Trades execute at the latest closing price
- No fractional shares — whole pairs only
- Short selling disabled (V1)
- No transaction fees (V1 — add in V2 for realism)

---

## V2 Features (Post-MVP — Do Not Build in Month 1)

Save these for after the MVP ships. They extend the vision but will derail Month 1 if started early.

- **Drop futures** — speculative trading on unreleased sneakers pre-retail
- **Short selling** — bet on resale price drops after Nike restocks
- **Options mechanics** — calls and puts on upcoming hyped releases
- **Streetwear category** — Supreme, Palace, same architecture
- **News feed** — sneaker news ticker that moves market sentiment
- **Trading cards / collectibles** — same system, different category value
- **Transaction fees** — adds realism to the trading simulation
- **Social features** — leaderboard, portfolio sharing

---

## Local Development Setup

```bash
# Clone and install
git clone https://github.com/yourusername/hype-terminal
cd hype-terminal

# Backend (FastAPI)
cd backend
python -m venv venv && source venv/bin/activate
pip install fastapi uvicorn supabase python-dotenv
cp .env.example .env   # add Supabase URL + anon key
uvicorn main:app --reload

# Frontend (React)
cd ../frontend
npm install
cp .env.example .env   # add VITE_SUPABASE_URL + VITE_API_URL
npm run dev
```

### Required Environment Variables

```
# backend/.env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-anon-key
DATABASE_URL=postgresql://...

# frontend/.env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key
VITE_API_URL=http://localhost:8000
```

---

## Deployment

| Service   | What lives there        | Free tier limits               |
|-----------|-------------------------|-------------------------------|
| Vercel    | React frontend          | Unlimited for personal projects |
| Railway   | FastAPI backend         | $5 free credits/month          |
| Supabase  | PostgreSQL + Auth       | 500MB DB, 50MB file storage    |

Deploy frontend first (Week 2), backend when the API is stable (Week 2–3).

---

## Interview Demo Script (2 minutes)

1. **Homepage** — "This is the index dashboard. The Jordan Index, Yeezy Index, and Top 10 Hype Index recalculate daily from real resale price data."
2. **Market page** — "Users can browse the market, filter by brand or category, see price charts with the same candlestick view you'd see on TradingView."
3. **Item detail** — "Each sneaker has a full price history. I'm pulling this from StockX historical data seeded into Postgres."
4. **Paper trade** — "I'll buy 2 pairs of the Jordan 1 Chicago. It deducts from my $10,000 balance and adds to my portfolio."
5. **Portfolio** — "Here's my holdings page — current value, P&L, average cost basis. Same data model you'd see in a real brokerage."
6. **Close** — "The architecture is built to extend to streetwear, trading cards, anything with resale volatility. Same schema, new category."

---

## Resume Line

> "Built a Bloomberg Terminal for hype culture — a full-stack paper trading simulator where users invest fake money in sneakers, track category indexes (Jordan Index, Yeezy Index), and analyze resale price history through a financial terminal UI. React frontend, FastAPI backend, PostgreSQL on Supabase."
