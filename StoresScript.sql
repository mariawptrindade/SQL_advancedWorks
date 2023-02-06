USE [AdventureWorks]
GO

/*
WITH 
		--location information
		location AS
		(
		SELECT a.AddressID, 
			a.AddressLine1,
			a.City, 
			a.StateProvinceID, 
			sp.StateProvinceCode, 
			sp.Name AS StateProvinceName, 
			sp.CountryRegionCode AS StateProvinceCountryRegionCode, 
			cr.Name AS StateProvinceCountryRegionName, 
			sp.IsOnlyStateProvinceFlag AS StateProvinceIsOnlyStateProvinceFlag, 
			sp.TerritoryID AS StateProvinceTerritoryID, 
			a.PostalCode, 
			a.SpatialLocation
		FROM Person.Address AS a
		LEFT JOIN Person.StateProvince AS sp 
		ON a.StateProvinceID = sp.StateProvinceID 
		LEFT JOIN Person.CountryRegion AS cr 
		ON sp.CountryRegionCode = cr.CountryRegionCode

		), 

		--stores located in the US
		storeslocation_us AS
		(
		SELECT s.BusinessEntityID, 
			s.Name,
			at.Name AS AddressType,
			a.AddressLine1,
			a.City,
			sp.Name AS StateProvinceName,
			a.PostalCode,
			cr.Name AS CountryRegionName
		FROM [Sales].[Store] s
		INNER JOIN [Person].[BusinessEntityAddress] bea 
		ON bea.[BusinessEntityID] = s.[BusinessEntityID] 
		INNER JOIN [Person].[Address] a 
		ON a.[AddressID] = bea.[AddressID]
		INNER JOIN [Person].[StateProvince] sp 
		ON sp.[StateProvinceID] = a.[StateProvinceID]
		INNER JOIN [Person].[CountryRegion] cr 
		ON cr.[CountryRegionCode] = sp.[CountryRegionCode]
		INNER JOIN [Person].[AddressType] at 
		ON at.[AddressTypeID] = bea.[AddressTypeID]
		WHERE cr.Name = 'United States' AND at.Name = 'Main Office'

		),

		--individual customers located in the US
		individualcustomers_us AS 
		(
		SELECT 
			p.BusinessEntityID,
			p.FirstName,
			p.MiddleName,
			p.LastName,
			pp.PhoneNumber,
			pnt.Name AS PhoneNumberType,
			ea.EmailAddress,
			p.EmailPromotion,
			at.Name AS AddressType,
			a.AddressLine1,
			a.City,
			sp.Name AS StateProvinceName,
			a.PostalCode,
			cr.Name AS CountryRegionName,
			p.Demographics,
			c.CustomerID
		FROM [Person].[Person] p
			INNER JOIN [Person].[BusinessEntityAddress] bea 
			ON bea.[BusinessEntityID] = p.[BusinessEntityID] 
			INNER JOIN [Person].[Address] a 
			ON a.[AddressID] = bea.[AddressID]
			INNER JOIN [Person].[StateProvince] sp 
			ON sp.[StateProvinceID] = a.[StateProvinceID]
			INNER JOIN [Person].[CountryRegion] cr 
			ON cr.[CountryRegionCode] = sp.[CountryRegionCode]
			INNER JOIN [Person].[AddressType] at 
			ON at.[AddressTypeID] = bea.[AddressTypeID]
			INNER JOIN [Sales].[Customer] c
			ON c.[PersonID] = p.[BusinessEntityID]
			LEFT OUTER JOIN [Person].[EmailAddress] ea
			ON ea.[BusinessEntityID] = p.[BusinessEntityID]
			LEFT OUTER JOIN [Person].[PersonPhone] pp
			ON pp.[BusinessEntityID] = p.[BusinessEntityID]
			LEFT OUTER JOIN [Person].[PhoneNumberType] pnt
			ON pnt.[PhoneNumberTypeID] = pp.[PhoneNumberTypeID]
		WHERE c.StoreID IS NULL AND cr.Name = 'United States'

		),

		--sales information by order
		salesorders AS
		(
		SELECT soh.[SalesOrderID],
			   soh.[OrderDate],
			   soh.[OnlineOrderFlag],
			   soh.[SalesOrderNumber],
			   soh.[PurchaseOrderNumber],
			   soh.[CustomerID],
			   soh.[SalesPersonID],
			   soh.[TerritoryID],
			   soh.[ShipToAddressID],
			   soh.[SubTotal],
			   soh.[TaxAmt],
			   soh.[Freight],
			   soh.[TotalDue],
			   st.CountryRegionCode,
			   SUM(sod.[OrderQty]) AS ProductQuantity
		  FROM [AdventureWorks].[Sales].[SalesOrderHeader] AS soh
		  LEFT JOIN [AdventureWorks].[Sales].[SalesTerritory] st
		  ON soh.TerritoryID = st.TerritoryID
		  LEFT JOIN [AdventureWorks].[Sales].[SalesOrderDetail] sod
		  ON soh.SalesOrderID = sod.SalesOrderID
		  GROUP BY soh.[SalesOrderID], soh.[OrderDate], soh.[OnlineOrderFlag], soh.[SalesOrderNumber], soh.[PurchaseOrderNumber], soh.[CustomerID], soh.[SalesPersonID], soh.[TerritoryID], soh.[ShipToAddressID], soh.[SubTotal], soh.[TaxAmt], soh.[Freight], soh.[TotalDue], st.CountryRegionCode
		  
		  ), 
		
		--sales by customer
		salesbycustomer AS
		(
		SELECT soh.CustomerID,
				soh.OnlineOrderFlag,
				soh.TerritoryID,
				SUM(soh.TotalDue) AS TotalSales,
				SUM(soh.ProductQuantity) AS TotalProductQuantity
		FROM salesorders AS soh
		GROUP BY soh.CustomerID, soh.OnlineOrderFlag, soh.TerritoryID

		),

		--individual customer sales in US
		salesindividualcustomers_us AS
		(
		SELECT icus.BusinessEntityID,
			icus.FirstName,
			icus.MiddleName,
			icus.LastName,
			icus.PhoneNumber,
			icus.PhoneNumberType,
			icus.EmailAddress,
			icus.EmailPromotion,
			icus.AddressType,
			icus.AddressLine1,
			icus.City,
			icus.StateProvinceName,
			icus.PostalCode,
			icus.CountryRegionName,
			icus.Demographics,
			icus.CustomerID,
			sbc.OnlineOrderFlag,
			sbc.TotalSales,
			sbc.TotalProductQuantity,
			RANK() OVER (ORDER BY sbc.TotalSales DESC) AS SalesRank,
			RANK() OVER (ORDER BY sbc.TotalSales DESC, sbc.TotalProductQuantity DESC) AS SalesandQtdRank
		FROM individualcustomers_us AS icus
		LEFT JOIN salesbycustomer sbc
		ON icus.CustomerID = sbc.CustomerID
		),

		--individual customer sales by city in us
		salesindividualcustomers_citysales AS
		(
		SELECT
			icus.City,
			icus.StateProvinceName,
			icus.PostalCode,
			icus.CountryRegionName,
			SUM(icus.TotalSales) AS TotalCitySales,
			SUM(icus.TotalProductQuantity) AS TotalCityProductQuantity
		FROM salesindividualcustomers_us AS icus
		GROUP BY icus.City, icus.StateProvinceName, icus.PostalCode, icus.CountryRegionName
		
		),

		--individual customer sales by state
		salesindividualcustomers_state AS
		(
		SELECT 
			cs.StateProvinceName,
			SUM(TotalCitySales) AS TotalStateSales
		FROM salesindividualcustomers_citysales AS cs
		GROUP BY StateProvinceName

		),

		--store sales and location
		salesstores AS
			(
		SELECT 
			sc.StoreID,
			soh.[TerritoryID],
			SUM(soh.[TotalDue]) AS TotalSales,
			ss.Name,
			sl.AddressLine1,
			sl.City,
			sl.StateProvinceName,
			sl.PostalCode,
			sl.CountryRegionName
		FROM [AdventureWorks].[Sales].[SalesOrderHeader] soh
		LEFT JOIN Sales.Customer sc
		ON soh.CustomerID = sc.CustomerID
		LEFT JOIN Sales.Store ss
		ON sc.StoreID = ss.BusinessEntityID
		LEFT JOIN storeslocation_us sl
		ON sc.StoreID = sl.BusinessEntityID
		WHERE sc.StoreID IS NOT NULL AND sl.CountryRegionName IS NOT NULL
		GROUP BY sc.StoreID, soh.[TerritoryID], ss.Name, sl.AddressLine1, sl.City, sl.StateProvinceName, sl.PostalCode, sl.CountryRegionName 
		  
		  ),

		--store sales
		salesbystore AS 
		(
		SELECT StoreID, 
			Name, 
			SUM(TotalSales) TotalStoreSales
		FROM salesstores
		GROUP BY StoreID, Name

		),

		--store sales in US
		salesbystore_us AS 
		(
		SELECT ss.StoreID,
			ss.Name,
			ss.[TerritoryID],
			ss.AddressLine1,
			ss.City,
			ss.StateProvinceName,
			ss.PostalCode,
			ss.CountryRegionName,
			sbs.TotalStoreSales,
			RANK() OVER (ORDER BY TotalStoreSales DESC) AS SalesRank
		FROM salesstores ss
		LEFT JOIN salesbystore sbs
		ON ss.StoreID = sbs.StoreID
		
		),

		--top 30 store sales in US
		salesbystore_top30 AS
		(
		SELECT *
		FROM salesbystore_us
		WHERE salesrank <= 30

		),

		--cities where the top 30 stores (by sales) are located
		salesbystore_cities_top30 AS 
		(
		SELECT DISTINCT City
		FROM salesbystore_top30
		
		),

		--store sales in US, excluding top 30
		salesbystore_cities_top30less AS
		(
		SELECT StoreID,
			Name,
			[TerritoryID],
			AddressLine1,
			City,
			StateProvinceName,
			PostalCode,
			CountryRegionName,
			TotalStoreSales,
			SalesRank
		FROM salesbystore_us
		WHERE SalesRank > 30

		)

--SELECT * 
--FROM salesbystore_cities_top30less

--SELECT * 
--FROM salesbystore_cities_top30

--SELECT *
--FROM salesindividualcustomers_us

*/

CREATE OR ALTER VIEW [Sales].[vStoreSales_LessTop30]
AS
WITH 
		--location information
		location AS
		(
		SELECT a.AddressID, 
			a.AddressLine1,  
			a.City, 
			a.StateProvinceID, 
			sp.StateProvinceCode, 
			sp.Name AS StateProvinceName, 
			sp.CountryRegionCode AS StateProvinceCountryRegionCode, 
			cr.Name AS StateProvinceCountryRegionName, 
			sp.IsOnlyStateProvinceFlag AS StateProvinceIsOnlyStateProvinceFlag, 
			sp.TerritoryID AS StateProvinceTerritoryID, 
			a.PostalCode, 
			a.SpatialLocation
		FROM Person.Address AS a
		LEFT JOIN Person.StateProvince AS sp 
		ON a.StateProvinceID = sp.StateProvinceID 
		LEFT JOIN Person.CountryRegion AS cr 
		ON sp.CountryRegionCode = cr.CountryRegionCode

		), 

		--stores located in the US
		storeslocation_us AS
		(
		SELECT s.BusinessEntityID, 
			s.Name,
			at.Name AS AddressType,
			a.AddressLine1,
			a.City,
			sp.Name AS StateProvinceName,
			a.PostalCode,
			cr.Name AS CountryRegionName
		FROM [Sales].[Store] s
		INNER JOIN [Person].[BusinessEntityAddress] bea 
		ON bea.[BusinessEntityID] = s.[BusinessEntityID] 
		INNER JOIN [Person].[Address] a 
		ON a.[AddressID] = bea.[AddressID]
		INNER JOIN [Person].[StateProvince] sp 
		ON sp.[StateProvinceID] = a.[StateProvinceID]
		INNER JOIN [Person].[CountryRegion] cr 
		ON cr.[CountryRegionCode] = sp.[CountryRegionCode]
		INNER JOIN [Person].[AddressType] at 
		ON at.[AddressTypeID] = bea.[AddressTypeID]
		WHERE cr.Name = 'United States' AND at.Name = 'Main Office'

		),

		--individual customers located in the US
		individualcustomers_us AS 
		(
		SELECT 
			p.BusinessEntityID,
			p.FirstName,
			p.MiddleName,
			p.LastName,
			pp.PhoneNumber,
			pnt.Name AS PhoneNumberType,
			ea.EmailAddress,
			p.EmailPromotion,
			at.Name AS AddressType,
			a.AddressLine1,
			a.City,
			sp.Name AS StateProvinceName,
			a.PostalCode,
			cr.Name AS CountryRegionName,
			p.Demographics,
			c.CustomerID
		FROM [Person].[Person] p
			INNER JOIN [Person].[BusinessEntityAddress] bea 
			ON bea.[BusinessEntityID] = p.[BusinessEntityID] 
			INNER JOIN [Person].[Address] a 
			ON a.[AddressID] = bea.[AddressID]
			INNER JOIN [Person].[StateProvince] sp 
			ON sp.[StateProvinceID] = a.[StateProvinceID]
			INNER JOIN [Person].[CountryRegion] cr 
			ON cr.[CountryRegionCode] = sp.[CountryRegionCode]
			INNER JOIN [Person].[AddressType] at 
			ON at.[AddressTypeID] = bea.[AddressTypeID]
			INNER JOIN [Sales].[Customer] c
			ON c.[PersonID] = p.[BusinessEntityID]
			LEFT OUTER JOIN [Person].[EmailAddress] ea
			ON ea.[BusinessEntityID] = p.[BusinessEntityID]
			LEFT OUTER JOIN [Person].[PersonPhone] pp
			ON pp.[BusinessEntityID] = p.[BusinessEntityID]
			LEFT OUTER JOIN [Person].[PhoneNumberType] pnt
			ON pnt.[PhoneNumberTypeID] = pp.[PhoneNumberTypeID]
		WHERE c.StoreID IS NULL AND cr.Name = 'United States'

		),

		--sales information by order
		salesorders AS
		(
		SELECT soh.[SalesOrderID],
			   soh.[OrderDate],
			   soh.[OnlineOrderFlag],
			   soh.[SalesOrderNumber],
			   soh.[PurchaseOrderNumber],
			   soh.[CustomerID],
			   soh.[SalesPersonID],
			   soh.[TerritoryID],
			   soh.[ShipToAddressID],
			   soh.[SubTotal],
			   soh.[TaxAmt],
			   soh.[Freight],
			   soh.[TotalDue],
			   st.CountryRegionCode,
			   SUM(sod.[OrderQty]) AS ProductQuantity
		  FROM [AdventureWorks].[Sales].[SalesOrderHeader] AS soh
		  LEFT JOIN [AdventureWorks].[Sales].[SalesTerritory] st
		  ON soh.TerritoryID = st.TerritoryID
		  LEFT JOIN [AdventureWorks].[Sales].[SalesOrderDetail] sod
		  ON soh.SalesOrderID = sod.SalesOrderID
		  GROUP BY soh.[SalesOrderID], soh.[OrderDate], soh.[OnlineOrderFlag], soh.[SalesOrderNumber], soh.[PurchaseOrderNumber], soh.[CustomerID], soh.[SalesPersonID], soh.[TerritoryID], soh.[ShipToAddressID], soh.[SubTotal], soh.[TaxAmt], soh.[Freight], soh.[TotalDue], st.CountryRegionCode
		  
		  ), 
		
		--sales by customer
		salesbycustomer AS
		(
		SELECT soh.CustomerID,
				soh.OnlineOrderFlag,
				soh.TerritoryID,
				SUM(soh.TotalDue) AS TotalSales,
				SUM(soh.ProductQuantity) AS TotalProductQuantity
		FROM salesorders AS soh
		GROUP BY soh.CustomerID, soh.OnlineOrderFlag, soh.TerritoryID

		),

		--individual customer sales in US
		salesindividualcustomers_us AS
		(
		SELECT icus.BusinessEntityID,
			icus.FirstName,
			icus.MiddleName,
			icus.LastName,
			icus.PhoneNumber,
			icus.PhoneNumberType,
			icus.EmailAddress,
			icus.EmailPromotion,
			icus.AddressType,
			icus.AddressLine1,
			icus.City,
			icus.StateProvinceName,
			icus.PostalCode,
			icus.CountryRegionName,
			icus.Demographics,
			icus.CustomerID,
			sbc.OnlineOrderFlag,
			sbc.TotalSales,
			sbc.TotalProductQuantity,
			RANK() OVER (ORDER BY sbc.TotalSales DESC) AS SalesRank,
			RANK() OVER (ORDER BY sbc.TotalSales DESC, sbc.TotalProductQuantity DESC) AS SalesandQtdRank
		FROM individualcustomers_us AS icus
		LEFT JOIN salesbycustomer sbc
		ON icus.CustomerID = sbc.CustomerID
		),

		--individual customer sales by city in us
		salesindividualcustomers_citysales AS
		(
		SELECT
			icus.City,
			icus.StateProvinceName,
			icus.PostalCode,
			icus.CountryRegionName,
			SUM(icus.TotalSales) AS TotalCitySales,
			SUM(icus.TotalProductQuantity) AS TotalCityProductQuantity
		FROM salesindividualcustomers_us AS icus
		GROUP BY icus.City, icus.StateProvinceName, icus.PostalCode, icus.CountryRegionName
		
		),

		--individual customer sales by state
		salesindividualcustomers_state AS
		(
		SELECT 
			cs.StateProvinceName,
			SUM(TotalCitySales) AS TotalStateSales
		FROM salesindividualcustomers_citysales AS cs
		GROUP BY StateProvinceName

		),

		--store sales and location
		salesstores AS
			(
		SELECT 
			sc.StoreID,
			soh.[TerritoryID],
			SUM(soh.[TotalDue]) AS TotalSales,
			ss.Name,
			sl.AddressLine1,
			sl.City,
			sl.StateProvinceName,
			sl.PostalCode,
			sl.CountryRegionName
		FROM [AdventureWorks].[Sales].[SalesOrderHeader] soh
		LEFT JOIN Sales.Customer sc
		ON soh.CustomerID = sc.CustomerID
		LEFT JOIN Sales.Store ss
		ON sc.StoreID = ss.BusinessEntityID
		LEFT JOIN storeslocation_us sl
		ON sc.StoreID = sl.BusinessEntityID
		WHERE sc.StoreID IS NOT NULL AND sl.CountryRegionName IS NOT NULL
		GROUP BY sc.StoreID, soh.[TerritoryID], ss.Name, sl.AddressLine1, sl.City, sl.StateProvinceName, sl.PostalCode, sl.CountryRegionName 
		  
		  ),

		--store sales
		salesbystore AS 
		(
		SELECT StoreID, 
			Name, 
			SUM(TotalSales) TotalStoreSales
		FROM salesstores
		GROUP BY StoreID, Name

		),

		--store sales in US
		salesbystore_us AS 
		(
		SELECT ss.StoreID,
			ss.Name,
			ss.[TerritoryID],
			ss.AddressLine1,
			ss.City,
			ss.StateProvinceName,
			ss.PostalCode,
			ss.CountryRegionName,
			sbs.TotalStoreSales,
			RANK() OVER (ORDER BY TotalStoreSales DESC) AS SalesRank
		FROM salesstores ss
		LEFT JOIN salesbystore sbs
		ON ss.StoreID = sbs.StoreID
		
		),

		--top 30 store sales in US
		salesbystore_top30 AS
		(
		SELECT *
		FROM salesbystore_us
		WHERE salesrank <= 30

		),

		--cities where the top 30 stores (by sales) are located
		salesbystore_cities_top30 AS 
		(
		SELECT DISTINCT City
		FROM salesbystore_top30
		
		),

		--store sales in US, excluding top 30
		salesbystore_cities_top30less AS
		(
		SELECT StoreID,
			Name,
			[TerritoryID],
			AddressLine1,
			City,
			StateProvinceName,
			PostalCode,
			CountryRegionName,
			TotalStoreSales,
			SalesRank
		FROM salesbystore_us
		WHERE SalesRank > 30

		)

SELECT *
FROM salesbystore_cities_top30less
GO

CREATE OR ALTER VIEW [Sales].[vStoreCities_Top30]
AS

WITH 
		--location information
		location AS
		(
		SELECT a.AddressID, 
			a.AddressLine1,  
			a.City, 
			a.StateProvinceID, 
			sp.StateProvinceCode, 
			sp.Name AS StateProvinceName, 
			sp.CountryRegionCode AS StateProvinceCountryRegionCode, 
			cr.Name AS StateProvinceCountryRegionName, 
			sp.IsOnlyStateProvinceFlag AS StateProvinceIsOnlyStateProvinceFlag, 
			sp.TerritoryID AS StateProvinceTerritoryID, 
			a.PostalCode, 
			a.SpatialLocation
		FROM Person.Address AS a
		LEFT JOIN Person.StateProvince AS sp 
		ON a.StateProvinceID = sp.StateProvinceID 
		LEFT JOIN Person.CountryRegion AS cr 
		ON sp.CountryRegionCode = cr.CountryRegionCode

		), 

		--stores located in the US
		storeslocation_us AS
		(
		SELECT s.BusinessEntityID, 
			s.Name,
			at.Name AS AddressType,
			a.AddressLine1,
			a.City,
			sp.Name AS StateProvinceName,
			a.PostalCode,
			cr.Name AS CountryRegionName
		FROM [Sales].[Store] s
		INNER JOIN [Person].[BusinessEntityAddress] bea 
		ON bea.[BusinessEntityID] = s.[BusinessEntityID] 
		INNER JOIN [Person].[Address] a 
		ON a.[AddressID] = bea.[AddressID]
		INNER JOIN [Person].[StateProvince] sp 
		ON sp.[StateProvinceID] = a.[StateProvinceID]
		INNER JOIN [Person].[CountryRegion] cr 
		ON cr.[CountryRegionCode] = sp.[CountryRegionCode]
		INNER JOIN [Person].[AddressType] at 
		ON at.[AddressTypeID] = bea.[AddressTypeID]
		WHERE cr.Name = 'United States' AND at.Name = 'Main Office'

		),

		--individual customers located in the US
		individualcustomers_us AS 
		(
		SELECT 
			p.BusinessEntityID,
			p.FirstName,
			p.MiddleName,
			p.LastName,
			pp.PhoneNumber,
			pnt.Name AS PhoneNumberType,
			ea.EmailAddress,
			p.EmailPromotion,
			at.Name AS AddressType,
			a.AddressLine1,
			a.City,
			sp.Name AS StateProvinceName,
			a.PostalCode,
			cr.Name AS CountryRegionName,
			p.Demographics,
			c.CustomerID
		FROM [Person].[Person] p
			INNER JOIN [Person].[BusinessEntityAddress] bea 
			ON bea.[BusinessEntityID] = p.[BusinessEntityID] 
			INNER JOIN [Person].[Address] a 
			ON a.[AddressID] = bea.[AddressID]
			INNER JOIN [Person].[StateProvince] sp 
			ON sp.[StateProvinceID] = a.[StateProvinceID]
			INNER JOIN [Person].[CountryRegion] cr 
			ON cr.[CountryRegionCode] = sp.[CountryRegionCode]
			INNER JOIN [Person].[AddressType] at 
			ON at.[AddressTypeID] = bea.[AddressTypeID]
			INNER JOIN [Sales].[Customer] c
			ON c.[PersonID] = p.[BusinessEntityID]
			LEFT OUTER JOIN [Person].[EmailAddress] ea
			ON ea.[BusinessEntityID] = p.[BusinessEntityID]
			LEFT OUTER JOIN [Person].[PersonPhone] pp
			ON pp.[BusinessEntityID] = p.[BusinessEntityID]
			LEFT OUTER JOIN [Person].[PhoneNumberType] pnt
			ON pnt.[PhoneNumberTypeID] = pp.[PhoneNumberTypeID]
		WHERE c.StoreID IS NULL AND cr.Name = 'United States'

		),

		--sales information by order
		salesorders AS
		(
		SELECT soh.[SalesOrderID],
			   soh.[OrderDate],
			   soh.[OnlineOrderFlag],
			   soh.[SalesOrderNumber],
			   soh.[PurchaseOrderNumber],
			   soh.[CustomerID],
			   soh.[SalesPersonID],
			   soh.[TerritoryID],
			   soh.[ShipToAddressID],
			   soh.[SubTotal],
			   soh.[TaxAmt],
			   soh.[Freight],
			   soh.[TotalDue],
			   st.CountryRegionCode,
			   SUM(sod.[OrderQty]) AS ProductQuantity
		  FROM [AdventureWorks].[Sales].[SalesOrderHeader] AS soh
		  LEFT JOIN [AdventureWorks].[Sales].[SalesTerritory] st
		  ON soh.TerritoryID = st.TerritoryID
		  LEFT JOIN [AdventureWorks].[Sales].[SalesOrderDetail] sod
		  ON soh.SalesOrderID = sod.SalesOrderID
		  GROUP BY soh.[SalesOrderID], soh.[OrderDate], soh.[OnlineOrderFlag], soh.[SalesOrderNumber], soh.[PurchaseOrderNumber], soh.[CustomerID], soh.[SalesPersonID], soh.[TerritoryID], soh.[ShipToAddressID], soh.[SubTotal], soh.[TaxAmt], soh.[Freight], soh.[TotalDue], st.CountryRegionCode
		  
		  ), 
		
		--sales by customer
		salesbycustomer AS
		(
		SELECT soh.CustomerID,
				soh.OnlineOrderFlag,
				soh.TerritoryID,
				SUM(soh.TotalDue) AS TotalSales,
				SUM(soh.ProductQuantity) AS TotalProductQuantity
		FROM salesorders AS soh
		GROUP BY soh.CustomerID, soh.OnlineOrderFlag, soh.TerritoryID

		),

		--individual customer sales in US
		salesindividualcustomers_us AS
		(
		SELECT icus.BusinessEntityID,
			icus.FirstName,
			icus.MiddleName,
			icus.LastName,
			icus.PhoneNumber,
			icus.PhoneNumberType,
			icus.EmailAddress,
			icus.EmailPromotion,
			icus.AddressType,
			icus.AddressLine1,
			icus.City,
			icus.StateProvinceName,
			icus.PostalCode,
			icus.CountryRegionName,
			icus.Demographics,
			icus.CustomerID,
			sbc.OnlineOrderFlag,
			sbc.TotalSales,
			sbc.TotalProductQuantity,
			RANK() OVER (ORDER BY sbc.TotalSales DESC) AS SalesRank,
			RANK() OVER (ORDER BY sbc.TotalSales DESC, sbc.TotalProductQuantity DESC) AS SalesandQtdRank
		FROM individualcustomers_us AS icus
		LEFT JOIN salesbycustomer sbc
		ON icus.CustomerID = sbc.CustomerID
		),

		--individual customer sales by city in us
		salesindividualcustomers_citysales AS
		(
		SELECT
			icus.City,
			icus.StateProvinceName,
			icus.PostalCode,
			icus.CountryRegionName,
			SUM(icus.TotalSales) AS TotalCitySales,
			SUM(icus.TotalProductQuantity) AS TotalCityProductQuantity
		FROM salesindividualcustomers_us AS icus
		GROUP BY icus.City, icus.StateProvinceName, icus.PostalCode, icus.CountryRegionName
		
		),

		--individual customer sales by state
		salesindividualcustomers_state AS
		(
		SELECT 
			cs.StateProvinceName,
			SUM(TotalCitySales) AS TotalStateSales
		FROM salesindividualcustomers_citysales AS cs
		GROUP BY StateProvinceName

		),

		--store sales and location
		salesstores AS
			(
		SELECT 
			sc.StoreID,
			soh.[TerritoryID],
			SUM(soh.[TotalDue]) AS TotalSales,
			ss.Name,
			sl.AddressLine1,
			sl.City,
			sl.StateProvinceName,
			sl.PostalCode,
			sl.CountryRegionName
		FROM [AdventureWorks].[Sales].[SalesOrderHeader] soh
		LEFT JOIN Sales.Customer sc
		ON soh.CustomerID = sc.CustomerID
		LEFT JOIN Sales.Store ss
		ON sc.StoreID = ss.BusinessEntityID
		LEFT JOIN storeslocation_us sl
		ON sc.StoreID = sl.BusinessEntityID
		WHERE sc.StoreID IS NOT NULL AND sl.CountryRegionName IS NOT NULL
		GROUP BY sc.StoreID, soh.[TerritoryID], ss.Name, sl.AddressLine1, sl.City, sl.StateProvinceName, sl.PostalCode, sl.CountryRegionName 
		  
		  ),

		--store sales
		salesbystore AS 
		(
		SELECT StoreID, 
			Name, 
			SUM(TotalSales) TotalStoreSales
		FROM salesstores
		GROUP BY StoreID, Name

		),

		--store sales in US
		salesbystore_us AS 
		(
		SELECT ss.StoreID,
			ss.Name,
			ss.[TerritoryID],
			ss.AddressLine1,
			ss.City,
			ss.StateProvinceName,
			ss.PostalCode,
			ss.CountryRegionName,
			sbs.TotalStoreSales,
			RANK() OVER (ORDER BY TotalStoreSales DESC) AS SalesRank
		FROM salesstores ss
		LEFT JOIN salesbystore sbs
		ON ss.StoreID = sbs.StoreID
		
		),

		--top 30 store sales in US
		salesbystore_top30 AS
		(
		SELECT *
		FROM salesbystore_us
		WHERE salesrank <= 30

		),

		--cities where the top 30 stores (by sales) are located
		salesbystore_cities_top30 AS 
		(
		SELECT DISTINCT City
		FROM salesbystore_top30
		
		),

		--store sales in US, excluding top 30
		salesbystore_cities_top30less AS
		(
		SELECT StoreID,
			Name,
			[TerritoryID],
			AddressLine1,
			City,
			StateProvinceName,
			PostalCode,
			CountryRegionName,
			TotalStoreSales,
			SalesRank
		FROM salesbystore_us
		WHERE SalesRank > 30

		)

SELECT *
FROM salesbystore_cities_top30

GO

CREATE OR ALTER VIEW [Sales].[vIndividualCustomers]
AS

WITH 
		--location information
		location AS
		(
		SELECT a.AddressID, 
			a.AddressLine1,  
			a.City, 
			a.StateProvinceID, 
			sp.StateProvinceCode, 
			sp.Name AS StateProvinceName, 
			sp.CountryRegionCode AS StateProvinceCountryRegionCode, 
			cr.Name AS StateProvinceCountryRegionName, 
			sp.IsOnlyStateProvinceFlag AS StateProvinceIsOnlyStateProvinceFlag, 
			sp.TerritoryID AS StateProvinceTerritoryID, 
			a.PostalCode, 
			a.SpatialLocation
		FROM Person.Address AS a
		LEFT JOIN Person.StateProvince AS sp 
		ON a.StateProvinceID = sp.StateProvinceID 
		LEFT JOIN Person.CountryRegion AS cr 
		ON sp.CountryRegionCode = cr.CountryRegionCode

		), 

		--stores located in the US
		storeslocation_us AS
		(
		SELECT s.BusinessEntityID, 
			s.Name,
			at.Name AS AddressType,
			a.AddressLine1,
			a.City,
			sp.Name AS StateProvinceName,
			a.PostalCode,
			cr.Name AS CountryRegionName
		FROM [Sales].[Store] s
		INNER JOIN [Person].[BusinessEntityAddress] bea 
		ON bea.[BusinessEntityID] = s.[BusinessEntityID] 
		INNER JOIN [Person].[Address] a 
		ON a.[AddressID] = bea.[AddressID]
		INNER JOIN [Person].[StateProvince] sp 
		ON sp.[StateProvinceID] = a.[StateProvinceID]
		INNER JOIN [Person].[CountryRegion] cr 
		ON cr.[CountryRegionCode] = sp.[CountryRegionCode]
		INNER JOIN [Person].[AddressType] at 
		ON at.[AddressTypeID] = bea.[AddressTypeID]
		WHERE cr.Name = 'United States' AND at.Name = 'Main Office'

		),

		--individual customers located in the US
		individualcustomers_us AS 
		(
		SELECT 
			p.BusinessEntityID,
			p.FirstName,
			p.MiddleName,
			p.LastName,
			pp.PhoneNumber,
			pnt.Name AS PhoneNumberType,
			ea.EmailAddress,
			p.EmailPromotion,
			at.Name AS AddressType,
			a.AddressLine1,
			a.City,
			sp.Name AS StateProvinceName,
			a.PostalCode,
			cr.Name AS CountryRegionName,
			p.Demographics,
			c.CustomerID
		FROM [Person].[Person] p
			INNER JOIN [Person].[BusinessEntityAddress] bea 
			ON bea.[BusinessEntityID] = p.[BusinessEntityID] 
			INNER JOIN [Person].[Address] a 
			ON a.[AddressID] = bea.[AddressID]
			INNER JOIN [Person].[StateProvince] sp 
			ON sp.[StateProvinceID] = a.[StateProvinceID]
			INNER JOIN [Person].[CountryRegion] cr 
			ON cr.[CountryRegionCode] = sp.[CountryRegionCode]
			INNER JOIN [Person].[AddressType] at 
			ON at.[AddressTypeID] = bea.[AddressTypeID]
			INNER JOIN [Sales].[Customer] c
			ON c.[PersonID] = p.[BusinessEntityID]
			LEFT OUTER JOIN [Person].[EmailAddress] ea
			ON ea.[BusinessEntityID] = p.[BusinessEntityID]
			LEFT OUTER JOIN [Person].[PersonPhone] pp
			ON pp.[BusinessEntityID] = p.[BusinessEntityID]
			LEFT OUTER JOIN [Person].[PhoneNumberType] pnt
			ON pnt.[PhoneNumberTypeID] = pp.[PhoneNumberTypeID]
		WHERE c.StoreID IS NULL AND cr.Name = 'United States'

		),

		--sales information by order
		salesorders AS
		(
		SELECT soh.[SalesOrderID],
			   soh.[OrderDate],
			   soh.[OnlineOrderFlag],
			   soh.[SalesOrderNumber],
			   soh.[PurchaseOrderNumber],
			   soh.[CustomerID],
			   soh.[SalesPersonID],
			   soh.[TerritoryID],
			   soh.[ShipToAddressID],
			   soh.[SubTotal],
			   soh.[TaxAmt],
			   soh.[Freight],
			   soh.[TotalDue],
			   st.CountryRegionCode,
			   SUM(sod.[OrderQty]) AS ProductQuantity
		  FROM [AdventureWorks].[Sales].[SalesOrderHeader] AS soh
		  LEFT JOIN [AdventureWorks].[Sales].[SalesTerritory] st
		  ON soh.TerritoryID = st.TerritoryID
		  LEFT JOIN [AdventureWorks].[Sales].[SalesOrderDetail] sod
		  ON soh.SalesOrderID = sod.SalesOrderID
		  GROUP BY soh.[SalesOrderID], soh.[OrderDate], soh.[OnlineOrderFlag], soh.[SalesOrderNumber], soh.[PurchaseOrderNumber], soh.[CustomerID], soh.[SalesPersonID], soh.[TerritoryID], soh.[ShipToAddressID], soh.[SubTotal], soh.[TaxAmt], soh.[Freight], soh.[TotalDue], st.CountryRegionCode
		  
		  ), 
		
		--sales by customer
		salesbycustomer AS
		(
		SELECT soh.CustomerID,
				soh.OnlineOrderFlag,
				soh.TerritoryID,
				SUM(soh.TotalDue) AS TotalSales,
				SUM(soh.ProductQuantity) AS TotalProductQuantity
		FROM salesorders AS soh
		GROUP BY soh.CustomerID, soh.OnlineOrderFlag, soh.TerritoryID

		),

		--individual customer sales in US
		salesindividualcustomers_us AS
		(
		SELECT icus.BusinessEntityID,
			icus.FirstName,
			icus.MiddleName,
			icus.LastName,
			icus.PhoneNumber,
			icus.PhoneNumberType,
			icus.EmailAddress,
			icus.EmailPromotion,
			icus.AddressType,
			icus.AddressLine1,
			icus.City,
			icus.StateProvinceName,
			icus.PostalCode,
			icus.CountryRegionName,
			icus.Demographics,
			icus.CustomerID,
			sbc.OnlineOrderFlag,
			sbc.TotalSales,
			sbc.TotalProductQuantity,
			RANK() OVER (ORDER BY sbc.TotalSales DESC) AS SalesRank,
			RANK() OVER (ORDER BY sbc.TotalSales DESC, sbc.TotalProductQuantity DESC) AS SalesandQtdRank
		FROM individualcustomers_us AS icus
		LEFT JOIN salesbycustomer sbc
		ON icus.CustomerID = sbc.CustomerID
		),

		--individual customer sales by city in us
		salesindividualcustomers_citysales AS
		(
		SELECT
			icus.City,
			icus.StateProvinceName,
			icus.PostalCode,
			icus.CountryRegionName,
			SUM(icus.TotalSales) AS TotalCitySales,
			SUM(icus.TotalProductQuantity) AS TotalCityProductQuantity
		FROM salesindividualcustomers_us AS icus
		GROUP BY icus.City, icus.StateProvinceName, icus.PostalCode, icus.CountryRegionName
		
		),

		--individual customer sales by state
		salesindividualcustomers_state AS
		(
		SELECT 
			cs.StateProvinceName,
			SUM(TotalCitySales) AS TotalStateSales
		FROM salesindividualcustomers_citysales AS cs
		GROUP BY StateProvinceName

		),

		--store sales and location
		salesstores AS
			(
		SELECT 
			sc.StoreID,
			soh.[TerritoryID],
			SUM(soh.[TotalDue]) AS TotalSales,
			ss.Name,
			sl.AddressLine1,
			sl.City,
			sl.StateProvinceName,
			sl.PostalCode,
			sl.CountryRegionName
		FROM [AdventureWorks].[Sales].[SalesOrderHeader] soh
		LEFT JOIN Sales.Customer sc
		ON soh.CustomerID = sc.CustomerID
		LEFT JOIN Sales.Store ss
		ON sc.StoreID = ss.BusinessEntityID
		LEFT JOIN storeslocation_us sl
		ON sc.StoreID = sl.BusinessEntityID
		WHERE sc.StoreID IS NOT NULL AND sl.CountryRegionName IS NOT NULL
		GROUP BY sc.StoreID, soh.[TerritoryID], ss.Name, sl.AddressLine1, sl.City, sl.StateProvinceName, sl.PostalCode, sl.CountryRegionName 
		  
		  ),

		--store sales
		salesbystore AS 
		(
		SELECT StoreID, 
			Name, 
			SUM(TotalSales) TotalStoreSales
		FROM salesstores
		GROUP BY StoreID, Name

		),

		--store sales in US
		salesbystore_us AS 
		(
		SELECT ss.StoreID,
			ss.Name,
			ss.[TerritoryID],
			ss.AddressLine1,
			ss.City,
			ss.StateProvinceName,
			ss.PostalCode,
			ss.CountryRegionName,
			sbs.TotalStoreSales,
			RANK() OVER (ORDER BY TotalStoreSales DESC) AS SalesRank
		FROM salesstores ss
		LEFT JOIN salesbystore sbs
		ON ss.StoreID = sbs.StoreID
		
		),

		--top 30 store sales in US
		salesbystore_top30 AS
		(
		SELECT *
		FROM salesbystore_us
		WHERE salesrank <= 30

		),

		--cities where the top 30 stores (by sales) are located
		salesbystore_cities_top30 AS 
		(
		SELECT DISTINCT City
		FROM salesbystore_top30
		
		),

		--store sales in US, excluding top 30
		salesbystore_cities_top30less AS
		(
		SELECT StoreID,
			Name,
			[TerritoryID],
			AddressLine1,
			City,
			StateProvinceName,
			PostalCode,
			CountryRegionName,
			TotalStoreSales,
			SalesRank
		FROM salesbystore_us
		WHERE SalesRank > 30

		)

SELECT *
FROM salesindividualcustomers_us
GO






