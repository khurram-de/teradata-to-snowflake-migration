CREATE OR REPLACE PROCEDURE load_customer_data()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    row_count INTEGER;
BEGIN
    INSERT INTO customer_target
    SELECT * FROM customer_stage;
    row_count := SQLROWCOUNT;
    RETURN 'Loaded ' || row_count || ' rows into customer_data table.';
EXCEPTION
    WHEN OTHERS THEN
        RETURN 'Error loading data: ' || SQLERRM;
        RAISE;
END;
$$;