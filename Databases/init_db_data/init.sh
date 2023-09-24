#!/bin/bash
set -e
export PGPASSWORD=$POSTGRES_PASSWORD;
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-END
		-- Set Users and its roles
		CREATE USER ${APP_DB_LOGISTIC_USER} WITH PASSWORD '${APP_DB_LOGISTIC_PASS}';
		CREATE USER ${APP_DB_ANALYTICS_USER} WITH PASSWORD '${APP_DB_ANALYTICS_PASS}';
		CREATE USER ${APP_DB_SALES_USER} WITH PASSWORD '${APP_DB_SALES_USER}';

		CREATE ROLE role_logistics;
		CREATE ROLE roles_analytics;
		CREATE ROLE roles_sales;

		ALTER USER ${APP_DB_LOGISTIC_USER} SET ROLE role_logistics;
		ALTER USER ${APP_DB_ANALYTICS_USER} SET ROLE roles_analytics;
		ALTER USER ${APP_DB_SALES_USER} SET ROLE roles_sales;

		-- tb_d_user_applications Section
		DROP TABLE IF EXISTS tb_d_user_applications;

		CREATE TABLE tb_d_user_applications (
      tb_d_user_applications_id SERIAL,
      membership_id character varying(100) PRIMARY KEY,
      first_name character varying(100) NOT NULL,
      last_name character varying(100) NOT NULL,
      email character varying(100) NOT NULL,
      birthday character varying(8) NOT NULL,
      mobile_no integer,
      above_18 boolean NOT NULL,
      etl_date DATE NOT NULL DEFAULT CURRENT_DATE
		);

		comment on column tb_d_user_applications.membership_id is 'The <last_name>_<hash(YYYYMMDD)>(truncated to first 5 digits of hash)';
		comment on column tb_d_user_applications.first_name is 'First name of Member';
		comment on column tb_d_user_applications.last_name is 'Last name of Member';
		comment on column tb_d_user_applications.email is 'Email of Member';
		comment on column tb_d_user_applications.birthday is 'Birthday of Member in YYYYMMDD format';
		comment on column tb_d_user_applications.mobile_no is 'Mobile no. of Member';
		comment on column tb_d_user_applications.above_18 is 'Applicant is over 18 years old as of 1 Jan 2022 or not';

		COPY tb_d_user_applications (first_name,last_name,birthday,mobile_no,email,above_18,membership_id)
		FROM '/docker-entrypoint-initdb.d/dataset/success_application/part-00000-bc67c6d5-b2f2-4631-ac02-91b4c689079f-c000.csv'
		DELIMITER ','
		CSV HEADER;

		-- tb_d_user_address Section
		DROP TABLE IF EXISTS tb_d_user_address;

		CREATE TABLE tb_d_user_address (
      tb_d_user_address_id SERIAL,
      membership_id character varying(100),
      address_line1 character varying(100) NOT NULL,
      address_line2 character varying(100) NOT NULL,
      city character varying(100) NOT NULL,
      postal_code character varying(8) NOT NULL,
	    mobile_no integer,
      created_date DATE NOT NULL,
      modified_date DATE NOT NULL,
	    FOREIGN KEY (membership_id) REFERENCES tb_d_user_applications(membership_id)
		);


    -- tb_d_manufacture Section
		DROP TABLE IF EXISTS tb_d_manufacture;

		CREATE TABLE tb_d_manufacture (
      tb_d_manufacture_id SERIAL,
      manufacture_id character varying(100) PRIMARY KEY,
      manufacture_name character varying(100) NOT NULL,
      active_ind BOOLEAN DEFAULT True,
      etl_date DATE NOT NULL DEFAULT CURRENT_DATE
		);

		COPY tb_d_manufacture (manufacture_id,manufacture_name)
		FROM '/docker-entrypoint-initdb.d/dataset/manufacture.csv'
		DELIMITER ','
		CSV HEADER;

    -- tb_d_item_inventory Section
		DROP TABLE IF EXISTS tb_d_item_inventory;

		CREATE TABLE tb_d_item_inventory (
      tb_d_item_inventory_id SERIAL,
      inventory_id character varying(100) PRIMARY KEY,
      quantity integer NOT NULL,
      created_date DATE NOT NULL,
      modified_date DATE NOT NULL,
	    deleted_date DATE
		);

    COPY tb_d_item_inventory (inventory_id,quantity,created_date,modified_date)
		FROM '/docker-entrypoint-initdb.d/dataset/item_inventory.csv'
		DELIMITER ','
		CSV HEADER;

		-- tb_d_items Section
		DROP TABLE IF EXISTS tb_d_items;

		CREATE TABLE tb_d_items (
      tb_d_items_id SERIAL,
      item_id character varying(100) PRIMARY KEY,
      sku character varying(100),
      inventory_id character varying(100),
      manufacture_id character varying(100) NOT NULL,
      item_name character varying(100) NOT NULL,
      item_price DECIMAL(10, 2) NOT NULL,
      item_weight DECIMAL(10, 2) NOT NULL,
      created_date DATE NOT NULL,
      modified_date DATE NOT NULL,
      deleted_date DATE,
      FOREIGN KEY (manufacture_id) REFERENCES tb_d_manufacture(manufacture_id),
      FOREIGN KEY (inventory_id) REFERENCES tb_d_item_inventory(inventory_id)
		);

		COPY tb_d_items (item_id,sku,inventory_id,manufacture_id,item_name,item_price,item_weight,created_date,modified_date)
		FROM '/docker-entrypoint-initdb.d/dataset/items.csv'
		DELIMITER ','
		CSV HEADER;


		-- tb_d_payment_details Section
		DROP TABLE IF EXISTS tb_d_payment_details;

		CREATE TABLE tb_d_payment_details (
      tb_d_payment_details_id SERIAL,
      payment_id character varying(100) PRIMARY KEY,
      amount DECIMAL(10,2) NOT NULL,
      provider character varying(100) NOT NULL,
      status character varying(100) NOT NULL,
      created_date DATE NOT NULL,
      modified_date DATE NOT NULL
		);

    COPY tb_d_payment_details (payment_id,amount,provider,status,created_date,modified_date)
		FROM '/docker-entrypoint-initdb.d/dataset/payment_details.csv'
		DELIMITER ','
		CSV HEADER;

    -- tb_f_sales_transactions Section
		DROP TABLE IF EXISTS tb_f_sales_transactions;

		CREATE TABLE tb_f_sales_transactions (
      tb_f_sales_transactions_id SERIAL,
      membership_id character varying(100),
      order_id character varying(100) NOT NULL,
      payment_id character varying(100) NOT NULL,
      item_id character varying(100) NOT NULL,
      quantity integer NOT NULL,
      item_total_price DECIMAL(10, 2) NOT NULL,
      item_total_weight DECIMAL(10, 2) NOT NULL,
      date_of_txn DATE NOT NULL,
      status character varying(100) NOT NULL,
      etl_date DATE NOT NULL DEFAULT CURRENT_DATE,
      FOREIGN KEY (membership_id) REFERENCES tb_d_user_applications(membership_id),
      FOREIGN KEY (payment_id) REFERENCES tb_d_payment_details(payment_id),
      FOREIGN KEY (item_id) REFERENCES tb_d_items(item_id)
		);

		comment on column tb_f_sales_transactions.membership_id is 'Foreign Key Rerferencing Primarky key of tb_d_user_applications.membership_id';
		comment on column tb_f_sales_transactions.order_id is 'ORDER ID assigned on a purchse';
		comment on column tb_f_sales_transactions.item_id is 'Actual Item line id , indivual product which got purchased';
		comment on column tb_f_sales_transactions.quantity is 'Quantity for an each item_line_id';
		comment on column tb_f_sales_transactions.item_total_price is 'total Price of each item_line_id ';
		comment on column tb_f_sales_transactions.item_total_weight is 'total weigth of each item_line_id';
		comment on column tb_f_sales_transactions.date_of_txn is 'Date of Purchase';
		comment on column tb_f_sales_transactions.etl_date is 'Date on Which Data was loaded';

		COPY tb_f_sales_transactions (membership_id,order_id,payment_id,item_id,quantity,item_total_price,item_total_weight,date_of_txn,status)
		FROM '/docker-entrypoint-initdb.d/dataset/sales_transactions.csv'
		DELIMITER ','
		CSV HEADER;

    -- Grant privileges to Analytics role
		GRANT SELECT ON tb_d_user_applications TO roles_analytics;

		-- Grant privileges to logistics role
		GRANT SELECT ON tb_f_sales_transactions TO role_logistics;
		GRANT UPDATE ON tb_f_sales_transactions TO role_logistics;

    -- Grant privileges to logistics role
		GRANT SELECT ON tb_d_items TO roles_sales;
		GRANT INSERT ON tb_d_items TO roles_sales;
		GRANT UPDATE ON tb_d_items TO roles_sales;
		GRANT DELETE ON tb_d_items TO roles_sales;

END