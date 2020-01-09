--USE [WapX]
--GO

--/****** Object:  StoredProcedure [dbo].[POL_JUM_GEN_Daily_Production_report]    Script Date: 12/12/2019 9:31:31 AM ******/
--SET ANSI_NULLS ON
--GO

--SET QUOTED_IDENTIFIER ON
--GO


CREATE PROCEDURE [dbo].[POL_JUM_GEN_Daily_Production_report]
  @SysownID BIGINT, /*(1 = Life, 2 = general)*/
  @BranchCode NVARCHAR(40),
  @DeptCode NVARCHAR(40),
  @ClassCode NVARCHAR(20),
  @ProductCode NVARCHAR(20), 
  @MarketerCode NVARCHAR(20),
  @BasicDate NVARCHAR(1), /*C = Conclusion Date (default), I=Inception Date, A = Approval Date*/
  @DateFrom datetime,
  @DateTo datetime,
  @culture_id BIGINT,
  @user_id BIGINT

AS BEGIN


/* 
VERSION 21
----------------
2019-12-03 HORVATOVA WAPICEXT-2101 - Production Report : Change 'Endoresment Type' column default value to 'Endorsement'
                     - changed as required 
2019-10-30 HORVATOVA WAPICEXT-2006 - refer to the observation 11.10.2019
                     - the record with NULL commission value were eliminated. Not the value was incorrect, the record itself should not be there.
2019-10-10 HORVATOVA WAPICEXT-2006 Unpaired cancelled billing resulting in negative premium on Renewal transaction on policy 00366462005 in production report
                     - spooling of sum_insured fixed 
2019-10-10 HORVATOVA WAPICEXT-2033 Mixup of Maker and Checker dates in the Production Report
                     - spooling inc_t_zmena_typy zt2 based on prem.policyh_orig_id 
					 - spooling of ENDORSEMENT column fixed
					 - spooling policyh_id_orig in PREM subselect fixed, priority is zh than zh2 
2019-09-11 HORVATOVA WAPICEXT-2013 Production Report: No data for assured spooled on group level
2019-09-04 HORVATOVA WAPICEXT-1973 Production Report: wrong grouping of distinct transactions by policy
                     Grouping fixed. 
					 In case of the decrease the original billing transaction is related to the original history version and 2 new transactions are created:
					  - one to cancel the original one
                      - and one for decreased premium
                    The history version used  for the first level grouping (as there are 2 levels) is spooled based on date_from and date_to not the approval_date.
2019-08-08 HORVATOVA WAPICEXT-1921 Disparity in report contents
                    FIX1: new goruping over the transaction due date, date from and date to was added to eliminate all billing transactions created as result 
					     of any technical change not reflecting the changes of the premium or new billing transaction of the premium for the following period.
						 So for example in case of rollback, the transactions created in relation to this version. 
						 In fact to eliminate all billing transactions which could be seen on the collection account when wieving NOT current status of the account.   
                    FIX2: the sum insured is spooled from the policy history version, not the current version
2019-07-25 MARTINKA WAPICEXT-1918 Missing Transactions - Observations from Production Report testing (1
                    FIX: main conditions on BasicDate simplified for BasicDate=A (Approval) :
					- timestamps are not to be checked, because the condition on prem.created_in_period = 1 is enough
2019-07-19 HORVATOVA WAPICEXT-1586 - fix to spool the same records for the same input parameters (period) when processed any date     
2019-07-15 HORVATOVA WAPICEXT-743 - fix to spool the migrated policies where the history version ID is NULL  
2019-05-14 HORVATOVA WAPICEXT-1229/1185 - fix to view the broker and sales channel date related to the policy history version viewed 
                     - new version (V3) of the function fn_INC_V_POLICY_ENDORSEMENTS_NEW - new column sales_channel_id was added, 
					   to have the information about sales channel related to the policy history version rather then the actual policy version    
					 - new function created fn_POL_POLICY_HISTVER_PARTNERS to pull the policy partner's data related to policy history version           
2019-04-12 HORVATOVA WAPICEXT-1765 To summarize premium the grouping was changed to be grouped only by the policy change     
2019-04-12 HORVATOVA WAPICEXT-1765 Subselect implemented in the PREMIUM (in with) to spool the commission information    
2019-04-02 HORVATOVA WAPICEXT-1229 Maker and Checker values spooled by extract fixed.
                                   Commission records linked to payments transactions joined, when the record is cancellation 'pp.storno_id is not null'    
2019-03-29 HORVATOVA WAPICEXT-1185 Validation of the transaction creation date changed to use CAST, as eliminate the time part    
2019-03-14 HORVATOVA WAPICEXT-1579 Validation of the dates against the input parameters was changed to reflect the approval dates on policy history.    
2019-01-18 MARTINKA WAPICEXT-1564 Identified Issues with General Production Report (subtask WAPICEXT-1588)
                    Group by PreiodFrom and PeriodTo
2019-01-18 MARTINKA WAPICEXT-1579 MISSING TRANSACTIONS ON PROD. REPORT (subtask WAPICEXT-1586)
                    FIX: correction of how the commissions for marketers were previously excluded
2019-01-16 MARTINKA WAPICEXT-1122 WRONG APPROVAL DATE AND PERIOD FROM AND TO ON PRODUCTION REPORT (subtask WAPICEXT-1149)
                    Dates taken from members level - period_from, period_to, policy_conclusion, policy_approval,
2019-01-04 MARTINKS WAPICEXT-1183, WAPICEXT-1283 FSA marketers - MCI #65 
                    Commissions going to marketers to be excluded
2018-12-07 MARTINKA WAPICEXT-1185 Disparity in report contents vis-à-vis data entered by CPU when generating production reports (subtask 1229)
                    Change of sales channel on policy - from DIRECT to BROKER (MERGE of 2 versions into 1 row : premium on 1st version, commisison on 2nd version)
					FIX3:  display MERGE even sum of gross premium is equal to zero
2018-11-29 MARTINKA WAPICEXT-1185 Disparity in report contents vis-à-vis data entered by CPU when generating production reports (subtask 1229)
                    Change of sales channel on policy - from DIRECT to BROKER (MERGE of 2 versions into 1 row : premium on 1st version, commisison on 2nd version)
                    FIX2: MERGE of rows iirespective of month when the change was performed
2018-10-31 MARTINKA WAPICEXT-1185 Disparity in report contents vis-à-vis data entered by CPU when generating production reports (subtask 1229)
                    Change of sales channel on policy - from DIRECT to BROKER 
					FIX1: MERGE of 2 versions into 1 row : premium on 1st version, commisison on 2nd version
2018-10-29 MARTINKA WAPICEXT-1122 WRONG APPROVAL DATE AND PERIOD FROM AND TO ON PRODUCTION REPORT (subtask 1149)
                    Output field "policy_approval" : in case of renewal, this column has to show the real date when the renewal  
2018-10-29 MARTINKA WAPICEXT-1185 Disparity in report contents vis-a-vis data (subtask 1229)
                    Change of sales channel on policy - from DIRECT (no commission) to BROKER (with commission)
					Now 2 rows will be displayed : 
					1/ DIRECT to date of Acceptance, Premium > 0, Coimmission = 0
					2/ BROKER to date of endorsement, Premium = 0, Commission > 0
2018-10-29 MARTINKA WAPICEXT-1122 WRONG APPROVAL DATE AND PERIOD FROM AND TO ON PRODUCTION REPORT (subtask WAPICEXT-1149)
                    Now 4 output fields (UW_Year, policy_approval, period_from, and period_to) were changed
					- the values are taken from historical version of policy (due to renewals)
2019-12-17 Kolawole The following column were added for Ghana  ECOWAS_Sticker_Serial_Number,
	                                                           NIC_Sticker_Serial_Number,
															   Fire_Certificate_Number,
															   Certificate_number,
															   Type_of_Industry,
															   payment_method,
															   Exchange_Rate,
															    CLASS_CODE,
																CLASS_NAME,
*/


  /*
DECLARE 
@SysownID BIGINT = 2, /*(1 = Life, 2 = general)*/
@BranchCode NVARCHAR(40),
@DeptCode NVARCHAR(40),
@ClassCode NVARCHAR(20),
@ProductCode NVARCHAR(20), 
@MarketerCode NVARCHAR(20),
@BasicDate NVARCHAR(1) = 'A', /*C = Conclusion Date (default), I=Inception Date, A = Approval Date*/
@DateFrom datetime = '20190801',
@DateTo datetime = '20191010',
@culture_id BIGINT = 3,
@user_id BIGINT; 
-- exec POL_JUM_GEN_Daily_Production_report 2, null, null, null, null, null, 'I', '20180101', '20181231', 3, null;
--  drop table #tmp_covers
 */




-- DECLARE 
--@SysownID BIGINT = 2, /*(1 = Life, 2 = general)*/
--@BranchCode NVARCHAR(40),
--@DeptCode NVARCHAR(40),
--@ClassCode NVARCHAR(20),
--@ProductCode NVARCHAR(20), 
--@MarketerCode NVARCHAR(20),
--@BasicDate NVARCHAR(1) = 'A', /*C = Conclusion Date (default), I=Inception Date, A = Approval Date*/
--@DateFrom datetime = '20180401',
--@DateTo datetime = '20191230',
--@culture_id BIGINT = 3,
--@user_id BIGINT;

--drop table #tmp_covers

SELECT y.policy_id, SUM(y.sum_insured) AS sum_insured, SUM(y.premium_annual) AS premium_annual, SUM(y.premium_modal) AS premium_modal,
	    SUM(rate_annual_tariff) AS rate_annual_tariff, SUM(premium_annual_discount) AS premium_annual_discount, SUM(premium_annual_loading) AS premium_annual_loading
	INTO #tmp_covers
	FROM (SELECT ISNULL(pp.POLICY_POLICY2_ID, ppr.policy_id) AS policy_id, 
			     ISNULL(ppr.sum_insured,0) AS sum_insured, ISNULL(ppr.premium_annual,0) AS premium_annual, ISNULL(ppr.premium_modal,0) AS premium_modal,
				 ISNULL(ppr.rate_annual_tariff,0) AS rate_annual_tariff, 
				 ISNULL(ppr.premium_annual_discount,0) AS premium_annual_discount, 
				 ISNULL(ppr.premium_annual_loading,0) AS premium_annual_loading
			FROM -- pol_d_policy pol
			 inc_v_policy_premium ppr
			LEFT JOIN POL_D_POLICY_POLICY pp ON pp.valid = 1 /*AND pp.POLICY_POLICY_ID = pol.policy_id --*/ AND pp.POLICY_POLICY_ID = ppr.policy_id
				AND pp.CREL_CREL_ID = (select r.CREL_ID from PAR_D_CL_RELATION r where r.valid = 1 and r.code = 'RZML' AND r.culture_id = 3)
           --  where ppr.policy_id = (select zml_id from inc_t_zmluvy where cpz = '00366462005') 
         --    cross apply fn_INC_V_POLICY_PREMIUM(ISNULL(pp.POLICY_POLICY2_ID, pol.policy_id)) ppr
		) y
    GROUP BY y.policy_id;

WITH premium AS (
 /*
DECLARE 
@SysownID BIGINT = 2, /*(1 = Life, 2 = general)*/
@BranchCode NVARCHAR(40),
@DeptCode NVARCHAR(40),
@ClassCode NVARCHAR(20),
@ProductCode NVARCHAR(20), 
@MarketerCode NVARCHAR(20),
@BasicDate NVARCHAR(1) = 'A', /*C = Conclusion Date (default), I=Inception Date, A = Approval Date*/
@DateFrom datetime = '20170101',
@DateTo datetime = '20190724',
@culture_id BIGINT = 3,
@user_id BIGINT;  
 */
SELECT y.policy_id AS policy_id, 
         MAX (y.policyh_id) AS policyh_id,
         MAX (y.policyh_orig_id) AS policyh_orig_id,
		 MAX (y.policyh_trans_id) as policyh_trans_id,
         MAX(y.to_date) as to_date,
		 MAX(y.period_from) as period_from,
		 MAX(y.period_to) as period_to,
	       MAX(CASE WHEN y.created_in_period = 1 THEN y.creation_date ELSE CONVERT(date, '19000101') END) AS creation_date,
		   MAX(CASE WHEN y.created_in_period = 1 THEN y.creation_datetime ELSE CONVERT(date, '19000101') END) AS creation_datetime,
		   MAX(y.creation_month) AS creation_month,
           MAX(y.max_transa_id) AS max_transa_id,
	       MAX(y.created_in_period) AS created_in_period, MAX(y.duedate_in_period) AS duedate_in_period,
		   MIN(y.policy_conclusion) AS policy_conclusion,
		   MIN(y.policy_approval) AS policy_approval,
		   SUM(y.premium_gross) AS premium_gross, SUM(y.premium_gross_home) AS premium_gross_home, 
		   SUM(y.broker_commission) AS broker_commission, SUM(y.broker_commission_home) AS broker_commission_home, 
		   SUM(y.premium_gross - y.broker_commission) AS premium_net,
		   SUM(y.premium_gross) - SUM(y.broker_commission) AS premium_net1,
		   SUM(y.premium_gross_home - y.broker_commission_home) AS premium_net_home
  FROM (

 /*
DECLARE 
@SysownID BIGINT = 2, /*(1 = Life, 2 = general)*/
@BranchCode NVARCHAR(40),
@DeptCode NVARCHAR(40),
@ClassCode NVARCHAR(20),
@ProductCode NVARCHAR(20), 
@MarketerCode NVARCHAR(20),
@BasicDate NVARCHAR(1) = 'A', /*C = Conclusion Date (default), I=Inception Date, A = Approval Date*/
@DateFrom datetime = '20170101',
@DateTo datetime = '20190724',
@culture_id BIGINT = 3,
@user_id BIGINT;  
 */

  SELECT x.policy_id AS policy_id, 
         MAX(x.policyh_id) AS policyh_id,
         -- MAX (x.policyh_id_orig) AS policyh_orig_id,
		 x.policyh_id_orig AS policyh_orig_id,
		 MAX(x.zmlh_id) AS policyh_trans_id,
         MAX(x.to_date) as to_date,
		 MAX(x.period_from) as period_from,
		 MAX(x.period_to) as period_to,
	     MAX(CASE WHEN x.created_in_period = 1 THEN x.creation_date ELSE CONVERT(date, '19000101') END) AS creation_date,
		 MAX(CASE WHEN x.created_in_period = 1 THEN x.creation_datetime ELSE CONVERT(date, '19000101') END) AS creation_datetime,
		 MAX(x.creation_month) AS creation_month,
         MAX(x.transa_id) AS max_transa_id,
	     MAX(x.created_in_period) AS created_in_period, MAX(x.duedate_in_period) AS duedate_in_period,
		 MIN(x.policy_conclusion) AS policy_conclusion,
		 MIN(x.policy_approval) AS policy_approval,
		 SUM(x.premium_gross) AS premium_gross, SUM(x.premium_gross_home) AS premium_gross_home, 
		 SUM(x.broker_commission) AS broker_commission, SUM(x.broker_commission_home) AS broker_commission_home, 
		 SUM(x.premium_gross - x.broker_commission) AS premium_net,
		 SUM(x.premium_gross) - SUM(x.broker_commission) AS premium_net1,
		 SUM(x.premium_gross_home - x.broker_commission_home) AS premium_net_home

 	  FROM (


--	  DECLARE 
--@SysownID BIGINT = 1, /*(1 = Life, 2 = general)*/
--@BranchCode NVARCHAR(40),
--@DeptCode NVARCHAR(40),
--@ClassCode NVARCHAR(20),
--@ProductCode NVARCHAR(20), 
--@MarketerCode NVARCHAR(20),
--@BasicDate NVARCHAR(1) = 'A', /*C = Conclusion Date (default), I=Inception Date, A = Approval Date*/
--@DateFrom datetime = '20180501',
--@DateTo datetime = '20191231',
--@culture_id BIGINT = 3,
--@user_id BIGINT; 



	    SELECT z.cpz as cpz, 
			  ISNULL(zv.ku_zmluve_id, z.zml_id) AS policy_id, 
			   CASE WHEN zv.ku_zmluve_id is not null then grp_mb_chng.group_policyh_id 
				    ELSE zh.zmlh_id 
			   END as policyh_id,
			   ISNULL(zh.zmlh_id, zh2.zmlh_id) as policyh_id_orig,
			   zh2.zmlh_id as zmlh2_id,
			   zh2.ucinny as ucinny_zh2,
			   c2.popis as zh2_zmena,
			   c2.skratka as zh2_zmena_skr,
			   zh.zmlh_id as zmlh_id,
			   zh.ucinny as ucinny_zh,
			   c.popis as zh_zmena,
			   c.skratka as zh_zmena_skr,
			   cast(t.datum_vytvorenia AS DATE) AS creation_date,
			   	cast(tr.datum_od AS DATE) AS to_date, 
			   ISNULL(tr.suma * t.smer * t.znak_vratka * t.znak_storno, 0) AS premium_gross,
			   ISNULL(tr.sum_home_currency * t.smer * t.znak_vratka * t.znak_storno, 0) AS premium_gross_home,
			   zv.ku_zmluve_id as group_policy_id,
			   grp_mb_chng.group_policyh_id as group_policyh_id,
			   zh.zmena_id as zml_zmena_id,
			   t.vznik_id as trans_vznik_id,
			   t.transa_id AS transa_id, 

			   cms.broker_commission_home as broker_commission_home,
			   cms.broker_commission as broker_commission,

			   -- t.transa_id AS transa_id, 
			   ISNULL(ISNULL(zh2.renewal_date, zh2.datum_zaciatku), ISNULL(z.renewal_date, z.datum_zaciatku)) AS period_from,
			   ISNULL(ISNULL(zh2.aktualny_koniec, zh2.datum_konca), ISNULL(z.aktualny_koniec, z.datum_konca)) AS period_to,
			   ISNULL(ISNULL(zh.renewal_date, zh.datum_uzatvorenia), ISNULL(z.renewal_date, z.datum_uzatvorenia)) AS policy_conclusion,
			   (CASE WHEN zh.zmlh_id IS NOT NULL THEN t.datum_vytvorenia WHEN z.renewal_date IS NOT NULL THEN z.date_acceptance ELSE CONVERT(date, '99991231') END) AS policy_approval,


			   substring(replace(convert(varchar, t.datum_vytvorenia,111),'/',''),1,6) AS creation_month,
			   t.datum_vytvorenia AS creation_datetime,
			   t.account_first_entry_date,
		       (CASE WHEN CONVERT(date, t.datum_vytvorenia) BETWEEN ISNULL(@DateFrom, '19000101') AND ISNULL(@DateTo, '99991231') THEN 1 ELSE 0 END) created_in_period,
			   (CASE WHEN CONVERT(date, tr.datum_od)        BETWEEN ISNULL(@DateFrom, '19000101') AND ISNULL(@DateTo, '99991231') THEN 1 ELSE 0 END) duedate_in_period
			
			   /*t.transa_id, tr.traroz_id, t.datum_splatnost,cast (t.datum_vytvorenia as date) as datum_vytvorenia
			   , pp.prprip_id, pp.platny, pp.podklad_id, pp.podobjekt_id,  pp.*,o.**/
			FROM pay_t_transakcia t   
			join com_t_transaction tra on tra.trans_id = t.vznik_id
			join com_t_transaction tra1 on tra1.trans_id = t.zmena_id
			JOIN pay_t_ucet u ON u.platny = 1 AND t.id_riad_ciel = u.ucet_id
			JOIN com_t_cis_object_type ot ON ot.objtyp_id = u.id_tab_obj AND ot.code = 'Zmluva'
			JOIN inc_t_zmluvy z ON u.id_riad_obj = z.zml_id AND z.platny = 1
			LEFT JOIN inc_t_zmluvy_h zh ON zh.zml_id = z.zml_id AND (zh.zmena_id = t.vznik_id) 
		left JOIN inc_t_zmena_typy zt ON zt.zme_id = zh.zme_zme_id
        left join inc_v_cis_zmena_typ c ON c.czmet_id = zt.czmet_czmet_id AND c.culture_id = 3
			LEFT JOIN inc_t_zmluvy_h zh2 ON zh2.zml_id = z.zml_id AND zh2.ucinny = 1 AND t.datum_splatnost BETWEEN zh2.datum_od AND zh2.datum_do
		left JOIN inc_t_zmena_typy zt2 ON zt2.zme_id = zh2.zme_zme_id
        left join inc_v_cis_zmena_typ c2 ON c2.czmet_id = zt2.czmet_czmet_id AND c2.culture_id = 3
			JOIN pay_t_trans_rozpad tr ON tr.platny = 1 AND tr.transa_transa_id = t.transa_id AND tr.suma <> 0
			JOIN pay_t_cis_trans_stav ts ON ts.trastav_id = t.trastav_trastav_id
			LEFT JOIN (select pp.podklad_id
							  ,SUM(ISNULL(dbo.get_amount_currid_conversion(o.suma_netto_origin_currency, o.origin_currency_id, o.agent_currency_id, pp.sysown_sysown_id, pp.date_from, 0), 0)) AS broker_commission_home
			                  ,SUM(ISNULL(o.suma_netto_origin_currency, 0)) AS broker_commission
					    from cms_t_proviz_pripad pp 
						LEFT JOIN cms_t_odmena o ON o.platny = 1 AND o.suma_netto <> 0 and o.prprip_narok_id = pp.prprip_id
			  	                                                AND o.spolupracovnik IN (SELECT sp.spoluprac_id FROM cms_t_spolupracovnik sp 
															                           	 JOIN cms_t_cis_spolupracovnik_typ spt ON spt.cspolty_id = sp.cspolty_cspolty_id
																                         WHERE spt.create_pay_out = 1)
						WHERE  pp.platny = 1
						group by pp.podklad_id 
							    ) cms ON cms.podklad_id = tr.traroz_id  
			 LEFT JOIN inc_t_zml_vazby zv ON zv.platny = 1 AND zv.zml_zml_id = z.zml_id 
			      AND zv.vztah_vztah_id = (select cv.vztah_id from par_t_cis_vztah cv where cv.platny = 1 and cv.vztah_kod = 'RZML')
             LEFT JOIN inc_t_group_change_member grp_mb_chng on grp_mb_chng.member_policy_id = zh.zml_id and grp_mb_chng.member_policyh_id = zh.zmlh_id and grp_mb_chng.platny = 1 
  		   WHERE t.platny = 1 AND t.predpis = 1
			 AND cast(t.datum_vytvorenia as DATE) BETWEEN ISNULL(@DateFrom, '19000101') AND ISNULL(@DateTo, '99991230')+1
			 and z.zml_id not in (select ku_zmluve_id 
			                        from inc_t_zml_vazby zv1
			  					   where zv1.vztah_vztah_id = (select cv.vztah_id from par_t_cis_vztah cv where cv.platny = 1 and cv.vztah_kod = 'RZML')) 
				           
						   -- and zv.ku_zmluve_id = (select zml_id from inc_t_zmluvy where cpz = '00342063003' ) -- '01808911001')
 			               -- and z.cpz IN ('00342063003') 
            -- and grp_mb_chng.group_policyh_id is null
	       ) x	
   	 
	    --    WHERE x.policy_id IN (select zml.zml_id from inc_t_zmluvy zml where zml.cpz IN ('01808911001')) -- ('01808911001') 	   )

	   -- GROUP BY x.policy_id, x.policyh_id-- , x.creation_date
	   GROUP BY x.policy_id, x.policyh_id_orig
       HAVING (SUM(x.premium_gross) <> 0 OR SUM(x.broker_commission) <> 0)
	) y
 GROUP BY y.policy_id, y.to_date, y.period_from, y.period_to
 HAVING (SUM(y.premium_gross) <> 0 OR SUM(y.broker_commission) <> 0)

),
coins_share AS (
	SELECT pc.POLICY_POLICY_ID AS policy_id, 
		   SUM(pc.RATIO * (CASE WHEN o.OWNER_ID IS NULL THEN 1 ELSE 0 END)) AS coins_coins_perc,
		   SUM(pc.RATIO * (CASE WHEN o.OWNER_ID IS NULL THEN 0 ELSE 1 END)) AS owner_coins_perc
	  FROM POL_D_POLICY_COINSURANCE pc
	  LEFT JOIN PAR_D_OWNER_IS o ON o.valid = 1 AND o.PARTNER_PARTNER_ID = pc.PARTNER_PARTNER_ID
	 WHERE pc.VALID = 1 
	 GROUP BY pc.POLICY_POLICY_ID
),

exchange_rate as 
		(
			select p.ccurr_ccurr_id, t.kod, 
			p.foreign_exchange_middle as xRate
			, p.effective_date
			from pay_d_exchange p join pay_t_cis_mena t
			on p.ccurr_ccurr_id = t.cmenak_id
			where  p.effective_date = (select max(effective_date) from pay_d_exchange where ccurr_ccurr_id =p.ccurr_ccurr_id)
		),

Elm AS (
       SELECT policy_policy_id, 
              MAX(CASE WHEN p.code like 'ECOWStickNo10' THEN (CASE WHEN paop.value IS NOT NULL THEN paop.description ELSE pp.value END) ELSE '' END) AS ECOWAS_Sticker_Serial_Number,
			  MAX(CASE WHEN p.code like 'NICStickNo10' THEN (CASE WHEN paop.value IS NOT NULL THEN paop.description ELSE pp.value END) ELSE '' END) AS NIC_Sticker_Serial_Number,
			  MAX(CASE WHEN p.code like 'FireCertNum' THEN (CASE WHEN paop.value IS NOT NULL THEN paop.description ELSE pp.value END) ELSE '' END) AS Fire_Certificate_Number,
			  MAX(CASE WHEN p.code like 'CerNo_Veh' THEN (CASE WHEN paop.value IS NOT NULL THEN paop.description ELSE pp.value END) ELSE '' END) AS Certificate_number,
			  MAX(CASE WHEN p.code like 'IndustType' THEN (CASE WHEN paop.value IS NOT NULL THEN paop.description ELSE pp.value END) ELSE '' END) AS Type_of_Industry
			  --MAX(CASE WHEN p.code like 'NICStickNo10'   THEN pp.value ELSE '' END) AS VehValue
        FROM pol_d_cover c 
        JOIN prd_d_cl_policy_status cs ON cs.polst_id = c.polst_polst_id AND cs.culture_id = 3
        JOIN prd_d_element e ON e.elm_id = c.elm_elm_id
        JOIN pol_d_cover_parameter pp ON pp.cover_cover_id = c.cover_id
        JOIN prd_d_element_parameter ep ON ep.elmprm_id = pp.elmprm_elmprm_id
        JOIN prd_d_parameter p ON p.param_id = ep.param_param_id 
		LEFT JOIN prd_d_param_option_h paop on paop.param_root_id = p.param_id AND paop.valid = 1 and paop.VALUE = pp.VALUE 
       WHERE c.valid = 1
	     AND c.policy_policy_id = 4679220840107265
	     --AND e.code IN ('014', '015')
      --   AND p.code IN ('Location_10', 'VehValue', 'RiskDesc_ObjectF', 'SI_ObjectF')
       GROUP BY policy_policy_id)

SELECT --prem.* 
       pol.policyh_id, pol.policy_id AS policy_id, pol.policy_number AS policy_no, pt.description AS policy_type,
	   prem.policyh_orig_id,
	   prem.policyh_trans_id,
       SUBSTRING(pr.code,1,2) AS class_code, pr.code AS product_code, pr.name AS product_name,
	   ou.code AS branch_code, ou.abbrev AS branch_abbrev, ou.name AS branch_name,
	   -- customer
       par.ph_partner_id as assured_partner_id, par.ph_customer_id AS customer_id,
       par.ph_firstname AS assured_partner_firstname, par.ph_middlename AS assured_partner_middlename, par.ph_surname AS assured_partner_surname,
	   YEAR(ISNULL(pol.date_renewal, pol.date_inception)) AS UW_Year,
	   polh.appr_user_desc as policy_issuance,
	   prem.policy_conclusion AS policy_conclusion,
	   (CASE WHEN prem.policy_approval = CONVERT(date, '99991231') THEN polh.appr_timestamp ELSE prem.policy_approval END) AS policy_approval,
	   prem.period_from AS period_from,
	   prem.period_to AS period_to,
  	   -- broker
	   par.br_partner_id AS broker_partner_id, par.br_code AS broker_code,
	   par.br_firstname AS broker_partner_firstname, par.br_middlename AS broker_partner_middlename, par.br_surname AS broker_partner_surname,
	   sal.code AS sales_channel_code, sal.name AS sales_channel_name, sal.description AS sales_channel_desc,
	   -- premium written / endorsement
	   prem.max_transa_id AS invoice_number,
	   prem.to_date AS trans_date,
	   prem.creation_date AS creation_date,
	   prem.creation_datetime AS creation_datetime,
	   -- endors.policyh_id,
       (CASE WHEN endors.policy_id IS NOT NULL THEN endors.endors_order ELSE polh.top_version_endors_order END) AS endorsement_no,
	   ISNULL(endors.change_type_id, ccht.CHNGTY_ID) AS change_type_id, 
	   ISNULL(ISNULL(endors.change_type_name,c2.skratka), ccht.NAME) AS change_type_code, 
	   ISNULL(ISNULL(endors.change_type_desc,c2.popis), ccht.DESCRIPTION) AS  change_type_desc,
	   Isnull(prem.premium_gross_home, cov.premium_modal) AS gross_premium,
	  --  c2.popis, c2.skratka,
	   ISNULL(endors.change_type_desc, ccht.description) AS change_type_name,
	   (CASE WHEN ISNULL(endors.policy_status_code, ps.code) LIKE 'S%' THEN 'CANCELLATION'
			 WHEN ISNULL(endors.policy_status_code, ps.code) LIKE 'Z%' AND prem.to_date = pol.date_renewal AND ISNULL(endors.change_type_code,ccht.code) IN ('MProl', 'MProlN', 'RenewPrem') THEN 'RENEWAL'
			 WHEN ISNULL(endors.policy_status_code, ps.code) LIKE 'Z%' AND prem.to_date = CONVERT(date, pol.date_inception) AND ISNULL(endors.change_type_code,ccht.code) IN ('CRE', 'AKCEP') THEN 'NEW POLICY'
			 WHEN prem.to_date = ISNULL(endors.date_version_from, polh.top_version_date_version_from) THEN 'ENDORSEMENT'
			 ELSE 'ENDORSEMENT'
	    END) AS endorsement_type,
	   -- premium & sum assured ORIG
	   ISNULL(premh.sum_insured,cov.sum_insured) as sum_insured_orig, cov.premium_annual as annual_gross_premium_orig, curr.code AS policy_currency,
	   -- premium & sum assured HOME
	   dbo.get_amount_currid_conversion(ISNULL(premh.sum_insured,cov.sum_insured), curr.ccurr_id, 43, pr.sysown_sysown_id, prem.to_date, 0) AS sum_insured,
	   dbo.get_amount_currid_conversion(cov.premium_annual, curr.ccurr_id, 43, pr.sysown_sysown_id, prem.to_date, 0) AS annual_gross_premium,
	    --premium & sum assured in GHS
	   dbo.get_amount_currid_conversion(cov.sum_insured, curr.ccurr_id, 49, pr.sysown_sysown_id, prem.to_date, 0) AS sum_insured_GHS,
       dbo.get_amount_currid_conversion(cov.premium_annual, curr.ccurr_id, 49, pr.sysown_sysown_id, prem.to_date, 0) AS annual_gross_premium_GHS, 
	   dbo.get_amount_currid_conversion(prem.broker_commission , curr.ccurr_id, 49, pr.sysown_sysown_id, prem.to_date, 0) AS broker_commission_GHS,
	   dbo.get_amount_currid_conversion(cov.premium_modal , curr.ccurr_id, 49, pr.sysown_sysown_id, prem.to_date, 0) AS Net_Premium_GHS, 

	   -- gross - commission = net ORIG
	   Isnull(prem.premium_gross, cov.premium_modal) AS gross_premium_orig,
	   prem.broker_commission AS broker_commission_orig,
	   IsNull(prem.premium_net, cov.premium_modal) AS net_premium_orig,
	   -- gross - commission = net HOME
	   Isnull(prem.premium_gross_home, cov.premium_modal) AS gross_premium,
	   prem.broker_commission_home AS broker_commission,
	   IsNull(prem.premium_net_home, cov.premium_modal) AS net_premium,
	   IsNull(pol.ACQUISITION_COMMISSION_PCT/100,0) AS broker_commision_perc,
       -- coinsurance
	   IsNull(cs.coins_coins_perc,0) as coins_perc,
	   -- prem.to_date, prem.premium_gross, prem.broker_commission, prem.premium_net,
	   Isnull(prem.premium_gross_home, cov.premium_modal) * IsNull(cs.coins_coins_perc/100,0) as coins_share_gross_premium,
	   IsNull(prem.premium_net_home, cov.premium_modal) * IsNull(cs.coins_coins_perc/100,0) as coins_share_net_premium,
       (CASE WHEN ct.code IS NULL THEN 'Direct business'
		     WHEN ct.code LIKE 'LEAD%' THEN 'Direct with Co. Insurance'
		     WHEN ct.code = 'FOLW' THEN 'Co. Insurance'
			 WHEN ct.code = 'FACIN' THEN 'FAC Inward'
	   END) AS trans_type,
	   -- marketer
       par.ma_partner_id AS marketer_partner_id, par.ma_code AS marketer_code, 
	   par.ma_firstname AS marketer_firstname, par.ma_middlename AS marketer_middlename, par.ma_surname AS marketer_surname,
	   -- status
	   (CASE WHEN ps.code LIKE 'Z%'  THEN 'Approved' WHEN ps.code LIKE 'Sns' THEN 'Refused' WHEN ps.code LIKE 'C%'  THEN 'Proposal' ELSE 'Approved' END) AS approval_status,
	   ISNULL(endors.policy_status_code, ps.code) AS policy_status_code, 
	   ISNULL(endors.policy_status_name, ps.name) AS policy_status_name, 
	   ISNULL(endors.policy_status_desc, ps.description) AS policy_status_desc,
	   -- user
	   ISNULL(polh.entry_user_login,endors.user_login) AS policy_initiator_user_login, 
	   ISNULL(polh.entry_user_desc,endors.user_desc) AS policy_initiator_user_name,
	   -- maker
	   ISNULL(endors.maker_time_stamp, polh.entry_timestamp) AS maker_timestamp, 
	   ISNULL(endors.maker_user_id, polh.entry_user_id) AS maker_user_id, 
	   ISNULL(endors.maker_user_login, polh.entry_user_login) AS maker_user_login, 
	   ISNULL(endors.maker_user_desc, polh.entry_user_desc) AS maker_user_desc,
	   -- checker
	   ISNULL(endors.user_id, polh.top_version_user_id) AS checker_user_id,
	   ISNULL(endors.user_login, polh.top_version_user_login) AS checker_user_login,
	   ISNULL(endors.user_desc, polh.top_version_user_desc) AS checker_user_desc,
	   ISNULL(endors.checker_time_stamp, polh.top_version_timestamp) AS checker_time_stamp,
       polh.top_version_timestamp AS checker_top_ver_time_stamp,
	   e.ECOWAS_Sticker_Serial_Number as ECOWAS_Sticker_Serial_Number,
	   e.NIC_Sticker_Serial_Number as NIC_Sticker_Serial_Number,
	   e.Fire_Certificate_Number as Fire_Certificate_Number,
	   e.Certificate_number as Certificate_number,
	   e.Type_of_Industry as Type_of_Industry,
	   pm.description as payment_method,
	   xRate.xRate as Exchange_Rate,
	   BR.BRAND_CODE AS CLASS_CODE,
	   BR.BRAND_NAME AS CLASS_NAME,
	   
	   -- input parameters
	   @BasicDate AS BasicDate, @DateFrom AS Column1, @DateTo AS Column2
	  ,endors.checker_time_stamp, polh.top_version_timestamp
	  ,if_endors_null.time_stamp ---time_stamp is used instead of checker time_stamp because the checker time stamp is not in the function fn_INC_V_POLICY_ENDORSEMENTS1
	  ,endors.policyh_id, pol.policyh_id

 FROM premium prem
  INNER JOIN pol_d_policy_h pol on prem.POLICY_ID = pol.policy_id /*and prem.POLICYh_ID = pol.policyh_id*/ and pol.valid = 1 AND pol.effective = 1  AND prem.to_date BETWEEN pol.date_version_from AND pol.date_version_to
  JOIN pol_d_cl_policy_type pt ON pt.polty_id = pol.polty_polty_id AND pt.culture_id = @culture_id  AND pt.code IN ('Ind', 'SOS', 'Ram')
  JOIN PRD_D_CL_POLICY_STATUS ps ON ps.POLST_ID = pol.POLST_POLST_ID AND ps.culture_id = @culture_id --AND ps.code LIKE 'Z%'
  JOIN PAR_D_CL_ORG_UNIT ou ON ou.orgunit_id = pol.orgunit_orgunit_book_id AND ou.culture_id = @culture_id
  JOIN PRD_D_PRODUCT pr ON pr.prod_id = pol.prod_prod_id 
  left JOIN PRD_D_CL_BRAND BR ON BR.BRAND_ID = PR.BRAND_BRAND_ID AND BR.CULTURE_ID = @culture_id
  JOIN pay_d_cl_currency curr ON curr.ccurr_id = pol.ccurr_ccurr_id AND curr.culture_id = @culture_id
  left JOIN exchange_rate xRate on xRate.ccurr_ccurr_id = curr.ccurr_id
  left JOIN PAY_D_CL_PAYMENT_METHOD pm on pm.CPAYMETH_ID = pol.CPAYMET_CPAYMET_ID and pm.culture_id = @culture_id
  JOIN POL_D_CHANGETYPE cht ON cht.CHTY_ID = pol.CHTY_CHTY_ID
  JOIN POL_D_CL_CHANGE_TYPE ccht ON ccht.CHNGTY_ID = cht.CHNGTY_CHNGTY_ID AND ccht.culture_id = @culture_id 
  left JOIN Elm e on e.policy_policy_id = pol.policy_id
  left JOIN inc_t_zmena_typy zt2 ON zt2.zme_id = (select zme_zme_id from inc_t_zmluvy_h where zmlh_id = prem.policyh_orig_id /*prem.policyh_trans_id*/ )
  left join inc_v_cis_zmena_typ c2 ON c2.czmet_id = zt2.czmet_czmet_id AND c2.culture_id = 3
  -- cross apply fn_POL_DX_POLICY_PARTNERS(pol.policy_id) par
  outer apply fn_INC_V_POLICY_HISTORY(pol.policy_id) polh   
 -- cross apply fn_INC_V_POLICY_HISTORY_NEW(pol.policy_id) polh 
  LEFT JOIN prd_d_cl_coinsurance_type ct ON ct.coinsty_id = pol.coinsty_coinsty_id AND ct.culture_id = @culture_id
  LEFT JOIN coins_share cs ON cs.policy_id = pol.policy_id 
  LEFT HASH JOIN #tmp_covers cov ON cov.POLICY_ID = pol.policy_id
    
  -- outer apply fn_INC_V_POLICY_ENDORSEMENTS_NEW(ISNULL(prem.policyh_id, pol.policyh_id), prem.creation_date, @culture_id) endors   
  outer apply fn_INC_V_POLICY_ENDORSEMENTS_NEW(prem.policyh_orig_id, prem.creation_date, @culture_id) endors 
  outer apply fn_INC_V_POLICY_ENDORSEMENTS1(prem.policy_id, prem.creation_date, @culture_id) if_endors_null
  left JOIN par_d_cl_sale_channel sal ON sal.schann_id = endors.sales_channel_id AND sal.culture_id = @culture_id
 --  outer apply fn_POL_POLICY_HISTVER_PARTNERS (pol.policy_id, ISNULL(endors.policyh_id, pol.policyh_id)) par
  outer apply fn_POL_POLICY_HISTVER_PARTNERS (ISNULL(endors.policy_id,pol.policy_id), ISNULL(endors.policyh_id,pol.policyh_id)) par
  outer apply fn_INC_V_POLICY_PREMIUM_H(ISNULL(endors.policyh_id, pol.policyh_id)) premh
   
 WHERE (prem.premium_gross <> 0 OR prem.broker_commission <> 0)
   AND cast(prem.created_in_period as varchar) = '1'
   AND ISNULL(@DateFrom, '19000101') <= CASE --  WHEN @BasicDate = 'A' THEN CONVERT(date,ISNULL(ISNULL(endors.checker_time_stamp, if_endors_null.checker_time_stamp), polh.top_version_timestamp))
                                             WHEN @BasicDate = 'A' THEN ISNULL(@DateFrom, '19000101')
                                             WHEN @BasicDate = 'I' THEN CONVERT(date,ISNULL(ISNULL(endors.date_version_from, if_endors_null.date_version_from),polh.top_version_date_version_from))
											 WHEN @BasicDate = 'C' THEN CONVERT(date,ISNULL(pol.date_renewal, pol.date_conclusion))
                                         END 

   AND ISNULL(@DateTo, '99991231') >= CASE -- WHEN @BasicDate = 'A' THEN CONVERT(date,ISNULL(ISNULL(endors.checker_time_stamp, if_endors_null.checker_time_stamp), polh.top_version_timestamp))
                                           WHEN @BasicDate = 'A' THEN ISNULL(@DateTo, '99991231')
										   WHEN @BasicDate = 'I' THEN CONVERT(date,ISNULL(ISNULL(endors.date_version_from, if_endors_null.date_version_from),polh.top_version_date_version_from))
										   WHEN @BasicDate = 'C' THEN CONVERT(date,ISNULL(pol.date_renewal, pol.date_conclusion))
                                         END
   -- other filters base on input parameters 
    AND (@SysownID IS NULL OR pr.sysown_sysown_id = @SysownID)
    AND (ISNULL(@BranchCode,'')='' OR ou.code = @BranchCode)
    AND (ISNULL(@ClassCode,'')='' OR @ClassCode = SUBSTRING(pr.code,1,2))
    AND (ISNULL(@ProductCode,'')='' OR pr.code = @ProductCode)
    AND (ISNULL(@MarketerCode,'')='' OR par.ma_code LIKE concat('%',ISNULL(@MarketerCode,''),'%') )

--  AND pol.policy_number IN ('00366462005') -- ('00394772001')

-- ORDER BY pol.policy_number, prem.to_date
OPTION (FORCE ORDER)

  END;


GO


