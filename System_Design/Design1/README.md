# Overview of this section
To implement a strategy for accessing this database based on the various teams' needs.  

---

## Approach
1. We will follow the postgres
   - Use Roles
   - Grant Least Privilege
   - Implement Column and Row level security
   - Create Read-Only, Update, Delete Roles
   - Don’t Share the Superuser Role
   - Use Password Authentication
   - Enforce Strong Passwords
2. We have Roles Created during Databases Creation Step(Refer [init.sh](https://github.com/KumarRoshandot/e-commerce-use-case/tree/main/Databases/init_db_data/init.sh) in docker composer)
---
### Logistics
- Activity Required
  - Get the sales details (in particular the weight of the total items bought)
  - Update the table for completed transactions
  
- Solution
-     -- CREATE ROLES AND USERS 
		CREATE USER ${APP_DB_LOGISTIC_USER} WITH PASSWORD '${APP_DB_LOGISTIC_PASS}';
		CREATE ROLE role_logistics;
		ALTER USER ${APP_DB_LOGISTIC_USER} SET ROLE role_logistics;
		
		-- Grant privileges to logistics role
		GRANT SELECT ON tb_f_sales_transactions TO role_logistics;
		------ GRANT UPDATE ON tb_f_sales_transactions TO role_logistics;
        CREATE POLICY tb_f_sales_transactions_policy ON tb_f_sales_transactions FOR UPDATE TO role_logistics USING (status=completed);


### Analytics
- Activity Required
  - Perform analysis on the sales and membership status
  - Should not be able to perform updates on any tables
  
- Solution
-     -- CREATE ROLES AND USERS 
		CREATE USER ${APP_DB_ANALYTICS_USER} WITH PASSWORD '${APP_DB_ANALYTICS_PASS}';
		CREATE ROLE roles_analytics;
		ALTER USER ${APP_DB_ANALYTICS_USER} SET ROLE roles_analytics;
		
		-- Grant privileges to analytics role
		GRANT SELECT ON tb_d_user_applications TO roles_analytics; 

### Sales
- Activity Required
  - Get the sales details (in particular the weight of the total items bought)
  - Update the table for completed transactions
  
- Solution
-     -- CREATE ROLES AND USERS 
		CREATE USER ${APP_DB_SALES_USER} WITH PASSWORD '${APP_DB_SALES_USER}';
		CREATE ROLE roles_sales;
		ALTER USER ${APP_DB_SALES_USER} SET ROLE roles_sales;
		
		-- Grant privileges to sales role
		GRANT SELECT ON tb_d_items TO roles_sales;
		GRANT INSERT ON tb_d_items TO roles_sales;
		GRANT UPDATE ON tb_d_items TO roles_sales;
		GRANT DELETE ON tb_d_items TO roles_sales;

---
