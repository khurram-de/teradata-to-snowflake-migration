CREATE OR REPLACE PROCEDURE dynamic_sql_example(start_date DATE, end_date DATE)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    sql_command STRING;
    initiation_date DATE;
    total_rows INTEGER := 0;
BEGIN
    initiation_date := start_date;
    
    while(initiation_date <= end_date) DO
        sql_command := 'INSERT INTO customer_target
        SELECT * FROM customer_stage
        WHERE event_date =''' ||initiation_date||''';';
        EXECUTE IMMEDIATE sql_command;
        total_rows := total_rows + SQLROWCOUNT;
        initiation_date := DATEADD(DAY, 1, initiation_date);
        END WHILE;
    RETURN 'Inserted ' || total_rows || ' into customer_target tbl';
EXCEPTION
    WHEN OTHER THEN
        RAISE;
END;
$$