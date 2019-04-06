CREATE TABLE dbo.TEST_Disk(
	ID  int IDENTITY(10000, 1),
	ProductID int NOT NULL,
	OrderQty int NOT NULL,
	SumOrder as ProductID + OrderQty,
	XMLData XML NULL,
	Description varchar(1000) SPARSE,
	StartDate datetime CONSTRAINT DF_TEST_DiskStart DEFAULT getdate() NOT NULL,
	ModifiedDate datetime CONSTRAINT DF_TEST_DiskEnd DEFAULT getdate() NOT NULL,
 CONSTRAINT PK_TEST_Disk_ID PRIMARY KEY CLUSTERED
	(
		ID 
	) 
)

GO

--ALTER DATABASE test ADD FILE (name='test_ram', filename='/var/opt/mssql/data/ramdisk') TO FILEGROUP ramdisk  


CREATE TABLE dbo.TEST_Memory(
	ID  int IDENTITY(1, 1),
	ProductID int NOT NULL,
	OrderQty int NOT NULL,
	SumOrder int NULL,
	XMLData nvarchar(MAX) NULL,
	Description varchar(1000) NULL,
	StartDate datetime CONSTRAINT DF_TEST_MemoryStart DEFAULT getdate() NOT NULL,
	ModifiedDate datetime CONSTRAINT DF_TEST_MemoryEnd DEFAULT getdate() NOT NULL,
 CONSTRAINT PK_TEST_Memory_ID PRIMARY KEY NONCLUSTERED HASH
	(
		ID 
	)WITH (BUCKET_COUNT = 1572864) 
) WITH ( MEMORY_OPTIMIZED = ON , DURABILITY = SCHEMA_AND_DATA )

GO

-- 1. Insert dummy row
SET IDENTITY_INSERT TEST_Memory ON
	INSERT TEST_Memory (ID,ProductID, OrderQty, SumOrder)
	SELECT 10000, 1,1,1
SET IDENTITY_INSERT TEST_Memory OFF
 
-- 2. Remove the record
DELETE TEST_Memory WHERE ID = 10000
 
-- 3. Verify Current Identity
SELECT TABLE_NAME, IDENT_SEED(TABLE_NAME) AS Seed, IDENT_CURRENT(TABLE_NAME) AS Current_Identity
FROM INFORMATION_SCHEMA.TABLES
WHERE OBJECTPROPERTY(OBJECT_ID(TABLE_NAME), 'TableHasIdentity') = 1
AND TABLE_NAME = 'TEST_Memory'

GO

;With ZeroToNine (Digit) As 
(Select 0 As Digit
        Union All
  Select Digit + 1 From ZeroToNine Where Digit < 9),
    OneMillionRows (Number) As (
        Select 
          Number = SixthDigit.Digit  * 100000 
                 + FifthDigit.Digit  *  10000 
                 + FourthDigit.Digit *   1000 
                 + ThirdDigit.Digit  *    100 
                 + SecondDigit.Digit *     10 
                 + FirstDigit.Digit  *      1 
        From
            ZeroToNine As FirstDigit  Cross Join
            ZeroToNine As SecondDigit Cross Join
            ZeroToNine As ThirdDigit  Cross Join
            ZeroToNine As FourthDigit Cross Join
            ZeroToNine As FifthDigit  Cross Join
            ZeroToNine As SixthDigit
)
Select   Number+1 ID,ABS(CHECKSUM(NEWID())) % 50 ProductID, ABS(CHECKSUM(NEWID())) % 55 OrderQty
, (SELECT Number+1 as ProductID,ABS(CHECKSUM(NEWID())) % 50 as OrderQty FROM master.dbo.spt_values as data 
		WHERE type = 'p' and data.number = v.number % 2047 FOR XML AUTO, ELEMENTS, TYPE  ) XMLData
INTO TEST_DataLoad
From OneMillionRows v


-------------------------------------------------------------

---- Load disk-based table
SET STATISTICS TIME ON; 
INSERT [dbo].[TEST_Disk] ( ProductID, OrderQty )
select ProductID, OrderQty from TEST_DataLoad
SET STATISTICS TIME OFF; 
--SQL Server Execution Times:
--   CPU time = 3933 ms,  elapsed time = 4116 ms.

--(1000000 rows affected)

---- Load the memory-optimized table
SET STATISTICS TIME ON; 
INSERT [dbo].[TEST_Memory](ProductID, OrderQty, SumOrder)
select ProductID, OrderQty,ProductID + OrderQty from TEST_DataLoad
SET STATISTICS TIME OFF; 

-- SQL Server Execution Times:
--   CPU time = 2237 ms,  elapsed time = 2479 ms.

-- (1000000 rows affected)
