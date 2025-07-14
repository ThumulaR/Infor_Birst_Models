SELECT 
    FORMAT(Cal_Date_, 'MM-yyyy') AS DatePart,
    Cal_Date_,
    SUM(Inbound_) / 1000000 AS Inbound,
    SUM(Outbound_) / 1000000 AS Outbound,
    SUM(Storage_) / 1000000 AS Storage,
    SUM(ChRate_) AS ChRate
FROM (
    SELECT 
        CAST(DATEADD(minute, 30, DATEADD(hour, 5, c.CHARGE_DATE)) AS DATE) AS Cal_Date_,
        SUM(c.CHARGE_QTY) AS Inbound_,
        0 AS Outbound_,
        0 AS Storage_,
        0 AS ChRate_
    FROM BILLADMIN.BIC_CHARGE_CODE CHG_CODE
    LEFT JOIN BILLADMIN.BIC_CHARGE c ON CHG_CODE.CHARGE_CODE = c.CHARGE_CODE
    WHERE c.CHARGE_CODE = 'SIN-N-INBHN'
      AND c.DELETE_FLAG = 0
    GROUP BY CAST(DATEADD(minute, 30, DATEADD(hour, 5, c.CHARGE_DATE)) AS DATE)

    UNION ALL

    SELECT 
        CAST(DATEADD(minute, 30, DATEADD(hour, 5, c.CHARGE_DATE)) AS DATE) AS Cal_Date_,
        0 AS Inbound_,
        SUM(c.CHARGE_QTY) AS Outbound_,
        0 AS Storage_,
        0 AS ChRate_
    FROM BILLADMIN.BIC_CHARGE_CODE CHG_CODE
    LEFT JOIN BILLADMIN.BIC_CHARGE c ON CHG_CODE.CHARGE_CODE = c.CHARGE_CODE
    WHERE c.CHARGE_CODE = 'SIN-N-OUTHN'
      AND c.DELETE_FLAG = 0
    GROUP BY CAST(DATEADD(minute, 30, DATEADD(hour, 5, c.CHARGE_DATE)) AS DATE)

    UNION ALL

    SELECT 
        CAST(DATEADD(minute, 30, DATEADD(hour, 5, DATEADD(DAY, -1, c.CHARGE_DATE))) AS DATE) AS Cal_Date_,
        0 AS Inbound_,
        0 AS Outbound_,
        SUM(c.CHARGE_QTY) AS Storage_,
        0 AS ChRate_
    FROM BILLADMIN.BIC_CHARGE_CODE CHG_CODE
    LEFT JOIN BILLADMIN.BIC_CHARGE c ON CHG_CODE.CHARGE_CODE = c.CHARGE_CODE
    WHERE c.CHARGE_CODE = 'SIN-N-ST'
      AND c.DELETE_FLAG = 0
    GROUP BY CAST(DATEADD(minute, 30, DATEADD(hour, 5, DATEADD(DAY, -1, c.CHARGE_DATE))) AS DATE)
) Summary
GROUP BY Cal_Date_