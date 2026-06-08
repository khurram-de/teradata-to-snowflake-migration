CREATE OR REPLACE PROCEDURE multi_step_transaction()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE 
    step_1_return_msg STRING;
    step_2_return_msg STRING;
BEGIN
    BEGIN TRANSACTION;
        INSERT INTO cdr_target
            SELECT * FROM cdr_stage;
        
        COMMIT;
        step_1_return_msg := 'Populated staging table.';
    EXCEPTION
        WHEN OTHER THEN
            ROLLBACK;
            RAISE;
    
    BEGIN TRANSACTION;
        UPDATE customer_summary
        SET total_calls = total_calls + 1
            WHERE customer_id IN (
                SELECT customer_id FROM cdr_stage 
            );
        COMMIT;
        step_2_return_msg := 'Updated customer Call count.';

        RETURN step_1_return_msg || ' ' || step_2_return_msg

    EXCEPTION
        WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END
$$
