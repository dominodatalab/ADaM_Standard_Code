 /*****************************************************************************\
*  ____                  _
* |  _ \  ___  _ __ ___ (_)_ __   ___
* | | | |/ _ \| '_ ` _ \| | '_ \ / _ \
* | |_| | (_) | | | | | | | | | | (_) |
* |____/ \___/|_| |_| |_|_|_| |_|\___/
* ____________________________________________________________________________
* Sponsor              : c999
* Study                : PILOT01
* Program              : t_ae_saept.SAS
* Purpose              : Create table 14.5.8
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files: adsl adae
*              
* Output files: t_ae_saept.rtf t_ae_saept.sas7bdat
*               
* Macros: p_align p_mcrAddPageVar init 
*         
* Assumptions: 
*
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  26MAY2022    | Jake Tombeur   | Original version
\*****************************************************************************/

*********;
%include "!DOMINO_WORKING_DIR/config/domino.sas";
*********;

**** USER CODE FOR ALL DATA PROCESSING **;

/*===========================================================================*/
/*    General options                                                        */
/*===========================================================================*/
%let dddatanam  = t_ae_saept;                        /* Dataset name for dddata */
%let tflid      = 14.5.8;                            /* Table ID */
%let outname    = t_ae_saept;                        /* Output file name */

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

/* Dataset for safety analysis set saes */
data steae_as;
    merge adamw.adae (in = inae)
          adamw.adsl (keep = usubjid saffl);
    by usubjid;
    if inae & saffl = 'Y' & trtemfl = 'Y' & aeser = 'Y';
run;

/* Adsl with trtan */
data adsl1;
    set adamw.adsl;
    trtan = trt01an;
run; 

%let trtvarn = trtan;
%let ptvar   = aedecod;

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

/* Counts */
%ne_freq(indat = steae_as, outdat = allcounts, byvars = &trtvarn &ptvar, anyvars =);
 
/* N counts for denominators */
%ne_freq(indat = adsl1, outdat = Ncounts, byvars = &trtvarn, anyvars =)
data Ncounts; 
    set Ncounts (drop = stat_e rename = (stat_n = bigN)); 
    call symputx(cats('N_',&trtvarn), bigN, 'g');
run; 

/* Template dataset */
proc sql;
    create table template as
    select *, 0 as stat_n
    from (select distinct &ptvar from steae_as), Ncounts
    order by &trtvarn, &ptvar
    ;
quit;

/* Merge on observed counts to template */
proc sort data = allcounts (drop = stat_e) out = allcounts_s;
    by &trtvarn &ptvar;
run;
data counts_w0;
    length &ptvar $ 200 statc_n statc_p $ 30;
    merge template allcounts_s;
    by &trtvarn &ptvar;
    /* Create character versions of counts */
    statc_n = strip(put(stat_n,5.));
    statc_p = put(stat_n/bigN * 100, pctmf.);
run;

/* Align */
%p_align(dsetin = counts_w0, dsetout = counts_al, varsin = statc_n, varsout = np);

/* Concatenate count and % */
proc sql;
    create table counts_ord as
    select &ptvar, &trtvarn, cat(np, ' ', statc_p) as npp length = 50
    from counts_al
    order by &ptvar, &trtvarn
    ;
quit;

/* Transpose to trts are cols */
proc transpose delim = _ prefix = trt_ data = counts_ord out = counts_wide (drop = _NAME_ );
    id &trtvarn;
    by &ptvar;
    var npp;
run;

proc sql;
    create table counts_s as
    select &ptvar label = 'Preferred term', 
           trt_0 label  = 'n (%)', 
           trt_54 label = 'n (%)', 
           trt_81 label = 'n (%)'
    from counts_wide
    order by input(scan(trt_81,1,'('),5.) desc, input(scan(trt_54,1,'('),5.) desc, input(scan(trt_0,1,'('),5.) desc, &ptvar
    ;
quit;

%p_mcrAddPageVar(dataset_in = counts_s, dataset_out = final, txt = AEDECOD, txt_col_width = 40, max_rows_per_page = 25);


/*===========================================================================*/
/*    Outputs                                                                */
/*===========================================================================*/

data tflw.&dddatanam;
    set final (drop = page);
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
title4 justify=c "Summary of Treatment-Emergent Serious Adverse events by Preferred term in descending frequency" ;

footnote1 justify=l "Treatment-emergent events are defined as adverse events following the first administration of the intervention that is either new or a worsening of an existing AE.";
footnote2 justify=l "Adverse Events are coded using MedDRA version xx.x.";
footnote3 justify=l "Percentages are based on the number of subjects in the safety population within each treatment group." ;
footnote4 justify=l "TEAE= Treatment-Emergent Adverse Event, MedDRA= Medical Dictionary for Regulatory Activities." ;
footnote5 ;
footnote6 justify=l "Source: &__full_path, %sysfunc(date(),date9.) %sysfunc(time(),tod5.)" ;
proc report data = final split = '~'
            style = rtfCourier
            style(report) = {width=100%} 
            style(column) = {asis = on just = l}
            style(header) = {just = c}
            ;
  
            column page
                   ("|S={bordertopcolor = black bordertopwidth =2}" aedecod)
                   ("|S={bordertopcolor = black bordertopwidth =2}Placebo~(N=&N_0)~ ~ " trt_0)
                   ("|S={bordertopcolor = black bordertopwidth =2}Xanomeline Low Dose~(N=&N_54)~ ~ " trt_54)
                   ("|S={bordertopcolor = black bordertopwidth =2}Xanomeline High Dose~(N=&N_81)~ ~ " trt_81)
                   ;

            define page         / order order = data noprint;
            define aedecod      / order order = data
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 39% just = l};
            define trt_0        / display 
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 20%} style(column) = {leftmargin = 4%};
            define trt_54       / display 
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 20%} style(column) = {leftmargin = 4%};
            define trt_81       / display 
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 20%} style(column) = {leftmargin = 4%};
           
            compute before page;
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
**%scanlog;
********;

    
