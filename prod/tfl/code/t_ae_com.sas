/*****************************************************************************\
*  ____                  _
* |  _ \  ___  _ __ ___ (_)_ __   ___
* | | | |/ _ \| '_ ` _ \| | '_ \ / _ \
* | |_| | (_) | | | | | | | | | | (_) |
* |____/ \___/|_| |_| |_|_|_| |_|\___/
* ____________________________________________________________________________
* Sponsor              : Domino
* Study                : H2QMCLZZT
* Program              : t_ae_com.SAS
* Purpose              : Create table 14.5.7
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files: adsl adae
*              
* Output files: t_ae_com.rtf t_ae_com.sas7bdat
*               
* Macros: p_align p_mcrAddPageVar init 
*         
* Assumptions: 
*
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  25MAY2022    | Jake Tombeur   | Original version
\*****************************************************************************/

*********;
%include "!DOMINO_WORKING_DIR/config/domino.sas";
*********;

**** USER CODE FOR ALL DATA PROCESSING **;

/*===========================================================================*/
/*    General options                                                        */
/*===========================================================================*/
%let dddatanam  = t_ae_com;                          /* Dataset name for dddata */
%let tflid      = 14.5.7;                            /* Table ID */
%let outname    = t_ae_com;                          /* Output file name */

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

/* Dataset for safety analysis set aes */
data teae_as;
    merge adam.adae (in = inae)
          adam.adsl (keep = usubjid saffl);
    by usubjid;
    if inae & saffl = 'Y' & trtemfl = 'Y';
run;

/* Adsl with trtan */
data adsl1 (where = (trtan ^= .));
    set adam.adsl;
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
%ne_freq(indat = teae_as, outdat = allcounts, byvars = &trtvarn &ptvar, anyvars =);
 
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
    from (select distinct &ptvar from teae_as), Ncounts
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
proc transpose delim = _ prefix = trt_ data = counts_ord out = counts_wide (drop = _NAME_ where = ( max(input(compress(scan(trt_0 , 2, '('),'.',"kd"),8.1),
                                                                                                        input(compress(scan(trt_54, 2, '('),'.',"kd"),8.1),
                                                                                                        input(compress(scan(trt_81, 2, '('),'.',"kd"),8.1)) >= 5 ));
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

%p_mcraddpagevar(dataset_in = counts_s, dataset_out = final, txt = AEDECOD, txt_col_width = 40, max_rows_per_page = 25);


/*===========================================================================*/
/*    Outputs                                                                */
/*===========================================================================*/

proc template;
	define style styles.pdfstyle;
		parent = styles.journal;
		replace fonts /
			'TitleFont' = ("Courier new",9pt) /* Titles from TITLE statements */
			'TitleFont2' = ("Courier new",9pt) /* Procedure titles ("The _____ Procedure")*/
			'StrongFont' = ("Courier new",9pt)
			'EmphasisFont' = ("Courier new",9pt)
			'headingEmphasisFont' = ("Courier new",9pt)
			'headingFont' = ("Courier new",9pt) /* Table column and row headings */
			'docFont' = ("Courier new",9pt) /* Data in table cells */
			'footFont' = ("Courier new",9pt) /* Footnotes from FOOTNOTE statements */
			'FixedEmphasisFont' = ("Courier new",9pt)
			'FixedStrongFont' = ("Courier new",9pt)
			'FixedHeadingFont' = ("Courier new",9pt)
			'BatchFixedFont' = ("Courier new",9pt)
			'FixedFont' = ("Courier new",9pt);
	end;
run;


data tfl.&dddatanam;
    set final;
run;

title; footnote;
ods listing close;
options orientation = landscape nodate nonumber;
ods pdf file = "/mnt/artifacts/results/&outname..pdf" style = pdfstyle;
ods escapechar = '|';

/* Titles and footnotes for PROC REPORT */
title1 justify=l "Protocol: &__PROTOCOL." j=r "Page |{thispage} of |{lastpage}" ;
title2 justify=l "Population: Safety" ;
title3 justify=c "Table &tflid";
title4 justify=c "Summary of Common (>=5%) Treatment-Emergent Adverse events by Preferred term in descending frequency" ;

footnote1 justify=l "Treatment-emergent events are defined as adverse events following the first administration of the intervention that is either new or a worsening of an existing AE.";
footnote2 justify=l "Common is defined as an incidence of >=5% in any treatment group.";
footnote3 justify=l "Adverse Events are coded using MedDRA version xx.x.";
footnote4 justify=l "Percentages are based on the number of subjects in the safety population within each treatment group." ;
footnote5 justify=l "TEAE= Treatment-Emergent Adverse Event, MedDRA= Medical Dictionary for Regulatory Activities." ;
footnote6 ;
footnote7 justify=l "Project: &__PROJECT_NAME. Datacut: &__DCUTDTC. File: &__prog_path/&__prog_name..&__prog_ext , %sysfunc(date(),date9.) %sysfunc(time(),tod5.)" ;
proc report data = final split = '~'
            style = pdfstyle
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
ods pdf close;

**** END OF USER DEFINED CODE **;

********;
**%scanlog;
********;

    
