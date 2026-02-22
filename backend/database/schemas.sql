-- Core sneaker catalog
CREATE TABLE sneakers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    brand VARCHAR(100) NOT NULL,
    colorway VARCHAR(255),
    sku VARCHAR(100) UNIQUE,
    retail_price DECIMAL(10,2),
    release_date DATE,
    category VARCHAR(100), -- 'jordan', 'yeezy', 'nike', etc.
    image_url TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Price history per sneaker (the core data)
CREATE TABLE price_history (
    id SERIAL PRIMARY KEY,
    sneaker_id INT REFERENCES sneakers(id) ON DELETE CASCADE,
    price DECIMAL(10,2) NOT NULL,
    recorded_at TIMESTAMP DEFAULT NOW(),
    source VARCHAR(50) -- 'stockx', 'goat', 'manual', etc.
);

-- Indexes (Jordan Index, Yeezy Index, etc.)
CREATE TABLE indexes (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Which sneakers belong to which index
CREATE TABLE index_members (
    index_id INT REFERENCES indexes(id) ON DELETE CASCADE,
    sneaker_id INT REFERENCES sneakers(id) ON DELETE CASCADE,
    weight DECIMAL(5,2) DEFAULT 1.0,
    PRIMARY KEY (index_id, sneaker_id)
);

-- Index value over time
CREATE TABLE index_history (
    id SERIAL PRIMARY KEY,
    index_id INT REFERENCES indexes(id) ON DELETE CASCADE,
    value DECIMAL(10,2) NOT NULL,
    recorded_at TIMESTAMP DEFAULT NOW()
);

-- Users
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    balance DECIMAL(10,2) DEFAULT 10000.00, -- fake money
    created_at TIMESTAMP DEFAULT NOW()
);

-- Portfolio holdings
CREATE TABLE holdings (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id) ON DELETE CASCADE,
    sneaker_id INT REFERENCES sneakers(id) ON DELETE CASCADE,
    quantity INT DEFAULT 1,
    avg_buy_price DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Trade history
CREATE TABLE trades (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id) ON DELETE CASCADE,
    sneaker_id INT REFERENCES sneakers(id) ON DELETE CASCADE,
    trade_type VARCHAR(4) CHECK (trade_type IN ('BUY', 'SELL')),
    quantity INT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    total DECIMAL(10,2) NOT NULL,
    executed_at TIMESTAMP DEFAULT NOW()
);