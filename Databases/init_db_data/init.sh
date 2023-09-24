#!/bin/bash
set -e
export PGPASSWORD=$POSTGRES_PASSWORD;
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  CREATE USER $APP_DB_USER WITH PASSWORD '$APP_DB_PASS';
  CREATE DATABASE $APP_DB_NAME;
  GRANT ALL PRIVILEGES ON DATABASE $APP_DB_NAME TO $APP_DB_USER;
  \connect $APP_DB_NAME $APP_DB_USER
  BEGIN;
    CREATE TABLE IF NOT EXISTS event (
	  id CHAR(26) NOT NULL CHECK (CHAR_LENGTH(id) = 26) PRIMARY KEY,
	  aggregate_id CHAR(26) NOT NULL CHECK (CHAR_LENGTH(aggregate_id) = 26),
	  event_data JSON NOT NULL,
	  version INT,
	  UNIQUE(aggregate_id, version)
	);
	CREATE INDEX idx_event_aggregate_id ON event (aggregate_id);
  COMMIT;
EOSQL


-- CREATE SCHEMA
CREATE USER bypass;
CREATE DATABASE bypass;
GRANT ALL PRIVILEGES ON DATABASE bypass TO bypass;

-- Drop tables that exists
DROP TABLE IF EXISTS tb_user_applications CASCADE;
DROP TABLE IF EXISTS tbl_Items CASCADE;
DROP TABLE IF EXISTS tbl_Transactions CASCADE;

-- Create the Members table
CREATE TABLE tb_user_applications (
    membership_id SERIAL PRIMARY KEY,
    first_name VARCHAR(255) NOT NULL,
    last_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    date_of_birth DATE NOT NULL,
    mobile_no CHAR(8) NOT NULL,
    above_18 BOOLEAN NOT NULL
);

-- Create an index on the membership_id column in Members table
CREATE INDEX idx_membership_id ON tbl_Members (membership_id);

-- Create the Items table
CREATE TABLE tbl_Items (
    item_id SERIAL PRIMARY KEY,
    item_name VARCHAR(255) NOT NULL,
    manufacturer_name VARCHAR(255) NOT NULL,
    cost DECIMAL(10, 2) NOT NULL,
    weight_kg DECIMAL(5, 2) NOT NULL
);

-- Create indexes on the item_id column in Items table
CREATE INDEX idx_item_id ON tbl_Items (item_id);

-- Create the Transactions table
CREATE TABLE tbl_Transactions (
    transaction_id SERIAL PRIMARY KEY,
    membership_id INT NOT NULL,
    item_id INT NOT NULL,
    quantity INT NOT NULL,
    total_items_price DECIMAL(10, 2) NOT NULL,
    total_items_weight_kg DECIMAL(5, 2) NOT NULL,
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (membership_id) REFERENCES tbl_Members(membership_id)
    FOREIGN KEY (item_id) REFERENCES tbl_Items(item_id)
);

COPY inflation_data
FROM '/docker-entrypoint-initdb.d/successfull_application/23_09_2023_201926/part*.csv'
DELIMITER ','
CSV HEADER;