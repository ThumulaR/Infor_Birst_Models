SELECT 
summary.DatePart,
sum(summary.Inbound_Rolls ) AS  Inbound, 
sum(summary.Outbound_Rolls ) AS Outbound,
sum(summary.Weight ) AS Weight,
sum(summary.Width ) AS Width,
sum(summary.One_Yrd) AS InboundYardCut1,
sum(summary.Additional_One_Yrd) AS InboundYardCut2,
sum(summary.Cut_Rolls) AS CutRolls,
sum(summary.Swatch) AS Swatch,
sum(summary.Additional_Swatch) AS AdditionalSwatch,
sum(summary.Additional_Roll) AS AdditionalRoll,
sum(summary.Recurring_Storage ) AS Storage



FROM
(
	SELECT 
		CombinedData.DatePart, 
		CombinedData.Cal_Date, 
		SUM(CombinedData.Swatch) AS Swatch, 
		SUM(CombinedData.Weight) AS Weight, 
		SUM(CombinedData.Width) AS Width, 
		SUM(CombinedData.One_Yrd) AS One_Yrd, 
		SUM(CombinedData.Inbound_Rolls) AS Inbound_Rolls, 
		SUM(CombinedData.Outbound_Rolls) AS Outbound_Rolls, 
		SUM(CombinedData.Cut_Rolls) AS Cut_Rolls, 
		SUM(CombinedData.Additional_Swatch) AS Additional_Swatch, 
		SUM(CombinedData.Additional_Roll) AS Additional_Roll, 
		SUM(CombinedData.Additional_One_Yrd) AS Additional_One_Yrd, 
		SUM(CombinedData.Fabric_Width_Measuring) AS Fabric_Width_Measuring, 
		SUM(CombinedData.Cross_Dock_Inbound) AS Cross_Dock_Inbound, 
		SUM(CombinedData.Cross_Dock_Outbound) AS Cross_Dock_Outbound, 
		SUM(CombinedData.Recurring_Storage) AS Recurring_Storage
	FROM (

	SELECT 
		FORMAT(CAST(DATEADD(minute, 30, DATEADD(hour, 5, r.EFFECTIVEDATE)) AS DATE), 'MM-yyyy') 'DatePart',
		CAST(DATEADD(minute, 30, DATEADD(hour, 5, r.EFFECTIVEDATE)) AS DATE) 'Cal_Date', 
		SUM(CAST(rd.EXT_UDF_LKUP2 AS INTEGER)) 'Swatch', 
		SUM(CAST(rd.EXT_UDF_LKUP3 AS INTEGER)) 'Weight', 
		SUM(CAST(rd.EXT_UDF_LKUP4 AS INTEGER)) 'Width', 
		SUM(CAST(rd.EXT_UDF_LKUP5 AS INTEGER)) 'One_Yrd',
		COUNT(rd.QTYRECEIVED) 'Inbound_Rolls',
		0 'Outbound_Rolls',
		0 'Cut_Rolls',
		0 'Additional_Swatch',
		0 'Additional_Roll',
		0 'Additional_One_Yrd',
		0 'Fabric_Width_Measuring',
		0 'Cross_Dock_Inbound',
		0 'Cross_Dock_Outbound',
		0 'Recurring_Storage'
		
		
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
	--AND FORMAT(CAST(DATEADD(minute, 30, DATEADD(hour, 5, r.EFFECTIVEDATE)) AS DATE), 'MM-yyyy')='04-2025'
	--AND CAST(DATEADD(minute, 30, DATEADD(hour, 5, r.EFFECTIVEDATE)) AS DATE) ='2025-04-10'
	GROUP by CAST(DATEADD(minute, 30, DATEADD(hour, 5, r.EFFECTIVEDATE)) AS DATE)

	UNION ALL

	Select 
		FORMAT(outboundSum.date, 'MM-yyyy') AS DatePart,
		outboundSum.Date AS EffectiveDate,
		0 'Swatch',
		0 'Weight',
		0 'Width',
		0 'One_Yrd',
		0 'Inbound_Rolls',
		SUM(outboundSum.SKU_Count) AS Outbound_Rolls,
		0 'Cut_Rolls',
		0 'Additional_Swatch',
		0 'Additional_Roll',
		0 'Additional_One_Yrd',
		0 'Fabric_Width_Measuring',
		0 'Cross_Dock_Inbound',
		0 'Cross_Dock_Outbound',
		0 'Recurring_Storage'
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

	SELECT 
		FORMAT(CAST(DATEADD(minute, 30, DATEADD(hour, 5, itrn.EFFECTIVEDATE)) AS DATE), 'MM-yyyy') 'DatePart',
		CAST(DATEADD(minute, 30, DATEADD(hour, 5, itrn.EFFECTIVEDATE)) AS DATE) 'Cal_Date',
		0 'Swatch',
		0 'Weight',
		0 'Width',
		0 'One_Yrd',
		0 'Inbound_Rolls',
		0 'Outbound_Rolls',
		0 'Cut_Rolls',
		count(itrn.QTY) 'Additional_Swatch',
		0 'Additional_Roll',
		0 'Additional_One_Yrd',
		0 'Fabric_Width_Measuring',
		0 'Cross_Dock_Inbound',
		0 'Cross_Dock_Outbound',
		0 'Recurring_Storage'
		FROM 
		V{=Replace(GetVariable('p_SCHEMA'), '\'', '')}.ITRN itrn
		WHERE 
		itrn.TRANTYPE = 'MV' and TOLOC='INQ-ADD-SWT'
	Group by CAST(DATEADD(minute, 30, DATEADD(hour, 5, itrn.EFFECTIVEDATE)) AS DATE)


	UNION ALL
		SELECT
		FORMAT(CAST(DATEADD(minute, 30, DATEADD(hour, 5, itrn.EFFECTIVEDATE)) AS DATE), 'MM-yyyy') 'DatePart',
		CAST(DATEADD(minute, 30, DATEADD(hour, 5, itrn.EFFECTIVEDATE)) AS DATE) 'Cal_Date',
		0 'Swatch',
		0 'Weight',
		0 'Width',
		0 'One_Yrd',
		0 'Inbound_Rolls',
		0 'Outbound_Rolls',
		0 'Cut_Rolls',
		0 'Additional_Swatch',
		count(itrn.QTY) 'Additional_Roll',
		0 'Additional_One_Yrd',
		0 'Fabric_Width_Measuring',
		0 'Cross_Dock_Inbound',
		0 'Cross_Dock_Outbound',
		0 'Recurring_Storage'
		FROM 
		V{=Replace(GetVariable('p_SCHEMA'), '\'', '')}.ITRN itrn
		WHERE 
		itrn.TRANTYPE = 'MV' and TOLOC='INQ-RE-INSP'
	Group by CAST(DATEADD(minute, 30, DATEADD(hour, 5, itrn.EFFECTIVEDATE)) AS DATE)


	UNION ALL
		SELECT
		FORMAT(CAST(DATEADD(minute, 30, DATEADD(hour, 5, itrn.EFFECTIVEDATE)) AS DATE), 'MM-yyyy') 'DatePart',
		CAST(DATEADD(minute, 30, DATEADD(hour, 5, itrn.EFFECTIVEDATE)) AS DATE) 'Cal_Date',
		0 'Swatch',
		0 'Weight',
		0 'Width',
		0 'One_Yrd',
		0 'Inbound_Rolls',
		0 'Outbound_Rolls',
		0 'Cut_Rolls',
		0 'Additional_Swatch',
		0 'Additional_Roll',
		count(itrn.QTY) 'Additional_One_Yrd',
		0 'Fabric_Width_Measuring',
		0 'Cross_Dock_Inbound',
		0 'Cross_Dock_Outbound',
		0 'Recurring_Storage'
		FROM 
		V{=Replace(GetVariable('p_SCHEMA'), '\'', '')}.ITRN itrn
		WHERE 
		itrn.TRANTYPE = 'MV' and TOLOC='INQ-ADD-1YD'
	Group by CAST(DATEADD(minute, 30, DATEADD(hour, 5, itrn.EFFECTIVEDATE)) AS DATE)

	UNION ALL

		SELECT
		FORMAT(CAST(DATEADD(minute, 30, DATEADD(hour, 5, r_.EFFECTIVEDATE)) AS DATE), 'MM-yyyy') 'DatePart',
		CAST(DATEADD(minute, 30, DATEADD(hour, 5, r_.EFFECTIVEDATE)) AS DATE) 'Cal_Date',
		0 'Swatch',
		0 'Weight',
		0 'Width',
		0 'One_Yrd',
		0 'Inbound_Rolls',
		0 'Outbound_Rolls',
		0 'Cut_Rolls',
		0 'Additional_Swatch',
		0 'Additional_Roll',
		0 'Additional_One_Yrd',
		count(rd_.EXT_UDF_LKUP4) 'Fabric_Width_Measuring',
		0 'Cross_Dock_Inbound',
		0 'Cross_Dock_Outbound',
		0 'Recurring_Storage'
		FROM 
		V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.receipt r_ ,
		V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.receiptdetail rd_
		where rd_.RECEIPTKEY = r_.RECEIPTKEY AND r_.STORERKEY = 'INQUBE-FABRICS'
		AND r_.RECEIPTKEY='INQINVBLUPMT'
		AND  rd_.EXT_UDF_LKUP4='Y'
		Group by CAST(DATEADD(minute, 30, DATEADD(hour, 5, r_.EFFECTIVEDATE)) AS DATE)

	UNION ALL
	Select 
		FORMAT(CAST(DATEADD(minute, 30, DATEADD(hour, 5, c.CHARGE_DATE)) AS DATE), 'MM-yyyy') 'DatePart',
		CAST(DATEADD(minute, 30, DATEADD(hour, 5, c.CHARGE_DATE)) AS DATE) 'Cal_Date',
		0 'Swatch',
		0 'Weight',
		0 'Width',
		0 'One_Yrd',
		0 'Inbound_Rolls',
		0 'Outbound_Rolls',
		0 'Cut_Rolls',
		0 'Additional_Swatch',
		0 'Additional_Roll',
		0 'Additional_One_Yrd',
		0 'Fabric_Width_Measuring',
		0 'Cross_Dock_Inbound',
		0 'Cross_Dock_Outbound',
		sum(c.CHARGE_QTY) 'Recurring_Storage'
		
	FROM BILLADMIN.BIC_CHARGE c
	INNER  Join BILLADMIN.BIC_CHARGE_CODE CHG_CODE ON c.CHARGE_CODE = CHG_CODE.CHARGE_CODE
	WHERE c.CHARGE_CODE ='INQFAB-ST-CS'
	AND c.DELETE_FLAG = 0
	--AND BIll_GROUP='INQUBE-FABRICS'
	Group by CAST(DATEADD(minute, 30, DATEADD(hour, 5, c.CHARGE_DATE)) AS DATE)

	UNION ALL

	SELECT
		FORMAT(CAST(DATEADD(minute, 30, DATEADD(hour, 5, r_.EFFECTIVEDATE)) AS DATE), 'MM-yyyy') 'DatePart',
		CAST(DATEADD(minute, 30, DATEADD(hour, 5, r_.EFFECTIVEDATE)) AS DATE) 'Cal_Date',
		0 'Swatch',
		0 'Weight',
		0 'Width',
		0 'One_Yrd',
		0 'Inbound_Rolls',
		0 'Outbound_Rolls',
		0 'Cut_Rolls',
		0 'Additional_Swatch',
		0 'Additional_Roll',
		0 'Additional_One_Yrd',
		0 'Fabric_Width_Measuring',
		count(rd_.EXT_UDF_LKUP4) 'Cross_Dock_Inbound',
		0 'Cross_Dock_Outbound',
		0 'Recurring_Storage'
		FROM 
		V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.receipt r_ ,
		V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.receiptdetail rd_,
		V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.codelkup code_
		where rd_.RECEIPTKEY = r_.RECEIPTKEY 
		AND r_.STORERKEY = 'INQUBE-FABRICS'
		AND r_.TYPE!=47
		AND rd_.QTYRECEIVED>0
		AND code_.CODE = r_.STATUS
		AND code_.listname = 'RECSTATUS'
		
		Group by CAST(DATEADD(minute, 30, DATEADD(hour, 5, r_.EFFECTIVEDATE)) AS DATE)
	UNION ALL

	select 
		Cross_sku_Count.Date_Part 'DatePart',	
		Cross_sku_Count.DateCal 'Cal_Date',	
		0 'Swatch',
		0 'Weight',
		0 'Width',
		0 'One_Yrd',
		0 'Inbound_Rolls',
		0 'Outbound_Rolls',
		0 'Cut_Rolls',
		0 'Additional_Swatch',
		0 'Additional_Roll',
		0 'Additional_One_Yrd',
		0 'Fabric_Width_Measuring',
		0 'Cross_Dock_Inbound',
		count(Cross_sku_Count.Cross_Outbound_Rolls) 'Cross_Dock_Outbound',
		0 'Recurring_Storage'	
		from(
		SELECT 
		CAST(DATEADD(minute, 30, DATEADD(hour, 5, o.ORDERDATE)) AS DATE) 'DateCal',
		FORMAT(CAST(DATEADD(minute, 30, DATEADD(hour, 5, o.ORDERDATE)) AS DATE), 'MM-yyyy') 'Date_Part',
		od.sku,
		Count(od.sku) 'Cross_Outbound_Rolls'
		FROM 
		V{=Replace(GetVariable('p_SCHEMA'), '\'', '')}.orderdetail od
		INNER JOIN V{=Replace(GetVariable('p_SCHEMA'), '\'', '')}.Orders o
		ON od.STORERKEY=o.STORERKEY
		AND od.ORDERKEY=o.ORDERKEY
		INNER JOIN 
		V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.itrn trn
		ON trn.sku= od.sku
		AND trn.SOURCEKEY = od.ORDERKEY + CAST(od.ORDERLINENUMBER AS VARCHAR)
		where od.STORERKEY = 'INQUBE-FABRICS'
		and o.TYPE!=47
		 AND od.status IN ('16', '95')
		AND TRANTYPE = 'WD'
	 
		--AND od.ORDERKEY='0000008624'
		Group by CAST(DATEADD(minute, 30, DATEADD(hour, 5, o.ORDERDATE)) AS DATE),od.sku
		) Cross_sku_Count
		GROUP BY 
		Cross_sku_Count.DateCal,Cross_sku_Count.Date_Part
	UNION ALL	
	SELECT 
		FORMAT(CAST(DATEADD(minute, 30, DATEADD(hour, 5, w.ext_udf_date1)) AS DATE), 'MM-yyyy') 'DatePart',
		CAST(DATEADD(minute, 30, DATEADD(hour, 5, w.ext_udf_date1)) AS DATE) 'Cal_Date',
		0 'Swatch',
		0 'Weight',
		0 'Width',
		0 'One_Yrd',
		0 'Inbound_Rolls',
		0 'Outbound_Rolls',
		COUNT(p.cartontype) 'Cut_Rolls',
		0 'Additional_Swatch',
		0 'Additional_Roll',
		0 'Additional_One_Yrd',
		0 'Fabric_Width_Measuring',
		0 'Cross_Dock_Inbound',
		0 'Cross_Dock_Outbound',
		0 'Recurring_Storage'
		
	FROM V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.wave w
	LEFT JOIN V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.pickdetail p 
		ON w.wavekey = p.wavekey AND p.cartontype = 'SPLIT'
	WHERE 
		w.ext_udf_date1 IS NOT NULL
		--AND CAST(DATEADD(minute, 30, DATEADD(hour, 5, w.ext_udf_date1)) AS DATE) BETWEEN '2025-07-01' AND '2025-07-31'
	GROUP BY CAST(DATEADD(minute, 30, DATEADD(hour, 5, w.ext_udf_date1)) AS DATE)

		) AS CombinedData
	--where DatePart='04-2025'
	--where Cal_Date='2025-01-02'
	GROUP BY DatePart, Cal_Date

)summary
WHERE summary.DatePart is not NULL
GROUP BY summary.DatePart
