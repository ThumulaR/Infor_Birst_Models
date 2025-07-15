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
	outboundSum.DatePart AS DatePart,
	outboundSum.Date AS EffectiveDate,
	0 'Swatch',
	0 'Weight',
	0 'Width',
	0 'One_Yrd',
	0 'Inbound_Rolls',
	count(outboundSum.SHIPPEDQTY) AS Outbound_Rolls,
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
SELECT DISTINCT
    od.SKU,
    trn.TOID,
    SUM(od.SHIPPEDQTY) AS SHIPPEDQTY,
    MAX(od.EFFECTIVEDATE) AS EFFECTIVEDATE,
    SUM(od.ORIGINALQTY) AS Quantity,
    FORMAT(CAST(MAX(DATEADD(minute, 30, DATEADD(hour, 5, wave.EXT_UDF_DATE1))) AS DATE), 'MM-yyyy') AS DatePart,
    CAST(MAX(DATEADD(minute, 30, DATEADD(hour, 5, wave.EXT_UDF_DATE1))) AS DATE) AS Date

FROM V{=Replace(GetVariable('p_SCHEMA'), '\'', '')}.orders  
INNER JOIN V{=Replace(GetVariable('p_SCHEMA'), '\'', '')}.wave wave
    ON orders.BATCHORDERNUMBER = wave.BATCHORDERNUMBER
	AND wave.BATCHORDERNUMBER IS NOT NULL
    AND wave.BATCHORDERNUMBER <> ''
INNER JOIN V{=Replace(GetVariable('p_SCHEMA'), '\'', '')}.orderdetail od
    ON od.ORDERKEY = orders.ORDERKEY
	
INNER JOIN 
    V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.itrn trn
    ON trn.sku= od.sku
AND trn.SOURCEKEY = od.ORDERKEY + CAST(od.ORDERLINENUMBER AS VARCHAR)

WHERE od.STORERKEY = 'INQUBE-FABRICS'
  AND orders.TYPE != '47'
  AND od.status IN ('16', '95')
  AND TRANTYPE = 'WD'
GROUP BY 
    od.SKU,
    trn.LOT,
	trn.TOID,
    wave.wavekey
	) 
	outboundSum
	--where outboundSum.Date='2025-04-01'
	Group by 
	outboundSum.Date,outboundSum.DatePart
	--order by outboundSum.Date asc

		
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
select
	FORMAT(roll_Sum.Date, 'MM-yyyy') 'DatePart',
	roll_Sum.Date 'Cal_Date',
	0 'Swatch',
	0 'Weight',
	0 'Width',
	0 'One_Yrd',
	0 'Inbound_Rolls',
	0 'Outbound_Rolls',
	sum(roll_Sum.CutRole) 'Cut_Rolls',
	0 'Additional_Swatch',
	0 'Additional_Roll',
	0 'Additional_One_Yrd',
	0 'Fabric_Width_Measuring',
	0 'Cross_Dock_Inbound',
	0 'Cross_Dock_Outbound',
	0 'Recurring_Storage'		
FROM
(
select 
roll_d.Date,
roll_d.sku,
roll_d.TotalWaveCount,
roll_d.OutQty,
roll_d.InQty,
roll_d.DayWaveCount,
IIF(
((roll_d.InQty-(-1)*roll_d.OutQty)>0 AND (roll_d.TotalWaveCount=roll_d.DayWaveCount)),IIF(roll_d.TotalWaveCount=1,1,iif (roll_d.TotalWaveCount>0,roll_d.TotalWaveCount-1,0))
,
IIF(
((roll_d.InQty-(-1)*roll_d.OutQty)>0 AND (roll_d.TotalWaveCount>roll_d.DayWaveCount)),IIF(roll_d.DayWaveCount>1,iif (roll_d.TotalWaveCount>0,roll_d.TotalWaveCount-1,0),1),0)
) 'CutRole'

FROM
(SELECT 
    wave_d.Date, 
	wave_d.sku,
	isnull((SELECT Sum(itrn.QTY)
    FROM V{=Replace(GetVariable('p_SCHEMA'), '\'', '')}.ITRN itrn
    WHERE 
	STORERKEY = 'INQUBE-FABRICS'
    AND itrn.TRANTYPE = 'WD' --Out
    AND itrn.sku = wave_d.sku
	AND CAST(DATEADD(minute, 30, DATEADD(hour, 5, itrn.EFFECTIVEDATE)) AS DATE)<=DATEADD(day, 1, wave_d.Date)
	--GROUP BY CAST(DATEADD(minute, 30, DATEADD(hour, 5, itrn.EFFECTIVEDATE)) AS DATE),itrn.sku
	),0) 'OutQty',
	
	isnull((SELECT Sum(itrn.QTY)
    FROM V{=Replace(GetVariable('p_SCHEMA'), '\'', '')}.ITRN itrn
    WHERE 
	STORERKEY = 'INQUBE-FABRICS'
    AND itrn.TRANTYPE = 'DP' --in
    AND itrn.sku = wave_d.sku
	AND CAST(DATEADD(minute, 30, DATEADD(hour, 5, itrn.EFFECTIVEDATE)) AS DATE)<=DATEADD(day, 1, wave_d.Date)
	--GROUP BY CAST(DATEADD(minute, 30, DATEADD(hour, 5, itrn.EFFECTIVEDATE)) AS DATE),itrn.sku
	),0) 'InQty',
	
	isnull((
	SELECT 
        count(pd_.wavekey)
    FROM 
        V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.wave wave_,
        V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.pickdetail pd_,
        V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.orderdetail od_
    WHERE 
        wave_.wavekey = pd_.wavekey 
        AND wave_.batchordernumber = od_.batchordernumber
        AND od_.storerkey = pd_.storerkey 
		AND od_.sku = pd_.sku
        AND od_.sku = wave_d.sku 
        AND od_.STORERKEY = pd_.STORERKEY
        --AND wave_.EXT_UDF_DATE1 > 0
		AND CAST(DATEADD(minute, 30, DATEADD(hour, 5, wave_.EXT_UDF_DATE1)) AS DATE)=wave_d.Date
	),0) 'DayWaveCount',
	
	isnull((
	SELECT 
        count(pd_.wavekey)
    FROM 
        V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.wave wave_,
        V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.pickdetail pd_,
        V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.orderdetail od_
    WHERE 
        wave_.wavekey = pd_.wavekey 
        AND wave_.batchordernumber = od_.batchordernumber
        AND od_.storerkey = pd_.storerkey 
		AND od_.sku = pd_.sku
        AND od_.sku = wave_d.sku 
        AND od_.STORERKEY = pd_.STORERKEY
        --AND wave_.EXT_UDF_DATE1 > 0
		AND CAST(DATEADD(minute, 30, DATEADD(hour, 5, wave_.EXT_UDF_DATE1)) AS DATE)<=wave_d.Date
	),0) 'TotalWaveCount'
	
	
FROM 
(
    SELECT 
	CAST(DATEADD(minute, 30, DATEADD(hour, 5, wave.EXT_UDF_DATE1)) AS DATE) AS Date,
	od.sku sku
    FROM V{=Replace(GetVariable('p_SCHEMA'), '\'', '')}.orderdetail od
		INNER JOIN V{=Replace(GetVariable('p_SCHEMA'), '\'', '')}.wave wave
		ON od.BATCHORDERNUMBER = wave.BATCHORDERNUMBER
		where od.STORERKEY = 'INQUBE-FABRICS'
		--and od.sku='CWPFAB2024DEC1096417'
		--and CAST(DATEADD(minute, 30, DATEADD(hour, 5, wave.EXT_UDF_DATE1)) AS DATE)='2024-12-31'
 		GROUP BY 
		CAST(DATEADD(minute, 30, DATEADD(hour, 5, wave.EXT_UDF_DATE1)) AS DATE)
		,od.sku
		 
) wave_d


) roll_d
--where roll_d.sku='CWPFAB2024DEC1096417'


) roll_Sum
--where roll_Sum.sku='CWPFAB2024NOV1089933'
GROUP BY roll_Sum.Date

	) AS CombinedData
--where DatePart='04-2025'
--where Cal_Date='2025-01-02'
GROUP BY DatePart, Cal_Date
