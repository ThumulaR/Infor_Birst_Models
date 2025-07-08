SELECT 
    FORMAT(Cal_Date_, 'MM-yyyy') 'DatePart',
	Cal_Date_ 'Cal_Date',
	sum(Inbound_)/1000000 'Inbound',
	sum(Outbound_)/1000000 'Outbound',
	sum(Storage_)/1000000 'Storage',
	sum(ChRate_) 'ChRate'
FROM 
(
SELECT
     CAST(DATEADD(minute, 30, DATEADD(hour, 5, c.CHARGE_DATE)) AS DATE) AS Cal_Date_,
     c.CHARGE_QTY 'Inbound_',
     0 'Outbound_',
     0 'Storage_',
	 0 'ChRate_'
    FROM BILLADMIN.BIC_CHARGE c
    INNER JOIN BILLADMIN.BIC_CHARGE_CODE CHG_CODE 
        ON c.CHARGE_CODE = CHG_CODE.CHARGE_CODE
    WHERE c.CHARGE_CODE = 'SIN-N-INBHN'
	AND c.DELETE_FLAG = 0
UNION
SELECT
        CAST(DATEADD(minute, 30, DATEADD(hour, 5, c.CHARGE_DATE)) AS DATE) AS Cal_Date_,
        0 'Inbound_',
        c.CHARGE_QTY 'Outbound_',
        0 'Storage_',
		0 'ChRate_'
    FROM BILLADMIN.BIC_CHARGE c
    INNER JOIN BILLADMIN.BIC_CHARGE_CODE CHG_CODE 
        ON c.CHARGE_CODE = CHG_CODE.CHARGE_CODE
    WHERE c.CHARGE_CODE = 'SIN-N-OUTHN'
	AND c.DELETE_FLAG = 0
UNION 
SELECT
        CAST(DATEADD(minute, 30, DATEADD(hour, 5, c.CHARGE_DATE)) AS DATE) AS Cal_Date_,
        0 'Inbound_',
        0 'Outbound_',
        c.CHARGE_QTY 'Storage_',
		0 'ChRate_'
    FROM BILLADMIN.BIC_CHARGE c
    INNER JOIN BILLADMIN.BIC_CHARGE_CODE CHG_CODE 
        ON c.CHARGE_CODE = CHG_CODE.CHARGE_CODE
    WHERE c.CHARGE_CODE = 'SIN-N-ST'
	AND c.DELETE_FLAG = 0
)  Summary
group by Cal_Date_