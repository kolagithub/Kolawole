--USE [WapX_TEST]
--GO

--/****** Object:  StoredProcedure [dbo].[CLM_ES_GEN_Claims_Outstanding_Report]    Script Date: 01-Jul-19 11:39:25 AM ******/
--SET ANSI_NULLS ON
--GO

--SET QUOTED_IDENTIFIER ON
--GO



--/* 24-11-2017 - new field accounting  org. unit name and description
--    5-3-2018 eleminantion duplicated records because of correspondence - more exec. DV */

CREATE procedure[dbo].[CLM_ES_GEN_Claims_Outstanding_Report]
@CULTURE_ID bigint, 
@BranchCode NVARCHAR(40), 
@DepartmentCode NVARCHAR(40), 
@ClassCode NVARCHAR(20), 
@ProductCode NVARCHAR(20), 
@AsAtDate datetime 

as begin 


--declare
--@CULTURE_ID bigint  =3,
--@BranchCode NVARCHAR(40)  = 'GEN',
--@DepartmentCode NVARCHAR(40)  = null, --'LI'
--@ClassCode NVARCHAR(20) = '', --null ; --brand code
--@ProductCode NVARCHAR(20)  = '',
--@AsAtDate datetime  = '20180305';



WITH 
--claim data
clm as (
		SELECT 
			 clm.ORGUNIT_ADMIN_ID, clm.CLAIM_ID, clm.CLMNO as claim_number, clm.POLICY_POLICY_ID 
			,clm.NOTIFICATION_DATE , clm.OCCURENCE_DATE as LOSS_DATE, clm.SETTLEMENT_DATE
			,clm.REGISTRATION_DATE
			,cst.CODE as claim_status_code
			,cst.DESCRIPTION as claim_status
			,losn.ADDRESS_STREET	as loss_street
			,losn.ADDRESS_HOUSE_NUMBER1	as loss_house_number1
			,losn.ADDRESS_HOUSE_NUMBER2	as loss_house_number2
			,losn.ADDRESS_CITY			as loss_city
			,losn.POSTAL_CODE			as loss_postal_code
			,losn.OCCURENCE_PLACE_DESCRIPTION	as loss_place
			,losn.LOSS_DESCRIPTION		as LOSS_DESCRIPTION
			, ou.CODE as department, ou.ABBREV as department_code, ou.NAME as department_name, ol.LEVEL_NO as department_level_no, ol.NAME as department_level_name
			, ou_branch.branch, ou_branch.branch_code, ou_branch.branch_name, ou_branch.branch_level_no, ou_branch.branch_level_name,clm.payment_identifier as Voucher_No
		from CLM_D_CLAIM clm
			JOIN CLM_D_CL_CLAIM_ST cst on cst.CCLMST_ID = clm.CCLMST_CCLMST_ID and cst.CULTURE_ID = @CULTURE_ID
			JOIN PAR_D_CL_ORG_UNIT ou on ou.ORGUNIT_ID = clm.ORGUNIT_ADMIN_ID AND ou.CULTURE_ID = @CULTURE_ID
			JOIN PAR_D_CL_ORG_LEVEL ol on ol.ORGLVL_ID = ou.ORGLVL_ORGLVL_ID AND ol.CULTURE_ID = @CULTURE_ID
			LEFT JOIN CLM_D_LOSS_NOTIFICATION losn on losn.LOSNTF_ID = clm.LOSNTF_LOSNTF_ID AND losn.VALID = 1
			LEFT JOIN 
					(  SELECT ou1.ORGUNIT_ID, ou1.CODE as branch, ou1.ABBREV as branch_code, ou1.NAME as branch_name, ol1.LEVEL_NO as branch_level_no, ol1.NAME as branch_level_name
					   FROM PAR_D_CL_ORG_UNIT ou1 
					   JOIN PAR_D_CL_ORG_LEVEL ol1 on ol1.ORGLVL_ID = ou1.ORGLVL_ORGLVL_ID AND ol1.CULTURE_ID = @CULTURE_ID
					   WHERE ou1.CULTURE_ID = @CULTURE_ID
					) ou_branch on ou_branch.ORGUNIT_ID = ou.ORGUNIT_ORGUNIT_ID 
		WHERE clm.VALID = 1
			AND coalesce(null, ou_branch.branch_code, '') = coalesce(ou_branch.branch_code,'')
			AND coalesce(null, ou.ABBREV, '') = coalesce(ou.ABBREV,'')
			AND ol.LEVEL_NO > 1
			--AND coalesce (clm.SETTLEMENT_DATE, @AsAtDate+1 ) > @AsAtDate
			AND case when cst.code not in ('R','SP', 'ZO') 
			AND clm.SETTLEMENT_DATE is null then '19000101' else coalesce (clm.SETTLEMENT_DATE, @AsAtDate+1 )  end > @AsAtDate
			AND clm.REGISTRATION_DATE < @AsAtDate + 1 --because of time part of datetime
			--AND clm.CLMNO = '2017003024'
		UNION ALL
		SELECT 
			 clm.ORGUNIT_ADMIN_ID, clm.CLAIM_ID, clm.CLMNO as claim_number, clm.POLICY_POLICY_ID 
			,clm.NOTIFICATION_DATE , clm.OCCURENCE_DATE as LOSS_DATE, clm.SETTLEMENT_DATE
			,clm.REGISTRATION_DATE
			,cst.CODE as claim_status_code
			,cst.DESCRIPTION as claim_status
			,losn.ADDRESS_STREET	as loss_street
			,losn.ADDRESS_HOUSE_NUMBER1	as loss_house_number1
			,losn.ADDRESS_HOUSE_NUMBER2	as loss_house_number2
			,losn.ADDRESS_CITY			as loss_city
			,losn.POSTAL_CODE			as loss_postal_code
			,losn.OCCURENCE_PLACE_DESCRIPTION	as loss_place
			,losn.LOSS_DESCRIPTION		as LOSS_DESCRIPTION
			, null as department, null as department_code, null as department_name, null as department_level_no, null as department_level_name
			, ou.code as branch, ou.ABBREV as branch_code, ou.NAME as branch_name, ol.LEVEL_NO as branch_level_no, ol.NAME as branch_level_name,clm.payment_identifier as Voucher_No
		from CLM_D_CLAIM clm
			JOIN CLM_D_CL_CLAIM_ST cst on cst.CCLMST_ID = clm.CCLMST_CCLMST_ID and cst.CULTURE_ID = @CULTURE_ID
			JOIN PAR_D_CL_ORG_UNIT ou on ou.ORGUNIT_ID = clm.ORGUNIT_ADMIN_ID AND ou.CULTURE_ID = @CULTURE_ID
			JOIN PAR_D_CL_ORG_LEVEL ol on ol.ORGLVL_ID = ou.ORGLVL_ORGLVL_ID AND ol.CULTURE_ID = @CULTURE_ID
			LEFT JOIN CLM_D_LOSS_NOTIFICATION losn on losn.LOSNTF_ID = clm.LOSNTF_LOSNTF_ID AND losn.VALID = 1
		WHERE clm.VALID = 1
			AND @departmentCode is null
			AND coalesce(@branchCode, ou.abbrev, '') = coalesce(ou.abbrev,'')
			--AND coalesce (clm.SETTLEMENT_DATE, @AsAtDate+1 ) > @AsAtDate
			AND case when cst.code not in ('R','SP', 'ZO') 
			AND clm.SETTLEMENT_DATE is null then '19000101' else coalesce (clm.SETTLEMENT_DATE, @AsAtDate+1 )  end > @AsAtDate
			AND clm.REGISTRATION_DATE < @AsAtDate + 1 --because of datetime time part 
			--AND clm.CLMNO = '2017003024'
)
-----------
, --claim officer
clm_officer as 
		(
		SELECT 
			clm.CLAIM_ID, 
			pp.FIRST_NAME		as phys_person_firstname
			,pp.surname			as phys_person_surname
			,lp.name			as legal_person_name
		FROM CLM_D_CLAIM clm 
			JOIN PAR_D_PARTNER p on p.PARTNER_ID = clm.ADJUSTER AND p.VALID = 1
			LEFT JOIN PAR_D_PHYSICAL_PERSON pp on pp.PARTNER_ROOT_ID = p.PARTNER_ID AND pp.VALID = 1
			left join PAR_D_LEGAL_PERSON lp on lp.PARTNER_ROOT_ID = p.PARTNER_ID ANd lp.VALID = 1
		WHERE clm.VALID = 1
		),

exchange_rate as 
		(
			select p.ccurr_ccurr_id, t.kod, 
			p.foreign_exchange_middle as xRate
			, p.effective_date
			from pay_d_exchange p join pay_t_cis_mena t
			on p.ccurr_ccurr_id = t.cmenak_id
			where  p.effective_date = (select max(effective_date) from pay_d_exchange where ccurr_ccurr_id =p.ccurr_ccurr_id)
		)
-----
SELECT 
	--count(*)
	  clm.branch_code					as SBU_CODE					--1
	, clm.branch_name				as SBU_NAME					--2
	, clm.NOTIFICATION_DATE			as NOTIFICATION_DATE
	, xRate.xRate as Exchange_Rate		--3
	, year(clm.LOSS_DATE)			as Year_of_loss				--4
	, clm.LOSS_DATE					as LOSS_DATE				--5
	,DATEDIFF ( DAY, clm.REGISTRATION_DATE, @AsAtDate) as age	--6	
	,clm.loss_city					as loss_location_CITY		--7
	,clm.loss_street				as loss_location_STREET		--7
	,clm.loss_postal_code			as loss_location_POSTAL_CODE --7
	,clm.loss_house_number1			as loss_location_house_no1	--7
	,clm.loss_house_number2			as loss_location_house_no2	--7
	,clm.loss_place					as loss_location_description --7
	,coalesce(ap.assured_pers,'')	as assured_name				--8
	,coalesce(ap.insured_pers,'')		as insured_name				--8
	,clm.claim_number				as claim_no					--9
	,pol.policy_number				as policy_no				--10
	,pol.UW_Year					as uw_year					--11
	,pol.date_inception				as policy_fm_date			--12
	,pol.date_maturity				as policy_to_date			--13
	,clm.LOSS_DESCRIPTION			as loss_description			--14
	,premium.annual_premium			as gross_premium			--15
	,pp.PAYMENT_AMOUNT				as premium_received			--16	--PAY
	,pp.first_premium_date			as date_prem_recvd_first	--17	--PAY
	,pp.last_premium_date			as date_prem_recvd_last		--17	--PAY
	,'*NOT IN StarINS*'				as date_dv_signed			--18	--not in starins
	,co.corresp_receive_date		as date_dv_recvd			--19	--correspondence
	,co.corresp_create_date			as date_dv_created			--		--correspondence
	,ExtAdj.amount_paid_extadj		as adjuster_fee				--20	--ext_partner_role =  'EXTADJ' - there is not currently this role in starins
	,ExtAdj.ext_payee				as adjusters_name			--21	--ext_partner_role =  'EXTADJ' - there is not currently this role in starins- if there are more external cost payouts for indemnity than 1 then there is first adjuster found
	,resind.indemnity_reserve_balance as claim_estimate_indemnity --22		
	,resext.extcost_reserve_balance as claim_estimate_extcost	--23
	,payout.amount_paid_indemnity	as amount_paid_indemnity	--23
	,payout.amount_paid_extcost		as amount_paid_extcost		--23
	,pay.PAYOUT_AMOUNT				as payout_amount_total		--23
	,case when ExtAdj.amount_paid_extadj is null then 0 else ExtAdj.amount_paid_extadj * coalesce( xRate.xRate, 1)  end 
									as adjuster_fee_ngn
	,case when payout.amount_paid_indemnity is null then 0 else coalesce( xRate.xRate, 1) * payout.amount_paid_indemnity end 
									as amount_paid_indemnity_dom_curr
	,case when payout.amount_paid_extcost is not null then coalesce( xRate.xRate, 1) * payout.amount_paid_extcost else 0 end 
									as amount_paid_extcost_dom_curr
	,case when resind.indemnity_reserve_balance is null then null else coalesce(pay.payout_currency,pol.currency_code)  end     
									as currency_indemnity	   
	,case when resind.indemnity_reserve_balance is null then 0 else coalesce( xRate.xRate, 1) * resind.indemnity_reserve_balance end 
									as claim_estimate_indemnity_dom_curr
	,case when resext.extcost_reserve_balance is not null then coalesce(pay.payout_currency,pol.currency_code) else null end             
									as currency_extcost 
	,case when resext.extcost_reserve_balance is not null then 
		coalesce( xRate.xRate, 1) * resext.extcost_reserve_balance  
		else 0 end as claim_estimate_extcost_dom_curr		
	,coins.PAYOUT_COINS_AMOUNT		as COINSURANCE_RECOVABLE	--24
	--,null							as FAC_RECOVERABLE			--25	--REI 
	--,null							as TREATY_RECOVERABLE		--26	--REI
	,rei1.recoverable				as FAC_RECOVERABLE			--25	--REI 
	,rei2.recoverable				as TREATY_RECOVERABLE		--26	--REI
	,null							as NET_CLAIM_AMOUNT			--27
	,clm.SETTLEMENT_DATE			as settled_date				--28
	,'*NOT IN StarINS*'				as date_rcvd_by_insured		--29	--not in starins
	,DATEDIFF ( DAY, coalesce(co.corresp_receive_date,clm.REGISTRATION_DATE), coalesce (clm.SETTLEMENT_DATE, getdate())) as process_period	--30
	,pol.orgunit_name				as uw_location				--31
	,null							as reason_of_outstanding	--32
	,notes.note						as remarks					--33	
	,premium.insured_sum			AS sum_insured				--34
	,'*NOT IN StarINS*'				as acknow_receipt_date		--35	--PAY
	--------
	,clm.claim_status				as claim_status				
	,pol.currency_code				as policy_currency
	,clm.CLAIM_ID
	,clm.registration_date
	,pol.sysowner
	,gp.group_pol_no                as group_pol_no 
	,gp.group_pol_prod_code         as group_pol_prod_code 
	,gp.group_pol_prod_name         as group_pol_prod_name
	--,pol.sysowner_code
	,@BranchCode					as BranchCode					
	,polB.orgunit_book_code	        as DepartmentCode				  
	,SUBSTRING(pol.product_code,1,2)as ClassCode						
	,pol.product_code				as ProductCode		
	,pol.product_name               as product_name    
	,@AsAtDate						AS AsAtDate
	,pol.acc_orgunit_name           as acc_ou_code  
	,pol.acc_orgunit_description    as acc_ou_description
	,offi.legal_person_name as Claim_Officer_Legal_P
	,offi.phys_person_firstname as Phy_P_Firstname
	,offi.phys_person_surname as Phy_P_Surname
	,ap.agent as Agent_name
	,ap.agent_number as Agent_code
	,payind.surname_name as Beneficiary_Surname
	,payind.name_abbr as Beneficiary_name_abbr
	,payind.middle_name as Beneficiary_middle_name
	,clm.Voucher_No
from clm
	join CLM_DX_POLICY			pol			on pol.policy_id = clm.POLICY_POLICY_ID
	join POL_DX_POLICY_BOOKING polB         on polB.policy_id=clm.POLICY_POLICY_ID
											AND pol.CULTURE_ID = @CULTURE_ID
											AND pol.sysowner_code = 'NONLIFE'
											AND ((pol.product_code like coalesce (@ProductCode, pol.product_code )) or (@ProductCode = ''))
	LEFT JOIN CLM_DX_PREMIUM	premium		on premium.policy_policy_id = clm.POLICY_POLICY_ID
	LEFT join CLM_DX_POLICY_PARTNER ap		on ap.policy_id = clm.POLICY_POLICY_ID
	LEFT JOIN CLM_DX_RESERVE		resind	on resind.claim_id = clm.CLAIM_ID AND resind.culture_id = @CULTURE_ID AND resind .INDEMNITY = 1 
	LEFT JOIN CLM_DX_RESERVE		resext	on resext.claim_id = clm.CLAIM_ID AND resext.culture_id = @CULTURE_ID AND resext.INDEMNITY = 0
	LEFT JOIN CLM_DX_PAYOUT			payout		on payout.claim_id = clm.CLAIM_ID AND payout.culture_id = @CULTURE_ID
	LEFT JOIN CLM_DX_PAYOUT_IND payind on payout.claim_id = payind.claim_id AND payind.culture_id = @CULTURE_ID
	LEFT JOIN (select claim_id,max(corresp_receive_date) as corresp_receive_date, 	min(corresp_create_date)	as corresp_create_date 
				from CLM_DX_CORRESPONDENCE ccx where ccx.culture_id = @CULTURE_ID group by ccx.claim_id) co on co.claim_id = clm.claim_id 
	LEFT JOIN CLM_DX_PAY_PAYOUT		pay	on pay.claim_id = clm.claim_id AND pay.CULTURE_ID = @CULTURE_ID
	LEFT JOIN clm_dx_pay_coinsurer coins	on coins.claim_id = clm.CLAIM_ID 
	LEFT JOIN CLM_DX_PAY_PREMIUM	 pp on pp.policy_id = clm.POLICY_POLICY_ID AND pp.culture_id = @CULTURE_ID
	LEFT JOIN CLM_DX_EXT_COST_BY_ROLE ExtAdj	on ExtAdj.claim_id = clm.CLAIM_ID AND ExtAdj.culture_id = @CULTURE_ID AND ExtAdj.role_code = 'EXTADJ'
	LEFT JOIN CLM_DX_NOTE			 Notes		on notes.CLAIM_ID = clm.CLAIM_ID AND notes.culture_id = @CULTURE_ID
	LEFT JOIN clm_officer offi	on offi.CLAIM_ID = clm.CLAIM_ID
	LEFT JOIN rei_dx_clm_brdr_sum_recoverable rei1 on rei1.claim_id = clm.CLAIM_ID AND rei1.contr_type_code like 'F%' --FAC recoverable
	LEFT JOIN rei_dx_clm_brdr_sum_recoverable rei2 on rei2.claim_id = clm.CLAIM_ID AND rei2.contr_type_code like 'O%' --Treaty recoverable
	LEFT JOIN CLM_DX_POLICY_GROUP gp on gp.policy_id = pol.policy_id and gp.culture_id = @CULTURE_ID
	LEFT JOIN exchange_rate xRate on xRate.kod = pol.currency_code
	--LEFT JOIN exchange_rate xRateAdj on xRateAdj.kod = pol.currency_code
WHERE clm.claim_status_code NOT IN ('B','Z')

END

--commit;




GO


