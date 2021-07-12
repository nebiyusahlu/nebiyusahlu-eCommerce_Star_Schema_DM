# nebiyusahlu-eCommerce_Star_Schema_DM

For this project, I was tasked to create a Star Schema data mart for an eCommerce sales company.
The company's OLTP system is in SQL Server and it contained 14 tables.

![eCommerce_OLTP](https://user-images.githubusercontent.com/82042663/125300500-b401a580-e2ef-11eb-8722-884c3ca4f4cd.PNG)


I created a staging database, then created a Stored Procedure in SQL Server which joins all the tables
and stores them in a Temporary table. Then, I created a SSIS package and used Execute SQL Task to execute the stored Procedure
to create the temp table which served as a source in the Data Flow Task to load data into the staging table in the 
staging database.

![SSIS_eCommerce_Staging](https://user-images.githubusercontent.com/82042663/125300903-1490e280-e2f0-11eb-955e-98bdd7eb68d5.PNG)


I created a Data Mart and schemas Dim and Fact in SQL Server and the Data Mart contained the following Dimension 
and Fact tables:-

1. Dim.Cusotmers
2. Dim.Products
3. Dim.Shipments
4. Dim.Invoices_Payments
5. Dim.Date
6. Fact.Orders

![Star eCommerce DM](https://user-images.githubusercontent.com/82042663/125300733-eb705200-e2ef-11eb-83fb-936db20df0f5.PNG)

I created another SSIS package to load the Dimension and Fact tables using the staging database table created earlier after applying transformations 
in the Data Flow task.

![SSIS_Load_Dim_Fact](https://user-images.githubusercontent.com/82042663/125302681-ca106580-e2f1-11eb-9dd3-cebc9827fa93.PNG)


I created another staging tables for each of the customer and product dimension tables which I used in a Merge statement in a Stored Procedure
to implement slowly changing dimension (SCD) Type 2, after intial load and loaded the matched data into the staging tables using Look Up Transformation for both dimensions 
and I used execute SQL task to execute the Stored Procedure.

![Merge_Dim_Customers](https://user-images.githubusercontent.com/82042663/125301185-54f06080-e2f0-11eb-88ea-60ddd8a775c9.PNG)

![Merge_Dim_Products](https://user-images.githubusercontent.com/82042663/125301848-01cadd80-e2f1-11eb-85e8-3b12b2331e99.PNG)


After creating the packge to load all the Dimensions and the Fact tables, I created another Master package which executes first the staging Package and then
the package that loads the Dimension and Fact tables using Execute Package Task.

![SSIS_Master_Package](https://user-images.githubusercontent.com/82042663/125302851-f1673280-e2f1-11eb-9a0d-21526315cbbc.PNG)


Thank you for taking the time to take a look at this project.

Any feedback is much appreciated.

- Nebiyu Sahlu


