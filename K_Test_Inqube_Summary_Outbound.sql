

SELECT 
	Final.date,
	SUM(Final.SKU_Count) AS count
FROM
(
SELECT	
	WaveOrder.date,
	WaveOrder.wavekey,COUNT(DISTINCT WaveOrder.sku) AS SKU_Count
--	WaveOrder.wave_orderkey,
--	COUNT(DISTINCT WaveOrder.sku)
--	WaveOrder.sku AS wave_sku,
--	WaveOrder.order_orderkey,
--	WaveOrder.orderlinenumber,
--	itrn.sku AS itran_sku,
--	SUM(WaveOrder.shippedqty)
--	WaveOrder.effectivedate
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
		WHERE w.whseid = 'wmwhse2' 
			AND w.batchordernumber <> ''
			AND w.ext_udf_date1 IS NOT NULL
			AND w.batchordernumber IS NOT NULL
			AND CAST(DATEADD(minute, 30, DATEADD(hour, 5, w.ext_udf_date1 )) AS DATE) between '2025-05-01' and '2025-05-31' 
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
)Final
GROUP BY Final.date
--ORDER BY Final.date
