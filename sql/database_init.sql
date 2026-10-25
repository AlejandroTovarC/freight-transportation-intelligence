/*
=================================
CREATE DATABASE AND SCHEMAS
=================================

Desc:
    This script creates the database named [insert name] after checking if it already exists. 
    If the database exists, it is dropped and recreated. Additionally, the script sets up three schemas 
    within the database: 'bronze', 'silver', and 'gold'.


WARNING:
    Running this script will drop all medallion database layers if it exists. 
    All data in the database will be permanently deleted. Proceed with caution 
    and ensure you have proper backups before running this script.
*/

-- Drop and recreate the 'Freight Transportation Intelligence' Database
DROP DATABASE IF EXISTS freight_transportation_intelligence WITH (FORCE);


-- Create the 'Freight Transportation Intelligence' Database
CREATE DATABASE freight_transportation_intelligence;

-- On Python orchestrator, this will be handled and is not needed
-- Connecting to Database
\connect freight_transportation_intelligence;

-- Baseline schemas
\echo
\echo 'Create Operational Schema'
DROP SCHEMA IF EXISTS operational CASCADE;
CREATE SCHEMA operational;

\echo
\echo 'Create Warehouse Schema'
DROP SCHEMA IF EXISTS warehouse CASCADE;
CREATE SCHEMA warehouse;


-- Later implementation: medallion schema

/*
-- Create medallion schemas
CREATE SCHEMA bronze;

CREATE SCHEMA silver;

CREATE SCHEMA gold;
*/