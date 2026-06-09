CREATE OR REPLACE PROCEDURE load_cdr_pipeline_v2()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    current_run_id  STRING := UUID_STRING();
    proc_name       STRING := 'load_cdr_pipeline_v2';
    step_num        INTEGER := 0;
    row_count       INTEGER;
    step_1_msg      STRING;
    step_2_msg      STRING;
BEGIN
    BEGIN
        step_num := step_num + 1;
        
        BEGIN TRANSACTION;
            INSERT INTO procedure_execution_log
                (run_id, parent_run_id, retry_count, procedure_name, procedure_status,
                 step_id, step_name, step_status, rows_processed, status_reason, run_date)
            VALUES
                (:current_run_id, NULL, 0, :proc_name, 'INPROGRESS',
                 :step_num, 'INSERT cdr_target', 'RUNNING', NULL, NULL, CURRENT_TIMESTAMP());
    
            INSERT INTO cdr_target SELECT * FROM cdr_stage;
            row_count := SQLROWCOUNT;
            step_1_msg := 'Inserted ' || row_count || ' rows into cdr_target.';
    
            UPDATE procedure_execution_log
            SET step_status = 'SUCCESS', rows_processed = :row_count, run_date = CURRENT_TIMESTAMP()
            WHERE run_id = :current_run_id AND step_id = :step_num; 
        COMMIT;
    
        EXCEPTION
            WHEN OTHER THEN
                ROLLBACK;
                INSERT INTO procedure_execution_log
                    (run_id, parent_run_id, retry_count, procedure_name, procedure_status,
                     step_id, step_name, step_status, rows_processed, status_reason, run_date)
                VALUES
                    (:current_run_id, NULL, 0, :proc_name, 'FAILED',
                     :step_num, 'INSERT cdr_target', 'FAILED', 0, SQLERRM, CURRENT_TIMESTAMP());
                RAISE;
    END;

    BEGIN
        step_num := step_num + 1;
    
        BEGIN TRANSACTION;
            INSERT INTO procedure_execution_log
                (run_id, parent_run_id, retry_count, procedure_name, procedure_status,
                 step_id, step_name, step_status, rows_processed, status_reason, run_date)
            VALUES
                (:current_run_id, NULL, 0, :proc_name, 'INPROGRESS',
                 :step_num, 'UPDATE customer_summary', 'RUNNING', NULL, NULL, CURRENT_TIMESTAMP());
    
            UPDATE customer_summary
            SET total_calls = total_calls + 1
            WHERE customer_id IN (SELECT customer_id FROM cdr_stage);
            row_count := SQLROWCOUNT;
            step_2_msg := 'Updated ' || row_count || ' rows in customer_summary.';
    
            UPDATE procedure_execution_log
            SET step_status = 'SUCCESS', rows_processed = :row_count,
                procedure_status = 'SUCCESS', run_date = CURRENT_TIMESTAMP()
            WHERE run_id = :current_run_id AND step_id = :step_num;
        COMMIT;
    
        RETURN step_1_msg || ' ' || step_2_msg;
        
        EXCEPTION
            WHEN OTHER THEN
                ROLLBACK;
                INSERT INTO procedure_execution_log
                    (run_id, parent_run_id, retry_count, procedure_name, procedure_status,
                     step_id, step_name, step_status, rows_processed, status_reason, run_date)
                VALUES
                    (:current_run_id, NULL, 0, :proc_name, 'FAILED',
                     :step_num, 'UPDATE customer_summary', 'FAILED', 0, SQLERRM, CURRENT_TIMESTAMP());
                RAISE;
    END;
END;
$$;