-- 001_init_schema.sql — baseline schema + seed data for the orders service.
-- Idempotent so bootstrap can be re-run safely.

CREATE TABLE IF NOT EXISTS customers (
    id         SERIAL PRIMARY KEY,
    email      VARCHAR(255) UNIQUE NOT NULL,
    name       VARCHAR(100),
    created_at TIMESTAMP DEFAULT now()
);

CREATE TABLE IF NOT EXISTS orders (
    id          SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customers(id),
    total       DECIMAL(10,2) NOT NULL,
    created_at  TIMESTAMP DEFAULT now()
);

-- Seed representative data so branches have realistic rows to test against.
INSERT INTO customers (email, name) VALUES
    ('ada@example.com',  'Ada Lovelace'),
    ('grace@example.com','Grace Hopper'),
    ('alan@example.com', 'Alan Turing')
ON CONFLICT (email) DO NOTHING;

INSERT INTO orders (customer_id, total)
SELECT c.id, v.total
FROM (VALUES
    ('ada@example.com',   49.99),
    ('ada@example.com',   19.00),
    ('grace@example.com', 129.50),
    ('alan@example.com',  12.00)
) AS v(email, total)
JOIN customers c ON c.email = v.email
WHERE NOT EXISTS (SELECT 1 FROM orders);  -- only seed once
