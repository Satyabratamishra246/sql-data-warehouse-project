/*
==================================================================
  Create Database and schemas
==================================================================

Script Purpose: 
  This script creates a new database named 'DataWarehouse'  after checking if it already exists.
  if the database exists, it is dropped and recreated. additionally, the script sets up three schemas within the database: 'bronze', 'silver', 'gold'.

WARNING: 
  RUNNING this script will drop the entire 'DataWarehouse' database if it exists.
  All the data in the database will be permanently deleted. Proceed with caution and ensure you have proper backup before running this script.
*/


-- Create Database 'DataWarehouse'

USE master;
GO

-- Drop and recreate the 'DataWarehouse' database

IF EXISTS(SELECT 1 FROM sys,databases WHERE name = 'DataWarehouse')
BEGIN
	ALTER DATABASE DataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DROP DATABASE DataWarehouse;
END;
GO

-- Create the 'DataWarehouse' database

CREATE DATABASE DataWarehouse;
GO

USE DataWarehouse;
GO

-- Create schemas

CREATE SCHEMA bronze;
GO
CREATE SCHEMA silver;
GO
CREATE SCHEMA gold;
GO
