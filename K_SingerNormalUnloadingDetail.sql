SELECT 
    FORMAT(Cal_Date_, 'MM-yyyy') AS DatePart,
    Cal_Date_,
	VehicleNumber,
    ContainerNo,
    --TrailerNo,
    COUNT(NULLIF(CUI_40FT, '')) AS CUI_40FT,
    COUNT(NULLIF(CUI_20FT, '')) AS CUI_20FT,
    COUNT(NULLIF(CUI_LCL, '')) AS CUI_LCL
FROM 
(
    SELECT 
        CAST(DATEADD(minute, 30, DATEADD(hour, 5, c.CHARGE_DATE)) AS DATE) AS Cal_Date_,
        c.CHARGE_CODE AS ChargeCode,
        r.VEHICLENUMBER 'VehicleNumber',
		r.CONTAINERKEY 'ContainerNo',
		--r.TrailerNumber 'TrailerNo',		
        IIF(c.CHARGE_CODE = 'SIN-N-CUI-20FT', c.CHARGE_CODE, '') AS CUI_20FT,
        IIF(c.CHARGE_CODE = 'SIN-N-CUI-40FT', c.CHARGE_CODE, '') AS CUI_40FT,
        IIF(c.CHARGE_CODE = 'SIN-N-CUI-LCL', c.CHARGE_CODE, '') AS CUI_LCL
    FROM BILLADMIN.BIC_CHARGE c
	Left join V{=Replace(GetVariable('p_SCHEMA'), '\'', '')}.receipt r ON c.order_no = r.RECEIPTKEY
    WHERE c.CHARGE_CODE IN ('SIN-N-CUI-20FT', 'SIN-N-CUI-40FT', 'SIN-N-CUI-LCL')
	AND c.DELETE_FLAG = 0

) Summary
GROUP BY Cal_Date_, VehicleNumber, ContainerNo
