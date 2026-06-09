CREATE OR REPLACE PROCEDURE multi_step_transaction()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE 
    step_1_return_msg STRING;
    step_2_return_msg STRING;
BEGIN
    BEGIN
        BEGIN TRANSACTION;
            INSERT INTO cdr_target
                SELECT * FROM cdr_stage;
            step_1_return_msg := 'Populated staging table.';
            COMMIT;
        EXCEPTION
            WHEN OTHER THEN
                ROLLBACK;
                RAISE;
    END;
    BEGIN
        BEGIN TRANSACTION;
            UPDATE customer_summary
            SET total_calls = total_calls + 1
                WHERE customer_id IN (
                    SELECT customer_id FROM cdr_stage 
                );
            step_2_return_msg := 'Updated customer Call count.';
            COMMIT;
        EXCEPTION
            WHEN OTHER THEN
            ROLLBACK;
            RAISE;
    END;
    RETURN step_1_return_msg || ' ' || step_2_return_msg;
END;
$$
