#!/bin/bash
START_DATE="2024-01-01"
END_DATE="2024-01-31"
CURRENT_DATE=$START_DATE

while [ "$CURRENT_DATE" != "$END_DATE" ]; do
    bteq << EOF
    .LOGON tdprod/myuser,mypassword;
    
    INSERT INTO customer_target
    SELECT * FROM customer_stage
    WHERE event_date = '${CURRENT_DATE}';
    
    .IF ERRORCODE <> 0 THEN .GOTO ERROREXIT;
    
    .QUIT 0;
    
    .LABEL ERROREXIT
    .QUIT 12;
EOF
    CURRENT_DATE=$(date -d "$CURRENT_DATE + 1 day" +%Y-%m-%d)
done