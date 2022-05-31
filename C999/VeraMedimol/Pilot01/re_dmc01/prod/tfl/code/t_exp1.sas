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
* Study                : pilot01
* Program              : t_exp1.SAS
* Purpose              : Create the exposure table 14.4.1
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files: adsl
*              
* Output files: t_exp1.sas7bdat t_exp1.rtf
*               
* Macros: None
*         
* Assumptions: 
*
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  18/MAY/2022    | Jake Tombeur     | Original version
\*****************************************************************************/

*********;
%init;
*********;

**** USER CODE FOR ALL DATA PROCESSING **;

%let dddatanam  = t_exp1;      /* Dataset name for dddata */
%let tflid      = 14.4.1;      /* Table ID */
%let outname    = t_exp1;      /* Output file name */

data anadsl (keep = pop trt01pn cumdose avgdd);
    length pop $ 6;
    /* Data for each population */
    set adamw.adsl (in = inwk26 where = (complfl = 'Y'))
        adamw.adsl (in = insaf  where = (saffl    = 'Y'));
    if      inwk26 then pop = 'week24';
    else if insaf  then pop = 'safety';
run;

/* Create summary stats */
proc means data = anadsl nway;
    class pop trt01pn;
    var avgdd cumdose;
    output out = sumstats (drop = _:) n= mean= median= std= min= max= / autoname;
run;

/* Transpose into long format */
proc transpose data = sumstats out = sumstats_t (drop = _LABEL_ rename = (_NAME_ = sec_stat col1 = value));
    by pop trt01pn;
    var cumdose: avgdd:;
run;

/* Split up section and stat */
data stats_long (drop = sec_stat value);
    set sumstats_t;

    sec =  scan(sec_stat, 1, '_');
    stat = scan(sec_stat, 2, '_');

    if      stat in ('N', 'MIN', 'MAX') then valc = strip(put(value, 10.));
    else if stat in ('MEAN', 'MEDIAN')  then valc = strip(put(value, 11.1));
    else if stat = 'STDDEV'             then valc = strip(put(value, 12.2));
run;

/* Template dataset and mergin on stats */ 
data temp1;
    length stat statf $ 10;
    stat = 'N';      statf = 'n';      statord = 1;  output;
    stat = 'MEAN';   statf = 'Mean';   statord = 2;  output;
    stat = 'STDDEV'; statf = 'SD';     statord = 3;  output;
    stat = 'MEDIAN'; statf = 'Median'; statord = 4;  output;
    stat = 'MIN';    statf = 'Min.';   statord = 5;  output;
    stat = 'MAX';    statf = 'Max.';   statord = 6;  output;
run;

data temp2;
    length sec secf $ 50;
    sec = 'AVGDD';    secf = 'Average daily dose (mg)';                   secord = 1;  output;
    sec = 'CUMDOSE';  secf = 'Cumulative dose at end of study (mg) [2]';  secord = 2;  output;
run;

proc sql;
    create table template as select *
    from temp1, temp2, (select distinct trt01pn, pop  from anadsl)
    order by secord, statord
    ;

    create table stats_disp as 
    select a.statf, a.statord, a.secf, a.secord, a.pop, a.trt01pn, b.valc, 1 as page
    from template a left join stats_long b 
                        on  a.sec     = b.sec 
                        and a.stat    = b.stat
                        and a.pop     = b.pop
                        and a.trt01pn = b.trt01pn
    order by secord, statord
    ;
quit;

/* Transpose by treatment/population */
proc transpose delim = _ data = stats_disp out = tflw.&dddatanam (drop = _:);
    id pop trt01pn;
    by page secord secf statord statf;
    var valc;
run;


/* Macro variables for N headers */
%macro bigN (indat  =, /* Input dataset */ 
             byvars =  /* Space separated list of by variables to do counts by */);

    /* Comma separated by values */
    %let byvars2 = %sysfunc(tranwrd(%quote(&byvars.),%str( ),%str( , )));

    /* Create counts */
    proc sql;
        create table counts as
        select count(*) as N, &byvars2
        from &indat
        group by &byvars2
        ;
    quit;

    /* create golbal N macro variables */
    data _NULL_;
        set counts;
        call symputx(catx('_','N',&byvars2),strip(put(N, 15.)), 'g');
    run;
%mend;
%bigN(indat = anadsl, byvars = pop trt01pn);

%p_rtfCourier();
title; footnote;
ods listing close;
options orientation = landscape nodate nonumber;
ods rtf file = "&__env_runtime.&__delim.prod&__delim.tfl&__delim.output&__delim.&outname..rtf" style = rtfCourier ;
ods escapechar = '|';

/* Titles and footnotes for PROC REPORT */
title1 justify=l "Protocol: CDISCPILOT01" j=r "Page |{thispage} of |{lastpage}" ;
title2 justify=l "Population: Efficacy" ;
title3 justify=c "Table &tflid" ;
title4 justify=c "Summary of Planned Exposure to Study drug" ;

footnote1 justify=l "SD = Standard deviation. Min = Minimum. Max = Maximum.";
footnote2 justify=l "[1] Includes completers and early terminations.";
footnote3 justify=l "[2] End of study refers to Week 26/Early termination" ;
footnote4 ;
footnote5 justify=l "Source: &__full_path, %sysfunc(date(),date9.) %sysfunc(time(),tod5.)" ;
proc report data = tflw.&dddatanam split = '~'
            style = rtfCourier
            style(report) = {width=100%} 
            style(column) = {asis = on just = l}
            style(header) = {just = c asis = on}
            ;
  
            column page 
                   ('|S={bordertopcolor = black bordertopwidth = 2}' secf) 
                   ('|S={bordertopcolor = black bordertopwidth = 2}' statf) 
                   ('|S={bordertopcolor = black bordertopwidth = 2} Completers at Week 24' week24_0 week24_54 week24_81)
                   ('|S={bordertopcolor = black bordertopwidth = 2} Safety population [1]' safety_0 safety_54 safety_81);

            define page      / order order = data noprint;
            define secf      / order order = data  "|S={borderbottomcolor = black borderbottomwidth = 2}"
                                    style(column) = {width = 30%};
            define statf     / order order = data  "|S={borderbottomcolor = black borderbottomwidth = 2}"
                                    style(column) = {width = 9%};
            define week24_0  / display "|S={borderbottomcolor = black borderbottomwidth = 2} ~Placebo~(N=&N_week24_0)"
                                    style(column) = {leftmargin = 3% width = 10%};
            define week24_54 / display "|S={borderbottomcolor = black borderbottomwidth = 2} ~Xanomeline Low Dose~(N=&N_week24_54)"
                                    style(column) = {leftmargin = 3% width = 10%};
            define week24_81 / display "|S={borderbottomcolor = black borderbottomwidth = 2} ~Xanomeline High Dose~(N=&N_week24_81)"
                                    style(column) = {leftmargin = 3% width = 10%};
            define safety_0  / display "|S={borderbottomcolor = black borderbottomwidth = 2} ~Placebo~(N=&N_safety_0)"
                                    style(column) = {leftmargin = 3% width = 10%};
            define safety_54 / display "|S={borderbottomcolor = black borderbottomwidth = 2} ~Xanomeline Low Dose~(N=&N_safety_54)"
                                    style(column) = {leftmargin = 3% width = 10%};
            define safety_81 / display "|S={borderbottomcolor = black borderbottomwidth = 2} ~Xanomeline High Dose~(N=&N_safety_81)"
                                    style(column) = {leftmargin = 3% width = 10%};

            compute before secf;
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
