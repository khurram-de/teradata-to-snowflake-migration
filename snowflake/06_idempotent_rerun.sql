
CREATE OR REPLACE PROCEDURE load_cdr_pipeline_v3(force_rerun BOOLEAN)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    current_run_id      STRING := UUID_STRING();
    parent_run_id       STRING := NULL;
    retry_count         INTEGER := 0;
    proc_name           STRING := 'load_cdr_pipeline_v3';
    resume_from_step    INTEGER := 0;
    step_num            INTEGER := 0;
    row_count           INTEGER;
    err_msg             STRING;
    step_1_msg          STRING := 'Step 1 skipped.';
    step_2_msg          STRING := 'Step 2 skipped.';
BEGIN

    BEGIN
        IF (NOT force_rerun) THEN
        
            -- check what the last run status was regardless of outcome
            LET last_status STRING;
            LET last_run_id STRING;
            LET current_retry_count INTEGER;
        
            SELECT run_id, procedure_status
            INTO :last_run_id, :last_status
            FROM procedure_execution_log
            WHERE procedure_name = :proc_name
            ORDER BY run_date DESC
            LIMIT 1;
        
            -- only attempt resume if last run was actually failed
            IF (:last_status IN ('FAILED', 'INPROGRESS')) THEN
        
                parent_run_id := :last_run_id;
        
                SELECT 
                    CASE 
                        WHEN MAX(step_status) = 'SUCCESS' THEN MAX(step_id) + 1
                        ELSE MAX(step_id)
                    END,
                    MAX(retry_count)
                INTO :resume_from_step, :current_retry_count
                FROM procedure_execution_log
                WHERE run_id = :parent_run_id
                AND run_date = (
                    SELECT MAX(run_date) 
                    FROM procedure_execution_log 
                    WHERE run_id = :parent_run_id
                );
        
                retry_count := :current_retry_count + 1;
        
            END IF;
        
        END IF;
    END;

    BEGIN
        step_num := :step_num + 1;

        IF (:step_num >= :resume_from_step) THEN

            BEGIN TRANSACTION;
                INSERT INTO procedure_execution_log
                    (run_id, parent_run_id, retry_count, procedure_name, procedure_status,
                     step_id, step_name, step_status, rows_processed, status_reason, run_date)
                VALUES
                    (:current_run_id, :parent_run_id, :retry_count, :proc_name, 'INPROGRESS',
                     :step_num, 'INSERT cdr_target', 'RUNNING', NULL, NULL, CURRENT_TIMESTAMP());

                INSERT INTO cdr_target SELECT * FROM cdr_stage;
                row_count := SQLROWCOUNT;
                step_1_msg := 'Inserted ' || :row_count || ' rows into cdr_target.';

                UPDATE procedure_execution_log
                SET step_status = 'SUCCESS', rows_processed = :row_count, run_date = CURRENT_TIMESTAMP()
                WHERE run_id = :current_run_id AND step_id = :step_num;
            COMMIT;

        END IF;

    EXCEPTION
        WHEN OTHER THEN
            err_msg := SQLERRM;
            ROLLBACK;
            INSERT INTO procedure_execution_log
                (run_id, parent_run_id, retry_count, procedure_name, procedure_status,
                 step_id, step_name, step_status, rows_processed, status_reason, run_date)
            VALUES
                (:current_run_id, :parent_run_id, :retry_count, :proc_name, 'FAILED',
                 :step_num, 'INSERT cdr_target', 'FAILED', 0, :err_msg, CURRENT_TIMESTAMP());
            RAISE;
    END;

    BEGIN
        step_num := :step_num + 1;

        IF (:step_num >= :resume_from_step) THEN

            BEGIN TRANSACTION;
                INSERT INTO procedure_execution_log
                    (run_id, parent_run_id, retry_count, procedure_name, procedure_status,
                     step_id, step_name, step_status, rows_processed, status_reason, run_date)
                VALUES
                    (:current_run_id, :parent_run_id, :retry_count, :proc_name, 'INPROGRESS',
                     :step_num, 'UPDATE customer_summary', 'RUNNING', NULL, NULL, CURRENT_TIMESTAMP());

                UPDATE customer_summary
                SET total_calls = total_calls + 1
                WHERE customer_id IN (SELECT customer_id FROM cdr_stage);
                row_count := SQLROWCOUNT;
                step_2_msg := 'Updated ' || :row_count || ' rows in customer_summary.';

                UPDATE procedure_execution_log
                SET step_status = 'SUCCESS', rows_processed = :row_count,
                    procedure_status = 'SUCCESS', run_date = CURRENT_TIMESTAMP()
                WHERE run_id = :current_run_id AND step_id = :step_num;
            COMMIT;

        END IF;

        RETURN :step_1_msg || ' ' || :step_2_msg;

    EXCEPTION
        WHEN OTHER THEN
            err_msg := SQLERRM;
            ROLLBACK;
            INSERT INTO procedure_execution_log
                (run_id, parent_run_id, retry_count, procedure_name, procedure_status,
                 step_id, step_name, step_status, rows_processed, status_reason, run_date)
            VALUES
                (:current_run_id, :parent_run_id, :retry_count, :proc_name, 'FAILED',
                 :step_num, 'UPDATE customer_summary', 'FAILED', 0, :err_msg, CURRENT_TIMESTAMP());
            RAISE;
    END;

END;
$$;