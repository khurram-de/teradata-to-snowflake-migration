-- =============================================================================
-- Setup Script: Teradata to Snowflake Migration
-- Creates all required objects before running any stored procedures
-- =============================================================================
 
-- Drop old audit table if exists (superseded by procedure_execution_log)
DROP TABLE IF EXISTS pipeline_audit_log;
DROP TABLE IF EXISTS procedure_audit_log;
 
-- =============================================================================
-- Unified Execution Log Table
-- Tracks procedure runs and step-level execution in a single table
-- Supports retry lineage via parent_run_id and resume logic via step_status
-- =============================================================================
 
CREATE TABLE IF NOT EXISTS procedure_execution_log (
    run_id          STRING,         -- unique ID per execution attempt (UUID)
    parent_run_id   STRING,         -- populated on retry, NULL on fresh run
    retry_count     INTEGER,        -- 0 on fresh run, increments on retry
    procedure_name  STRING,         -- name of the stored procedure
    procedure_status STRING,        -- INPROGRESS, SUCCESS, FAILED
    step_id         INTEGER,        -- sequential step number within the procedure
    step_name       STRING,         -- human readable step description
    step_status     STRING,         -- RUNNING, SUCCESS, FAILED
    rows_processed  INTEGER,        -- rows affected by this step
    status_reason   STRING,         -- error message on failure, NULL on success
    run_date        TIMESTAMP       -- timestamp of this log entry
);

-- CDR_STAGE: source table, data lands here first
CREATE OR REPLACE TABLE cdr_stage (
    cdr_id        INTEGER,
    customer_id   INTEGER,
    call_date     DATE,
    duration_secs INTEGER,
    call_type     STRING
);

-- CDR_TARGET: destination table, same schema as stage
CREATE OR REPLACE TABLE cdr_target (
    cdr_id        INTEGER,
    customer_id   INTEGER,
    call_date     DATE,
    duration_secs INTEGER,
    call_type     STRING
);

-- CUSTOMER_SUMMARY: one row per customer with running call count
CREATE OR REPLACE TABLE customer_summary (
    customer_id  INTEGER,
    customer_name STRING,
    total_calls  INTEGER DEFAULT 0
);

-- Sample data
INSERT INTO cdr_stage VALUES
    (1, 101, '2024-01-01', 120, 'INBOUND'),
    (2, 101, '2024-01-02', 300, 'OUTBOUND'),
    (3, 102, '2024-01-01', 60,  'INBOUND'),
    (4, 103, '2024-01-03', 450, 'OUTBOUND'),
    (5, 104, '2024-01-04', 200, 'INBOUND');

INSERT INTO customer_summary VALUES
    (101, 'Alice',   5),
    (102, 'Bob',     3),
    (103, 'Charlie', 8),
    (104, 'Diana',   1);