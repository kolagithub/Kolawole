--USE [WapX_TEST]
--GO

--/****** Object:  StoredProcedure [dbo].[CLM_ES_GEN_Claims_Settled_Statement]    Script Date: 02-Jul-19 11:32:25 AM ******/
--SET ANSI_NULLS ON
--GO

--SET QUOTED_IDENTIFIER ON
--GO



CREATE PROCEDURE [dbo].[CLM_ES_GEN_Claims_Settled_Statement]
@Culture_id bigint, 
@BranchCode NVARCHAR(40), 
@DepartmentCode NVARCHAR(40) ,
@ClassCode NVARCHAR(20), 
@ProductCode NVARCHAR(20), 
@SettledDateFrom datetime, 
@SettledDateTo datetime 

as begin 


--declare 
--@Culture_id bigint  = 3,
--@BranchCode NVARCHAR(40)  = null,--'GEN',
--@DepartmentCode NVARCHAR(40)  = null, --'LI'
--@ClassCode NVARCHAR(20) = '%', --null ; --brand code
--@ProductCode NVARCHAR(20)  = '%',
--@SettledDateFrom datetime  = '20180101', --getdate()-50,--'2018101',
--@SettledDateTo datetime  = '20180301'; --getdate();


with exchange_rate as 
		(
			select p.ccurr_ccurr_id, t.kod, 
			p.foreign_exchange_middle as xRate
			, p.effective_date
			from pay_d_exchange p join pay_t_cis_mena t
			on p.ccurr_ccurr_id = t.cmenak_id
			where  p.effective_date = (select max(effective_date) from pay_d_exchange where ccurr_ccurr_id =p.ccurr_ccurr_id)
		)

SELECT distinct 
    ou.ABBREV						as branch_code, 
	ou.NAME							as branch_name, 
	clm.NOTIFICATION_DATE			as NOTIFICATION_DATE, 
	year(clm.OCCURENCE_DATE)		as Year_of_loss, 
	clm.OCCURENCE_DATE				as LOSS_DATE
	,coalesce(ap.insured_pers,'')	as insured_name
	,coalesce(ap.assured_pers,'')	as assured_name
	,clm.CLMNO			        	as claim_no 
	,pol.policy_number				as policy_no
	,pol.UW_Year					as uw_year
	,pol.date_inception				as policy_fm_date
	,pol.date_maturity				as policy_to_date 
	,losn.LOSS_DESCRIPTION			as loss_description
	,premium.annual_premium			as gross_premium
	,pp.PAYMENT_AMOUNT				as premium_received	--PAY
	,pp.first_premium_date			as date_prem_recvd_first	--PAY
	,pp.last_premium_date			as date_prem_recvd_last	--PAY
	,pod.confirm_date                       as date_dv_signed		--not in starins
	,co.corresp_receive_date		as date_dv_recvd		--correspondence
	,co.corresp_create_date			as date_dv_created	--correspondence
	,ExtAdj.amount_paid_extadj		as adjuster_fee		--ext_partner_role =  'EXTADJ' - there is not currently this role in starins
	,ExtAdj.ext_payee				as adjusters_name		--ext_partner_role =  'EXTADJ' - there is not currently this role in starins- if there are more external cost payouts for indemnity than 1 then there is first adjuster found
	,resind.indemnity_reserve_balance as claim_estimate_indemnity		
	,case when pod.is_expense = 1 then null else pod.payout_amount  end         	
									as amount_paid_indemnity		
	,case when pod.is_expense = 1 then null else pod.currency_code  end     
									as currency_indemnity	   
	,case when pod.is_expense = 1 then null else pod.payout_amount_hc  end
							   		as amount_paid_indemnity_dom_curr
	,resext.extcost_reserve_balance as claim_estimate_extcost
	,case when pod.is_expense = 1 then pod.payout_amount else null end 
									as amount_paid_extcost
	,case when pod.is_expense = 1 then pod.currency_code else null end             
									as currency_extcost 

	,case when pod.is_expense = 1 then pod.payout_amount_hc else null end 
							        as amount_paid_extcost_dom_curr
	--,pod.			    ???
	,0								as payout_amount_total --??
	,coins.PAYOUT_COINS_AMOUNT		as coinsurance_recovable	--PAY?
	--,null							as fac_recoverable		--REI
	--,null							as treaty_recoverable		--REI
	,rei1.recoverable				as FAC_RECOVERABLE			--25	--REI 
	,rei2.recoverable				as TREATY_RECOVERABLE		--26
	,'*must be computed*'			as net_claims_amount		--TODO
	--,clm.SETTLEMENT_DATE			as settled_date
	,pod.approval_date              as settled_date    
	,'*NOT IN StarINS*'				as date_rcvd_by_insured	--not in starins
	,DATEDIFF ( DAY, coalesce(co.corresp_receive_date,clm.SETTLEMENT_DATE), clm.REGISTRATION_DATE) as process_period			--
	,pol.orgunit_name				as uw_location
	,notes.note						as remarks				--TODO
	,premium.insured_sum			AS insured_sum	
	,'*NOT IN StarINS*'				as acknow_receipt_date	--PAY
	,pod.ACCOUNT_DEBITED_DATE		as date_account_debited	--PAY
	,pod.addressee					as payee					--CLM
	,case when pod.is_expense = 1  then null else pod.payout_method_descr  end	
									as settle_mode_indemnity
	,case when pod.is_expense = 1  then pod.payout_method_descr else null end 
									as settle_mode_extcost
	,pol.product_code				as product_code
	,pol.product_name               as product_name    
	,pol.product_brand_code
	,pol.currency_code				as policy_currency
	,pod.CURRENCY_code              as payout_currency
	,coins.PAYOUT_COINS_CURRENCY
	,cst.DESCRIPTION				as claim_status
	,clm.CLAIM_ID
	,clm.registration_date
	,pol.sysowner
	,pol.policy_number        as group_pol_no 
	,pol.product_code         as group_pol_prod_code 
	,pol.product_name         as group_pol_prod_name
	,@BranchCode					as BranchCode					
	,null				            as DepartmentCode
	,pol.product_brand_code         as Class_code				  
	,@ClassCode						as ClassCode						
	,@ProductCode					as ProductCode					
	,@SettledDateFrom				AS SettledDateFrom				
	,@SettledDateTo					AS SettledDateTo	
	,pol.acc_orgunit_name           as acc_ou_code  
	,pol.acc_orgunit_description    as acc_ou_description 	
	,polh.entry_user_desc           as policy_initiator
	,polh.appr_user_desc		as policy_approval
	,polhgr.entry_user_desc         as gr_policy_initiator
	,polhgr.appr_user_desc		as gr_policy_approval
	,pod.adjuster_name              as claim_initiator
	,pod.inspector_name		as claim_approval
	,pod.VAT_tax			as VAT_tax
	,pod.full_amount		as full_amount
	,pod.WHT_tax			as WHT_tax
	,case when cst.code <> 'U' and pod.is_expense is null then 'PARTIAL PAYOUTS' else '' end as remark
	,losn.ADDRESS_STREET	as loss_street
	,losn.ADDRESS_HOUSE_NUMBER1	as loss_house_number1
	,losn.ADDRESS_HOUSE_NUMBER2	as loss_house_number2
	,losn.ADDRESS_CITY			as loss_city
	,losn.POSTAL_CODE			as loss_postal_code
	,losn.OCCURENCE_PLACE_DESCRIPTION	as loss_place
	,ap.agent as Agent_name
	,ap.agent_number as Agent_code
	,payind.surname_name as Beneficiary_Surname
	,payind.name_abbr as Beneficiary_name_abbr
	,payind.middle_name as Beneficiary_middle_name
	,clm.payment_identifier as Voucher_No
	,cipd.payout_method_descr as Mode_of_payment
	,xRate.xRate               as Rate
	,(pod.full_amount * xRate.xRate) as Amount_Paid_GHS
from  (select v.pudal_koren_id claim_root_id, 
		       v.vypla_id as payout_id,
		       v.POR_CISLO payout_order, 
			   vst.kod as payout_status_code,
			   t.datum_vytvorenia as approval_date,
			   parr.firstname_abbrev +' '+ isnull(parr.middle_name,'')  +' '+isnull(parr.surname_name,'')  as  inspector_name, 
			   parl.firstname_abbrev +' '+ isnull(parl.middle_name,'')  +' '+isnull(parl.surname_name,'')  as adjuster_name,
		       para.firstname_abbrev +' '+ isnull(para.middle_name,'')  +' '+isnull(para.surname_name,'')  as addressee,
			   v.PLN_PLN_ID as indm_indm_id,
			   case when v.PUNAKL_PUNAKL_ID is not null then 1 else 0 end as is_expense,
			   t.suma trans_suma, 
			   v.VYPL_CIASTKA as payout_amount,
			   v.DAN as WHT_tax, 
			   v.tax_included as VAT_tax,
			   v.SUMA as full_amount,
			   cm.kod as currency_code,
			   t.sum_home_currency as payout_amount_hc,
			   tpo.DATUM_SPLATNOST AS ACCOUNT_DEBITED_DATE,
			   pm.kod as payout_method_code,
			   pm.popis as payout_method_descr,
                           v.confirm_date
		from INA_T_VYPLATY v 
		     JOIN INA_T_CIS_VYPLATA_STAVY vst on vst.CVYPST_ID = v.CVYPST_CVYPST_ID  and vst.kod = 'S'
			 JOIN PAY_V_CIS_PLATBA_FORMA pm on pm.plafor_id = v.PLAFOR_PLAFOR_ID   and culture_id = @Culture_id
			 left join pay_t_transakcia t on t.ID_RIAD_ZDROJ = v.VYPLA_ID
		     left JOIN INA_T_PLN_ADRESATI cc on cc.PLNADR_ID = v.PLNADR_PLNADR_ID
			 left join ina_t_pu_naklady pun on pun.PUNAKL_ID = v.PUNAKL_PUNAKL_ID and pun.platny = 1
			 left JOIN INA_T_PUDALOST_PARTNERI cp on (cp.PUPAR_ID = cc.PUPAR_PUPAR_ID or cp.PUPAR_ID = pun.PUPAR_PUPAR_ID) AND cp.PLATNY = 1	 
	         JOIN PAR_DX_PARTNERS para ON para.partner_id = cp.partner_partner_id
			 left JOIN PAR_DX_PARTNERS parr	on parr.partner_id =  v.revident
			 left JOIN PAR_DX_PARTNERS parl	on parl.partner_id =  v.likvidator
		 	 
			 left JOIN PAY_T_CIS_MENA cm on cm.cmenak_id = t.cmenak_cmenak_id
			 left join PAY_T_CIS_TYP_TRANS tt on tt.typtra_id = typtra_id and tt.kod = 'PREVYP' 
			 left join PAY_T_CIS_TRANS_STAV ts on  ts.TRASTAV_ID = t.TRASTAV_TRASTAV_ID and ts.AKT_STAV = 1
			 left JOIN (select TRANSA_TRANSA_HLAV_ID, DATUM_SPLATNOST 
							from PAY_T_TRANS_VZTAHY tv1 
								JOIN PAY_T_CIS_TYP_VZTAHU typv1 ON typv1.TYPVZT_ID = tv1.TYPVZT_TYPVZT_ID AND typv1.KOD = 'PR/PL' 
								JOIN PAY_T_TRANSAKCIA t2 ON tv1.TRANSA_TRANSA_VEDL_ID  = t2.TRANSA_ID 
							where tv1.platny = 1) tpo ON tpo.TRANSA_TRANSA_HLAV_ID = t.TRANSA_ID
	where  v.platny = 1
		   and t.datum_vytvorenia  >= coalesce(@SettledDateFrom,  t.datum_vytvorenia ) 
		   and t.datum_vytvorenia   < coalesce(@SettledDateTo+1,  t.datum_vytvorenia)
		   ) pod
	join CLM_D_CLAIM clm						on clm.claim_id = pod.claim_root_id and clm.valid = 1
	JOIN CLM_DX_PAYOUT_IND payind               on clm.CLAIM_ID = payind.claim_id and payind.culture_id = @CULTURE_ID
	JOIN CLM_DX_IND_PAYOUT_DETAILS cipd         on clm.claim_id = cipd.claim_root_id and cipd.culture_id = @CULTURE_ID
	JOIN CLM_D_CL_CLAIM_ST cst					on cst.CCLMST_ID = clm.CCLMST_CCLMST_ID and cst.CULTURE_ID = @CULTURE_ID
	JOIN PAR_D_CL_ORG_UNIT ou					on ou.ORGUNIT_ID = clm.orgunit_accounting_id AND ou.CULTURE_ID = @CULTURE_ID
	JOIN PAR_D_CL_ORG_LEVEL ol					on ol.ORGLVL_ID = ou.ORGLVL_ORGLVL_ID AND ol.CULTURE_ID = @CULTURE_ID
    LEFT JOIN CLM_D_LOSS_NOTIFICATION losn		on losn.LOSNTF_ID = clm.LOSNTF_LOSNTF_ID AND losn.VALID = 1
	JOIN CLM_DX_POLICY pol						on pol.policy_id = clm.POLICY_POLICY_ID AND pol.CULTURE_ID = @culture_id
													AND pol.sysowner_code = 'NONLIFE'
													AND ((pol.product_code like coalesce (@ProductCode, pol.product_code )) or (@ProductCode = ''))
	JOIN  INC_V_POLICY_HISTORY   polh			on polh.policy_id = pol.policy_id
	LEFT JOIN CLM_DX_PREMIUM	premium			on premium.policy_policy_id = clm.POLICY_POLICY_ID
	LEFT join CLM_DX_POLICY_PARTNER ap			on ap.policy_id = clm.POLICY_POLICY_ID
	LEFT JOIN CLM_DX_RESERVE		resind		on resind.claim_id = clm.CLAIM_ID AND resind.culture_id = @Culture_id AND resind .INDEMNITY = 1 
	LEFT JOIN CLM_DX_RESERVE		resext		on resext.claim_id = clm.CLAIM_ID AND resext.culture_id = @Culture_id AND resext.INDEMNITY = 0
	--LEFT JOIN CLM_DX_PAYOUT			payout		on payout.claim_id = clm.CLAIM_ID AND payout.culture_id = @Culture_id --removed at 1.8.2018 -JIRA 1133
    LEFT JOIN (select claim_id,  cdv.corresp_receive_date, cdv.corresp_create_date,
				row_number() over (partition by claim_id order by corresp_receive_date desc) rn
				from CLM_DX_CORRESPONDENCE cdv
				where culture_id = @Culture_id) co	on co.claim_id = clm.claim_id  and co.rn = 1
	--LEFT JOIN CLM_DX_PAY_PAYOUT		pay				on pay.claim_id = clm.claim_id AND pay.CULTURE_ID = @Culture_id --removed at 1.8.2018 -JIRA 1133
	LEFT JOIN clm_dx_pay_coinsurer coins			on coins.claim_id = clm.CLAIM_ID 
    LEFT JOIN CLM_DX_PAY_PREMIUM	 pp				on pp.policy_id = clm.POLICY_POLICY_ID AND pp.culture_id = @Culture_id
	LEFT JOIN CLM_DX_EXT_COST_BY_ROLE ExtAdj		on ExtAdj.claim_id = clm.CLAIM_ID AND ExtAdj.culture_id = @Culture_id AND ExtAdj.role_code = 'EXTADJ'
	LEFT JOIN CLM_DX_NOTE			 Notes			on notes.CLAIM_ID = clm.CLAIM_ID AND notes.culture_id = @Culture_id
	LEFT JOIN rei_dx_clm_brdr_sum_recoverable rei1  on rei1.claim_id = clm.CLAIM_ID AND rei1.contr_type_code like 'F%'
	LEFT JOIN rei_dx_clm_brdr_sum_recoverable rei2  on rei2.claim_id = clm.CLAIM_ID AND rei2.contr_type_code like 'O%'
	LEFT JOIN INC_V_POLICY_HISTORY   polhgr			on polhgr.policy_id = pol.policy_id
	LEFT JOIN exchange_rate xRate on xRate.kod = pol.currency_code	
WHERE coalesce(@branchCode, ou.abbrev, '') = coalesce(ou.abbrev,'')
option (force order )

END



GO


