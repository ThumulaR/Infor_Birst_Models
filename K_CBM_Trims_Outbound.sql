-- Date      Version  Author  Description
-- 07/02/25    1.00     TR     Initial query 

SELECT
        o. orderkey AS Order_Number,
        o. storerkey AS Owner,
        od. orderlinenumber AS Line_No,
        od. sku AS Item,
        od. ext_udf_str1 AS Description,
        od. packkey AS Pack,
        od. uom AS UOM,
        od. externlineno AS External_Line_No,
        od. shippedqty AS Shipped,
        od. externorderkey AS External_Order_No,
        la. lottable03 AS Flow_Thru_License_Plate_Required,
        la. lottable01 AS Lottable01,
        la. lottable02 AS Lottable02,
        la. lottable03 AS Lottable03,
        la. lottable06 AS Lottable06,
        la. lottable07 AS Lottable07,
        la. lottable08 AS Lottable08,
        la. lottable09 AS Lottable09,
        la. lottable10 AS Lottable10,
        CAST(DATEADD(minute, 30, DATEADD(hour, 5, od. effectivedate )) AS DATE) AS Overide_Date,
        CAST(od. effectivedate AS DATE) AS Date_Created,
        CAST(od. actualshipdate AS DATE) AS Actual_Ship_Date,        
        CAST(od. effectivedate AS DATE) AS Transaction_Date_Override,
        CASE 
                WHEN la. lottable06 LIKE '%QCLRTN%' THEN 'INQUBE-TRIMS'
                ELSE o. storerkey
        END As Billing_Owner,        
        CASE
                WHEN la.lottable01 LIKE '%NO PACK%' THEN 0 
                WHEN SUBSTRING(la.lottable06,4,6) LIKE '%BRL%' THEN ROUND((p."cube" * od.shippedqty) ,4) 
                ELSE ROUND(p."cube",4)
        END CBM
FROM V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.orders o
LEFT JOIN V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.orderdetail od ON o.orderkey = od.orderkey
LEFT JOIN V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.lotattribute la ON od.sku = la.sku AND od.lottable03 = la.lottable03
LEFT JOIN V{=Replace(GetVariable('p_SCHEMA'),'\'','')}.pack p ON la.lottable01 = p.packkey and la.whseid = p.whseid
WHERE (o.storerkey = 'INQUBE-TRIMS'OR  o.storerkey = 'INQUBE-QCLTRIMS') AND od.status = 95