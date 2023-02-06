/*
Post-Graduation in Enterprise Data Science & Analytics @ NOVA IMS
Managing Relational & Non-Relational Data 2022
IV - STOCK CLEARANCE 
20211044 - João Magalhães
20211049 - Maria Trindade
20211052 - Nuno Bolas
20211058 - Mariana Teixeira

*/
-- SQL Statements

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
USE [AdventureWorks]
GO

-- SCHEMA CONFIGURATION
-- Create schema if not previously created


IF NOT EXISTS (SELECT DB_NAME() AS dbname WHERE SCHEMA_ID('Auction') IS NOT NULL)
	BEGIN
	IF NOT EXISTS (SELECT TOP(1) * FROM sys.schemas WHERE name='Auction')
		BEGIN
			PRINT 'The Auction schema does not exist. It will be created with respective tables.';
			EXEC sp_executesql N'CREATE SCHEMA Auction AUTHORIZATION dbo'; 
		END
	END
GO

IF (OBJECT_ID('Auction.ProductBid') IS NOT NULL) 
BEGIN
	DROP TABLE [Auction].[ProductBid]
END
GO

IF (OBJECT_ID('Auction.Product') IS NOT NULL)
BEGIN
	DROP TABLE [Auction].[Product]
END
GO

IF (OBJECT_ID('Auction.Configurations') IS NOT NULL)
BEGIN
	DROP TABLE [Auction].[Configurations]
END
GO

-- TABLE CREATION
-- Table: Auction.Product

BEGIN
	CREATE TABLE [Auction].[Product]
	(
		[AuctionProductID] [int] NOT NULL IDENTITY PRIMARY KEY,
		[ProductID] [int] NOT NULL,
		[ExpireDate] [datetime] NULL,
		[AuctionStatus] [bit] NOT NULL,
		[Removed] [bit] NULL,
		[InitialBidPrice] [money] NULL,
		[ListedPrice] [money] NULL
	) ON [PRIMARY]

	ALTER TABLE [Auction].[Product] WITH CHECK ADD CONSTRAINT [FK_ProductAuction_Product] FOREIGN KEY([ProductID])
	REFERENCES [Production].[Product] ([ProductID])

	ALTER TABLE [Auction].[Product] ADD CONSTRAINT [DF_ProductAuction_AuctionStatus] DEFAULT ((1)) FOR [AuctionStatus]

	ALTER TABLE [Auction].[Product] ADD CONSTRAINT [DF_ProductAuction_Removed] DEFAULT ((0)) FOR [Removed]

	PRINT 'Table Product was created within Auction Schema.';
END

-- Table: Auction.ProductBid

BEGIN
	CREATE TABLE [Auction].[ProductBid]
	(
		[AuctionProductID] [int] NOT NULL,
		[ProductID] [int] NULL,
		[CustomerID] [int] NULL,
		[BidAmmount] [money] NULL,
		[BidTimestamp] [datetime] NOT NULL
	) ON [PRIMARY]

	ALTER TABLE [Auction].[ProductBid] WITH CHECK ADD CONSTRAINT [FK_ProductBidAuction_Customer] FOREIGN KEY([CustomerID])
	REFERENCES [Sales].[Customer] ([CustomerID])

	ALTER TABLE [Auction].[ProductBid] WITH CHECK ADD CONSTRAINT [FK_ProductBidAuction_Product] FOREIGN KEY([AuctionProductID])
	REFERENCES [Auction].[Product] ([AuctionProductID])

	PRINT 'Table ProductBid was created within Auction Schema.';
END


-- Table: Auction.Configurations

BEGIN
	CREATE TABLE [Auction].[Configurations]
	(
		[Setting] [varchar](50) NOT NULL,
		[Value] [sql_variant] NOT NULL
	) ON [PRIMARY]

	PRINT 'Table Configurations was created within Auction Schema, with the default settings.';

	-- Parameters pre defined settings
	INSERT INTO [Auction].[Configurations] ([Setting], [Value]) VALUES ('MinIncreaseBid', CAST(0.05 as money))
	INSERT INTO [Auction].[Configurations] ([Setting], [Value]) VALUES ('MaxBidLimit', CAST(1.0 as real))
	INSERT INTO [Auction].[Configurations] ([Setting], [Value]) VALUES ('StartBidDate', CAST('20221114' as datetime))
	INSERT INTO [Auction].[Configurations] ([Setting], [Value]) VALUES ('StopBidDate', CAST('20221127' as datetime))
END
GO

-- STORED PROCEDURES
-- uspAddProductToAuction
-- This stored procedure adds a product as auctioned

CREATE OR ALTER PROCEDURE [Auction].[uspAddProductToAuction]
(
	@ProductID int,
	@ExpireDate datetime = NULL,
	@InitialBidPrice money = NULL
)
AS
-- Variable storing the current timestamp
DECLARE @CurrentTimestamp datetime2 = GETDATE();

-- Variables storing aux values from [Auction].[Configurations]
DECLARE @StartBidDate datetime = NULL
DECLARE @StopBidDate datetime = NULL


-- Variables storing aux values from [Production].[Product]
DECLARE @P_ProductID int = NULL;
DECLARE @SellStartDate datetime = NULL;
DECLARE @SellEndDate datetime = NULL;
DECLARE @DiscontinuedDate datetime = NULL;
DECLARE @ProductSubcategoryID int = NULL
DECLARE @MakeFlag bit = NULL;

-- Variables storing aux values from [Production].[ProductListPriceHistory]
DECLARE @ListedPrice money = NULL;
DECLARE @Min_InitialBidPrice money = NULL;
DECLARE @Max_InitialBidPrice money = NULL;


BEGIN TRY
	SELECT  @P_ProductID = [ProductID],
			@SellStartDate = [SellStartDate],
			@SellEndDate = [SellEndDate],
			@DiscontinuedDate = [DiscontinuedDate],
			@ProductSubcategoryID = [ProductSubcategoryID],
			@MakeFlag = [MakeFlag]
	FROM
	(
	SELECT [ProductID],
		   [SellStartDate],
		   [SellEndDate],
		   [DiscontinuedDate],
		   [ProductSubcategoryID],
		   [MakeFlag]
	FROM [Production].[Product]
	WHERE [ProductID] = @ProductID
	) AS pp

	
	-- Confirm whether the @ProductID exists or is being auctioned
	IF @P_ProductID IS NULL
		BEGIN
			DECLARE @errormessage1 VARCHAR(200) = 'Error uspAddProductToAuction@ProductID: @ProductID does not exist.';
			THROW 50001, @errormessage1, 0;
		END
	ELSE IF EXISTS (
					SELECT [ProductID]
					FROM [Auction].[Product]
					WHERE [ProductID] = @ProductID 
						AND [AuctionStatus] = 1
					) 
		BEGIN
			DECLARE @errormessage2 VARCHAR(200) = 'Error uspAddProductToAuction@ProductID: @ProductID is being auctioned.';
			THROW 50002, @errormessage2, 0;
		END

	-- Confirm whether the @ProductID is from Bikes category and non-null
	ELSE IF @ProductSubcategoryID IS NULL OR 
		(
			(
				SELECT ppc.[Name] 
				FROM [Production].[ProductSubcategory] AS pps
				INNER JOIN [Production].[ProductCategory] AS ppc
				ON pps.[ProductCategoryID] = ppc.[ProductCategoryID]
				WHERE pps.[ProductSubcategoryID] = @ProductSubcategoryID
			) = N'Accessories'
		)OR
		(
			(
				SELECT ppc.[Name] 
				FROM [Production].[ProductSubcategory] AS pps
				INNER JOIN [Production].[ProductCategory] AS ppc
				ON pps.[ProductCategoryID] = ppc.[ProductCategoryID]
				WHERE pps.[ProductSubcategoryID] = @ProductSubcategoryID
			) = N'Components'
		)OR
		(
			(
				SELECT ppc.[Name] 
				FROM [Production].[ProductSubcategory] AS pps
				INNER JOIN [Production].[ProductCategory] AS ppc
				ON pps.[ProductCategoryID] = ppc.[ProductCategoryID]
				WHERE pps.[ProductSubcategoryID] = @ProductSubcategoryID
			) = N'Clothing'
		)
		BEGIN
			DECLARE @errormessage3 VARCHAR(200) = CONCAT('Error uspAddProductToAuction: The product ', CONVERT(varchar(8), @ProductID), ' category is not valid.');
			THROW 50003, @errormessage3, 0;
		END
	
	-- Confirm whether @ProductID is being commercialised
	ELSE IF (@CurrentTimestamp < @SellStartDate) OR (@SellEndDate IS NOT NULL AND @CurrentTimestamp > @SellEndDate) OR (@DiscontinuedDate IS NOT NULL AND @CurrentTimestamp > @DiscontinuedDate)
		BEGIN
			DECLARE @errormessage4 VARCHAR(200) = CONCAT('Error uspAddProductToAuction: Product ',  CONVERT(varchar(8), @ProductID),' is not currently commercialized.');
			THROW 50007, @errormessage4, 0;
		END

	-- Confirm whether there's stock of the product
	ELSE IF NOT EXISTS 
		(SELECT [ProductID]
		FROM [Production].[ProductInventory]
		WHERE [ProductID] = @ProductID
		AND (@CurrentTimestamp > [ModifiedDate])
		AND [Quantity] >= 1)		
		BEGIN
			DECLARE @errormessage5 VARCHAR(200) = CONCAT('Error uspAddProductToAuction: Product ', CONVERT(varchar(8), @ProductID), ' is out of stock @', CONVERT(char(10), @CurrentTimestamp,126), '.');
			THROW 50008, @errormessage5, 0;
		END
	
		BEGIN
		-- If @ExpireDate not defined, set the default value for the @ExpireDate between ExpireDate or in 1 week
		IF @ExpireDate IS NULL 
			BEGIN
			SET @ExpireDate = COALESCE(@ExpireDate, DATEADD(WEEK,1,GETDATE()));
			END

		BEGIN
		-- Check whether the @ExpireDate is after the @StartBidDate
		SELECT @StartBidDate = CAST([Value] as datetime) 
					FROM (SELECT [Value] FROM [Auction].[Configurations] 
					WHERE [Setting] = N'StartBidDate') as thr;	
		IF @ExpireDate < @StartBidDate
			BEGIN
				DECLARE @errormessage6 VARCHAR(200) = 'Error uspAddProductToAuction@ExpireDate: The @ExpireDate is before the begining of the auction.';
				THROW 50004, @errormessage6, 0;
			END
		ELSE
			BEGIN
			-- Check whether the @CurrentTimestamp is after @StopBidDate
			SELECT @StopBidDate = CAST([Value] as datetime) 
				FROM (SELECT [Value] FROM [Auction].[Configurations] 
				WHERE [Setting] = N'StopBidDate') as thr;	
			IF @CurrentTimestamp > @StopBidDate
			BEGIN
				DECLARE @errormessage7 VARCHAR(200) = 'Error uspAddProductToAuction@ExpireDate: The @CurrentTimestamp is after the end of the auction.';
				THROW 50004, @errormessage7, 0;
			END
		
			BEGIN
				-- Define maximum value for the @InitialBidPrice at current time
				SELECT @ListedPrice = [ListPrice] 
					FROM
					(
						SELECT TOP(1) pplph.[ListPrice] 
						FROM [Production].[ProductListPriceHistory] AS pplph
						WHERE pplph.[ProductID] = @ProductID							
						ORDER BY pplph.[StartDate] DESC
					) AS t_ListedPrice
				
				-- Define the initial bid price based on the @MakeFlag variable (50% of listed price for products manufactured in-house, 75% for not manufactured in-house)
				SELECT @Min_InitialBidPrice = [Min_InitialBidPrice], 
					   @Max_InitialBidPrice = [Max_InitialBidPrice]
				FROM 
				( 
					SELECT
						CASE WHEN @MakeFlag = 0 
							THEN @ListedPrice*0.75
							ELSE @ListedPrice*0.5
						END AS [Min_InitialBidPrice],
						@ListedPrice AS [Max_InitialBidPrice]
				) AS t_BidPrice;

				BEGIN
					-- Confirm whether the @InitialBidPrice is not lower than minimum initial bid price
					IF @InitialBidPrice < @Min_InitialBidPrice
					BEGIN
						DECLARE @errormessage8 VARCHAR(200) = CONCAT('Error uspAddProductToAuction@InitialBidPrice: @InitialBidPrice must be greater than', CAST(@Min_InitialBidPrice AS VARCHAR(30)),'.');
						THROW 50005, @errormessage8, 0;
					END

					-- Confirm whether the @InitialBidPrice is higher than the maximum initial bid price
					ELSE IF @InitialBidPrice > @Max_InitialBidPrice
						BEGIN
							DECLARE @errormessage9 VARCHAR(200) = CONCAT('Error uspAddProductToAuction@InitialBidPrice: @InitialBidPrice must be less than', CAST(@Max_InitialBidPrice AS VARCHAR(30)),'.');
							THROW 50006, @errormessage9, 0;
						END
					ELSE
						BEGIN
							-- If @InitialBidPrice is not defined then = @Min_InitialBidPrice
							SET @InitialBidPrice = COALESCE(@InitialBidPrice, @Min_InitialBidPrice);				
						END							
					END
				END
			END
		END
	END
BEGIN
	BEGIN TRANSACTION
		-- Add @ProductID to auction
		INSERT INTO [Auction].[Product] 
		(
			[ProductID],
			[ExpireDate],
			[InitialBidPrice],
			[ListedPrice]	
		)
		VALUES 
		(
			@ProductID,
			@ExpireDate,
			@InitialBidPrice,
			@ListedPrice			
		);
	COMMIT TRANSACTION
END
RETURN
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0
		BEGIN 
			ROLLBACK TRANSACTION
		END
	ELSE
		BEGIN
			PRINT ERROR_MESSAGE();
		END
END CATCH
GO

-- uspTryBidProduct
-- This stored procedure adds bid on behalf of that customer

CREATE OR ALTER PROCEDURE [Auction].[uspTryBidProduct]
(
	@ProductID int,
	@CustomerID int,
	@BidAmmount money = NULL
)
AS

-- Variable storing the current timestamp
DECLARE @BidTimestamp datetime2 = GETDATE();

-- Variables storing aux values from [Auction].[Configurations]
DECLARE @MinIncreaseBid money = NULL;
DECLARE @MaxBidLimit real = NULL;
DECLARE @StartBidDate datetime = NULL
DECLARE @StopBidDate datetime = NULL


-- Variables storing aux values from [Auction].[Product]
DECLARE @AuctionProductID int = NULL;
DECLARE @BidProductID int = NULL;
DECLARE @ExpireDate datetime = NULL;
DECLARE @InitialBidPrice money = NULL;
DECLARE @ListedPrice money = NULL;

-- Variables storing aux values from [Auction].[ProductBid]
DECLARE @LastBid money = NULL;
DECLARE @Update bit = 0;

BEGIN TRY
	-- Storing values for @ProductID 
	SELECT @AuctionProductID = [AuctionProductID],
		   @BidProductID = [ProductID],
		   @ExpireDate = [ExpireDate],
		   @InitialBidPrice = [InitialBidPrice],
		   @ListedPrice = [ListedPrice]
	FROM
	(
	SELECT [AuctionProductID], 
		   [ProductID],
		   [ExpireDate],
		   [InitialBidPrice],
		   [ListedPrice]
	FROM [Auction].[Product]
	WHERE [ProductID] = @ProductID
		AND [AuctionStatus] = 1
	) AS t_Bid

	BEGIN
	-- Confirm whether the @ProductID is on auction
	IF @BidProductID IS NULL
		BEGIN
			DECLARE @errormessage10 VARCHAR(200) = 'Error uspTryBidProduct@ProductID: @ProductID is not currently on auction.';
			THROW 50011, @errormessage10, 0;
		END
	ELSE
		BEGIN
		-- Confirm whether the @CustomerID exists
		IF NOT EXISTS (
			SELECT [CustomerID] 
			FROM [Sales].[Customer] 
			WHERE [CustomerID] = @CustomerID
			)
			BEGIN
				DECLARE @errormessage11 VARCHAR(200) = 'Error uspTryBidProduct@CustomerID: @CustomerID does not exist.';
				THROW 50012, @errormessage11, 0;
			END
		ELSE
			BEGIN
			-- Confirm whether the auction expired for @ProductID
			IF (@BidTimestamp > @ExpireDate)
				BEGIN
					DECLARE @errormessage12 VARCHAR(200) = CONCAT('Error uspTryBidProduct: The auction for product ', CONVERT(varchar(8), @ProductID), ' expired.');
					THROW 50013, @errormessage12, 0;
				END
			ELSE
				BEGIN
				-- Confirm whether the auction has started
				SELECT @StartBidDate = CAST([Value] as datetime) 
					FROM (SELECT [Value] FROM [Auction].[Configurations] 
					WHERE [Setting] = N'StartBidDate') as thr;

				IF (@BidTimestamp < @StartBidDate)
					BEGIN
						DECLARE @errormessage13 VARCHAR(200) = 'Error uspTryBidProduct: The auction has not started.';
						THROW 50013, @errormessage13, 0;
					END

				BEGIN
				-- Check whether the @CurrentTimestamp is after @StopBidDate
				SELECT @StopBidDate = CAST([Value] as datetime) 
					FROM (SELECT [Value] FROM [Auction].[Configurations] 
					WHERE [Setting] = N'StopBidDate') as thr;	
				IF @BidTimestamp > @StopBidDate
					BEGIN
						DECLARE @errormessage131 VARCHAR(200) = 'Error uspAddProductToAuction@ExpireDate: The @BidTimestamp is after the end of the auction.';
						THROW 50004, @errormessage131, 0;
					END

				BEGIN
					-- Confirm whether there is a bid on the product
					SELECT @LastBid = [BidAmmount]
					FROM
					(
					SELECT TOP(1) [BidAmmount]
					FROM [Auction].[ProductBid]
					WHERE [ProductID] = @ProductID
						AND [AuctionProductID] = @AuctionProductID
					ORDER BY [BidAmmount] DESC
					) AS lbid

					-- Compare bid value with the configuration parameters
					SELECT @MinIncreaseBid = CAST([Value] as money) 
					FROM (SELECT [Value] FROM [Auction].[Configurations] 
					WHERE [Setting] = N'MinIncreaseBid') as thr;

					SELECT @MaxBidLimit = CAST([Value] as real) 
					FROM (SELECT [Value] FROM [Auction].[Configurations] 
					WHERE [Setting] = N'MaxBidLimit') as thr;
					
					-- If @BidAmount is not specified, then increase by threshold specified in thresholds configuration table.
					IF @BidAmmount IS NULL 
						BEGIN
						SET @BidAmmount = COALESCE(@LastBid + @MinIncreaseBid, @InitialBidPrice);
						END
					BEGIN

					-- Confirm whether @BidAmmount is valid
					IF(@BidAmmount > ROUND(@MaxBidLimit * @ListedPrice, 1))
						BEGIN
							DECLARE @errormessage14 VARCHAR(200) = 'Error uspTryBidProduct@BidAmount: @BidAmount cannot be greater than the maximum bid limit.';
							THROW 50014, @errormessage14, 0;
						END

					-- Confirm whether the defined minimum increase and initial bid price are respected
					ELSE IF @BidAmmount < (COALESCE(@LastBid + @MinIncreaseBid, @InitialBidPrice))
						BEGIN
							DECLARE @errormessage15 VARCHAR(200) = 'Error uspTryBidProduct@BidAmount: @BidAmount must be greather than initial bid price and respect minimum bid increment.';
							THROW 50015, @errormessage15, 0;			
						END

					-- Confirm whether the maximum bid limit was surpassed
					ELSE IF (
						@BidAmmount > ROUND(@MaxBidLimit * @ListedPrice, 1) - @MinIncreaseBid 
						AND @BidAmmount <= ROUND(@MaxBidLimit * @ListedPrice, 1)
						)
						BEGIN
							-- Change @Update variable to end the auction
							SET @Update = 1;
						END
						END					
						END
					END
				END
			END
		END
	END
BEGIN
	BEGIN TRANSACTION
		-- Bid on behalf of @CustomerID
		INSERT INTO [Auction].[ProductBid] 
		(
			[AuctionProductID],
			[ProductID],
			[CustomerID],
			[BidAmmount],
			[BidTimestamp]
		)
		VALUES 
		(
			@AuctionProductID,
			@ProductID,
			@CustomerID,
			@BidAmmount,
			@BidTimestamp
		);
		-- End auction for @ProductID if the MaxBidLimit was reached (@Update = 1)
		IF @Update = 1
			BEGIN
				UPDATE [Auction].[Product]
				SET [AuctionStatus] = 0
				WHERE [ProductID] = @BidProductID
					AND [AuctionStatus] = 1;
			END
	COMMIT TRANSACTION
END
RETURN
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0
		BEGIN 
			ROLLBACK TRANSACTION
		END
	ELSE
		BEGIN
			PRINT ERROR_MESSAGE();
		END
END CATCH
GO

-- uspRemoveProductFromAuction
-- This stored procedure removes product from being listed as auctioned even there might have been bids for that product

CREATE OR ALTER PROCEDURE [Auction].[uspRemoveProductFromAuction]
(
	@ProductID int
)
AS
BEGIN TRY
	BEGIN
		-- Confirm whether ProductID has an active auction
		IF NOT EXISTS (
			SELECT [ProductID] 
			FROM [Auction].[Product] 
			WHERE [ProductID] = @ProductID AND [AuctionStatus] = 1
			)
			BEGIN
				DECLARE @errormessage21 VARCHAR(200) = 'Error uspRemoveProductFromAuction@ProductID: @ProductID is not on auction.';
				THROW 50021, @errormessage21, 0;
			END
		END
		BEGIN
			BEGIN TRANSACTION
				-- Remove and cancel auction for ProductID
				UPDATE [Auction].[Product]
				SET [AuctionStatus] = 0,
					[Removed] = 1
				WHERE [ProductID] = @ProductID AND [AuctionStatus] = 1;
			COMMIT TRANSACTION
	END
	RETURN
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0
		BEGIN 
			ROLLBACK TRANSACTION
		END
	ELSE
		BEGIN
			PRINT ERROR_MESSAGE();
		END
END CATCH
GO

-- uspListBidsOffersHistory
-- This stored procedure returns customer bid history for specified date time interval

CREATE OR ALTER PROCEDURE [Auction].[uspListBidsOffersHistory]
(
	@CustomerID int,
	@StartTime datetime,
	@EndTime datetime,
	@Active bit
)
AS
BEGIN TRY
	BEGIN
	-- Confirm whether CustomerID has bidded
	IF NOT EXISTS (
		SELECT [CustomerID] 
		FROM [Auction].[ProductBid] 
		WHERE [CustomerID] = @CustomerID
		)
		BEGIN
			DECLARE @errormessage31 VARCHAR(200) = 'Error uspListBidsOffersHistory@CustomerID: @CustomerID does not have bidded.';
			THROW 50031, @errormessage31, 0;
		END
	-- Confirm whether the dates are valid
	ELSE IF @EndTime <= @StartTime
		BEGIN
			DECLARE @errormessage32 VARCHAR(200) = 'Error uspListBidsOffersHistory@StartTime and @EndTime: @EndTime has to be greater or equal to @StartTime.';
			THROW 50032, @errormessage32, 0;
		END
	ELSE
		BEGIN
			-- Return customer bid history sorted by most recent date
			-- If Active parameter is set to false, then all bids should be returned including ones related for products no longer auctioned or purchased by customer.
			-- If Active set to true only returns products currently auctioned
					SELECT  apb.[AuctionProductID],
					apb.[ProductID],
					[CustomerID],
					[BidAmmount],
					[BidTimestamp],
					CASE
						WHEN ap.[Removed] = 1 THEN 'Cancelled'
						WHEN ap.[AuctionStatus] = 0 THEN 'Closed'
					ELSE 'Active'
					END AS AuctionStatus
			FROM [Auction].[ProductBid] as apb
			LEFT JOIN [Auction].[Product] as ap
			ON apb.[AuctionProductID] = ap.[AuctionProductID]
			WHERE apb.[CustomerID] = @CustomerID AND
				(apb.[BidTimestamp] BETWEEN @StartTime AND @EndTime) AND
				(ap.[AuctionStatus] = @Active OR @Active = 0)
			ORDER BY [BidTimestamp] DESC;
		END
	END
RETURN
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0
		BEGIN 
			ROLLBACK TRANSACTION
		END
	ELSE
		BEGIN
			PRINT ERROR_MESSAGE();
		END
END CATCH
GO

-- uspUpdateProductAuctionStatus
-- This stored procedure updates auction status for all auctioned products
CREATE OR ALTER PROCEDURE [Auction].[uspUpdateProductAuctionStatus]
AS
	-- See if there's active auctions and cancel if surpassed products expire date 
	UPDATE [Auction].[Product]
	SET [AuctionStatus] = 0
	WHERE [AuctionStatus] = 1 
		AND GETDATE() > [ExpireDate];
GO





