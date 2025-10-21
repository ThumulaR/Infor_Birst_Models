SELECT
	FinalSum.MonthYear,
	ROUND(SUM(FinalSum.Trims_Inbound),3) AS Trims_Inbound,
	ROUND(SUM(FinalSum.Trims_Outbound),3) AS Trims_Outbound,
	ROUND(SUM(FinalSum.Trims_Storage),3) AS Trims_Storage,
	ROUND(SUM(FinalSum.Qcl_Inbound),3) AS Qcl_Inbound,
	ROUND(SUM(FinalSum.Qcl_Outbound),3) AS Qcl_Outbound,
	ROUND(SUM(FinalSum.Qcl_Addtional_Storage),3) AS Qcl_Addtional_Storage

FROM(

	--Calculate Trims Inbound & Outbound
	SELECT
		summary.MonthYear,
		SUM(summary.Inbound_CBM) AS Trims_Inbound,
		SUM(summary.Outbound_CBM) AS Trims_Outbound,
		0 AS Trims_Storage,
		0 AS Qcl_Inbound,
		0 AS Qcl_Outbound,
		0 AS Qcl_Addtional_Storage
	FROM
	(
		SELECT 
			Final.Overide_Date,
			Final.MonthYear,
			ISNULL(Final.Inbound_CBM, 0.0) AS Inbound_CBM,
			ISNULL(Final.Outbound_CBM, 0.0) AS Outbound_CBM,
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
					CAST(DATEADD(minute, 30, DATEADD(hour, 5, r.effectivedate)) AS DATE) AS Overide_Date,
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
					AND (r.storerkey = 'INQUBE-TRIMS' OR (r.storerkey = 'INQUBE-QCLTRIMS' AND rd.lottable06 LIKE '%QCLRTN%'))
				GROUP BY CAST(DATEADD(minute, 30, DATEADD(hour, 5, r.effectivedate)) AS DATE)

				UNION ALL

				-- Outbound
				SELECT
					CAST(DATEADD(minute, 30, DATEADD(hour, 5, o.effectivedate)) AS DATE) AS Overide_Date,
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
				LEFT JOIN V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.itrn la 
					ON od.sku = la.sku AND od.orderkey +  CAST(od.orderlinenumber AS VARCHAR) = la.sourcekey
				LEFT JOIN V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.pack p 
					ON la.lottable01 = p.packkey AND la.whseid = p.whseid
				WHERE 
					od.status = 95
					AND od.effectivedate IS NOT NULL
					AND (od.storerkey = 'INQUBE-TRIMS' OR (od.storerkey = 'INQUBE-QCLTRIMS' AND la.lottable06 LIKE '%QCLRTN%'))
				GROUP BY CAST(DATEADD(minute, 30, DATEADD(hour, 5, o.effectivedate)) AS DATE)
			) AS Combined
			GROUP BY Combined.Overide_Date
		) AS Final

		LEFT JOIN (
			SELECT 
				FORMAT(charge_date, 'MM-yyyy') AS MonthYear,
				SUM(charge_qty) AS charge_qty
			FROM BILLADMIN.BIC_CHARGE 
			WHERE charge_code = 'INQTRIMOB' 
			  AND bill_to = 'INQUBE-TRIMS'
			  AND DELETE_FLAG = 0
			GROUP BY FORMAT(charge_date, 'MM-yyyy')
		) AS Init ON Final.MonthYear = Init.MonthYear

	)summary
	GROUP BY summary.MonthYear

	UNION ALL

	--Calculate Trims Storage
	SELECT 
		MonthYear,
		0 AS Trims_Inbound,
		0 AS Trims_Outbound,
		Storage AS Trims_Storage,
		0 AS Qcl_Inbound,
		0 AS Qcl_Outbound,
		0 AS Qcl_Addtional_Storage
	FROM (
		SELECT 
			Final.MonthYear,
			ROW_NUMBER() OVER (
				PARTITION BY Final.MonthYear 
				ORDER BY Final.Overide_Date DESC
			) AS rn,
			ISNULL(Init.charge_qty, 0) + 
				SUM(Final.day_dif) OVER (
					PARTITION BY Final.MonthYear 
					ORDER BY Final.Overide_Date 
					ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
				) AS Storage
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
					CAST(DATEADD(minute, 30, DATEADD(hour, 5, r.effectivedate)) AS DATE) AS Overide_Date,
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
					AND (r.storerkey = 'INQUBE-TRIMS' OR (r.storerkey = 'INQUBE-QCLTRIMS' AND rd.lottable06 LIKE '%QCLRTN%'))
				GROUP BY CAST(DATEADD(minute, 30, DATEADD(hour, 5, r.effectivedate)) AS DATE)

				UNION ALL

				-- Outbound
				SELECT
					CAST(DATEADD(minute, 30, DATEADD(hour, 5, o.effectivedate)) AS DATE) AS Overide_Date,
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
				LEFT JOIN V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.itrn la 
					ON od.sku = la.sku AND od.orderkey + CAST(od.orderlinenumber AS VARCHAR) = la.sourcekey
				LEFT JOIN V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.pack p 
					ON la.lottable01 = p.packkey AND la.whseid = p.whseid
				WHERE 
					od.status = 95
					AND od.effectivedate IS NOT NULL
					AND (od.storerkey = 'INQUBE-TRIMS' OR (od.storerkey = 'INQUBE-QCLTRIMS' AND la.lottable06 LIKE '%QCLRTN%'))
				GROUP BY CAST(DATEADD(minute, 30, DATEADD(hour, 5, o.effectivedate)) AS DATE)
			) AS Combined
			GROUP BY Combined.Overide_Date
		) AS Final
		LEFT JOIN (
			SELECT 
				FORMAT(charge_date, 'MM-yyyy') AS MonthYear,
				SUM(charge_qty) AS charge_qty
			FROM BILLADMIN.BIC_CHARGE 
			WHERE charge_code = 'INQTRIMOB' 
			  AND bill_to = 'INQUBE-TRIMS'
			  AND DELETE_FLAG = 0
			GROUP BY FORMAT(charge_date, 'MM-yyyy')
		) AS Init ON Final.MonthYear = Init.MonthYear
	) AS Derived
	WHERE rn = 1
	
	UNION ALL
	--Calculate QCLTrims Additional Inbound / Outbound / Storage
	SELECT 
		QclSummary.MonthYear,
		0 AS Trims_Inbound,
		0 AS Trims_Outbound,
		0 AS Trims_Storage,
		(SUM(QclSummary.Inbound_CBM) - 432) AS Qcl_Inbound,
		(SUM(QclSummary.Outbound_CBM) - 432) AS Qcl_Outbound,
		SUM(QclSummary.Addtional_Storage) AS Qcl_Addtional_Storage
	FROM (
		SELECT 
		Final.Overide_Date,
		Final.MonthYear,
		ISNULL(Final.Inbound_CBM, 0.0) AS Inbound_CBM,
		ISNULL(Final.Outbound_CBM, 0.0) AS Outbound_CBM,
		Final.day_dif,
		ISNULL(Init.charge_qty, 0) AS init_qty,
		
		ISNULL(Init.charge_qty, 0) + 
			SUM(Final.day_dif) OVER (
				PARTITION BY Final.MonthYear 
				ORDER BY Final.Overide_Date 
				ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
			) AS Closing_CBM,
			
		(CASE
			WHEN ISNULL(Init.charge_qty, 0) + 
			SUM(Final.day_dif) OVER (
				PARTITION BY Final.MonthYear 
				ORDER BY Final.Overide_Date 
				ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
			) > 300 THEN (ISNULL(Init.charge_qty, 0) + 
			SUM(Final.day_dif) OVER (
				PARTITION BY Final.MonthYear 
				ORDER BY Final.Overide_Date 
				ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
			)) - 300
			ELSE 0
		END) AS Addtional_Storage,
		
		(CASE
			WHEN ISNULL(Final.Inbound_CBM, 0.0) >= 20 THEN (ISNULL(Final.Inbound_CBM, 0.0) - 20)
			ELSE 0
		END) AS Inbound_OT,
		
		(CASE
			WHEN ISNULL(Final.Outbound_CBM, 0.0) >= 20 THEN (ISNULL(Final.Outbound_CBM, 0.0) - 20)
			ELSE 0
		END) AS Outbound_OT,
		
		(CASE
			WHEN ISNULL(Final.Inbound_CBM, 0.0) >= 20 THEN (ISNULL(Final.Inbound_CBM, 0.0) - 20)/2.5
			ELSE 0
		END) AS Inbound_OT_Hrs,
		
		(CASE
			WHEN ISNULL(Final.Outbound_CBM, 0.0) >= 20 THEN (ISNULL(Final.Outbound_CBM, 0.0) - 20)/2.5
			ELSE 0
		END) AS Outbound_OT_Hrs

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
				CAST(DATEADD(minute, 30, DATEADD(hour, 5, r.effectivedate)) AS DATE) AS Overide_Date,
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
			GROUP BY CAST(DATEADD(minute, 30, DATEADD(hour, 5, r.effectivedate)) AS DATE)

			UNION ALL

			-- Outbound
			SELECT
				CAST(DATEADD(minute, 30, DATEADD(hour, 5, o.effectivedate)) AS DATE) AS Overide_Date,
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
			LEFT JOIN V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.itrn la 
				ON od.sku = la.sku AND od.orderkey +  CAST(od.orderlinenumber AS VARCHAR) = la.sourcekey
			LEFT JOIN V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.pack p 
				ON la.lottable01 = p.packkey AND la.whseid = p.whseid
			WHERE 
				od.status = 95
				AND od.effectivedate IS NOT NULL
				AND (od.storerkey = 'INQUBE-QCLTRIMS' AND la.lottable06 NOT LIKE '%QCLRTN%')
			GROUP BY CAST(DATEADD(minute, 30, DATEADD(hour, 5, o.effectivedate)) AS DATE)
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
		  AND DELETE_FLAG = 0
		GROUP BY FORMAT(charge_date, 'MM-yyyy')
	) AS Init ON Final.MonthYear = Init.MonthYear
	
	)QclSummary
	GROUP BY QclSummary.MonthYear
)FinalSum
GROUP BY FinalSum.MonthYear
