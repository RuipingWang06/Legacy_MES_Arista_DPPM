USE [XXXXDataBase]
GO
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
-- ==================================================================
-- Server: MYPENXXXXXXXX
-- Database: XXXXDataBase
-- Author: Ashleigh Wang
-- Modification History:
-- Date      | Author        | Description
-- ----------|---------------|------------------------------------------
-- 2025-02-13| Ashleigh Wang | Initial submit the procedure.
-- ====================================================================

CREATE PROCEDURE usp_GenerateDPPMReport
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN

-- keep only the latest 2 years of data
    DELETE FROM ARISTA_DPPM_REPORT
    WHERE StartDate < DATEADD(YEAR, -2, GETDATE());

-- Set default date values
	Declare @ErrorMessage varchar(max);
	Declare @DateRange INT;
	SET @DateRange = 1
    SET @StartDate = ISNULL(@StartDate, CAST(GETDATE() - 1 AS DATE));
    SET @EndDate = ISNULL(@EndDate, DATEADD(DAY, 1, @StartDate));
	 

	IF (DATEDIFF(DAY,@StartDate,@EndDate) > @DateRange)
		BEGIN
     		SELECT @ErrorMessage = 'The maximal time interval between Start time and End Time should be under '+ CONVERT(NVARCHAR, @DateRange) +' days!';
			THROW 51000, @ErrorMessage, 1;
	END	

-- Drop temporary tables if they exist
	IF OBJECT_ID('tempdb..#Temp_Wips') IS NOT NULL DROP TABLE #Temp_Wips;
	IF OBJECT_ID('tempdb..#Assembly') IS NOT NULL DROP TABLE #Assembly;
	IF OBJECT_ID('tempdb..#CRDs') IS NOT NULL DROP TABLE #CRDs;
	IF OBJECT_ID('tempdb..#CRD_Serials') IS NOT NULL DROP TABLE #CRD_Serials;
	IF OBJECT_ID('tempdb..#temp_ConsumedQty') IS NOT NULL DROP TABLE #temp_ConsumedQty;
	IF OBJECT_ID('tempdb..#temp_FailedQty') IS NOT NULL DROP TABLE #temp_FailedQty;


-- Create #Temp_Wips table to store WIP route step data along with SerialNumber
	SELECT 
		WipRS.Wip_ID,
		wip.SerialNumber,
		WipRS.StartTime,
		WipRS.EndTime,
		WipRS.RouteStep_ID,
		WipRS.Equipment_ID
	INTO #Temp_Wips
	FROM jems.dbo.WP_WipRouteSteps AS WipRS WITH (NOLOCK)
	INNER JOIN jems.dbo.WP_Wip AS wip WITH (NOLOCK)
		ON WipRS.Wip_ID = wip.Wip_ID
	WHERE 
		WipRS.StartTime >= @StartDate  
		AND WipRS.StartTime < @EndDate
		AND wip.Customer_ID IN (68, 110);
	
-- Create a clustered index on #Temp_Wips for better performance
	CREATE CLUSTERED INDEX IX_#Temp_Wips 
	ON #Temp_Wips (Equipment_ID, RouteStep_ID, StartTime, EndTime);
	
-- Create #Assembly table to store assembly data linked to each WIP
	SELECT 
		wparw.Assembly_ID,
		Wip_ID
	INTO #Assembly
	FROM jems.dbo.WP_AssemblyRouteWIP AS wparw WITH (NOLOCK)
	WHERE EXISTS (
		SELECT 1 
		FROM #Temp_Wips AS WIP
		WHERE wparw.Wip_ID = WIP.Wip_ID
	);

-- Create #CRDs table to store detailed CRD records
	CREATE TABLE #CRDs (
		CRD NVARCHAR(27) ,
		JPN NVARCHAR(18) ,
		Descr NVARCHAR(50) ,
		GRN NVARCHAR(16) ,
		Supplier NVARCHAR(35) ,
		MPN VARCHAR(50),
		SerialNumber VARCHAR(50),
		Flag VARCHAR(50),
		Sort INT
	);


-- Declare a cursor to iterate over distinct Wip_ID values from #Temp_Wips
	DECLARE @Wip_ID INT;
	DECLARE @CurrentWipID INT;
	DECLARE WipCursor CURSOR LOCAL FAST_FORWARD FOR
		SELECT DISTINCT Wip_ID FROM #Temp_Wips;
	
	OPEN WipCursor;
	FETCH NEXT FROM WipCursor INTO @CurrentWipID;
	
	WHILE @@FETCH_STATUS = 0
BEGIN
    SET @Wip_ID = @CurrentWipID;

	----------------------------------------
    --Insert the data into Filtered table
    ----------------------------------------
	IF OBJECT_ID('tempdb..#FilteredTemp_Wips') IS NOT NULL DROP TABLE #FilteredTemp_Wips; 
	IF OBJECT_ID('tempdb..#FilteredAssembly') IS NOT NULL DROP TABLE #FilteredAssembly; 

	SELECT RouteStep_ID, StartTime, EndTime, Wip_ID, Equipment_ID, SerialNumber
	INTO #FilteredTemp_Wips
    FROM #Temp_Wips
    WHERE Wip_ID = @Wip_ID
 
	SELECT Assembly_ID, Wip_ID
	INTO #FilteredAssembly
    FROM #Assembly
    WHERE Wip_ID = @Wip_ID
 
    ----------------------------------------
    -- First INSERT into #CRDs (CT_EquipmentSetup join)
    ----------------------------------------
    INSERT INTO #CRDs (CRD, JPN, Descr, GRN, Supplier,MPN, SerialNumber, Flag, Sort)
    SELECT DISTINCT
        h.CRD,
        f.Material,
        f.Descr,
        e.GRN,
        e.Vendor,
		e.SAPMaskedMPN,
        z.SerialNumber,
        'EquipmentSetup',
        ROW_NUMBER() OVER (PARTITION BY z.SerialNumber, h.CRD ORDER BY d.LoadTime DESC) AS Sort
    FROM #FilteredTemp_Wips AS z
    INNER JOIN #FilteredAssembly AS y ON 1 = 1
    INNER JOIN jems.dbo.CT_EquipmentSetup AS c WITH (NOLOCK)
        ON c.RouteStep_ID = z.RouteStep_ID
        AND c.Equipment_ID = z.Equipment_ID
        AND c.Assembly_ID = y.Assembly_ID
    INNER JOIN jems.dbo.CT_ComponentUse AS d WITH (NOLOCK, INDEX(IX_CT_ComponentUse_1))
        ON c.EquipmentSetup_ID = d.EquipmentSetup_ID
    INNER JOIN jems.dbo.CR_GRNs AS e WITH (NOLOCK)
        ON d.GRN_ID = e.GRN_ID
    INNER JOIN jems.dbo.CR_Materials AS f WITH (NOLOCK, INDEX(PK_CR_Materials))
        ON e.Material_ID = f.Material_ID
    INNER JOIN jems.dbo.CT_EquipmentSetupFeeders AS g WITH (NOLOCK, INDEX(IX_CT_EquipmentSetupFeeders))
        ON c.EquipmentSetup_ID = g.EquipmentSetup_ID
    INNER JOIN jems.dbo.CT_FeederCRDs AS h WITH (NOLOCK)
        ON g.Feeder_ID = h.Feeder_ID
        AND g.FeederTrayTrack_ID = d.FeederTrayTrack_ID
    WHERE 
    (
        (z.StartTime BETWEEN d.LoadTime AND d.RemovalTime) 
        OR (z.StartTime >= d.LoadTime AND d.RemovalTime IS NULL)
        OR (z.EndTime BETWEEN d.LoadTime AND d.RemovalTime) 
        OR (z.EndTime >= d.LoadTime AND d.RemovalTime IS NULL)
    )
    AND NOT EXISTS (
        SELECT 1
        FROM jems.dbo.QM_GRNReplacement AS grnr WITH (NOLOCK)
        WHERE grnr.Wip_ID = z.Wip_ID
          AND grnr.NewGRN_ID > 0
          AND grnr.CRD = h.CRD
    );

    ----------------------------------------
    -- Second INSERT into #CRDs (CT_RouteStepSetup join)
    ----------------------------------------
    INSERT INTO #CRDs (CRD, JPN, Descr, GRN, Supplier,MPN, SerialNumber, Flag, Sort)
    SELECT DISTINCT
        h.CRD, 
        f.Material, 
        f.Descr, 
        e.GRN, 
        e.Vendor,
		e.SAPMaskedMPN,
        z.SerialNumber,
        'RouteStepSetup',
        ROW_NUMBER() OVER (PARTITION BY z.SerialNumber, h.CRD ORDER BY d.LoadTime DESC) AS Sort
    FROM #FilteredTemp_Wips AS z
    INNER JOIN #FilteredAssembly AS y ON 1 = 1
    INNER JOIN jems.dbo.CT_RouteStepSetup AS c WITH (NOLOCK) 
        ON c.Assembly_ID = y.Assembly_ID 
        AND c.RouteStep_ID = z.RouteStep_ID
    INNER JOIN jems.dbo.CT_ComponentUseBins AS d WITH (NOLOCK, INDEX(IX_CT_ComponentUseBins_1))
        ON c.RouteStepSetup_ID = d.RouteStepSetup_ID
    INNER JOIN jems.dbo.CR_GRNs AS e WITH (NOLOCK)
        ON d.GRN_ID = e.GRN_ID
    INNER JOIN jems.dbo.CR_Materials AS f WITH (NOLOCK, INDEX(PK_CR_Materials))
        ON e.Material_ID = f.Material_ID
    INNER JOIN jems.dbo.CT_RouteStepSetupBins AS g WITH (NOLOCK, INDEX(IX_CT_RouteStepSetupBins))
        ON g.RouteStepSetup_ID = d.RouteStepSetup_ID 
        AND g.Bin = d.Bin
    INNER JOIN jems.dbo.CT_BinCRDs AS h WITH (NOLOCK)
        ON h.RouteStepSetupBin_ID = g.RouteStepSetupBin_ID
    WHERE 
    (
        (z.StartTime BETWEEN d.LoadTime AND d.RemovalTime) 
        OR (z.StartTime >= d.LoadTime AND d.RemovalTime IS NULL)
        OR (z.EndTime BETWEEN d.LoadTime AND d.RemovalTime)
        OR (z.EndTime >= d.LoadTime AND d.RemovalTime IS NULL)
    )
    AND NOT EXISTS (
        SELECT 1 
        FROM jems.dbo.QM_GRNReplacement grnr WITH (NOLOCK)
        WHERE grnr.WIP_ID = @Wip_ID 
          AND grnr.NewGRN_ID > 0 
          AND grnr.CRD = h.CRD
    );

    ----------------------------------------
    -- Third INSERT into #CRDs (QM_GRNReplacement join)
    ----------------------------------------
    INSERT INTO #CRDs (CRD, JPN, Descr, GRN, Supplier,MPN, SerialNumber, Flag, Sort)
    SELECT DISTINCT 
        grnr.CRD, 
        mat.Material, 
        mat.Descr, 
        grn.GRN, 
        grn.Vendor,
		grn.SAPMaskedMPN,
        WIP.SerialNumber AS SerialNumber, 
        'Replacement',
         1
    FROM jems.dbo.QM_GRNReplacement AS grnr WITH (NOLOCK)
    JOIN jems.dbo.CR_GRNs AS grn WITH (NOLOCK)
        ON grnr.NewGRN_ID = grn.GRN_ID
    JOIN jems.dbo.CR_Materials AS mat WITH (NOLOCK)
        ON grn.Material_ID = mat.Material_ID
	JOIN jems.dbo.WP_Wip AS WIP WITH (NOLOCK)
	    ON grnr.WIP_ID=WIP.WIP_ID
    WHERE 
        grnr.WIP_ID = @Wip_ID 
        AND grnr.NewGRN_ID > 0

    FETCH NEXT FROM WipCursor INTO @CurrentWipID;
END

CLOSE WipCursor;
DEALLOCATE WipCursor;

--Summary
	SELECT 
		JPN,
		CASE 
		WHEN LEFT(JPN, 2) = 'AS' THEN SUBSTRING(JPN, 3, LEN(JPN))
		ELSE JPN 
		END AS AristaPartNumber,
		ISNULL(NULLIF(Supplier, ''), 'Unknown') AS Supplier,
		ISNULL(NULLIF(MPN, ''), 'Unknown') AS MPN,
		CAST(@StartDate AS DATE) AS RouteStepStartDate,
		COUNT(*) AS ConsumedQty
	INTO #temp_ConsumedQty
	FROM #CRDs 
	WHERE JPN LIKE 'AS%'
	AND NOT (Supplier = '' AND MPN = '' AND JPN LIKE '%$%') 
	AND Sort=1
	GROUP BY JPN,Supplier,MPN;
	
	-- Calculate failed quantity
	SELECT 
		material.Material AS JPN,
		CASE 
			WHEN LEFT(material.Material, 2) = 'AS' THEN SUBSTRING(material.Material, 3, LEN(material.Material))
			ELSE material.Material 
		END AS AristaPartNumber,
		ISNULL(NULLIF(oldgrn.Vendor, ''), 'Unknown') AS Supplier,
		ISNULL(NULLIF(oldgrn.SAPMaskedMPN, ''), 'Unknown') AS MPN,
		CAST(@StartDate AS DATE) AS TestDate,
		COUNT(*) AS FailedQty
	INTO #temp_FailedQty
	FROM jems.dbo.QM_TestData a WITH (NOLOCK)
	INNER JOIN jems.dbo.QM_DataRec g WITH (NOLOCK)
		ON a.WIP_ID = g.WIP_ID 
		AND a.Process_ID = g.Process_ID
	INNER JOIN jems.dbo.QM_DataAnalysis b WITH (NOLOCK)
		ON a.WIP_ID = b.WIP_ID 
		AND a.Process_ID = b.Process_ID 
		AND g.Data_ID = b.Data_ID
		AND b.Repair_ID <> 0
		AND b.AssociatedDefectFlag = 'F'
	INNER JOIN jems.dbo.QM_Analysis Analysis WITH (NOLOCK) 
		ON b.Analysis_ID = Analysis.Analysis_ID
	INNER JOIN jems.dbo.QM_Repair c WITH (NOLOCK)
		ON b.Repair_ID = c.Repair_ID
	INNER JOIN jems.dbo.WP_Wip WIP WITH (NOLOCK) 
		ON a.Wip_ID = WIP.Wip_ID 
	INNER JOIN jems.dbo.QM_GRNReplacement x WITH (NOLOCK)
		ON c.Repair_ID = x.Repair_ID
	LEFT JOIN jems.dbo.CR_GRNs oldgrn WITH (NOLOCK)
		ON x.OldGRN_ID = oldgrn.GRN_ID
	LEFT JOIN jems.dbo.CR_Materials material 
		ON Analysis.Material_ID = material.Material_ID 
	WHERE 
		c.RepairDateTime >= @StartDate
		AND c.RepairDateTime < @EndDate
		AND WIP.Customer_ID IN (68, 110)
		AND WIP.RMA = 0
		AND material.Material LIKE 'AS%'
		AND NOT (oldgrn.Vendor = '' AND oldgrn.SAPMaskedMPN = '' AND material.Material LIKE '%$%') 
	GROUP BY oldgrn.SAPMaskedMPN, oldgrn.Vendor, material.Material;
	
	-- Aggregate consumed and failed data 
	INSERT INTO ARISTA_DPPM_REPORT
	SELECT 
		COALESCE(Consumed.JPN, Failed.JPN) AS JabilPartNumber,
		COALESCE(Consumed.AristaPartNumber, Failed.AristaPartNumber) AS AristaPartNumber,
		COALESCE(Consumed.Supplier, Failed.Supplier) AS Supplier,
		COALESCE(Consumed.MPN, Failed.MPN) AS MPN,
		ISNULL(Consumed.ConsumedQty, 0) AS ConsumedQty,
		ISNULL(Failed.FailedQty, 0) AS FailedQty,
		COALESCE(Consumed.RouteStepStartDate, Failed.TestDate) AS StartDate,
		GETDATE() AS InsertDatetime,
		CAST(GETDATE() AS DATE) AS SnapshotDate
	FROM #Temp_ConsumedQty Consumed
	FULL JOIN #temp_FailedQty Failed
		ON Consumed.JPN = Failed.JPN
		AND Consumed.Supplier = Failed.Supplier
		AND Consumed.MPN = Failed.MPN
		AND Consumed.RouteStepStartDate = Failed.TestDate

END;
GO
