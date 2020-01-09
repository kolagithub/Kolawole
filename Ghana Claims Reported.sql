--USE [WapX_TEST]
--GO

--/****** Object:  StoredProcedure [dbo].[CLM_ES_GEN_Claims_reported_for_a_period]    Script Date: 02-Jul-19 10:40:57 AM ******/
--SET ANSI_NULLS ON
--GO

--SET QUOTED_IDENTIFIER ON
--GO


--/* 24-11-2017 - new field accounting  org. unit name and description
--   6.12.2017 - remove duplicity caused by recieved DV - now here is last one from all
--*/
---- exec CLM_ES_GEN_Claims_reported_for_a_period 3, null,null,null,null, '20170210', '20170215'
CREATE procedure[dbo].[CLM_ES_GEN_Claims_reported_for_a_period]
@Culture_id bigint, 
@BranchCode NVARCHAR(40), 
@DepartmentCode NVARCHAR(40), 
@ClassCode NVARCHAR(20), 
@ProductCode NVARCHAR(20), 
@ClaimIntimationDateFrom datetime, 
@ClaimIntimationDateTo datetime 

as begin 


--declare
--@Culture_id bigint  = 3,
--@BranchCode NVARCHAR(40)  = 'GEN',
--@DepartmentCode NVARCHAR(40)  = null, --'LI'
--@ClassCode NVARCHAR(20) = '', --null ; --brand code
--@ProductCode NVARCHAR(20)  = '',
--@ClaimIntimationDateFrom datetime  = '20170905',
--@ClaimIntimationDateTo datetime  = '20170906';


WITH 
--claim data
clm as (
			SELECT 
				 clm.ORGUNIT_ADMIN_ID, clm.CLAIM_ID, clm.CLMNO as claim_number, clm.POLICY_POLICY_ID 
				,clm.NOTIFICATION_DATE , clm.OCCURENCE_DATE as LOSS_DATE, clm.SETTLEMENT_DATE
				,clm.REGISTRATION_DATE
				,cst.DESCRIPTION as claim_status
				,losn.ADDRESS_STREET	as loss_street
				,losn.ADDRESS_HOUSE_NUMBER1	as loss_house_number1
				,losn.ADDRESS_HOUSE_NUMBER2	as loss_house_number2
				,losn.ADDRESS_CITY			as loss_city
				,losn.POSTAL_CODE			as loss_postal_code
				,losn.OCCURENCE_PLACE_DESCRIPTION	as loss_place
				,losn.LOSS_DESCRIPTION		as LOSS_DESCRIPTION
				, ou.CODE as department, ou.ABBREV as department_code, ou.NAME as department_name, ol.LEVEL_NO as department_level_no, ol.NAME as department_level_name
				, ou_branch.branch, ou_branch.branch_code, ou_branch.branch_name, ou_branch.branch_level_no, ou_branch.branch_level_name
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
				AND coalesce(@branchCode, ou_branch.branch_code, '') = coalesce(ou_branch.branch_code,'')
				AND @departmentCode = ou.ABBREV
				AND ol.LEVEL_NO > 1
				AND clm.notification_date >= coalesce(@ClaimIntimationDateFrom, clm.OCCURENCE_DATE )
				AND clm.notification_date <= coalesce(@ClaimIntimationDateTo, clm.OCCURENCE_DATE )
			UNION ALL
			SELECT 
				clm.ORGUNIT_ADMIN_ID, clm.CLAIM_ID, clm.CLMNO as claim_number, clm.POLICY_POLICY_ID 
				,clm.NOTIFICATION_DATE , clm.OCCURENCE_DATE as LOSS_DATE, clm.SETTLEMENT_DATE
				,clm.REGISTRATION_DATE
				,cst.DESCRIPTION as claim_status
				,losn.ADDRESS_STREET	as loss_street
				,losn.ADDRESS_HOUSE_NUMBER1	as loss_house_number1
				,losn.ADDRESS_HOUSE_NUMBER2	as loss_house_number2
				,losn.ADDRESS_CITY			as loss_city
				,losn.POSTAL_CODE			as loss_postal_code
				,losn.OCCURENCE_PLACE_DESCRIPTION	as loss_place
				,losn.LOSS_DESCRIPTION		as LOSS_DESCRIPTION
				, null as department, null as department_code, null as department_name, null as department_level_no, null as department_level_name
				, ou.code as branch, ou.ABBREV as branch_code, ou.NAME as branch_name, ol.LEVEL_NO as branch_level_no, ol.NAME as branch_level_name
			from CLM_D_CLAIM clm
				JOIN CLM_D_CL_CLAIM_ST cst on cst.CCLMST_ID = clm.CCLMST_CCLMST_ID and cst.CULTURE_ID = @CULTURE_ID
				JOIN PAR_D_CL_ORG_UNIT ou on ou.ORGUNIT_ID = clm.ORGUNIT_ADMIN_ID AND ou.CULTURE_ID = @CULTURE_ID
				JOIN PAR_D_CL_ORG_LEVEL ol on ol.ORGLVL_ID = ou.ORGLVL_ORGLVL_ID AND ol.CULTURE_ID = @CULTURE_ID
				LEFT JOIN CLM_D_LOSS_NOTIFICATION losn on losn.LOSNTF_ID = clm.LOSNTF_LOSNTF_ID AND losn.VALID = 1
			WHERE clm.VALID = 1
				AND @departmentCode is null
				AND coalesce(@branchCode, ou.abbrev, '') = coalesce(ou.abbrev,'')
				AND clm.notification_date >= coalesce(@ClaimIntimationDateFrom, clm.OCCURENCE_DATE )
				AND clm.notification_date <= coalesce(@ClaimIntimationDateTo, clm.OCCURENCE_DATE )
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
		, clm.NOTIFICATION_DATE			as NOTIFICATION_DATE		--3
		, year(clm.LOSS_DATE)			as Year_of_loss				--4
		, clm.LOSS_DATE					as LOSS_DATE				--5
		,clm.loss_city					as loss_location_CITY		--6
		,clm.loss_street				as loss_location_STREET		--6
		,clm.loss_postal_code			as loss_location_POSTAL_CODE --6
		,clm.loss_house_number1			as loss_location_house_no1	--6
		,clm.loss_house_number2			as loss_location_house_no2	--6
		,clm.loss_place					as loss_location_description --6
		,coalesce(ap.assured_pers,'')	as assured_name				--7
		,coalesce(ap.insured_pers,'')		as insured_name				--
		,clm.claim_number				as claim_no					--8
		,pol.policy_number				as policy_no				--9
		,pol.UW_Year					as uw_year					--10
		,pol.date_inception				as policy_fm_date			--11
		,pol.date_maturity				as policy_to_date			--12
		,clm.LOSS_DESCRIPTION			as loss_description			--13
		,premium.annual_premium			as gross_premium			--14
		,pp.PAYMENT_AMOUNT				as premium_received			--15	--PAY
		,pp.first_premium_date			as date_prem_recvd_first	--16	--PAY
		,pp.last_premium_date			as date_prem_recvd_last		--16	--PAY
		,'*NOT IN StarINS*'				as date_dv_signed			--17	--not in starins
		,co.corresp_receive_date		as date_dv_recvd			--18	--correspondence
		,co.corresp_create_date			as date_dv_created			--		--correspondence
		,ExtAdj.amount_paid_extadj		as adjuster_fee				--19	--ext_partner_role =  'EXTADJ' - there is not currently this role in starins
		,ExtAdj.ext_payee				as adjusters_name			--20	--ext_partner_role =  'EXTADJ' - there is not currently this role in starins- if there are more external cost payouts for indemnity than 1 then there is first adjuster found
		,resind.indemnity_reserve_balance as claim_estimate_indemnity --21		
		,resext.extcost_reserve_balance as claim_estimate_extcost	--21
		,payout.amount_paid_indemnity	as amount_paid_indemnity	--22
		,payout.amount_paid_extcost		as amount_paid_extcost		--22
		,pay.PAYOUT_AMOUNT				as payout_amount_total		--22
		,clm.SETTLEMENT_DATE			as settled_date				--23
		,'*NOT IN StarINS*'				as date_rcvd_by_insured		--24	--not in starins
		,DATEDIFF ( DAY, coalesce(co.corresp_receive_date,clm.REGISTRATION_DATE), clm.SETTLEMENT_DATE) as process_period	--25	
		,pol.orgunit_name				as uw_location				--26
		,premium.insured_sum			AS sum_insured				--27
		,'*NOT IN StarINS*'				as acknow_receipt_date		--28	--PAY
		,clm.claim_status				as claim_status				--29
		,notes.note						as remarks					--30	
		,resind.indemnity_reserve_balance as AMOUNT_RESERVED_IND	--31
		,resext.extcost_reserve_balance as AMOUNT_RESERVED_EXTCOST	--31
		,resind.indemnity_reserve_change_date	as date_of_claim_reserve_ind	--32
		,resext.indemnity_reserve_change_date	as date_of_claim_reserve_extcost--32
		, offi.phys_person_firstname	as claim_officer_pp_firstname	--33
		, offi.phys_person_surname		as claim_officer_pp_surname		--33
		, offi.legal_person_name		as claim_officer_legal_pers_name	--33
		--,coins.PAYOUT_COINS_AMOUNT		as coinsurance_recovable	--PAY?
		--,null							as fac_recoverable		--REI
		--,null							as treaty_recoverable		--REI
		--,'*must be computed*'			as net_claims_amount		--TODO
		--,pay.ACCOUN_DEBITED_DATE		as date_account_debited	--PAY
		,payout.payee					as payee					--CLM
		,payout.paymethod_indemnity		as settle_mode_indemnity
		,payout.paymethod_extcost		as settle_mode_extcost
		,pol.product_code				as product_code
		,pol.product_brand_code
		,pol.currency_code				as policy_currency
		,pay.PAYOUT_CURRENCY
		,coins.PAYOUT_COINS_CURRENCY
		,clm.CLAIM_ID
		,clm.registration_date
		,pol.sysowner
		,gp.group_pol_no                as group_pol_no 
		,gp.group_pol_prod_code         as group_pol_prod_code 
		,gp.group_pol_prod_name         as group_pol_prod_name
		,@BranchCode					as BranchCode					
		,polB.orgunit_book_code	        as DepartmentCode				  
	    ,SUBSTRING(pol.product_code,1,2)as ClassCode						
	     ,pol.product_code				as ProductCode			
	    ,@ClaimIntimationDateFrom		AS ClaimIntimationDateFrom				
		,@ClaimIntimationDateTo			AS ClaimIntimationDateTo	
		,pol.acc_orgunit_name           as acc_ou_code  
	    ,pol.acc_orgunit_description    as acc_ou_description
		,ap.agent as Agent_name
	    ,ap.agent_number as Agent_code
		,xRate.xRate as Exchange_Rate 				
		from clm
		join CLM_DX_POLICY			pol			on pol.policy_id = clm.POLICY_POLICY_ID
												AND pol.CULTURE_ID = @culture_id
												AND pol.sysowner_code = 'NONLIFE'
												AND ((pol.product_code like coalesce (@ProductCode, pol.product_code )) or (@ProductCode = ''))
	     join POL_DX_POLICY_BOOKING polB         on polB.policy_id=clm.POLICY_POLICY_ID
		LEFT JOIN CLM_DX_PREMIUM	premium		on premium.policy_policy_id = clm.POLICY_POLICY_ID
		LEFT join CLM_DX_POLICY_PARTNER ap		on ap.policy_id = clm.POLICY_POLICY_ID
		LEFT JOIN CLM_DX_RESERVE		resind	on resind.claim_id = clm.CLAIM_ID AND resind.culture_id = @Culture_id AND resind .INDEMNITY = 1 
		LEFT JOIN CLM_DX_RESERVE		resext	on resext.claim_id = clm.CLAIM_ID AND resext.culture_id = @Culture_id AND resext.INDEMNITY = 0
		LEFT JOIN CLM_DX_PAYOUT			payout		on payout.claim_id = clm.CLAIM_ID AND payout.culture_id = @Culture_id
		--LEFT JOIN CLM_DX_CORRESPONDENCE	co on co.claim_id = clm.claim_id AND co.culture_id = @Culture_id
		LEFT JOIN (select claim_id,  cdv.corresp_receive_date, cdv.corresp_create_date,
				row_number() over (partition by claim_id order by corresp_receive_date desc) rn
				from CLM_DX_CORRESPONDENCE cdv
				where culture_id = @Culture_id)co	on co.claim_id = clm.claim_id  and co.rn = 1
		LEFT JOIN CLM_DX_PAY_PAYOUT		pay	on pay.claim_id = clm.claim_id AND pay.CULTURE_ID = @Culture_id
		LEFT JOIN clm_dx_pay_coinsurer coins	on coins.claim_id = clm.CLAIM_ID 
		LEFT JOIN CLM_DX_PAY_PREMIUM	 pp on pp.policy_id = clm.POLICY_POLICY_ID AND pp.culture_id = @Culture_id
		LEFT JOIN CLM_DX_EXT_COST_BY_ROLE ExtAdj	on ExtAdj.claim_id = clm.CLAIM_ID AND ExtAdj.culture_id = @Culture_id AND ExtAdj.role_code = 'EXTADJ'
		LEFT JOIN CLM_DX_NOTE			 Notes		on notes.CLAIM_ID = clm.CLAIM_ID AND notes.culture_id = @Culture_id
		LEFT JOIN clm_officer offi	on offi.CLAIM_ID = clm.CLAIM_ID
		LEFT JOIN CLM_DX_POLICY_GROUP gp on gp.policy_id = pol.policy_id and gp.culture_id = @Culture_id
		LEFT JOIN exchange_rate xRate on xRate.kod = pol.currency_code
END

--commit





GO


