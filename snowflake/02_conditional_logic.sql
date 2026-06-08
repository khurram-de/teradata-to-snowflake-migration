CREATE OR REPLACE PROCEDURE conditional_logic_example()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    row_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO row_count FROM customer_stage;
    IF (row_count = 0) THEN
        RETURN 'No data to load';
    ELSEIF (row_count > 1000000) THEN
        RETURN 'Source too large, aborting';
    ELSE 
        INSERT INTO customer_data SELECT * FROM customer_stage;
        RETURN 'Inserted ' || SQLROWCOUNT || ' into customer_data'
    END IF;
EXCEPTION 
    WHEN OTHER THEN
        RAISE;
END;
$$