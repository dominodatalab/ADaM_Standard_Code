/*****************************************************************************\
*  ____                  _
* |  _ \  ___  _ __ ___ (_)_ __   ___
* | | | |/ _ \| '_ ` _ \| | '_ \ / _ \
* | |_| | (_) | | | | | | | | | | (_) |
* |____/ \___/|_| |_| |_|_|_| |_|\___/
* ____________________________________________________________________________
* Sponsor              : C999
* Study                : PILOT01
* Program              : t_ae_sum.SAS
* Purpose              : Create summary of teaes for safety population
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files: None
*              
* Output files: t_ae_sum.rtf t_ae_sum.sas7bdat
*               
* Macros: init scanlog u_pop p_align p_mcrAddPageVar p_rtfCourier
*         
* Assumptions: /
*
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  13APR2022  | Jake Tombeur | Original version
*  24MAY2022  | Jake Tombeur | Update formatting of rtf with new shells 
* ----------------------------------------------------------------------------
\*****************************************************************************/

*********;
%include "!DOMINO_WORKING_DIR/config/domino.sas";
*********;

**** USER CODE FOR ALL DATA PROCESSING **;

/*===========================================================================*/
/*    General options                                                        */
/*===========================================================================*/
%let relterms   = %str(('Possible', 'Probable', 'Definite'));  /* AEREL terms that count as 'treatment related' */
%let dddatanam  = t_ae_sum;                                      /* Dataset name for dddata */
%let tflid      = 14.5.1
;                                     /* Table ID */
%let outname    = t_ae_sum;                                      /* Output file name */

proc format;
   picture pctmf (round)                               /* Picture format for percentages */
               .     = ' '        (noedit)
        low-0.001    = ' '        (noedit)
        0.001-<0.1   = '(<0.1%)'  (noedit)
              0.1-<1 =   '9.9%)'  (prefix='(')
         1-<99.90001 =  '00.0%)'  (prefix='(')
       99.90001-<100 = '(>99.9%)' (noedit)
                 100 = '(100%)'   (noedit)
   ;
run;

/*===========================================================================*/
/*    Creating frequency counts                                              */
/*===========================================================================*/

/* Big N counts */
%u_pop(inds = adamw.adsl, trtvarn = trt01an, mvpre = POP, where = saffl = 'Y')

/* Creating treatment related flag, subsetting by teae and analysis set, joining on N */
proc sql;
    create table teae_as as 
    select a.*, b.count as Ncount,
           case when upcase(a.aerel) in &relterms. then 'Y'
               else 'N' end as aerelfl label = 'Treatement related AE flag' 

    from adamw.adae a left join upop_counts b 
           on a.trtan = b.trtvarn
    where a.saffl = 'Y' & a.trtemfl = 'Y'
    order by a.usubjid, a.trta, Ncount, a.aeseq
    ;
run;

/* Transpose so each ae has a row for each row in output */
proc transpose data = teae_as out = teae_as_t (rename = (col1 = flagval _name_ = flagtype _label_ = flaglab));
    by usubjid trta trtan Ncount aeseq;
    var aesdth aeser aerelfl trtemfl;
run;

/* Create number of subjects, number of events and percents */
proc sql;
    create table counts as
    select distinct lowcase(flagtype) as flagtype, flaglab, trtan, trta,
           strip(put(count(distinct usubjid), best.)) as np,
           strip(put(round(count(distinct usubjid)/Ncount * 100,0.1), pctmf.)) as perc,
           strip(put(count(usubjid), best.)) as ev
    from teae_as_t (where = (flagval = 'Y'))
    group by flagtype, trtan
    ;
quit;

/*===========================================================================*/
/*   Formatting counts                                                       */
/*===========================================================================*/

/* Create template dataset to fill in zeros */
data temp_rows;
    length flagtype $ 10 flaglab $ 100;
    flagtype = 'trtemfl'; flaglab = 'Any TEAE';                                                                            ord = 1; output;
    flagtype = 'aeser';   flaglab = 'Any Serious TEAE';                                                                    ord = 2; output;
    flagtype = 'aesdth';  flaglab = 'Any Fatal TEAE';                                                                      ord = 3; output;
    flagtype = 'aerelfl'; flaglab = 'Any TEAE Related to Study Treatment';                                                 ord = 4; output;
/*    flagtype = 'aeacn';   flaglab = 'Any TEAE Leading to Discontinuation of Study Treatment or Withdrawal from the Study'; ord = 5; output;*/
run;

proc sql;
    create table template as
    select a.*, b.*
    from temp_rows a, (select distinct trt01a as trta, trt01an as trtan from adamw.adsl) b
    ;

    /* Merge counts onto template - filling in any missings as zeros */
    create table counts_w0 as 
    select a.*, b.perc, 
           case when b.np ^= '' then b.np else '0' end as np, 
           case when b.ev ^= '' then b.ev else '0' end as ev
    from template a left join counts b
        on  a.flagtype = b.flagtype 
        and a.trta     = b.trta
    order by ord, flaglab, trta, trtan
    ;
quit;

/* Align counts and percentages - and concatenate np and perc*/
%p_align(dsetin = counts_w0, dsetout = counts_al, varsin = np ev perc, varsout = np_A ev_A perc_A);

data counts_cat (keep = ord flaglab trta trtan npp ev);
    length npp ev $30;
    set counts_al;

    ev = ev_A;
    npp = cat(np_A,' ', perc_A);
run;

/* Transpose so treatments are columns */
proc transpose data = counts_cat out = counts_T (rename = (COL1 = Value _NAME_ = statty));
    by ord flaglab trta trtan;
    var npp ev;
run;

proc transpose prefix = trt_ delimiter = _ data = counts_T out = counts_TT (drop = _NAME_);
    by ord flaglab;
    id trtan statty;
    var value;
run;

%p_mcrAddPageVar(dataset_in = counts_TT, dataset_out = final, txt = flaglab, txt_col_width = 40, max_rows_per_page = 20)
/*===========================================================================*/
/*   Output files                                                            */
/*===========================================================================*/

/* Output the dddata */
data tflw.&dddatanam;
    set final;
run;

/* Create rtf output */
%p_rtfCourier();
title; footnote;

options orientation = landscape nodate nonumber;
ods rtf file = "&__env_runtime.&__delim.prod&__delim.tfl&__delim.output&__delim.&outname..rtf" style = rtfCourier ;
ods escapechar = '|';

    /* Titles and footnotes for PROC REPORT */
    title1 justify=l "Protocol: CDISCPILOT01" j=r "Page |{thispage} of |{lastpage}" ;
    title2 justify=l "Population: Safety" ;
    title3 justify=c "Table &tflid";
    title4 justify=c "Overview of Treatment-Emergent Adverse events" ;

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
                   ("|S={bordertopcolor = black bordertopwidth =2}" flaglab)
                   ("|S={bordertopcolor = black bordertopwidth =2}Placebo~(N=&POP0)~ ~ " trt_0_npp trt_0_ev)
                   ("|S={bordertopcolor = black bordertopwidth =2}Xanomeline Low Dose~(N=&POP54)~ ~ " trt_54_npp trt_54_ev)
                   ("|S={bordertopcolor = black bordertopwidth =2}Xanomeline High Dose~(N=&POP81)~ ~ " trt_81_npp trt_81_ev)
                   ;

            define page         / order order = data noprint;
            define flaglab      / order order = data ""
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 33%};
            define trt_0_npp    / order order = data 'n (%)'
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 11%} style(column) = {leftmargin = 1%};
            define trt_0_ev     / order order = data 'Total Events'
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 11%} style(column) = {leftmargin = 3%};
            define trt_54_npp   / order order = data 'n (%)'
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 11%} style(column) = {leftmargin = 1%};
            define trt_54_ev    / order order = data 'Total Events'
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 11%} style(column) = {leftmargin = 3%};
            define trt_81_npp   / order order = data 'n (%)'
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 11%} style(column) = {leftmargin = 1%};
            define trt_81_ev    / order order = data 'Total Events'
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 11%} style(column) = {leftmargin = 3%};
            
            compute before page;
                line ' ';
            endcomp;

            compute after page / style = {borderbottomcolor = black borderbottomwidth = 2};
                line ' ';
            endcomp;

            
    run;
    
ods rtf close; 
title; footnote;


**** END OF USER DEFINED CODE **;

********;
**%scanlog;
********;

