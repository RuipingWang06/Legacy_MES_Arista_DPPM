
declare	@SerialNumber nvarchar(50) = 'JPG2508PD2H',
	@Customer_ID int =110

-- ------------------------------------------------------------------------------------------
-- System:	MES
-- Section:	WP_WIP.ListCRDs
-- Procedure:	up_CT_ListCRDsBySerialNumberByCustomer
-- Purpose:	Used to List CRDs by Serial Number and Customer
-- Original:		By:	
-- Prerequisites: 
-- ------------------------------------------------------------------------------------------
-- Maintenance History
-- Date			Name			Change
-- -----------  --------------  -----------------------------------------------
-- 3/30/2006	rvb				Optimization
-- 10/25/2012   JC Mow			add filter by Equipment
-- 10/10/2013	JC Mow			PR3997: Enabled filtering on CRD base on board offset in panel setup
-- 01/27/2014	JC Mow			Rollback PR3997
-- ------------------------------------------------------------------------------------------ 
BEGIN

set nocount on
set rowcount 0
declare @RouteStep_ID int
declare @StartTime datetime
declare @Wip_ID int

select @Wip_ID = a.WIP_ID
from dbo.WP_Wip a with (nolock)
where a.SerialNumber = @SerialNumber and a.Customer_ID = @Customer_ID

set forceplan on

create table #CRDs (
	CRD nvarchar(27) COLLATE SQL_Latin1_General_CP1_CI_AS not null,
	Material nvarchar(18) COLLATE SQL_Latin1_General_CP1_CI_AS not null,
	Descr nvarchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS not null,
	GRN nvarchar(16) COLLATE SQL_Latin1_General_CP1_CI_AS not null,
	Vendor nvarchar(35) COLLATE SQL_Latin1_General_CP1_CI_AS not null
	)

if (@@ERROR <> 0)
begin
	RAISERROR('up_CT_ListCRDsBySerialNumber: Unable to create temp table!',18,1)

end
--distinct
insert #CRDs
select h.CRD, f.Material, f.Descr, e.GRN, e.Vendor
from (select b.RouteStep_ID, b.StartTime, b.EndTime, b.WIP_ID, b.Equipment_ID from dbo.WP_WipRouteSteps b with (nolock) where b.Wip_ID = @Wip_ID) z,
	(select Assembly_ID from dbo.WP_AssemblyRouteWIP wparw WITH (NOLOCK) where wparw.WIP_ID = @WIP_ID) y,
	dbo.CT_EquipmentSetup c with (nolock), dbo.CT_ComponentUse d with (nolock, index(IX_CT_ComponentUse_1)),
	dbo.CR_GRNs e with (nolock), dbo.CR_Materials f with (nolock, index (PK_CR_Materials)),
	dbo.CT_EquipmentSetupFeeders g with (nolock, index(IX_CT_EquipmentSetupFeeders)), dbo.CT_FeederCRDs h with (nolock)
where c.RouteStep_ID = z.RouteStep_ID and c.Assembly_ID = y.Assembly_ID AND c.Equipment_ID = z.Equipment_ID
	and c.EquipmentSetup_ID = d.EquipmentSetup_ID
	--and z.StartTime between d.LoadTime and isnull(d.RemovalTime, '20501231')
	and ((z.StartTime between d.LoadTime and d.RemovalTime) or (z.StartTime >= d.LoadTime and d.RemovalTime is null)
		or (z.EndTime between d.LoadTime and d.RemovalTime) or (z.EndTime >= d.LoadTime and d.RemovalTime is null))
	and d.GRN_ID = e.GRN_ID and e.Material_ID = f.Material_ID and c.EquipmentSetup_ID = g.EquipmentSetup_ID
	and g.FeederTrayTrack_ID = d.FeederTrayTrack_ID and g.Feeder_ID = h.Feeder_ID
	and Not Exists (Select grnr.WIP_ID from dbo.QM_GRNReplacement grnr WITH (NOLOCK) Where grnr.WIP_ID = @WIP_ID
					and grnr.NewGRN_ID > 0 and grnr.CRD = h.CRD)
group by f.Material, f.Descr, h.CRD, e.GRN, e.Vendor

union
select h.CRD, f.Material, f.Descr, e.GRN, e.Vendor
from (select Assembly_ID from dbo.WP_AssemblyRouteWIP wparw WITH (NOLOCK) where wparw.WIP_ID = @WIP_ID) y,
	(select b.RouteStep_ID, b.StartTime, b.EndTime, b.WIP_ID from dbo.WP_WipRouteSteps b with (nolock) where b.Wip_ID = @Wip_ID) x,
	dbo.CT_RouteStepSetup c with (nolock), dbo.CT_ComponentUseBins d with (nolock, index (IX_CT_ComponentUseBins_1)),
	dbo.CR_GRNs e with (nolock), dbo.CR_Materials f with (nolock, index (PK_CR_Materials)),
	dbo.CT_RouteStepSetupBins g with (nolock, index(IX_CT_RouteStepSetupBins)), dbo.CT_BinCRDs h with (nolock)
where c.Assembly_ID = y.Assembly_ID and c.RouteStep_ID = x.RouteStep_ID and c.RouteStepSetup_ID = d.RouteStepSetup_ID
	--and x.StartTime between d.LoadTime and isnull(d.RemovalTime, '20501231')
	and ((x.StartTime between d.LoadTime and d.RemovalTime) or (x.StartTime >= d.LoadTime and d.RemovalTime is null)
		or (x.EndTime between d.LoadTime and d.RemovalTime) or (x.EndTime >= d.LoadTime and d.RemovalTime is null))
	and d.GRN_ID = e.GRN_ID and e.Material_ID = f.Material_ID and g.RouteStepSetup_ID = d.RouteStepSetup_ID
	and g.Bin = d.Bin and g.RouteStepSetupBin_ID = h.RouteStepSetupBin_ID
	and Not Exists (Select grnr.WIP_ID from dbo.QM_GRNReplacement grnr WITH (NOLOCK) Where grnr.WIP_ID = @WIP_ID
					and grnr.NewGRN_ID > 0 and grnr.CRD = h.CRD)
group by f.Material, f.Descr, h.CRD, e.GRN, e.Vendor
--order by e.GRN, f.Material, h.CRD

Union
Select grnr.CRD, mat.Material, mat.Descr, grn.GRN, grn.Vendor
From dbo.QM_GRNReplacement grnr WITH (NOLOCK), dbo.CR_GRNS grn WITH (NOLOCK), dbo.CR_Materials mat WITH (NOLOCK)
Where grnr.WIP_ID = @WIP_ID and grnr.NewGRN_ID > 0 and grnr.NewGRN_ID = grn.GRN_ID and grn.Material_ID = mat.Material_ID
Group By grnr.CRD, mat.Material, mat.Descr, grn.GRN, grn.Vendor

if (@@ERROR <> 0)
begin
	drop table #CRDs
	RAISERROR('up_CT_ListCRDsBySerialNumber: Unable to insert temp table!',18,1)

end

select distinct CRD, Material, Descr, GRN, Vendor
from #CRDs
group by CRD, Material, Descr, GRN, Vendor
order by CRD, Material, Descr, GRN

if (@@ERROR <> 0)
begin
	drop table #CRDs
	RAISERROR('up_CT_ListCRDsBySerialNumber: Unable to select from temp table!',18,1)

end

drop table #CRDs


END