SELECT DISTINCT
    od.SKU,
    SUM(od.SHIPPEDQTY) AS SHIPPEDQTY,
    MAX(od.EFFECTIVEDATE) AS EFFECTIVEDATE,
    MAX(wave.BATCHORDERNUMBER) AS BATCHORDERNUMBER,
    MAX(wave.DESCR) AS wave_description,
    MAX(od.STORERKEY) AS STORERKEY,
    MAX(wave.EXT_UDF_DATE1) AS Wave_Transaction_Override_Date,
    MAX(DATEADD(minute, 30, DATEADD(hour, 5, wave.EXT_UDF_DATE1))) AS LocalDate,
    wave.wavekey AS wavekey,
    MAX(wave.status) AS WaveStatus,
    MAX(orders.TYPE) AS Type,
    MAX(od.status) AS OrderStatus,
    MAX(wave.EXT_UDF_STR1) AS Wave_Maintenance_Text_UDF_1,
    MAX(wave.EXT_UDF_STR2) AS Wave_Maintenance_Text_UDF_2,
    MAX(wave.EXT_UDF_STR3) AS Wave_Maintenance_Text_UDF_3,
    MAX(trn.TOID) AS LPN, -- fallback if STRING_AGG unsupported
    SUM(od.ORIGINALQTY) AS Quantity,
    FORMAT(CAST(MAX(DATEADD(minute, 30, DATEADD(hour, 5, wave.EXT_UDF_DATE1))) AS DATE), 'MM-yyyy') AS DatePart,
    CAST(MAX(DATEADD(minute, 30, DATEADD(hour, 5, wave.EXT_UDF_DATE1))) AS DATE) AS TransactionDate
FROM 
    V{=Replace(GetVariable('p_SCHEMA'), '\'', '')}.orders  
INNER JOIN 
    V{=Replace(GetVariable('p_SCHEMA'), '\'', '')}.wave wave
    ON orders.BATCHORDERNUMBER = wave.BATCHORDERNUMBER
    AND wave.BATCHORDERNUMBER IS NOT NULL
    AND wave.BATCHORDERNUMBER <> ''
INNER JOIN 
    V{=Replace(GetVariable('p_SCHEMA'), '\'', '')}.orderdetail od
    ON od.ORDERKEY = orders.ORDERKEY
INNER JOIN 
    V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.itrn trn
    ON trn.sku = od.sku
    AND trn.SOURCEKEY = od.ORDERKEY + CAST(od.ORDERLINENUMBER AS VARCHAR)
WHERE 
    od.STORERKEY = 'INQUBE-FABRICS'
    AND orders.TYPE != '47'
    AND od.status IN ('16', '95')
    AND TRANTYPE = 'WD'
    --AND CAST(DATEADD(minute, 30, DATEADD(hour, 5, wave.EXT_UDF_DATE1)) AS DATE) = '2025-05-08'
GROUP BY 
    od.SKU,
    trn.LOT,
    wave.wavekey
