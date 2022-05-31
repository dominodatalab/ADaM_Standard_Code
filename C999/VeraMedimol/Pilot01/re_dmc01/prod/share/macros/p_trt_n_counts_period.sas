/*****************************************************************************\
*        O                                                                     
*       /                                                                      
*  O---O     _  _ _  _ _  _  _|                                                
*       \ \/(/_| (_|| | |(/_(_|                                                
*        O                                                                     
* ____________________________________________________________________________
* Sponsor              :  Evelo
* Study                :  EDP1867-101
* Analysis             :
* Program              :  p_trt_N_counts_period.sas
* ____________________________________________________________________________
* DESCRIPTION                                                   
*                                                                   
* Input files: adam.adsl                                                  
*                                                                   
* Output files: Global Macro Variables trt1_hv trt2_hv trt3_hv trt4_hv trt5_hv trt6_hv 
*									   trt1_ad trt2_ad
*									   trt1_ps trt2_ps
*									   trt1_as trt2_as
*                                                                
* Macros: None                                                        
*                                                                   
* Assumptions: Creates counts for treatment and group subsets of patient data 
*			   for each treatment period.                                            
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
* ----------------------------------------------------------------------------
*  21SEP2021  |  Daniil Trunov   |  Original.
\*****************************************************************************/


%macro p_trt_N_counts_period(flag=, trt01var = tr01pg1n, trt02var = tr02pg1n);

/* Placebo [HV] Period 1 */
%global trt1_hv;
/* EDP1867 4.5 x 10^10 [HV] */
%global trt2_hv;
/* EDP1867 1.5 x 10^11 [HV] */
%global trt3_hv;
/* Placebo [HV] Period 2 */
%global trt4_hv;
/* EDP1867 7.5 x 10^11 [HV] */
%global trt5_hv;
/* EDP1867 1.5 x 10^12 [HV] */
%global trt6_hv;
/* Placebo [AD] */
%global trt1_ad;
/* EDP1867 7.5 x 10^11 [AD] */
%global trt2_ad;
/* Placebo [Ps] */
%global trt1_ps;
/* EDP1867 7.5 x 10^11 [Ps] */
%global trt2_ps;
/* Placebo [As] */
%global trt1_as;
/* EDP1867 7.5 x 10^11 [As] */
%global trt2_as;


proc sql noprint;

    select count(distinct usubjid) into: trt1_hv
    from adam.adsl
    where &trt01var.=1 and &flag. = 'Y';

	select count(distinct usubjid) into: trt2_hv
    from adam.adsl
    where &trt01var.=2 and &flag. = 'Y';

	select count(distinct usubjid) into: trt3_hv
    from adam.adsl
    where &trt01var.=4 and &flag. = 'Y';

	select count(distinct usubjid) into: trt4_hv
    from adam.adsl
    where &trt02var.=1 and &flag. = 'Y';

	select count(distinct usubjid) into: trt5_hv
    from adam.adsl
    where &trt02var.=3 and &flag. = 'Y';

	select count(distinct usubjid) into: trt6_hv
    from adam.adsl
    where &trt02var.=5 and &flag. = 'Y';

	select count(distinct usubjid) into: trt1_ad
    from adam.adsl
    where &trt01var.=6  and &flag. = 'Y';

	select count(distinct usubjid) into: trt2_ad
    from adam.adsl
    where &trt01var.=7  and &flag. = 'Y';

	select count(distinct usubjid) into: trt1_ps
    from adam.adsl
    where &trt01var.=8  and &flag. = 'Y';

	select count(distinct usubjid) into: trt2_ps
    from adam.adsl
    where &trt01var.=9  and &flag. = 'Y';

	select count(distinct usubjid) into: trt1_as
    from adam.adsl
    where &trt01var.=10  and &flag. = 'Y';

	select count(distinct usubjid) into: trt2_as
    from adam.adsl
    where &trt01var.=11  and &flag. = 'Y';

quit;

%mend p_trt_N_counts_period;


