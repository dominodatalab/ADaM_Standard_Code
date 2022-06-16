/*****************************************************************************\
*        O                                                                      
*       /                                                                       
*  O---O     _  _ _  _ _  _  _|                                                 
*       \ \/(/_| (_|| | |(/_(_|                                                 
*        O                                                                      
* ____________________________________________________________________________
* Sponsor              : Domino
* Study                : H2QMCLZZT
* Program              : t_pop.SAS
* Purpose              : Create Summary of populations table 
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files: adsl
*              
* Output files: t_pop.rtf t_pop.sas7bdat
*               
* Macros: None
*         
* Assumptions: 
*
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  07JUN2022      | Jake Tombeur     | Original version
\*****************************************************************************/
%include "!DOMINO_WORKING_DIR/config/domino.sas";

**** USER CODE FOR ALL DATA PROCESSING **;

%let dddatanam  = t_pop;      /* Dataset name for dddata */
%let tflid      = 14.1.1;     /* Table ID */
%let outname    = t_pop;      /* Output file name */

/* Picture format for percentages */
proc format;
   picture pctmf (round default = 8)                              
               .     = ' '        (noedit)
        low-0.001    = ' '        (noedit)
        0.001-<0.1   = ' (<0.1%)' (noedit)
              0.1-<1 = '  (9.9%)' (prefix='  (')
         1-<99.90001 = ' (00.0%)' (prefix=' (')
       99.90001-<100 = '(>99.9%)' (noedit)
                 100 = '(100%)  ' (noedit)
   ;
run;

/* Create total column data and sort */
data adsltot (where = (trt01an ^= .));
    set adam.adsl adam.adsl (in = intot);
    if intot then trt01an = 99;
run;
proc sort data = adsltot out = adsltot_s;
    by usubjid trt01an;
run;

/* Extract and transpose population flags by usubjid */
proc transpose data = adsltot_s (keep = trt01an usubjid ittfl saffl efffl comp26fl complfl)
               out = pops_t (rename = (col1 = flag _name_ = flagvar) where = (flag = 'Y'));
    by usubjid trt01an;
    var ittfl saffl efffl comp26fl complfl;
run;

/* Partial template (with row order and display variable */
data temp_part;
length flagvar $ 8 flaglab $ 25;
    flagvar = 'ittfl'   ; flagord = 1; flaglab = 'Intent-to-treat (ITT)'; output; 
    flagvar = 'saffl'   ; flagord = 2; flaglab = 'Safety';                output; 
    flagvar = 'efffl'   ; flagord = 3; flaglab = 'Efficacy';              output;
    flagvar = 'complfl';  flagord = 4; flaglab = 'Completer Week 24';     output;
    flagvar = 'comp26fl'; flagord = 5; flaglab = 'Complete Study';        output;
run;

proc sql;
    /* Dataset containing big n counts */
    create table bign as
    select count(distinct usubjid) as bign, trt01an
    from adsltot_s
    group by trt01an
    ; 

    /* Create and merge template with observed counts */
    create table n_perc as 
    select a.*, ifc(b.count = . ,'0',strip(put(b.count, 5.))) as count, put(round(100*b.count/a.bign,0.1), pctmf.) as perc
    from (select * from bign, temp_part) a
         left join (select count(distinct usubjid) as count, trt01an, flagvar
                    from pops_t
                    group by trt01an, flagvar) b
         on  a.trt01an = b.trt01an
         and a.flagvar = lowcase(b.flagvar)
    ;
quit;

/* Align counts, then concatenate with percentage*/
%p_align(dsetin = n_perc, dsetout = nal_perc, varsin = count, varsout = count_A);

/* Concatenate n and % , add page variable */
proc sql;
    create table statcat as
    select cat(count_a,' ', perc) as npp, 1 as page, flagord, flaglab, trt01an
    from nal_perc
    order by page, flagord, flaglab
    ;
quit;

/* Transpose into final dddataset */
proc transpose prefix = trt_ data = statcat out = tfl.&dddatanam (drop = _name_);
    by page flagord flaglab;
    id trt01an;
    var npp;
run;

/* Macro variables for proc report */
data _NULL_;
    set bign;
    call symput(cats('N_', trt01an), strip(put(bign,5.)));
run; 

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

title; footnote;
ods listing close;
options orientation = landscape nodate nonumber;
ods pdf file = "/mnt/artifacts/results/&outname..pdf" style = pdfstyle;
ods escapechar = '|';
/* Titles and footnotes for PROC REPORT */
title1 justify=l "Protocol: &__PROTOCOL." j=r "Page |{thispage} of |{lastpage}" ;
title2 justify=l "Population: All subjects" ;
title3 justify=c "Table &tflid";
title4 justify=c "Summary of Populations" ;

footnote1 justify=l "N in column headers represents number of subjects entered into the study (i.e. signed informed consent).";
footnote2 justify=l "The ITT population includes all subjects randomized.";
footnote3 justify=l "The safety population includes all randomized subjects known to have taken at least one dose of randomized study drug." ;
footnote4 justify=l "The efficacy population includes all subjects in the safety population who also have at least one post-baseline ADAS-cog and CIBIC+ assessment. " ;
footnote5 ;
footnote6 justify=l "Project: &__PROJECT_NAME. Datacut: &__DCUTDTC. File: &__prog_path/&__prog_name..&__prog_ext , %sysfunc(date(),date9.) %sysfunc(time(),tod5.)" ;
proc report data = tfl.&dddatanam split = '~'
            style = pdfstyle
            style(report) = {width=100% font_face = 'courier new'} 
            style(column) = {asis = on just = l}
            style(header) = {just = c borderbottomcolor = black borderbottomwidth = 2 bordertopcolor = black bordertopwidth = 2}
            ;
  
            column page flaglab trt_0 trt_54 trt_81 trt_99;

            define page      / order order = data noprint;
            define flaglab   / order order = data  " ~Population"
                                    style(header) = {width = 23% just = l};
            define trt_0     / display "Placebo~(N=&N_0)"
                                    style(header) = {width = 19%} style(column) = {leftmargin = 3%};
            define trt_54    / display "Xanomeline Low Dose~(N=&N_54)"
                                    style(header) = {width = 19%} style(column) = {leftmargin = 3%};
            define trt_81    / display "Xanomeline High Dose~(N=&N_81)"
                                    style(header) = {width = 19%} style(column) = {leftmargin = 3%};
            define trt_99    / display "Total~(N=&N_99)"
                                    style(header) = {width = 19%} style(column) = {leftmargin = 3%};

            compute before page;
                line '';
            endcomp;

            compute after page / style = {borderbottomcolor = black borderbottomwidth = 2};
                line ' ';
            endcomp;
            break after page / page;

            
    run;
ods pdf close;

*EOF;


