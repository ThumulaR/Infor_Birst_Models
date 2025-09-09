SELECT
	Final.DatePart,
	Final.Cal_Date,
	SUM(Final.Inbound_Rolls) AS Inbound_Rolls,
	SUM(Final.Outbound_Rolls) AS Outbound_Rolls,
	SUM(Final.Cut_Rolls) AS Cut_Rolls
	
FROM 
(
--Inbound
SELECT 
	FORMAT(CAST(DATEADD(minute, 30, DATEADD(hour, 5, r.EFFECTIVEDATE)) AS DATE), 'MM-yyyy') AS DatePart,
    CAST(DATEADD(minute, 30, DATEADD(hour, 5, r.EFFECTIVEDATE)) AS DATE) Cal_Date, 
	COUNT(rd.QTYRECEIVED) AS Inbound_Rolls,
	0 AS Outbound_Rolls,
	0 AS Cut_Rolls
	
FROM V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.receipt r 
INNER JOIN 
    V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.receiptdetail rd
    ON rd.RECEIPTKEY = r.RECEIPTKEY
INNER JOIN 
	V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.codelkup code
	ON 	code.CODE = r.STATUS
	AND code.listname = 'RECSTATUS'
WHERE 
    r.STORERKEY = 'INQUBE-FABRICS' 
    AND rd.QTYRECEIVED > 0
	AND r.TYPE != '47'
GROUP by CAST(DATEADD(minute, 30, DATEADD(hour, 5, r.EFFECTIVEDATE)) AS DATE)

UNION ALL

--Outbound
Select 
	FORMAT(outboundSum.date, 'MM-yyyy') AS DatePart,
	outboundSum.Date AS EffectiveDate,
	0 AS Inbound_Rolls,
	SUM(outboundSum.SKU_Count) AS Outbound_Rolls,
	0 AS Cut_Rolls
from 
(
	SELECT	
		WaveOrder.date,
		WaveOrder.wavekey,COUNT(DISTINCT WaveOrder.sku) AS SKU_Count

	FROM
	(
		SELECT	
			waveData.date,	
			waveData.wavekey,
			waveData.orderkey AS wave_orderkey,
			orderData.sku,	
			orderData.orderkey AS order_orderkey,
			orderData.orderlinenumber,
			orderData.shippedqty,
			orderData.effectivedate
		FROM
		(
			SELECT CAST(DATEADD(minute, 30, DATEADD(hour, 5, w.ext_udf_date1 )) AS DATE) AS date,w.wavekey,w.batchordernumber,wd.orderkey
			FROM V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.wave w
			INNER JOIN V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.wavedetail wd	ON w.wavekey = wd.wavekey
			WHERE 
				w.batchordernumber <> ''
				AND w.ext_udf_date1 IS NOT NULL
				AND w.batchordernumber IS NOT NULL
		)waveData	
		
		INNER JOIN (
			SELECT od.sku,od.orderkey,od.orderlinenumber,od.shippedqty,o.effectivedate
				FROM V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.orders o
				INNER JOIN V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.orderdetail od ON o.orderkey = od.orderkey
				WHERE od.storerkey = 'INQUBE-FABRICS'
					AND o."type" != '47'
					AND od.status IN ('16', '95')
					--AND CAST(DATEADD(minute, 30, DATEADD(hour, 5, o.effectivedate )) AS DATE) = '2025-05-09'
		)orderData ON waveData.orderkey = orderData.orderkey
	)WaveOrder

	INNER JOIN(
		SELECT i.sku, i.sourcekey
		FROM V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.itrn i
		WHERE i.trantype = 'WD'
	)itrn ON WaveOrder.sku = itrn.sku AND itrn.sourcekey =  WaveOrder.order_orderkey + CAST(WaveOrder.orderlinenumber AS VARCHAR)

	GROUP BY WaveOrder.wavekey,WaveOrder.date
)outboundSum
Group by outboundSum.Date

UNION ALL

--Cut rolles
SELECT 
	FORMAT(CAST(DATEADD(minute, 30, DATEADD(hour, 5, w.ext_udf_date1)) AS DATE), 'MM-yyyy') AS DatePart,
	CAST(DATEADD(minute, 30, DATEADD(hour, 5, w.ext_udf_date1)) AS DATE) AS Cal_Date,
	0 AS Inbound_Rolls,
	0 AS Outbound_Rolls,
	COUNT(p.cartontype) AS Cut_Rolls
	
FROM V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.wave w
LEFT JOIN V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.pickdetail p 
	ON w.wavekey = p.wavekey AND p.cartontype = 'SPLIT'
WHERE 
	w.ext_udf_date1 IS NOT NULL
GROUP BY CAST(DATEADD(minute, 30, DATEADD(hour, 5, w.ext_udf_date1)) AS DATE)

) AS Final
WHERE Final.DatePart = '06-2025'
GROUP BY DatePart, Cal_Date
