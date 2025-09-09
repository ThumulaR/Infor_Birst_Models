SELECT
    dd.DatePart,
    dd.Cal_Date,
    dd.Inbound_Rolls,
    dd.Outbound_Rolls,
    dd.Cut_Rolls,
    COALESCE(dd.Month_Opening, 0) 
      + COALESCE(SUM(dd.Net_Change) 
          OVER (
            PARTITION BY dd.DatePart
            ORDER BY dd.Cal_Date
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
          ), 0) AS Opening_Balance,
    COALESCE(dd.Month_Opening, 0) 
      + COALESCE(SUM(dd.Net_Change) 
          OVER (
            PARTITION BY dd.DatePart
            ORDER BY dd.Cal_Date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
          ), 0) AS Closing_Balance
FROM
(
    /* Aggregate daily facts + month opening + net change (no CTEs) */
    SELECT
        Final.DatePart,
        Final.Cal_Date,
        SUM(Final.Inbound_Rolls)   AS Inbound_Rolls,
        SUM(Final.Outbound_Rolls)  AS Outbound_Rolls,
        SUM(Final.Cut_Rolls)       AS Cut_Rolls,
        MAX(Init.charge_qty)       AS Month_Opening,
        SUM(Final.Inbound_Rolls) - SUM(Final.Outbound_Rolls) + SUM(Final.Cut_Rolls) AS Net_Change
    FROM
    (
        /* ===== Inbound ===== */
        SELECT 
            FORMAT(CAST(DATEADD(minute, 30, DATEADD(hour, 5, r.EFFECTIVEDATE)) AS DATE), 'MM-yyyy') AS DatePart,
            CAST(DATEADD(minute, 30, DATEADD(hour, 5, r.EFFECTIVEDATE)) AS DATE)              AS Cal_Date, 
            COUNT(rd.QTYRECEIVED) AS Inbound_Rolls,
            0                     AS Outbound_Rolls,
            0                     AS Cut_Rolls
        FROM V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.receipt r 
        INNER JOIN V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.receiptdetail rd
            ON rd.RECEIPTKEY = r.RECEIPTKEY
        INNER JOIN V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.codelkup code
            ON code.CODE = r.STATUS
           AND code.listname = 'RECSTATUS'
        WHERE r.STORERKEY = 'INQUBE-FABRICS' 
          AND rd.QTYRECEIVED > 0
          AND r.TYPE <> '47'
        GROUP BY CAST(DATEADD(minute, 30, DATEADD(hour, 5, r.EFFECTIVEDATE)) AS DATE)

        UNION ALL

        /* ===== Outbound ===== */
        SELECT
            FORMAT(outboundSum.[date], 'MM-yyyy') AS DatePart,
            outboundSum.[date]                    AS Cal_Date,
            0                                     AS Inbound_Rolls,
            SUM(outboundSum.SKU_Count)            AS Outbound_Rolls,
            0                                     AS Cut_Rolls
        FROM
        (
            SELECT WaveOrder.[date],
                   WaveOrder.wavekey,
                   COUNT(DISTINCT WaveOrder.sku) AS SKU_Count
            FROM
            (
                SELECT
                    waveData.[date],
                    waveData.wavekey,
                    waveData.orderkey         AS wave_orderkey,
                    orderData.sku,
                    orderData.orderkey        AS order_orderkey,
                    orderData.orderlinenumber,
                    orderData.shippedqty,
                    orderData.effectivedate
                FROM
                (
                    SELECT CAST(DATEADD(minute, 30, DATEADD(hour, 5, w.ext_udf_date1)) AS DATE) AS [date],
                           w.wavekey,
                           w.batchordernumber,
                           wd.orderkey
                    FROM V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.wave w
                    INNER JOIN V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.wavedetail wd
                        ON w.wavekey = wd.wavekey
                    WHERE w.batchordernumber <> ''
                      AND w.ext_udf_date1 IS NOT NULL
                      AND w.batchordernumber IS NOT NULL
                ) waveData
                INNER JOIN (
                    SELECT od.sku,
                           od.orderkey,
                           od.orderlinenumber,
                           od.shippedqty,
                           o.effectivedate
                    FROM V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.orders o
                    INNER JOIN V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.orderdetail od
                        ON o.orderkey = od.orderkey
                    WHERE od.storerkey = 'INQUBE-FABRICS'
                      AND o.[type] <> '47'
                      AND od.status IN ('16','95')
                ) orderData
                    ON waveData.orderkey = orderData.orderkey
            ) WaveOrder
            INNER JOIN (
                SELECT i.sku, i.sourcekey
                FROM V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.itrn i
                WHERE i.trantype = 'WD'
            ) itrn
                ON WaveOrder.sku = itrn.sku
               AND itrn.sourcekey = WaveOrder.order_orderkey + CAST(WaveOrder.orderlinenumber AS VARCHAR)
            GROUP BY WaveOrder.wavekey, WaveOrder.[date]
        ) outboundSum
        GROUP BY outboundSum.[date]

        UNION ALL

        /* ===== Cut Rolls ===== */
        SELECT 
            FORMAT(CAST(DATEADD(minute, 30, DATEADD(hour, 5, w.ext_udf_date1)) AS DATE), 'MM-yyyy') AS DatePart,
            CAST(DATEADD(minute, 30, DATEADD(hour, 5, w.ext_udf_date1)) AS DATE)                    AS Cal_Date,
            0 AS Inbound_Rolls,
            0 AS Outbound_Rolls,
            COUNT(p.cartontype) AS Cut_Rolls
        FROM V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.wave w
        LEFT JOIN V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.pickdetail p
               ON w.wavekey = p.wavekey
              AND p.cartontype = 'SPLIT'
        WHERE w.ext_udf_date1 IS NOT NULL
        GROUP BY CAST(DATEADD(minute, 30, DATEADD(hour, 5, w.ext_udf_date1)) AS DATE)
    ) AS Final
    LEFT JOIN
    (
        SELECT 
            FORMAT(charge_date, 'MM-yyyy') AS MonthYear,
            SUM(charge_qty)                AS charge_qty
        FROM BILLADMIN.BIC_CHARGE 
        WHERE charge_code = 'INQFAB-ST-OS'
        GROUP BY FORMAT(charge_date, 'MM-yyyy')
    ) AS Init
        ON Final.DatePart = Init.MonthYear
    WHERE Final.DatePart = '07-2025'   /* <<-- parameterize this in Birst if required */
    GROUP BY Final.DatePart, Final.Cal_Date
) dd
