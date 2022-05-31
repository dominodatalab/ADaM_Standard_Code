/*****************************************************************************\
*        O                                                                      
*       /                                                                       
*  O---O     _  _ _  _ _  _  _|                                                 
*       \ \/(/_| (_|| | |(/_(_|                                                 
*        O                                                                      
* ____________________________________________________________________________
* Sponsor              : Evelo
* Study                : 1867-101
* Analysis             : Final Analysis
* Program              : q_big_n.sas
* Purpose              : QC macro to calculate the big N totals for each treatment.
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files:                                                    
*                                                                   
* Output files:                                                   
*                                                                 
* Macros:                                                         
*                                                                   
* Assumptions:                                                    
*                                                                   
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  08SEP2021  |  Natalie Thompson  |  Original                                    
* ----------------------------------------------------------------------------
*  16DEC2021  |  Natalie Thompson  |  Updated to include macro variables as global.        
\*****************************************************************************/


%macro q_big_n(popfl = /* Include the name of the population flag for your output e.g. enrlfl, fasfl, saffl, etc. */
                );

%global trt1_hv trt1_hv_l
        trt2_hv trt2_hv_l
		trt3_hv trt3_hv_l
		trt4_hv trt4_hv_l
		trt5_hv trt5_hv_l
		trt6_hv trt6_hv_l
		trt1_ad trt1_ad_l
		trt2_ad trt2_ad_l
		trt1_ps trt1_ps_l
		trt2_ps trt2_ps_l
		trt1_as trt1_as_l
		trt2_as trt2_as_l;

/* Calculate Big N */
proc sql noprint;

  /* Placebo period 1 - HV */
  select count(distinct usubjid), strip(tr01ag1) || "$(N=" || strip(put(count(distinct usubjid),best.)) || ")" into :trt1_hv, :trt1_hv_l
  from adam.adsl 
  where &popfl. = "Y" and tr01ag1n = 1;

  /* EDP1867 4.5 x 10^10  period 1 - HV */
  select count(distinct usubjid), strip(tr01ag1) || "$(N=" || strip(put(count(distinct usubjid),best.)) || ")" into :trt2_hv, :trt2_hv_l
  from adam.adsl 
  where &popfl. = "Y" and tr01ag1n = 2;

  /* EDP1867 1.5 x 10^11 period 1 - HV */
  select count(distinct usubjid), strip(tr01ag1) || "$(N=" || strip(put(count(distinct usubjid),best.)) || ")" into :trt3_hv, :trt3_hv_l
  from adam.adsl 
  where &popfl. = "Y" and tr01ag1n = 4;

  /* Placebo period 2 - HV */
  select count(distinct usubjid), strip(tr02ag1) || "$(N=" || strip(put(count(distinct usubjid),best.)) || ")" into :trt4_hv, :trt4_hv_l
  from adam.adsl 
  where &popfl. = "Y" and tr02ag1n = 1;

  /* EDP1867 7.5 x 10^11 period 2 - HV */
  select count(distinct usubjid), strip(tr02ag1) || "$(N=" || strip(put(count(distinct usubjid),best.)) || ")" into :trt5_hv, :trt5_hv_l
  from adam.adsl 
  where &popfl. = "Y" and tr02ag1n = 3;

  /* EDP1867 1.5 x 10^12 period 2 - HV */
  select count(distinct usubjid), strip(tr02ag1) || "$(N=" || strip(put(count(distinct usubjid),best.)) || ")" into :trt6_hv, :trt6_hv_l
  from adam.adsl 
  where &popfl. = "Y" and tr02ag1n = 5;

  /* Placebo - AD */
  select count(distinct usubjid), strip(tr01ag1) || "$(N=" || strip(put(count(distinct usubjid),best.)) || ")" into :trt1_ad, :trt1_ad_l
  from adam.adsl 
  where &popfl. = "Y" and tr01ag1n = 6;

  /* EDP1867 7.5 x 10^11 - AD */
  select count(distinct usubjid), strip(tr01ag1) || "$(N=" || strip(put(count(distinct usubjid),best.)) || ")" into :trt2_ad, :trt2_ad_l
  from adam.adsl 
  where &popfl. = "Y" and tr01ag1n = 7;

  /* Placebo - Ps */
  select count(distinct usubjid), strip(tr01ag1) || "$(N=" || strip(put(count(distinct usubjid),best.)) || ")" into :trt1_ps, :trt1_ps_l
  from adam.adsl 
  where &popfl. = "Y" and tr01ag1n = 8;

  /* EDP1867 7.5 x 10^11 - Ps */
  select count(distinct usubjid), strip(tr01ag1) || "$(N=" || strip(put(count(distinct usubjid),best.)) || ")" into :trt2_ps, :trt2_ps_l
  from adam.adsl 
  where &popfl. = "Y" and tr01ag1n = 9;

  /* Placebo - As */
  select count(distinct usubjid), strip(tr01ag1) || "$(N=" || strip(put(count(distinct usubjid),best.)) || ")" into :trt1_as, :trt1_as_l
  from adam.adsl 
  where &popfl. = "Y" and tr01ag1n = 10;

  /* EDP1867 7.5 x 10^11 - As */
  select count(distinct usubjid), strip(tr01ag1) || "$(N=" || strip(put(count(distinct usubjid),best.)) || ")" into :trt2_as, :trt2_as_l
  from adam.adsl 
  where &popfl. = "Y" and tr01ag1n = 11;

quit;

%mend q_big_n;
