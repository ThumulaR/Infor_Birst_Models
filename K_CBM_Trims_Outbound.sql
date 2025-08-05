SELECT
        o.orderkey AS Order_Number,
        od.storerkey AS Owner,
        od.orderlinenumber AS Line_No,
        od.sku AS Item,
        i.ITEM_DESC AS Description,
        od.packkey AS Pack,
        od.uom AS UOM,
        od.externlineno AS External_Line_No,
        od.shippedqty AS Shipped,
        od.externorderkey AS External_Order_No,
        od.idrequired AS Flow_Thru_License_Plate_Required,
        la.lottable01 AS Lottable01,
        la.lottable02 AS Lottable02,
        la.lottable03 AS Lottable03,
        la.lottable06 AS Lottable06,
        la.lottable07 AS Lottable07,
        la.lottable08 AS Lottable08,
        la.lottable09 AS Lottable09,
        la.lottable10 AS Lottable10,
        CAST(DATEADD(minute, 30, DATEADD(hour, 5, o.effectivedate )) AS DATE) AS Overide_Date,
        CAST(o.orderdate AS DATE) AS Date_Created,
        CAST(o.actualshipdate AS DATE) AS Actual_Ship_Date,        
        CAST(o.effectivedate AS DATE) AS Transaction_Date_Override,
        CASE 
                WHEN la.lottable06 LIKE '%QCLRTN%' THEN 'INQUBE-TRIMS'
                ELSE od.storerkey
        END As Billing_Owner,        
        CASE
                WHEN la.lottable01 LIKE '%NO PACK%' THEN 0 
                WHEN SUBSTRING(la.lottable06,4,6) LIKE '%BRL%' THEN ROUND((p."cube" * od.shippedqty) ,6) 
                ELSE ROUND(p."cube",6)
        END CBM
FROM V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.orders o
LEFT JOIN V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.orderdetail od ON o.orderkey = od.orderkey
LEFT JOIN V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.itrn la ON od.sku = la.sku AND od.orderkey +  CAST(od.orderlinenumber AS VARCHAR) = la.sourcekey
LEFT JOIN V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.pack p ON la.lottable01 = p.packkey and la.whseid = p.whseid
LEFT JOIN BILLADMIN.BIC_ITEM i on od.sku = i.ITEM AND od.storerkey = i.CUST_CODE
WHERE (od.storerkey = 'INQUBE-TRIMS'OR  od.storerkey = 'INQUBE-QCLTRIMS') AND od.status = 95
