dm 'out;clear;';
dm 'log;clear;';
 /*****************************************************************************\
*        O                                                                      
*       /                                                                       
*  O---O     _  _ _  _ _  _  _|                                                 
*       \ \/(/_| (_|| | |(/_(_|                                                 
*        O                                                                      
* ____________________________________________________________________________
* Sponsor              : c999
* Study                : PILOT01
* Program              : t_ae3.SAS
* Purpose              : Create table 14.5.4
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files: adsl adae
*              
* Output files: t_ae_int.rtf t_ae_int.sas7bdat
*               
* Macros: p_align p_mcrAddPageVar init 
*         
* Assumptions: 
*
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  20MAY2022    | Jake Tombeur   | Original version
\*****************************************************************************/

*********;
%init;
*********;

**** USER CODE FOR ALL DATA PROCESSING **;

/*===========================================================================*/
/*    General options                                                        */
/*===========================================================================*/
%let dddatanam  = t_ae_int;                         /* Dataset name for dddata */
%let tflid      = 14.5.4;                           /* Table ID */
%let outname    = t_ae_int;                         /* Output file name */

proc format;
   picture pctmf (round default = 8)                               /* Picture format for percentages */
               .     = ' '        (noedit)
        low-0.001    = ' '        (noedit)
        0.001-<0.1   = ' (<0.1%)' (noedit)
              0.1-<1 = '  (9.9%)' (prefix='  (')
         1-<99.90001 = ' (00.0%)' (prefix=' (')
       99.90001-<100 = '(>99.9%)' (noedit)
                 100 = '(100%)  ' (noedit)
   ;
run;

/*===========================================================================*/
/*    Creating count data                                                    */
/*===========================================================================*/

/* Dataset for safety analysis set teaes */
data steae_as;
    merge adamw.adae (in = inae)
          adamw.adsl (keep = usubjid saffl);
    by usubjid;
    if inae & saffl = 'Y' & trtemfl = 'Y' ;
run;

/* Adsl with trtan */
data adsl1;
    set adamw.adsl;
    trtan = trt01an;
run; 

%let indat     = steae_as;
%let trtvarn   = trtan;
%let inadsl    = adsl1;
%let socvar    = aesoc;
%let ptvar     = aedecod;
%let totval    = 99;
%let trtnord   = 99;
%let pctfmt    = pctmf.;
%let byvar     = aesev;

/* Macro for freating #patients/#events counts */
%macro ne_freq (indat =,outdat =, byvars =, anyvars = );

    %let byvars2  = %sysfunc(tranwrd(%quote(&byvars.) ,%str( ),%str( , )));
    %if &byvars ^= %then %let sep = %str( , );
    %else %let sep = ;

    proc sql;
        create table &outdat. as
        select count(distinct USUBJID) as stat_n,
               count(USUBJID) as stat_e
               &sep. &byvars2.
               %if &anyvars ^= %then %do i = 1 %to %sysfunc(countw(&anyvars));
                , 'ANY' as %scan(&anyvars, &i)
               %end;
        from &indat.
        %if &byvars. ^= %then group by &byvars2.;
        ;
    quit;

%mend;

/* All aes (with total column if required */
data aes;
    set &indat  
        &indat (in = intot);
    if intot then &trtvarn = &totval; 
run;

/* Adsl with total column if required */
data adslmod;
    set &inadsl
        &inadsl (in = intot );
    if intot then &trtvarn = &totval; 
run;

/* Counts including totals (by Severity) */
%ne_freq(indat = aes, outdat = out1, byvars = &byvar &trtvarn,                anyvars = &socvar &ptvar);
%ne_freq(indat = aes, outdat = out2, byvars = &byvar &trtvarn &socvar,        anyvars = &ptvar);
%ne_freq(indat = aes, outdat = out3, byvars = &byvar &trtvarn &socvar &ptvar, anyvars =);

/* Counts including totals (Any Severity) */
%ne_freq(indat = aes, outdat = out4, byvars = &trtvarn,                       anyvars = &byvar &socvar &ptvar);
%ne_freq(indat = aes, outdat = out5, byvars = &trtvarn &socvar,               anyvars = &byvar &ptvar);
%ne_freq(indat = aes, outdat = out6, byvars = &trtvarn &socvar &ptvar,        anyvars = &byvar);

/* N counts for denominators */
%ne_freq(indat = adslmod, outdat = Ncounts, byvars = &trtvarn, anyvars =);

data Ncounts; 
    set Ncounts (drop = stat_e rename = (stat_n = bigN)); 
    call symputx(cats('N_',&trtvarn), bigN, 'g');
run; 

/* Set all ae counts together */
data allcounts;
    length &socvar &ptvar $ 200;
    set out1-out6;
run;

/* Template dataset */
proc sql;
    create table template as
    select *, 0 as stat_e, 0 as stat_n
    from (select distinct &socvar, &ptvar from &indat 
          union 
          select distinct &socvar, 'ANY' as &ptvar from &indat 
          union 
          select distinct 'ANY' as &ptvar, 'ANY' as &socvar from &indat),
         (select distinct &byvar from &indat
          union 
          select distinct 'ANY' as &byvar from &indat),
         Ncounts
    order by &trtvarn, &socvar, &ptvar, &byvar;
    ;
quit;
    
/* Merge on observed counts to template */
proc sort data = allcounts out = allcounts_s;
    by &trtvarn &socvar &ptvar &byvar;
run;
data counts_w0;
    length &socvar &ptvar $ 200 statc_n statc_e statc_p $ 30;
    merge template allcounts_s;
    by &trtvarn &socvar &ptvar &byvar;
    /* Create character versions of counts */
    statc_n = strip(put(stat_n,5.));
    statc_e = strip(put(stat_e,5.));
    statc_p = put(stat_n/bigN * 100, &pctfmt);
run;

/* Align */
%p_align(dsetin = counts_w0, dsetout = counts_al, varsin = statc_e statc_n, varsout = ev np);

/* Concatenate n and percent*/
data counts_cat (keep = &socvar &ptvar &trtvarn &byvar ev npp);
    length ev npp $ 50;
    set counts_al;
    npp = cat(np, ' ', statc_p);
run;

/* Create SOC and PT order variables based on # patients / frequency of event */
proc rank data = counts_w0  (where = (&trtvarn = &trtnord & &ptvar = 'ANY' & &socvar ^= 'ANY' & &byvar = 'ANY')) out = socranks (keep = &socvar SOCord_NP SOCord_EV) ties = low descending;
    var stat_n stat_e;
    ranks SOCord_NP SOCord_EV;
run;

proc sort data = counts_w0 out = counts_w0s;
	by &socvar;
run;

proc rank data = counts_w0s (where = (&trtvarn = &trtnord & &ptvar ^= 'ANY' & &socvar ^= 'ANY' & &byvar = 'ANY')) out = ptranks (keep = &socvar &ptvar PTord_NP PTord_EV) ties = low descending;
    by &socvar;
    var stat_n stat_e;
    ranks PTord_NP PTord_EV;
run;

proc format;
    invalue sevord 'ANY'      = 1
                   'MILD'     = 2
                   'MODERATE' = 3
                   'SEVERE'   = 4
                   ;
run;

proc sql;
    create table counts_word as 
    select a.*, 
           case when a.&socvar = 'ANY' then 1 else b.SOCord_NP + 1 end as SOCord_NP, 
           case when a.&socvar = 'ANY' then 1 else b.SOCord_EV + 1 end as SOCord_EV,
           case when a.&ptvar  = 'ANY' then 1 else c.PTord_NP  + 1 end as PTord_NP,
           case when a.&ptvar  = 'ANY' then 1 else c.PTord_EV  + 1 end as PTord_EV,
           input(aesev,sevord.) as sevord
    from counts_cat a left join socranks b
                          on  a.&socvar = b.&socvar
                      left join ptranks c
                          on  a.&socvar = c.&socvar
                          and a.&ptvar  = c.&ptvar
    order by SOCord_NP, &socvar, PTord_NP, &ptvar, sevord, &byvar, &trtvarn
    ;
quit;

/* Transpose into long format */
proc transpose data = counts_word out = counts_T (rename = (_NAME_ = statty COL1 = statval));
    by SOCord_NP &socvar PTord_NP &ptvar sevord &byvar &trtvarn ;
    var npp ev;
run;

/* Transpose to trts are cols */
proc transpose delim = _ prefix = trt_ data = counts_T out = counts_TT (drop = _NAME_);
    id &trtvarn statty;
    by SOCord_NP &socvar PTord_NP  &ptvar sevord &byvar;
    var statval;
run;

data extrow (keep = aesoc aedecod soc_pt_disp aesev trt_0_npp trt_54_npp trt_81_npp); 
    length soc_pt_disp $ 200; 
    set counts_TT;
    by SOCord_NP aesoc;

    if first.aesoc & aesoc ^= 'ANY' then do;
        soc_pt_disp = aesoc;
        output;
    end;
    if aesoc = 'ANY' then do;
        soc_pt_disp = 'Subjects with at least one TEAE';
        output;
    end;
    if aedecod = 'ANY' then aedecod = 'Any event';
    soc_pt_disp = aedecod;
    if aesoc ^= 'ANY' then output;
run;

data final (drop = i);
    set extrow;
    array trtcounts $ trt_:;
    if aesoc = soc_pt_disp then do i = 1 to dim(trtcounts);
        trtcounts[i] = '';
        aesev = '  ';
    end;
    if aedecod = soc_pt_disp then indent = 'Y';
    else indent = 'N';

    if aesev = 'ANY' then aesev = 'Total';
    aesev = propcase(aesev);
run;

%p_mcrAddPageVar(dataset_in = final, dataset_out = final1, txt = soc_pt_disp, txt_col_width = 40, max_rows_per_page = 25)


/*===========================================================================*/
/*    Creating count data                                                    */
/*===========================================================================*/

/* Output the dddata */
data tflw.&dddatanam;
    set final1;
run;

%p_rtfCourier();
title; footnote;
ods listing close;
options orientation = landscape nodate nonumber;
ods rtf file = "&__env_runtime.&__delim.prod&__delim.tfl&__delim.output&__delim.&outname..rtf" style = rtfCourier ;
ods escapechar = '|';

/* Titles and footnotes for PROC REPORT */
title1 justify=l "Protocol: CDISCPILOT01" j=r "Page |{thispage} of |{lastpage}" ;
title2 justify=l "Population: Safety" ;
title3 justify=c "Table &tflid";
title4 justify=c "Summary of Treatment-Emergent Adverse events by System Organ Class, Preferred term and Intensity" ;

footnote1 justify=l "Treatment-emergent events are defined as adverse events following the first administration of the intervention that is either new or a worsening of an existing AE.";
footnote2 justify=l "Adverse Events are coded using MedDRA version xx.x.";
footnote3 justify=l "Percentages are based on the number of subjects in the safety population within each treatment group." ;
footnote4 justify=l "TEAE= Treatment-Emergent Adverse Event, MedDRA= Medical Dictionary for Regulatory Activities." ;
footnote5 ;
footnote6 justify=l "Source: &__full_path, %sysfunc(date(),date9.) %sysfunc(time(),tod5.)" ;
proc report data = tflw.&dddatanam split = '~'
            style = rtfCourier
            style(report) = {width=100%} 
            style(column) = {asis = on just = l}
            style(header) = {just = c}
            ;
  
            column page
                   aesoc
                   aedecod
                   indent
                   ("|S={bordertopcolor = black bordertopwidth =2}" soc_pt_disp)
                   ("|S={bordertopcolor = black bordertopwidth =2}" aesev)
                   ("|S={bordertopcolor = black bordertopwidth =2}Placebo~(N=&N_0)~ ~ " trt_0_npp)
                   ("|S={bordertopcolor = black bordertopwidth =2}Xanomeline Low Dose~(N=&N_54)~ ~ " trt_54_npp)
                   ("|S={bordertopcolor = black bordertopwidth =2}Xanomeline High Dose~(N=&N_81)~ ~ " trt_81_npp)
                   ;

            define page         / order order = data noprint;
            define aesoc        / order order = data noprint;
            define aedecod      / order order = data noprint;
            define indent       / order order = data noprint;
            define aesev        / display ''
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 10% just = l};
            define soc_pt_disp  / order order = data  "System Organ Class~|R'    'Preferred Term"
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 32% just = l};
            define trt_0_npp  / display 'n (%)'
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 19%} style(column) = {leftmargin = 4%};
            define trt_54_npp / display 'n (%)'
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 19%} style(column) = {leftmargin = 4%};
            define trt_81_npp / display 'n (%)'
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 19%} style(column) = {leftmargin = 4%};
            compute soc_pt_disp;
                if indent = 'Y' then call define(_COL_, "style", "style=[leftmargin = 0.3in]");
            endcomp;

            compute before aesoc;
                line '';
            endcomp;

            compute after page / style = {borderbottomcolor = black borderbottomwidth = 2};
                line ' ';
            endcomp;
            break after page / page;

            
    run;
ods rtf close;

**** END OF USER DEFINED CODE **;

********;
%scanlog;
********;

    