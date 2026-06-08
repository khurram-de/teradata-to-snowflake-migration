CREATE OR REPLACE PROCEDURE dynamic_sql_example(start_date DATE, end_date DATE)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    sql_command STRING;
    initiation_date DATE;
BEGIN
    initiation_date := start_date;
    
    while(initiation_date <= end_date) DO
        INSERT INTO customer_target
        SELECT * FROM customer_stage
        WHERE event_date = '${initiation_date}';
        DATEADD(DAY, 1, initiation_date);
        END WHILE;

EXCEPTION
    WHEN OTHER THEN
        RAISE
END;
$$