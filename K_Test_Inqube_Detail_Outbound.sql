SELECT
	FORMAT(WaveOrder.date, 'MM-yyyy') AS DatePart,
	WaveOrder.date AS TransactionDate,
	WaveOrder.wavekey,
	WaveOrder.sku,
	---------------------------------------------------
	MAX(WaveOrder.batchordernumber) AS batchordernumber,
	MAX(WaveOrder.descr) AS wave_description,
	MAX(WaveOrder.ext_udf_date1) AS Wave_Transaction_Override_Date,
	MAX(WaveOrder.w_status) AS Wave_Status,
	MAX(WaveOrder.ext_udf_str1) AS Wave_Maintenance_Text_UDF_1,
	MAX(WaveOrder.ext_udf_str2) AS Wave_Maintenance_Text_UDF_2,
	MAX(WaveOrder.ext_udf_str3) AS Wave_Maintenance_Text_UDF_3,
	SUM(WaveOrder.shippedqty) AS Shippedqty,
	MAX(WaveOrder.effectivedate) AS Effectivedate,
	MAX(WaveOrder.storerkey) AS Storerkey,
	MAX(WaveOrder.o_status) AS Order_Status,
	SUM(WaveOrder.originalqty) AS Quantity,
	MAX(WaveOrder.type) AS Type,
	MAX(itrn.toid) AS LPN
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
		orderData.effectivedate,
		-----------------------------
		waveData.batchordernumber,
		waveData.descr,
		waveData.ext_udf_date1,
		waveData.status AS w_status,
		waveData.ext_udf_str1,
		waveData.ext_udf_str2,
		waveData.ext_udf_str3,
		orderData.storerkey,
		orderData.status AS o_status,
		orderData.originalqty,
		orderData.type
	FROM
	(
		SELECT 
			CAST(DATEADD(minute, 30, DATEADD(hour, 5, w.ext_udf_date1 )) AS DATE) AS date,
			w.wavekey,
			w.batchordernumber,
			wd.orderkey,
			------------
			w.descr,
			w.ext_udf_date1,
			w.status,
			w.ext_udf_str1,
			w.ext_udf_str2,
			w.ext_udf_str3
		FROM V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.wave w
		INNER JOIN V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.wavedetail wd	ON w.wavekey = wd.wavekey
		WHERE 
			w.batchordernumber <> ''
			AND w.ext_udf_date1 IS NOT NULL
			AND w.batchordernumber IS NOT NULL
	)waveData	
	
	INNER JOIN (
		SELECT 
			od.sku,
			od.orderkey,
			od.orderlinenumber,
			od.shippedqty,
			o.effectivedate,
			---------------------
			od.storerkey,
			od.status,
			od.originalqty,
			o.type
		FROM V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.orders o
		INNER JOIN V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.orderdetail od ON o.orderkey = od.orderkey
		WHERE od.storerkey = 'INQUBE-FABRICS'
			AND o."type" != '47'
			AND od.status IN ('16', '95')
	)orderData 
		ON waveData.orderkey = orderData.orderkey
)WaveOrder

INNER JOIN(
	SELECT 
		i.sku, 
		i.sourcekey,
		i.toid
	FROM V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.itrn i
	WHERE i.trantype = 'WD'
)itrn 
	ON WaveOrder.sku = itrn.sku 
	AND itrn.sourcekey =  WaveOrder.order_orderkey + CAST(WaveOrder.orderlinenumber AS VARCHAR)

GROUP BY 
	WaveOrder.date,
	WaveOrder.wavekey,
	WaveOrder.sku
