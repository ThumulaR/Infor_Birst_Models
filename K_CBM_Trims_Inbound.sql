SELECT DISTINCT
        r.receiptkey AS ASN_Receipt,
        r.storerkey AS Owner,
        r.effectivedate  AS Date_Created,
        r.externreceiptkey AS External_ASN_No,
        rd.ext_udf_str1  AS Article_Descr,
        rd.lottable09  AS T2_Color,
        rd.receiptlinenumber AS Line_No,
        rd.sku AS Item,
        i.ITEM_DESC AS Description,
        rd.packkey AS Pack,
        rd.uom AS UOM,
        rd.toid AS LPN,
        rd.toloc  AS Location,
        rd.status AS Status,
        rd.qtyreceived AS Received_Qty,
        rd.lottable01 AS Lottable01,
        rd.lottable02 AS Lottable02,
        rd.lottable03 AS Lottable03,
        rd.lottable06 AS Lottable06,
        rd.lottable07 AS Lottable07,
        rd.lottable08 AS Lottable08,
        rd.lottable09 AS Lottable09,
        rd.lottable10 AS Lottable10,
        rd.tolot AS Lot_Number,
        r.SupplierName AS Supplier_Name,
        CAST(DATEADD(minute, 30, DATEADD(hour, 5, r.effectivedate )) AS DATE) AS Overide_Date,
        (CASE 
                WHEN rd.lottable06 LIKE '%QCLRTN%' THEN 'INQUBE-TRIMS'
                ELSE r.storerkey
        END) AS Billing_Owner,
        (CASE
                WHEN rd.lottable01 LIKE '%NO PACK%' THEN 0 
                WHEN SUBSTRING(rd.lottable06,4,6) LIKE '%BRL%' THEN ROUND((p."cube" * rd.qtyreceived),6) 
                ELSE ROUND(p."cube" ,6)
        END) AS CBM
        
FROM V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.receipt r

LEFT JOIN 
        V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.receiptdetail rd 
        ON r.receiptkey = rd.receiptkey 

LEFT JOIN 
        V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.pack p 
        ON rd.lottable01 = p.packkey 
		
LEFT JOIN
        BILLADMIN.BIC_ITEM i
		ON rd.sku = i.ITEM	
		AND r.storerkey = i.CUST_CODE

WHERE 
        rd.qtyreceived  > 0 AND 
        (r.storerkey = 'INQUBE-TRIMS' OR  r.storerkey = 'INQUBE-QCLTRIMS')
