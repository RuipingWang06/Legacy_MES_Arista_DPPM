CREATE  PROCEDURE dbo.up_QM_TestDataListTestAnalysisRepair
	@UserID_ID int,
	@StartDate varchar(50),
	@EndDate varchar(50),
	@AnalysisStartDate varchar(50),
	@AnalysisEndDate varchar(50),
	@AssemblyIDList varchar(8000),
	@CustomerIDList varchar(8000),
	@FamilyIDList varchar(8000),
	@TestFactoryMARouteIDList varchar(8000),
	@TestRouteStepIDList varchar(8000),
	@TestStepIDList varchar(8000),
	@TestEquipmentIDList varchar(8000),
	@TestStatusList varchar(8000),
	@ProcessLoopBegin int,
	@ProcessLoopEnd int,
	@MinimumProcessID int,
	@MinimumAnalysisID int,
	@DefectCategoryIDList varchar(8000),
	@DefectCodeList varchar(8000),
	@ExcludeDefectCodeList varchar(8000),
	@MaterialIDList varchar(8000),
	@ComponentTypeList varchar(8000),
	@SerialNumberList varchar(8000),
	@TestUserIDList varchar(8000),
	@AnalysisUserIDList varchar(8000),
	@RepairUserIDList varchar(8000),
	@CorrectAnalysisOnly bit,
	@ExcludeDefectsNotAssingableToAComponent bit,
	@AssemblyTestSummary bit,
	@TotalTestSummary bit,
	@RouteStepTestSummary bit,
	@TestsWithAnalysisRepairCount bit,
	@ShowRecordsWithAnalysisOnly bit,
	@ShowRecordsWithRepairOnly bit,
	@ExcludeRMABoards bit,
	@ShowDataLabels bit,
	@Language_ID int,
	@MaxCount int
as

-- ------------------------------------------------------------------------------------------
-- System:		MES
-- Section:		Static API
-- Proc:		up_QM_TestDataListTestAnalysisRepair
-- Purpose:		Provides complete test, analysis, and repair information for a wide variety
--			of criteria -- the most complex but most complete of the APIs.
-- Created:		10/20/2006	By:	KCG
-- Last Maint:		By:
-- Called By:		JEMS_2.QM_TestData.ListTestAnalysisRepair
-- Calls To:
--
-- ------------------------------------------------------------------------------------------
-- << Notes >>
-- A date range for the tests is the *only* non-optional parameter. Most everything else is lists.
-- Lots of toggles provide summarized or restricted information....
-- Note that DistinctTestFields only works on the
-- ------------------------------------------------------------------------------------------

begin

set nocount on
set rowcount @MaxCount

declare @StartTime datetime
declare @EndTime datetime
declare @TotalTime int

if not exists(select * from dbo.SC_Users where UserID_ID = @UserID_ID and Active = 1)
	begin
		raiserror ('Invalid User ID - you do not have permission to access the JEMS database',18,1)
		return 1
	end

set @StartTime = dbo.uf_GetDateWithOffset3(getUTCdate())

	declare @testoutput TABLE (WIP_ID int, Process_ID int, SerialNumber nvarchar(50), Assembly_ID int, Number nvarchar(60), Revision nvarchar(20), Version nvarchar(20),
	Customer_ID int, Customer nvarchar(200), Division nvarchar(200), Family_ID int, Family nvarchar(200), TestFactoryMARoute_ID int, TestRouteStep_ID int,
	TestFactory nvarchar(200), TestManufacturingArea nvarchar(200), TestRoute nvarchar(200), TestRouteStep nvarchar(200), TestStep_ID int, TestEquipment_ID int, TestEquipment nvarchar(200),
	TestStartDateTime datetime, TestEndDateTime datetime, TestStatus nchar(1), ProcessLoop int, TestLoop int, TestUserID_ID int, TestUser nvarchar(200),
	DataLabel nvarchar(25), Data_ID int)

	declare @analysisoutput TABLE (AnalysisWIP_ID int, AnalysisProcess_ID int, AnalysisData_ID int, Analysis_ID int, Defect_ID int, Defect nvarchar(200), DefectCategory_ID int,
	DefectCategory nvarchar(200), Material_ID int, Material nvarchar(200), MaterialDescr nvarchar(200), ComponentType nvarchar(10), PinCount int, DefectCount int,
	DefectLocation nvarchar(27), EquipmentOrRouteStep_ID int, IsEquipment int, FeederTrayTrack_ID int, DefectDetail nvarchar(25), AnalysisUserID_ID int, AnalysisUser nvarchar(200),
	AnalysisDateTime datetime)

	declare @repairoutput TABLE (RepairWIP_ID int, RepairProcess_ID int, RepairData_ID int, RepairAnalysis_ID int, Repair_ID int, RepairCategory_ID int, RepairCategory nvarchar(200), RepairedBy_ID int,
	RepairedBy nvarchar(200), RepairDateTime datetime, RepairDetail nvarchar(25), Memo nvarchar(300), OldGRN_ID int, OldGRN nvarchar(16), NewGRN_ID int, NewGRN nvarchar(16))


	/* STEP 1: Lets get the test IDs and analysis IDs we need to look at */

	if (@ShowDataLabels = 1)
	begin
		insert into @testoutput
			select a.WIP_ID, a.Process_ID, b.SerialNumber, a.Assembly_ID, c.Number, c.Revision, c.Version,
			c.Customer_ID int, trans1.Translation Customer, trans2.Translation Division, c.Family_ID, trans3.Translation Family,
			fmrs.FactoryMARoute_ID, a.RouteStep_ID, fmrs.FactoryText TestFactory, fmrs.MAText TestMA, fmrs.RouteText TestRoute,
			fmrs.StepText TestStep, fmrs.Step_ID, equip.Equipment_ID, equip.Equipment, a.StartDateTime, a.StopDateTime, a.TestStatus, a.ProcessLoop, a.TestLoop,
			a.UserID_ID, case f.FirstName when '' then f.LastName else f.FirstName + ' ' + f.LastName end, isnull(g.DataLabel, ''), isnull(g.Data_ID, 0)
			from dbo.QM_TestData a with (nolock)
			inner join dbo.WP_WIP b with (nolock) on a.WIP_ID = b.WIP_ID
			inner join dbo.CR_Assemblies c with (nolock) on a.Assembly_ID = c.Assembly_ID
			inner join dbo.CR_Customers d with (nolock) on c.Customer_ID = d.Customer_ID
			inner join dbo.CR_Text trans1 with (nolock) on d.Customer = trans1.Text_ID
			inner join dbo.CR_Text trans2 with (nolock) on d.Division = trans2.Text_ID
			inner join dbo.CR_Families e with (nolock) on c.Family_ID = e.Family_ID
			inner join dbo.CR_Text trans3 with (nolock) on e.Family = trans3.Text_ID
			inner join dbo.CR_FMRS_V fmrs with (nolock) on a.RouteStep_ID = fmrs.RouteStep_ID
			inner join dbo.CR_Equipment_V equip with (nolock) on a.Equipment_ID = equip.Equipment_ID
			inner join dbo.SC_Users f with (nolock) on a.UserID_ID = f.UserID_ID
			left outer join dbo.QM_DataRec g with (nolock) on a.WIP_ID = g.WIP_ID and a.Process_ID = g.Process_ID
		where
			trans1.Language_ID = @Language_ID and trans2.Language_ID = @Language_ID
			and trans3.Language_ID = @Language_ID and fmrs.Language_ID = @Language_ID
		and	(a.StartDateTime between @StartDate and @EndDate)
		and (
			(@CustomerIDList = '') or
			(c.Customer_ID in (select zz.Customer_ID from CR_Customers zz with (nolock) inner join dbo.uf_SplitValuesToInt(',',@CustomerIDList) zt on zz.Customer_ID = zt.Value))
		    )
		and (
			(@AssemblyIDList = '') or
			(a.Assembly_ID in (select zz.Assembly_ID from CR_Assemblies zz with (nolock) inner join dbo.uf_SplitValuesToInt(',',@AssemblyIDList) zt on zz.Assembly_ID = zt.Value))
		    )
		and (
			(@FamilyIDList = '') or
			(c.Family_ID in (select zz.Family_ID from CR_Families zz with (nolock) inner join dbo.uf_SplitValuesToInt(',',@FamilyIDList) zt on zz.Family_ID = zt.Value))
		    )
		and (
			(@TestFactoryMARouteIDList = '') or
			(fmrs.FactoryMARoute_ID in (select zz.FactoryMARoute_ID from CR_MARoutes zz with (nolock) inner join dbo.uf_SplitValuesToInt(',',@TestFactoryMARouteIDList) zt on zz.FactoryMARoute_ID = zt.Value))
		    )
		and (
			(@TestRouteStepIDList = '') or
			(fmrs.RouteStep_ID in (select zz.RouteStep_ID from CR_RouteSteps zz with (nolock) inner join dbo.uf_SplitValuesToInt(',',@TestRouteStepIDList) zt on zz.RouteStep_ID = zt.Value))
		    )
		and (
			(@TestStepIDList = '') or
			(fmrs.Step_ID in (select zz.Step_ID from CR_Steps zz with (nolock) inner join dbo.uf_SplitValuesToInt(',',@TestStepIDList) zt on zz.Step_ID = zt.Value))
		    )
		and (
			(@TestEquipmentIDList = '') or
			(a.Equipment_ID in (select zz.Equipment_ID from CR_Equipment zz with (nolock) inner join dbo.uf_SplitValuesToInt(',',@TestEquipmentIDList) zt on zz.Equipment_ID = zt.Value))
		    )
		and (
			(@SerialNumberList = '') or
			(a.WIP_ID in (select zz.WIP_ID from WP_WIP zz with (nolock) inner join dbo.uf_SplitValuesToChar(',',@SerialNumberList) zt on zz.SerialNumber = zt.Value))
		    )
		and (
			(@TestUserIDList = '') or
			(a.UserID_ID in (select zz.UserID_ID from SC_Users zz with (nolock) inner join dbo.uf_SplitValuesToInt(',',@TestUserIDList) zt on zz.UserID_ID = zt.Value))
		    )
		and (
			(@TestUserIDList = '') or
			(a.UserID_ID in (select zz.UserID_ID from SC_Users zz with (nolock) inner join dbo.uf_SplitValuesToInt(',',@TestUserIDList) zt on zz.UserID_ID = zt.Value))
		    )
		and (
			(@TestStatusList = '') or
			(a.TestStatus in (select zy.Translation from QM_TestStatus zz inner join CR_Text zy on zz.TestStatus = zy.Text_ID inner join dbo.uf_SplitValuesToChar(',',@TestStatusList) zt on zy.Translation = zt.Value where zy.Language_ID = 0))
		    )
		and a.ProcessLoop between @ProcessLoopBegin and @ProcessLoopEnd
		and a.Process_ID >= @MinimumProcessID
		and ((@ExcludeRMABoards = 0) or (@ExcludeRMABoards = 1 and b.RMA = 0))
	end
	else
	begin
		insert into @testoutput
			select a.WIP_ID, a.Process_ID, b.SerialNumber, a.Assembly_ID, c.Number, c.Revision, c.Version,
			c.Customer_ID int, trans1.Translation Customer, trans2.Translation Division, c.Family_ID, trans3.Translation Family,
			fmrs.FactoryMARoute_ID, a.RouteStep_ID, fmrs.FactoryText TestFactory, fmrs.MAText TestMA, fmrs.RouteText TestRoute,
			fmrs.StepText TestStep, fmrs.Step_ID, equip.Equipment_ID, equip.Equipment, a.StartDateTime, a.StopDateTime, a.TestStatus, a.ProcessLoop, a.TestLoop,
			a.UserID_ID, case f.FirstName when '' then f.LastName else f.FirstName + ' ' + f.LastName end, '' DataLabel, 0 Data_ID
			from dbo.QM_TestData a with (nolock)
			inner join dbo.WP_WIP b with (nolock) on a.WIP_ID = b.WIP_ID
			inner join dbo.CR_Assemblies c with (nolock) on a.Assembly_ID = c.Assembly_ID
			inner join dbo.CR_Customers d with (nolock) on c.Customer_ID = d.Customer_ID
			inner join dbo.CR_Text trans1 with (nolock) on d.Customer = trans1.Text_ID
			inner join dbo.CR_Text trans2 with (nolock) on d.Division = trans2.Text_ID
			inner join dbo.CR_Families e with (nolock) on c.Family_ID = e.Family_ID
			inner join dbo.CR_Text trans3 with (nolock) on e.Family = trans3.Text_ID
			inner join dbo.CR_FMRS_V fmrs with (nolock) on a.RouteStep_ID = fmrs.RouteStep_ID
			inner join dbo.CR_Equipment_V equip with (nolock) on a.Equipment_ID = equip.Equipment_ID
			inner join dbo.SC_Users f with (nolock) on a.UserID_ID = f.UserID_ID
		where
			trans1.Language_ID = @Language_ID and trans2.Language_ID = @Language_ID
			and trans3.Language_ID = @Language_ID and fmrs.Language_ID = @Language_ID
		and	(a.StartDateTime between @StartDate and @EndDate)
		and (
			(@CustomerIDList = '') or
			(c.Customer_ID in (select zz.Customer_ID from CR_Customers zz with (nolock) inner join dbo.uf_SplitValuesToInt(',',@CustomerIDList) zt on zz.Customer_ID = zt.Value))
		    )
		and (
			(@AssemblyIDList = '') or
			(a.Assembly_ID in (select zz.Assembly_ID from CR_Assemblies zz with (nolock) inner join dbo.uf_SplitValuesToInt(',',@AssemblyIDList) zt on zz.Assembly_ID = zt.Value))
		    )
		and (
			(@FamilyIDList = '') or
			(c.Family_ID in (select zz.Family_ID from CR_Families zz with (nolock) inner join dbo.uf_SplitValuesToInt(',',@FamilyIDList) zt on zz.Family_ID = zt.Value))
		    )
		and (
			(@TestFactoryMARouteIDList = '') or
			(fmrs.FactoryMARoute_ID in (select zz.FactoryMARoute_ID from CR_MARoutes zz with (nolock) inner join dbo.uf_SplitValuesToInt(',',@TestFactoryMARouteIDList) zt on zz.FactoryMARoute_ID = zt.Value))
		    )
		and (
			(@TestRouteStepIDList = '') or
			(fmrs.RouteStep_ID in (select zz.RouteStep_ID from CR_RouteSteps zz with (nolock) inner join dbo.uf_SplitValuesToInt(',',@TestRouteStepIDList) zt on zz.RouteStep_ID = zt.Value))
		    )
		and (
			(@TestStepIDList = '') or
			(fmrs.Step_ID in (select zz.Step_ID from CR_Steps zz with (nolock) inner join dbo.uf_SplitValuesToInt(',',@TestStepIDList) zt on zz.Step_ID = zt.Value))
		    )
		and (
			(@TestEquipmentIDList = '') or
			(a.Equipment_ID in (select zz.Equipment_ID from CR_Equipment zz with (nolock) inner join dbo.uf_SplitValuesToInt(',',@TestEquipmentIDList) zt on zz.Equipment_ID = zt.Value))
		    )
		and (
			(@SerialNumberList = '') or
			(a.WIP_ID in (select zz.WIP_ID from WP_WIP zz with (nolock) inner join dbo.uf_SplitValuesToChar(',',@SerialNumberList) zt on zz.SerialNumber = zt.Value))
		    )
		and (
			(@TestUserIDList = '') or
			(a.UserID_ID in (select zz.UserID_ID from SC_Users zz with (nolock) inner join dbo.uf_SplitValuesToInt(',',@TestUserIDList) zt on zz.UserID_ID = zt.Value))
		    )
		and (
			(@TestUserIDList = '') or
			(a.UserID_ID in (select zz.UserID_ID from SC_Users zz with (nolock) inner join dbo.uf_SplitValuesToInt(',',@TestUserIDList) zt on zz.UserID_ID = zt.Value))
		    )
		and (
			(@TestStatusList = '') or
			(a.TestStatus in (select zy.Translation from QM_TestStatus zz inner join CR_Text zy on zz.TestStatus = zy.Text_ID inner join dbo.uf_SplitValuesToChar(',',@TestStatusList) zt on zy.Translation = zt.Value where zy.Language_ID = 0))
		    )
		and a.ProcessLoop between @ProcessLoopBegin and @ProcessLoopEnd
		and a.Process_ID >= @MinimumProcessID
		and ((@ExcludeRMABoards = 0) or (@ExcludeRMABoards = 1 and b.RMA = 0))
	end

	-- We now have the tests that we can grab analysis records for...

	if (@AssemblyTestSummary = 0) and (@RouteStepTestSummary = 0) and (@TotalTestSummary = 0)
	begin
		insert into @analysisoutput
			select a.WIP_ID, a.Process_ID, a.Data_ID, b.Analysis_ID, c.Defect_ID, trans1.Translation Defect, d.DefectCategory_Id, trans2.Translation DefectCategory,
			c.Material_ID, f.Material, f.Descr, f.ComponentType, f.PinCount, c.DefectCount, c.DefectLocation, c.EquipmentOrRouteStep_ID, c.IsEquipment,
			c.FeederTrayTrack_ID, c.DefectDetail, c.AnalysisBy_ID, case g.FirstName when '' then g.LastName else g.FirstName + ' ' + g.LastName end,
			--fmrs.FactoryMARoute_ID, c.RouteStep_ID,
			--fmrs.FactoryText TestFactory, fmrs.MAText TestMA, fmrs.RouteText TestRoute,
			--fmrs.StepText TestStep, fmrs.Step_ID,
			c.AnalysisDateTime
			from @testoutput a
			inner join dbo.QM_DataAnalysis b with (nolock) on a.WIP_ID = b.WIP_ID and a.Process_ID = b.Process_ID and a.Data_ID = b.Data_ID
			inner join dbo.QM_Analysis c with (nolock) on b.Analysis_ID = c.Analysis_ID
			inner join dbo.QM_Defects d with (nolock) on c.Defect_ID = d.Defect_ID
			inner join dbo.CR_Text trans1 with (nolock) on d.Defect = trans1.Text_ID
			inner join dbo.QM_DefectCategory e with (nolock) on d.DefectCategory_ID = e.DefectCategory_ID
			inner join dbo.CR_Text trans2 with (nolock) on e.DefectCategory = trans2.Text_ID
			inner join dbo.CR_Materials f with (nolock) on c.Material_ID = f.Material_ID
			inner join dbo.SC_Users g with (nolock) on c.AnalysisBy_ID = g.UserID_ID
			--inner join dbo.CR_FMRS_V fmrs with (nolock) on c.RouteStep_ID = fmrs.RouteStep_ID
			where a.Data_ID <> 0
			and b.AssociatedDefectFlag = 'F'
			and ((@CorrectAnalysisOnly = 0) or (@CorrectAnalysisOnly = 1 and b.AnalysisStatus = 'C'))
			and trans1.Language_ID = @Language_ID and trans2.Language_ID = @Language_ID
			--and fmrs.Language_ID = @Language_ID
			and (
				(@AnalysisUserIDList = '') or
				(c.AnalysisBy_ID in (select zz.UserID_ID from SC_Users zz with (nolock) inner join dbo.uf_SplitValuesToInt(',',@AnalysisUserIDList) zt on zz.UserID_ID = zt.Value))
			    )
			and (
				(@DefectCodeList = '') or
				(c.Defect_ID in (select zz.Defect_ID from QM_Defects zz with (nolock) inner join dbo.uf_SplitValuesToInt(',',@DefectCodeList) zt on zz.Defect_ID = zt.Value))
			    )
			and (
				(@DefectCategoryIDList = '') or
				(d.DefectCategory_ID in (select zz.DefectCategory_ID from QM_DefectCategory zz with (nolock) inner join dbo.uf_SplitValuesToInt(',',@DefectCategoryIDList) zt on zz.DefectCategory_ID = zt.Value))
			    )
			and (
				(@ExcludeDefectCodeList = '') or
				(c.Defect_ID not in (select zz.Defect_ID from QM_Defects zz with (nolock) inner join dbo.uf_SplitValuesToInt(',',@ExcludeDefectCodeList) zt on zz.Defect_ID = zt.Value))
			    )
			and (
				(@MaterialIDList = '') or
				(c.Material_ID in (select zz.Material_ID from CR_Materials zz with (nolock) inner join dbo.uf_SplitValuesToInt(',',@MaterialIDList) zt on zz.Material_ID = zt.Value))
			    )
			and (
				(@ComponentTypeList = '') or
				(f.ComponentType in (select distinct zz.ComponentType from CR_Materials zz with (nolock) inner join dbo.uf_SplitValuesToChar(',',@ComponentTypeList) zt on zz.ComponentType = zt.Value))
			    )
			and AnalysisDateTime between case @AnalysisStartDate when '' then '1/1/1980' else @AnalysisStartDate end and case @AnalysisEndDate when '' then '1/1/2099' else @AnalysisEndDate end
			and ((@ExcludeDefectsNotAssingableToAComponent=0) or (@ExcludeDefectsNotAssingableToAComponent=1 and c.Material_ID <> 0))
			and c.Analysis_ID >= @MinimumAnalysisID

		insert into @repairoutput
			select a.WIP_ID, a.Process_ID, a.Data_ID, b.Analysis_ID, b.Repair_ID, c.RepairCategory_ID, trans1.Translation RepairCategory, c.RepairedBy_ID,
			case g.FirstName when '' then g.LastName else g.FirstName + ' ' + g.LastName end, c.RepairDateTime, c.RepairDetail, c.Memo,
			x.OldGRN_ID, y.GRN, x.NewGRN_ID, yy.GRN
			from @testoutput a
			inner join dbo.QM_DataAnalysis b with (nolock) on a.WIP_ID = b.WIP_ID and a.Process_ID = b.Process_ID and a.Data_ID = b.Data_ID
			inner join dbo.QM_Repair c with (nolock) on b.Repair_ID = c.Repair_ID
			inner join @analysisoutput d on b.WIP_ID = d.AnalysisWIP_ID and b.Process_ID = d.AnalysisProcess_ID and b.Analysis_ID = d.Analysis_ID
			inner join dbo.QM_RepairCategory e with (nolock) on c.RepairCategory_ID = e.RepairCategory_ID
			inner join dbo.CR_Text trans1 with (nolock) on e.RepairCategory = trans1.Text_ID
			inner join dbo.SC_Users g with (nolock) on c.RepairedBy_ID = g.UserID_ID
			Left Outer Join dbo.QM_GRNReplacement x with (nolock) On c.Repair_ID = x.Repair_ID
   			Left Outer Join dbo.CR_GRNs y with (nolock) On x.NewGRN_ID = y.GRN_ID
		        Left Outer Join dbo.CR_GRNs yy with (nolock) On x.OldGRN_ID = yy.GRN_ID
			where a.Data_ID <> 0
			and b.Repair_ID <> 0
			and b.AssociatedDefectFlag = 'F'
			and trans1.Language_ID = @Language_ID
			and ((@CorrectAnalysisOnly = 0) or (@CorrectAnalysisOnly = 1 and b.AnalysisStatus = 'C'))
			and (
				(@RepairUserIDList = '') or
				(c.RepairedBy_ID in (select zz.UserID_ID from SC_Users zz with (nolock) inner join dbo.uf_SplitValuesToInt(',',@RepairUserIDList) zt on zz.UserID_ID = zt.Value))
			    )
	end


	if (@AssemblyTestSummary = 1)
	begin
		select Assembly_ID, Number, Revision, Version, Customer_ID, Customer, Division, Family_ID, Family,
		sum(case TestStatus when 'P' then 1 else 0 end) PassRecords,
		sum(case TestStatus when 'F' then 1 else 0 end) FailRecords,
		sum(case TestStatus when 'A' then 1 else 0 end) AbortRecords
		from @testoutput
		group by Assembly_ID, Number, Revision, Version, Customer_ID, Customer, Division, Family_ID, Family
		order by Number, Revision, Version
	end
	else if (@RouteStepTestSummary = 1)
	begin
		select TestFactoryMARoute_ID, TestRouteStep_ID, TestFactory, TestManufacturingArea, TestRoute, TestRouteStep,
		sum(case TestStatus when 'P' then 1 else 0 end) PassRecords,
		sum(case TestStatus when 'F' then 1 else 0 end) FailRecords,
		sum(case TestStatus when 'A' then 1 else 0 end) AbortRecords
		from @testoutput
		group by TestFactoryMARoute_ID, TestRouteStep_ID, TestFactory, TestManufacturingArea, TestRoute, TestRouteStep
		order by TestFactory, TestManufacturingArea, TestRoute, TestRouteStep
	end
	else if (@TotalTestSummary = 1)
	begin
		select
		sum(case TestStatus when 'P' then 1 else 0 end) PassRecords,
		sum(case TestStatus when 'F' then 1 else 0 end) FailRecords,
		sum(case TestStatus when 'A' then 1 else 0 end) AbortRecords
		from @testoutput
	end
	else if (@TestsWithAnalysisRepairCount = 1)
	begin
		select distinct a.WIP_ID, a.Process_ID, a.SerialNumber, a.Assembly_ID, a.Number, a.Revision, a.Version, a.Customer_ID, a.Customer, a.Division, a.Family_ID,
		a.Family, a.TestFactoryMARoute_ID, a.TestRouteStep_ID, a.TestFactory, a.TestManufacturingArea, a.TestRoute, a.TestRouteStep, a.TestStep_ID, a.TestEquipment_ID,
		a.TestEquipment, a.TestStartDateTime, a.TestEndDateTime, a.TestStatus, a.ProcessLoop, a.TestLoop, a.TestUserID_ID, a.TestUser,
		count (a.DataLabel) DataLabelCount,
		count(b.AnalysisWIP_ID) AnalysisRecords, count(c.RepairWIP_ID) RepairRecords
		from @testoutput a
		left outer join @analysisoutput b on a.WIP_ID = b.AnalysisWIP_ID and a.Process_ID = b.AnalysisProcess_ID and a.Data_ID = b.AnalysisData_ID
		left outer join @repairoutput c on b.AnalysisWIP_ID = c.RepairWIP_ID and b.AnalysisProcess_ID = c.RepairProcess_ID and b.AnalysisData_ID = c.RepairData_ID and b.Analysis_ID = c.RepairAnalysis_ID
		group by a.WIP_ID, a.Process_ID, a.SerialNumber, a.Assembly_ID, a.Number, a.Revision, a.Version, a.Customer_ID, a.Customer, a.Division, a.Family_ID,
		a.Family, a.TestFactoryMARoute_ID, a.TestRouteStep_ID, a.TestFactory, a.TestManufacturingArea, a.TestRoute, a.TestRouteStep, a.TestStep_ID, a.TestEquipment_ID,
		a.TestEquipment, a.TestStartDateTime, a.TestEndDateTime, a.TestStatus, a.ProcessLoop, a.TestLoop, a.TestUserID_ID, a.TestUser
		order by a.TestStartDateTime desc
	end
	else if (@ShowRecordsWithRepairOnly = 1)
	begin
		select a.*, b.*, c.*
		from @testoutput a
		inner join @analysisoutput b on a.WIP_ID = b.AnalysisWIP_ID and a.Process_ID = b.AnalysisProcess_ID and a.Data_ID = b.AnalysisData_ID
		inner join @repairoutput c on b.AnalysisWIP_ID = c.RepairWIP_ID and b.AnalysisProcess_ID = c.RepairProcess_ID and b.AnalysisData_ID = c.RepairData_ID and b.Analysis_ID = c.RepairAnalysis_ID
		order by a.TestStartDateTime desc
	end
	else if (@ShowRecordsWithAnalysisOnly = 1)
	begin
		select a.*, b.*, c.*
		from @testoutput a
		inner join @analysisoutput b on a.WIP_ID = b.AnalysisWIP_ID and a.Process_ID = b.AnalysisProcess_ID and a.Data_ID = b.AnalysisData_ID
		left outer join @repairoutput c on b.AnalysisWIP_ID = c.RepairWIP_ID and b.AnalysisProcess_ID = c.RepairProcess_ID and b.AnalysisData_ID = c.RepairData_ID and b.Analysis_ID = c.RepairAnalysis_ID
		order by a.TestStartDateTime desc
	end
	else
	begin
		select a.*, b.*, c.*
		from @testoutput a
		left outer join @analysisoutput b on a.WIP_ID = b.AnalysisWIP_ID and a.Process_ID = b.AnalysisProcess_ID and a.Data_ID = b.AnalysisData_ID
		left outer join @repairoutput c on b.AnalysisWIP_ID = c.RepairWIP_ID and b.AnalysisProcess_ID = c.RepairProcess_ID and b.AnalysisData_ID = c.RepairData_ID and b.Analysis_ID = c.RepairAnalysis_ID
		order by a.TestStartDateTime desc
	end


set rowcount 0

set @EndTime = dbo.uf_GetDateWithOffset3(getUTCdate())
set @TotalTime = isnull(datediff(millisecond, @StartTime, @EndTime),0)

insert dbo.CR_AuditLog
	values ('up_QM_TestDataListTestAnalysisRepair', @TotalTime, @UserID_ID, @StartTime )

return 0

end
