SELECT
	FORMAT(summary.Cal_Date, 'MM-yyyy') AS DatePart,
	summary.Cal_Date AS Cal_Date_,
	summary.VehicleNumber,
	summary.ContainerNo,
	summary.CUI_20FT,
	summary.CUI_40FT,
	summary.CUI_LCL
FROM
(
	SELECT 
		CAST(DATEADD(minute, 30, DATEADD(hour, 5, c.CHARGE_DATE)) AS DATE) AS Cal_Date,
		r.VEHICLENUMBER AS VehicleNumber,
		r.CONTAINERKEY AS ContainerNo,
		COUNT(c.CHARGE_CODE) AS  CUI_20FT,
		0 AS CUI_40FT,
		0 AS  CUI_LCL
		
	FROM BILLADMIN.BIC_CHARGE c
	Left join V{=Replace(GetVariable('p_SCHEMA'), '\'', '')}.receipt r ON c.order_no = r.RECEIPTKEY
	WHERE c.CHARGE_CODE IN ('SIN-N-CUI-20FT')
	AND c.DELETE_FLAG = 0
	GROUP BY CAST(DATEADD(minute, 30, DATEADD(hour, 5, c.CHARGE_DATE)) AS DATE),
			 r.VEHICLENUMBER,
			 r.CONTAINERKEY
			 
	UNION ALL		 
			 
	SELECT 
		CAST(DATEADD(minute, 30, DATEADD(hour, 5, c.CHARGE_DATE)) AS DATE) AS Cal_Date,
		r.VEHICLENUMBER AS VehicleNumber,
		r.CONTAINERKEY AS ContainerNo,
		0 AS  CUI_20FT,
		COUNT(c.CHARGE_CODE) AS  CUI_40FT,
		0 AS  CUI_LCL
		
	FROM BILLADMIN.BIC_CHARGE c
	Left join V{=Replace(GetVariable('p_SCHEMA'), '\'', '')}.receipt r ON c.order_no = r.RECEIPTKEY
	WHERE c.CHARGE_CODE IN ('SIN-N-CUI-40FT')
	AND c.DELETE_FLAG = 0
	GROUP BY CAST(DATEADD(minute, 30, DATEADD(hour, 5, c.CHARGE_DATE)) AS DATE),
			 r.VEHICLENUMBER,
			 r.CONTAINERKEY

	UNION ALL

	SELECT 
		CAST(DATEADD(minute, 30, DATEADD(hour, 5, c.CHARGE_DATE)) AS DATE) AS Cal_Date,
		r.VEHICLENUMBER AS VehicleNumber,
		r.CONTAINERKEY AS ContainerNo,
		0 AS  CUI_20FT,
		0 AS  CUI_40FT,
		COUNT(c.CHARGE_CODE) AS  CUI_LCL
		
	FROM BILLADMIN.BIC_CHARGE c
	Left join V{=Replace(GetVariable('p_SCHEMA'), '\'', '')}.receipt r ON c.order_no = r.RECEIPTKEY
	WHERE c.CHARGE_CODE IN ('SIN-N-CUI-LCL')
	AND c.DELETE_FLAG = 0
	GROUP BY CAST(DATEADD(minute, 30, DATEADD(hour, 5, c.CHARGE_DATE)) AS DATE),
			 r.VEHICLENUMBER,
			 r.CONTAINERKEY	
)summary
