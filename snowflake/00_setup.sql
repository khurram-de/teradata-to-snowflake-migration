CREATE TABLE pipeline_audit_log (
    procedure_name STRING,
    run_id STRING,
    step_id INTEGER,
    step_name STRING,
    run_date TIMESTAMP,
    status STRING,
    rows_processed INTEGER,
    status_reason STRING
);