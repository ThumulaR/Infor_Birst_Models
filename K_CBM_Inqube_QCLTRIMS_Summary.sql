SELECT 
    Final.Overide_Date,
    Final.MonthYear,
    Final.Inbound_CBM,
    Final.Outbound_CBM,
    Final.day_dif,
    ISNULL(Init.charge_qty, 0) AS init_qty,
    
    ISNULL(Init.charge_qty, 0) + 
        SUM(Final.day_dif) OVER (
            PARTITION BY Final.MonthYear 
            ORDER BY Final.Overide_Date 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS Closing_CBM

FROM (
    SELECT 
        Combined.Overide_Date,
        FORMAT(Combined.Overide_Date, 'MM-yyyy') AS MonthYear,
        SUM(Combined.Inbound_CBM) AS Inbound_CBM,
        SUM(Combined.Outbound_CBM) AS Outbound_CBM,
        SUM(Combined.Inbound_CBM - Combined.Outbound_CBM) AS day_dif
    FROM (
        -- Inbound
        SELECT 
            CAST(DATEADD(minute, 30, DATEADD(hour, 5, rd.effectivedate)) AS DATE) AS Overide_Date,
            ROUND(SUM(
                CASE
                    WHEN rd.lottable01 LIKE '%NO PACK%' THEN 0 
                    WHEN SUBSTRING(rd.lottable06, 4, 6) LIKE '%BRL%' THEN p.cube * rd.qtyreceived
                    ELSE p.cube
                END
            ), 4) AS Inbound_CBM,
            0 AS Outbound_CBM
        FROM V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.receipt r  
        LEFT JOIN V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.receiptdetail rd 
            ON r.receiptkey = rd.receiptkey
        LEFT JOIN V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.pack p 
            ON rd.lottable01 = p.packkey 
        WHERE 
            rd.qtyreceived > 0 
            AND rd.effectivedate IS NOT NULL
            AND (r.storerkey = 'INQUBE-QCLTRIMS' AND rd.lottable06 NOT LIKE '%QCLRTN%')
        GROUP BY CAST(DATEADD(minute, 30, DATEADD(hour, 5, rd.effectivedate)) AS DATE)

        UNION ALL

        -- Outbound
        SELECT
            CAST(DATEADD(minute, 30, DATEADD(hour, 5, od.effectivedate)) AS DATE) AS Overide_Date,
            0 AS Inbound_CBM,
            ROUND(SUM(
                CASE
                    WHEN la.lottable01 LIKE '%NO PACK%' THEN 0 
                    WHEN SUBSTRING(la.lottable06, 4, 6) LIKE '%BRL%' THEN p.cube * od.shippedqty
                    ELSE p.cube
                END
            ), 4) AS Outbound_CBM
        FROM V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.orders o
        LEFT JOIN V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.orderdetail od 
            ON o.orderkey = od.orderkey
        LEFT JOIN V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.lotattribute la 
            ON od.sku = la.sku AND od.lottable03 = la.lottable03
        LEFT JOIN V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.pack p 
            ON la.lottable01 = p.packkey AND la.whseid = p.whseid
        WHERE 
            od.status = 95
            AND od.effectivedate IS NOT NULL
            AND (o.storerkey = 'INQUBE-QCLTRIMS' AND la.lottable06 NOT LIKE '%QCLRTN%')
        GROUP BY CAST(DATEADD(minute, 30, DATEADD(hour, 5, od.effectivedate)) AS DATE)
    ) AS Combined
    GROUP BY Combined.Overide_Date
) AS Final

LEFT JOIN (
    SELECT 
        FORMAT(charge_date, 'MM-yyyy') AS MonthYear,
        SUM(charge_qty) AS charge_qty
    FROM BILLADMIN.BIC_CHARGE 
    WHERE charge_code = 'INQTRIMOB' 
      AND bill_to = 'INQUBE-QCLTRIMS'
    GROUP BY FORMAT(charge_date, 'MM-yyyy')
) AS Init ON Final.MonthYear = Init.MonthYear