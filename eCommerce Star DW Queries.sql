CREATE DATABASE eCommerce_DW
GO
USE eCommerce_DW
GO
IF NOT EXISTS (
			   SELECT *
               FROM information_schema.schemata 
               WHERE schema_name='Dim'
			   )
BEGIN
  EXEC sp_executesql N'CREATE SCHEMA Dim';
END
GO

IF NOT EXISTS (
			   SELECT *
               FROM information_schema.schemata 
               WHERE schema_name='Fact'
			   )
BEGIN
  EXEC sp_executesql N'CREATE SCHEMA Fact';
END
GO

--=================  Create Temp Table of Denormalized eCommerce tables


CREATE PROC   usp_Load_Staging_eCommerce
AS
BEGIN
SET NOCOUNT ON

IF OBJECT_ID('tempdb..##Denormalized_eCommerce_Data') IS NOT NULL 
DROP TABLE ##Denormalized_eCommerce_Data


SELECT		 OT.order_id,OT.order_item_id,OT.order_item_price,OT.order_item_quantity,
			O.date_order_placed,O.order_details,
			I.invoice_date,I.invoice_number,I.order_id AS Invoice_Order_Id,
			PR.product_id,PR.product_name,PR.product_color,ISNULL([product_size],'N/A') AS [product_size],
			PR.product_price,PR.product_description,
			RP.product_type_code,
			RPM.payment_method_code,RPM.payment_method_description,
			C.Customer_Id,C.Organisation_or_person,C.Organisation_name,C.First_Name,
			C.Middle_Initial,C.Last_Name,C.Gender,
			C.Email_Address,C.Login_name,C.Login_Password,C.Phone_number,C.Address_Line1,C.Address_Line2,C.Address_Line3,
			C.Address_Line4,C.Town_City,C.County,C.Country,
			ROS.order_status_code,ROS.order_status_description,
			ROI.order_item_status_code,ROI.order_item_status_description,
			CPM.customer_payment_id,CPM.credit_card_number,CPM.payment_method_details,
			S.shipment_id,S.shipment_date,S.shipment_tracking_number,S.other_shipment_details,
			P.payment_id,COALESCE(P.payment_amount,0)AS payment_amount,
			 ISNULL(P.payment_date ,'') AS payment_date  ,
			SI.order_item_id AS Shipment_Order_Item_ID,S.order_id AS Shipment_Order_Id,S.shipment_Id as Shipment_Item_Id,
			S.invoice_number AS Shipment_Invoice_Number,
			RSC.invoice_status_code RSC_Invoice_Status_Code,RSC.invoice_status_description
INTO        ##Denormalized_eCommerce_Data
FROM		[eCommerceDB].dbo.[Order_Items] OT 
LEFT JOIN	[eCommerceDB].dbo.Orders O
ON			O.order_id = OT.order_id
LEFT JOIN   [eCommerceDB].dbo.Products PR
ON			OT.product_id = PR.product_id
LEFT JOIN   [eCommerceDB].dbo.Ref_Product_Type_Codes RP
ON			PR.product_type_code = RP.product_type_code
LEFT JOIN   [eCommerceDB].dbo.Invoices I
ON          O.order_id = I.order_id
LEFT JOIN		(
				[eCommerceDB].dbo.ShipmentS S
				INNER JOIN       [eCommerceDB].dbo.Shipment_Items SI
				ON				 S.shipment_id = SI.shipment_id				
				)
ON          OT.order_item_id = SI.order_item_id
LEFT JOIN   [eCommerceDB].dbo.Payments P
ON			I.invoice_number = P.invoice_number
LEFT JOIN   [eCommerceDB].dbo.Ref_Invoice_Status_Codes RSC
ON			I.invoice_status_code = RSC.invoice_status_code
LEFT JOIN	[eCommerceDB].dbo.Ref_Order_Status_Codes ROS
ON			O.order_status_code = ROS.order_status_code
LEFT JOIN   [eCommerceDB].dbo.Ref_Order_Item_Status_Codes ROI
ON          OT.order_item_status_code = ROI.order_item_status_code
LEFT JOIN	[eCommerceDB].dbo.Customers C
ON			O.customer_id = C.Customer_Id
LEFT JOIN   [eCommerceDB].dbo.Customer_Payment_Methods CPM
ON			C.Customer_Id = CPM.customer_id
LEFT JOIN   [eCommerceDB].dbo.Ref_Payment_Methods RPM
ON			CPM.payment_method_code = RPM.payment_method_code

END

----- CREATE Dimension table Customers

IF EXISTS (
		   SELECT *
           FROM INFORMATION_SCHEMA.TABLES 
           WHERE TABLE_SCHEMA = 'Dim' 
           AND TABLE_NAME = 'Customers'
		   )
BEGIN
     DROP TABLE Dim.Customers
END
GO
CREATE TABLE Dim.Customers 
( 
Customer_Key			int identity(1,1) Primary Key not null,
Customer_Id				int not null,
Organisation_or_person	varchar(1),
Organisation_name		varchar(50) ,
Gender					varchar(10) DEFAULT 'N/A'  ,
First_Name				varchar(50) DEFAULT 'N/A' ,
Middle_Initial			varchar(50) DEFAULT 'N/A',
Last_Name				varchar(50) DEFAULT 'N/A',
Email_Address			nvarchar(50),
Login_name				nvarchar(50),
Login_Password			nvarchar(25),
Phone_number			nvarchar(50),
Address_Line1			nvarchar(50),
Address_Line4			nvarchar(50) DEFAULT 'N/A',
Town_City				varchar(50)not null,
County					varchar(50) not null,
Country					varchar(50)not null,
Credit_Card_Number		nvarchar(50) DEFAULT 'Pain in Check',
Customer_Payment_ID		int DEFAULT 0,
Payment_method_code     char(4) not null,
Payment_method_description varchar(50),
IsCurrent				bit default 1,
End_Date				datetime default '12/31/2999'
)


ALTER TABLE Dim.Customers
ADD CONSTRAINT CK_Customer_Or_Org
DEFAULT   'Not Organization' FOR Organisation_name


ALTER TABLE Dim.Customers
ADD CONSTRAINT CK_Customer_Organization_or_Person 
CHECK  ([Organisation_or_person] IN('O','P'))


-- ===================== Stored Proc to Implement SCD Type 2 on Dimension Customers Table


CREATE PROC usp_Merge_Dim_Cusomers
AS
BEGIN
SET NOCOUNT ON
DECLARE @AuditCustomers TABLE
(
Customer_Id				int not null,
Organisation_or_person	varchar(1),
Organisation_name		varchar(50) ,
Gender					varchar(10) DEFAULT 'N/A'  ,
First_Name				varchar(50) DEFAULT 'N/A' ,
Middle_Initial			varchar(50) DEFAULT 'N/A',
Last_Name				varchar(50) DEFAULT 'N/A',
Email_Address			nvarchar(50),
Login_name				nvarchar(50),
Login_Password			nvarchar(25),
Phone_number			nvarchar(50),
Address_Line1			nvarchar(50),
Address_Line4			nvarchar(50) DEFAULT 'N/A',
Town_City				varchar(50)not null,
County					varchar(50) not null,
Country					varchar(50)not null,
Credit_Card_Number		nvarchar(50) DEFAULT 'Pain in Check',
Customer_Payment_ID		int DEFAULT 0,
Payment_method_code     char(4) not null,
Payment_method_description varchar(50),
IsCurrent				bit default 1,
End_Date				datetime default '12/31/2999'
)

INSERT INTO @AuditCustomers
SELECT   [Customer_Id], [Organisation_or_person], [Organisation_name], 
		 COALESCE([Gender],'N/A'), COALESCE([First_Name],'N/A'), COALESCE([Middle_Initial],'N/A'), 
		 COALESCE([Last_Name],'N/A'),[Email_Address], [Login_name],[Login_Password], [Phone_number],
		 [Address_Line1], [Address_Line4], [Town_City], [County], [Country], [Credit_Card_Number],
		 [Customer_Payment_ID],Payment_method_code,Payment_method_description ,1,'12/31/2999'
FROM    (
	MERGE Dim.Customers as TARGET
			USING (
			SELECT 	[Customer_Id],[Organisation_or_person], [Organisation_name],[Gender],[First_Name],[Middle_Initial], 
					[Last_Name], [Email_Address], [Login_name], [Login_Password],[Phone_number], [Address_Line1], 
					[Address_Line4], [Town_City], [County], [Country], [Credit_Card_Number],[Customer_Payment_ID],
					Payment_method_code,Payment_method_description
			FROM    [eCommerce_Staging].[dbo].[Staging_Customers] 
					)as SOURCE
			ON  TARGET.[Customer_Id]= SOURCE.[Customer_Id]
WHEN NOT MATCHED 
THEN INSERT (
				[Customer_Id],[Organisation_or_person],[Organisation_name], 
				[Gender], [First_Name], [Middle_Initial],[Last_Name], [Email_Address], [Login_name], 
				[Login_Password], [Phone_number], [Address_Line1],[Address_Line4], [Town_City], 
				[County], [Country], [Credit_Card_Number],Customer_Payment_ID,Payment_method_code,
				Payment_method_description,IsCurrent,End_Date
			)																		
VALUES		(	[Customer_Id], [Organisation_or_person], [Organisation_name], 
				[Gender],[First_Name],[Middle_Initial],	[Last_Name], [Email_Address], [Login_name], 
				[Login_Password], [Phone_number], [Address_Line1],[Address_Line4], [Town_City], 
				[County], [Country], [Credit_Card_Number],[Customer_Payment_ID],
				Payment_method_code,Payment_method_description,1,'12/31/2999'
			)
WHEN MATCHED AND TARGET.Customer_ID = SOURCE.Customer_ID  AND 
				TARGET.[Organisation_name]<> SOURCE.[Organisation_name] OR
				TARGET.[Last_Name]<> SOURCE.[Last_Name] OR 
				TARGET.[Email_Address]<> SOURCE.[Email_Address] OR 
				TARGET.[Login_name]<> SOURCE.[Login_name] OR
				TARGET.[Login_Password]<> SOURCE.[Login_Password] OR
				TARGET.[Phone_number]<> SOURCE.[Phone_number] OR
				TARGET.[Address_Line1]<> SOURCE.[Address_Line1] OR
				TARGET.[Address_Line4]<> SOURCE.[Address_Line4] OR
				TARGET.[Town_City]<> SOURCE.[Town_City] OR
				TARGET.[County]<> SOURCE.[County] OR
				TARGET.[Country]<> SOURCE.[Country] OR
				TARGET.[Credit_Card_Number]<> SOURCE.[Credit_Card_Number] OR
				TARGET.Customer_Payment_ID <> SOURCE.[Customer_Payment_ID] OR
				TARGET.Payment_method_code <> SOURCE.Payment_method_code OR
				TARGET.Payment_method_description <> SOURCE.Payment_method_description
				AND TARGET.ISCURRENT = 1

THEN UPDATE 
SET				IsCurrent = 0,
				End_Date = GETDATE()
OUTPUT 
				$Action Action_out,
				SOURCE.Customer_Id,SOURCE.[Organisation_or_person], 
				SOURCE.[Organisation_name], 
				SOURCE.[Gender], SOURCE.[First_Name], SOURCE.[Middle_Initial], 
				SOURCE.[Last_Name], SOURCE.[Email_Address], SOURCE.[Login_name], SOURCE.[Login_Password], 
				SOURCE.[Phone_number], SOURCE.[Address_Line1], 
				SOURCE.[Address_Line4], SOURCE.[Town_City], SOURCE.[County], SOURCE.[Country],
				SOURCE.[Credit_Card_Number],
				SOURCE.[Customer_Payment_ID],
				SOURCE.Payment_method_code,
				SOURCE.Payment_method_description
				
		) AS Merge_Out
WHERE Merge_Out.Action_out ='UPDATE' ;

INSERT INTO Dim.Customers
SELECT				[Customer_Id],[Organisation_or_person], [Organisation_name],[Gender],[First_Name],[Middle_Initial], 
					[Last_Name], [Email_Address], [Login_name], [Login_Password],[Phone_number], [Address_Line1], 
					[Address_Line4], [Town_City], [County], [Country], [Credit_Card_Number],[Customer_Payment_ID],
					Payment_method_code,Payment_method_description,IsCurrent,End_Date
FROM @AuditCustomers

TRUNCATE TABLE [eCommerce_Staging].[dbo].[Staging_Customers] 

END


-- ====================Dim.Products =========================================================



IF EXISTS (
		   SELECT *
           FROM INFORMATION_SCHEMA.TABLES 
           WHERE TABLE_SCHEMA = 'Dim' 
           AND TABLE_NAME = 'Products'
		   )
BEGIN
     DROP TABLE Dim.Products
END
CREATE TABLE Dim.Products
(
Product_Key				int identity(1,1) PRIMARY KEY not null,
[product_id]			int not null,
[product_type_code]		nvarchar(10) not null,
[product_name]			varchar(100) not null,
[product_price]			money not null,
[product_color]			varchar(50) not null,
[product_size]			nvarchar(10)  DEFAULT 'N/A' null ,
[product_description]	nvarchar(100),
IsCurrent				bit default 1,
End_Date				datetime default '12/31/2999'
)

--=====================================Merge Statment for Dimension Products===========================

CREATE PROC usp_Merge_Dim_Products
AS
BEGIN
SET NOCOUNT ON

INSERT INTO Dim.Products
SELECT		[product_id], [product_type_code], [product_name], [product_price], 
			[product_color],COALESCE( [product_size],'N/A'), [product_description], 1,'12/30/2999'
FROM		(
		MERGE		Dim.Products as TARGET
		USING (
			SELECT 	[product_id],[product_type_code],[product_name],[product_price],[product_color],
					[product_size], [product_description]
			FROM    [eCommerce_Staging].[dbo].[Staging_Products]
			 )as SOURCE
			ON  TARGET.[Product_Id]= SOURCE.[Product_Id]
WHEN NOT MATCHED BY TARGET
		THEN INSERT ([product_id], [product_type_code], [product_name], [product_price], 
					[product_color], [product_size], [product_description], [IsCurrent], [End_Date])
		VALUES		([product_id], [product_type_code], [product_name], [product_price], [product_color], 
					[product_size], [product_description],1,'12/31/2999')
WHEN MATCHED AND TARGET.[product_id] = SOURCE.[product_id] AND TARGET.ISCURRENT = 1 AND 
					TARGET.[product_type_code]<> SOURCE.[product_type_code] OR
					TARGET.[product_name] <> SOURCE.[product_name] OR 
					TARGET.[product_price]<> SOURCE.[product_price] OR 
					TARGET.[product_color]<> SOURCE.[product_color] OR
					TARGET.[product_size]<> SOURCE.[product_size]	OR
					TARGET.[product_description]<> SOURCE.[product_description] 					
THEN UPDATE 
SET				IsCurrent = 0,
				End_Date = GETDATE()
OUTPUT 
				$Action Action_out,
				SOURCE.*
				) AS Merge_Out
WHERE Merge_Out.Action_out ='Update' ;

TRUNCATE TABLE [eCommerce_Staging].[dbo].[Staging_Products] 


END




--=======================================Dim.Date==========================================

CREATE TABLE Dim.Date (
   DateKey INT NOT NULL PRIMARY KEY,
   [Date] DATE NOT NULL,
   [Day] TINYINT NOT NULL,
   [DaySuffix] CHAR(2) NOT NULL,
   [Weekday] TINYINT NOT NULL,
   [WeekDayName] VARCHAR(10) NOT NULL,
   [WeekDayName_Short] CHAR(3) NOT NULL,
   [WeekDayName_FirstLetter] CHAR(1) NOT NULL,
   [DOWInMonth] TINYINT NOT NULL,
   [DayOfYear] SMALLINT NOT NULL,
   [WeekOfMonth] TINYINT NOT NULL,
   [WeekOfYear] TINYINT NOT NULL,
   [Month] TINYINT NOT NULL,
   [MonthName] VARCHAR(10) NOT NULL,
   [MonthName_Short] CHAR(3) NOT NULL,
   [MonthName_FirstLetter] CHAR(1) NOT NULL,
   [Quarter] TINYINT NOT NULL,
   [QuarterName] VARCHAR(6) NOT NULL,
   [Year] INT NOT NULL,
   [MMYYYY] CHAR(6) NOT NULL,
   [MonthYear] CHAR(7) NOT NULL,
   IsWeekend BIT NOT NULL,
   )

SET NOCOUNT ON

TRUNCATE TABLE DIM.Date

DECLARE @CurrentDate DATE = '2016-01-01'
DECLARE @EndDate DATE = '2016-12-31'

WHILE @CurrentDate < @EndDate
BEGIN
   INSERT INTO Dim.Date (
      [DateKey],
      [Date],
      [Day],
      [DaySuffix],
      [Weekday],
      [WeekDayName],
      [WeekDayName_Short],
      [WeekDayName_FirstLetter],
      [DOWInMonth],
      [DayOfYear],
      [WeekOfMonth],
      [WeekOfYear],
      [Month],
      [MonthName],
      [MonthName_Short],
      [MonthName_FirstLetter],
      [Quarter],
      [QuarterName],
      [Year],
      [MMYYYY],
      [MonthYear],
      [IsWeekend]
      )
   SELECT DateKey = YEAR(@CurrentDate) * 10000 + MONTH(@CurrentDate) * 100 + DAY(@CurrentDate),
      DATE = @CurrentDate,
      Day = DAY(@CurrentDate),
      [DaySuffix] = CASE 
         WHEN DAY(@CurrentDate) = 1
            OR DAY(@CurrentDate) = 21
            OR DAY(@CurrentDate) = 31
            THEN 'st'
         WHEN DAY(@CurrentDate) = 2
            OR DAY(@CurrentDate) = 22
            THEN 'nd'
         WHEN DAY(@CurrentDate) = 3
            OR DAY(@CurrentDate) = 23
            THEN 'rd'
         ELSE 'th'
         END,
      WEEKDAY = DATEPART(dw, @CurrentDate),
      WeekDayName = DATENAME(dw, @CurrentDate),
      WeekDayName_Short = UPPER(LEFT(DATENAME(dw, @CurrentDate), 3)),
      WeekDayName_FirstLetter = LEFT(DATENAME(dw, @CurrentDate), 1),
      [DOWInMonth] = DAY(@CurrentDate),
      [DayOfYear] = DATENAME(dy, @CurrentDate),
      [WeekOfMonth] = DATEPART(WEEK, @CurrentDate) - DATEPART(WEEK, DATEADD(MM, DATEDIFF(MM, 0, @CurrentDate), 0)) + 1,
      [WeekOfYear] = DATEPART(wk, @CurrentDate),
      [Month] = MONTH(@CurrentDate),
      [MonthName] = DATENAME(mm, @CurrentDate),
      [MonthName_Short] = UPPER(LEFT(DATENAME(mm, @CurrentDate), 3)),
      [MonthName_FirstLetter] = LEFT(DATENAME(mm, @CurrentDate), 1),
      [Quarter] = DATEPART(q, @CurrentDate),
      [QuarterName] = CASE 
         WHEN DATENAME(qq, @CurrentDate) = 1
            THEN 'First'
         WHEN DATENAME(qq, @CurrentDate) = 2
            THEN 'second'
         WHEN DATENAME(qq, @CurrentDate) = 3
            THEN 'third'
         WHEN DATENAME(qq, @CurrentDate) = 4
            THEN 'fourth'
         END,
      [Year] = YEAR(@CurrentDate),
      [MMYYYY] = RIGHT('0' + CAST(MONTH(@CurrentDate) AS VARCHAR(2)), 2) + CAST(YEAR(@CurrentDate) AS VARCHAR(4)),
      [MonthYear] = CAST(YEAR(@CurrentDate) AS VARCHAR(4)) + UPPER(LEFT(DATENAME(mm, @CurrentDate), 3)),
      [IsWeekend] = CASE 
         WHEN DATENAME(dw, @CurrentDate) = 'Sunday'
            OR DATENAME(dw, @CurrentDate) = 'Saturday'
            THEN 1
         ELSE 0
         END
   SET @CurrentDate = DATEADD(DD, 1, @CurrentDate)
END
--==================================Dim.Shipments================================

IF EXISTS (
		   SELECT *
           FROM INFORMATION_SCHEMA.TABLES 
           WHERE TABLE_SCHEMA = 'Dim' 
           AND TABLE_NAME = 'Shipments'
		   )
BEGIN
     DROP TABLE Dim.Shipments
END

CREATE TABLE Dim.Shipments
(
 Shipment_Key int identity(1,1) Primary key not null,
 Shipment_Id int,
 Shipment_Order_Id int,
 Invoice_Number int,
 Shipment_tracking_number nvarchar(25),
 )

 --=====================Dim.Invoices===================================
 
IF EXISTS (
		   SELECT *
           FROM INFORMATION_SCHEMA.TABLES 
           WHERE TABLE_SCHEMA = 'Dim' 
           AND TABLE_NAME = 'Invoice_Payments'
		   )
BEGIN
     DROP TABLE Dim.Invoice_Payments
END

CREATE TABLE Dim.Invoice_Payments
(
Invoice_Payment_Key int identity(1,1) Primary key not null,
Invoice_number int,
Order_id int,
Invoice_status_code varchar(50),
Payment_id int DEFAULT 0,
Invoice_status_description varchar(50)
)


--============================================Fact.Orders=============================================

IF EXISTS (
		   SELECT *
           FROM INFORMATION_SCHEMA.TABLES 
           WHERE TABLE_SCHEMA = 'Fact' 
           AND TABLE_NAME = 'Orders'
		   )
BEGIN
     DROP TABLE Fact.Orders
END

CREATE TABLE Fact.Orders
( 
Fact_Key int identity(0,1) Primary Key,
[Customer_Key] int Foreign Key References Dim.Customers([Customer_Key]),
[Product_Key] int Foreign Key References Dim.Products([Product_Key]),
[Invoice_Payment_Key] int Foreign Key References [Dim].[Invoice_Payments]([Invoice_Payment_Key]),
[Shipment_Key] int Foreign Key References [Dim].[Shipments]([Shipment_Key]),
[DateKey] int Foreign Key References [Dim].[Date]([DateKey]),
[Order_Id] int,
[Order_item_id] int, 
[Order_item_quantity] int, 
[Order_item_price] money, 
[Payment_amount] money,
[Order_details] varchar(100),
[Date_order_placed] datetime,
[Payment_date] Datetime ,
[Shipment_date] datetime,
[Invoice_date] datetime
)












