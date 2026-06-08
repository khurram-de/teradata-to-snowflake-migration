CREATE OR REPLACE PROCEDURE multi_step_transaction()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE 
    step_1_return_msg STRING;
    step_2_return_msg STRING;
    procedure_name STRING := 'multi_step_transaction';
    current_run_id STRING := UUID_STRING();
    current_step_id INTEGER := 0;
    row_count INTEGER; 
BEGIN
    BEGIN TRANSACTION;
        -- Step 1: Insert into cdr_target from cdr_stage
        current_step_id := current_step_id + 1;
        INSERT INTO cdr_target
            SELECT * FROM cdr_stage;
        row_count := SQLROWCOUNT;
        COMMIT;
        step_1_return_msg := 'Populated staging table.';
        INSERT INTO pipeline_audit_log (procedure_name, run_id, step_id, step_name, run_date, status, rows_processed)
        VALUES (procedure_name, current_run_id, current_step_id, step_1_return_msg, CURRENT_TIMESTAMP(), 'SUCCESS', row_count);
    EXCEPTION
        WHEN OTHER THEN
            ROLLBACK;
            step_1_return_msg := 'Failed to populate staging table.';
            INSERT INTO pipeline_audit_log (procedure_name, run_id, step_id, step_name, run_date, status, status_reason)
            VALUES (procedure_name, current_run_id, current_step_id, step_1_return_msg, CURRENT_TIMESTAMP(), 'FAILURE', SQLERRM);
            RAISE;
    
    BEGIN TRANSACTION;
        current_step_id := current_step_id + 1;
        UPDATE customer_summary
        SET total_calls = total_calls + 1
            WHERE customer_id IN (
                SELECT customer_id FROM cdr_stage 
            );
        row_count := SQLROWCOUNT;
        COMMIT;
        step_2_return_msg := 'Updated customer Call count.';
        INSERT INTO pipeline_audit_log (procedure_name, run_id, step_id, step_name, run_date, status, rows_processed)
        VALUES (procedure_name, current_run_id, current_step_id, step_2_return_msg, CURRENT_TIMESTAMP(), 'SUCCESS', row_count);
        RETURN step_1_return_msg || ' ' || step_2_return_msg;

    EXCEPTION
        WHEN OTHER THEN
        ROLLBACK;
        step_2_return_msg := 'Failed to update customer Call count.';
        INSERT INTO pipeline_audit_log (procedure_name, run_id, step_id, step_name, run_date, status, status_reason)
            VALUES (procedure_name, current_run_id, current_step_id, step_2_return_msg, CURRENT_TIMESTAMP(), 'FAILURE', SQLERRM);
        RAISE;
END
$$
