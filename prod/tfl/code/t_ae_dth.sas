 /*****************************************************************************\
*  ____                  _
* |  _ \  ___  _ __ ___ (_)_ __   ___
* | | | |/ _ \| '_ ` _ \| | '_ \ / _ \
* | |_| | (_) | | | | | | | | | | (_) |
* |____/ \___/|_| |_| |_|_|_| |_|\___/
* ____________________________________________________________________________
* Sponsor              : c999
* Study                : PILOT01
* Program              : t_ae_dth.SAS
* Purpose              : Create table 14.5.6
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files: adsl adae
*              
* Output files: t_ae_dth.rtf t_ae_dth.sas7bdat
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
%let dddatanam  = t_ae_dth;                            /* Dataset name for dddata */
%let tflid      = 14.5.6;                              /* Table ID */
%let outname    = t_ae_dth;                            /* Output file name */

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

/* Dataset for safety analysis set death aes */
data teae_as;
    merge adamw.adae (in = inae)
          adamw.adsl (keep = usubjid saffl);
    by usubjid;
    if inae & saffl = 'Y' & trtemfl = 'Y' & aesdth = 'Y';
run;

/* Adsl with trtan */
data adsl1;
    set adamw.adsl;
    trtan = trt01an;
run; 

%macro soc_pt(indat     =, /* Input dataset */ 
              outdat    =, /* Output dataset */
              trtvarn   =, /* Numeric treatment variable */
              inadsl    =, /* Adsl dataset (must include trtvarn) for % */ 
              socvar    =, /* SOC variable */
              ptvar     =, /* Preferred Term variable */
              totval    =, /* If total column wanted, defines numeric treatment for total */
              totcond   =, /* If total column should not be all values of trtvar, use to specify which, i.e. trta in (1,3) */
              trtnord   =, /* Numeric treatment column to use for the sort order */
              pctfmt    =  /* Picture format for percentages */ 
              );

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
        %if  &totval ^= %then %do;    
            &indat (in = intot where = (%if &totcond ^= %then &totcond; %else &trtvarn ^= .;));
            if intot then &trtvarn = &totval; 
        %end;
        %else ; ; 
    run;

    /* Adsl with total column if required */
    data adslmod;
        set &inadsl
        %if  &totval ^= %then %do;    
            &inadsl (in = intot where = (%if &totcond ^= %then &totcond; %else &trtvarn ^= .;));
            if intot then &trtvarn = &totval; 
        %end;
        %else ; ; 
    run;

    /* Counts including totals */
    %ne_freq(indat = aes, outdat = out1, byvars = &trtvarn,                anyvars = &socvar &ptvar);
    %ne_freq(indat = aes, outdat = out2, byvars = &trtvarn &socvar,        anyvars = &ptvar);
    %ne_freq(indat = aes, outdat = out3, byvars = &trtvarn &socvar &ptvar, anyvars =);
 
    /* N counts for denominators */
    %ne_freq(indat = adslmod, outdat = Ncounts, byvars = &trtvarn, anyvars =)
    data Ncounts; 
        set Ncounts (drop = stat_e rename = (stat_n = bigN)); 
        call symputx(cats('N_',&trtvarn), bigN, 'g');
    run; 

    /* Set all ae counts together */
    data allcounts;
        length &socvar &ptvar $ 200;
        set out1 out2 out3;
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
              Ncounts
        order by &trtvarn, &socvar, &ptvar;
        ;
    quit;
    
    /* Merge on observed counts to template */
    proc sort data = allcounts out = allcounts_s;
        by &trtvarn &socvar &ptvar;
    run;
    data counts_w0;
        length &socvar &ptvar $ 200 statc_n statc_e statc_p $ 30;
        merge template allcounts_s;
        by &trtvarn &socvar &ptvar;
        /* Create character versions of counts */
        statc_n = strip(put(stat_n,5.));
        statc_e = strip(put(stat_e,5.));
        statc_p = put(stat_n/bigN * 100, &pctfmt);
    run;

    /* Align */
    %p_align(dsetin = counts_w0, dsetout = counts_al, varsin = statc_e statc_n, varsout = ev np);

    /* Concatenate n and percent*/
    data counts_cat (keep = &socvar &ptvar &trtvarn ev npp);
        length ev npp $ 50;
        set counts_al;
        npp = cat(np, ' ', statc_p);

    run;

    /* Create SOC and PT order variables based on # patients / frequency of event */
    proc rank data = counts_w0  (where = (&trtvarn = &trtnord & &ptvar = 'ANY' & &socvar ^= 'ANY')) out = socranks (keep = &socvar SOCord_NP SOCord_EV) ties = low descending;
        var stat_n stat_e;
        ranks SOCord_NP SOCord_EV;
    run;

	proc sort data = counts_w0 out = counts_w0s;
		by &socvar;
	run;

    proc rank data = counts_w0s (where = (&trtvarn = &trtnord & &ptvar ^= 'ANY' & &socvar ^= 'ANY')) out = ptranks (keep = &socvar &ptvar PTord_NP PTord_EV) ties = low descending;
        by &socvar;
        var stat_n stat_e;
        ranks PTord_NP PTord_EV;
    run;

    proc sql;
        create table counts_word as 
        select a.*, 
               case when a.&socvar = 'ANY' then 1 else b.SOCord_NP + 1 end as SOCord_NP, 
               case when a.&socvar = 'ANY' then 1 else b.SOCord_EV + 1 end as SOCord_EV,
               case when a.&ptvar  = 'ANY' then 1 else c.PTord_NP  + 1 end as PTord_NP,
               case when a.&ptvar  = 'ANY' then 1 else c.PTord_EV  + 1 end as PTord_EV
        from counts_cat a left join socranks b
                              on  a.&socvar = b.&socvar
                          left join ptranks c
                              on  a.&socvar = c.&socvar
                              and a.&ptvar  = c.&ptvar
        order by SOCord_NP, SOCord_EV, &socvar, PTord_NP, PTord_EV, &ptvar, &trtvarn
        ;
    quit;
    
    /* Transpose into long format */
    proc transpose data = counts_word out = counts_T (rename = (_NAME_ = statty COL1 = statval));
        by SOCord_NP SOCord_EV &socvar PTord_NP PTord_EV &ptvar &trtvarn ;
        var npp ev;
    run;

    /* Transpose to trts are cols */
    proc transpose delim = _ prefix = trt_ data = counts_T out = &outdat (drop = _NAME_);
        id &trtvarn statty;
        by SOCord_NP SOCord_EV &socvar PTord_NP PTord_EV &ptvar;
        var statval;
    run;
%mend;
  options mprint ;
%soc_pt(indat     = teae_as,
        outdat    = outtab,
        trtvarn   = trtan,
        inadsl    = adsl1,
        socvar    = aesoc,
        ptvar     = aedecod,
        totval    = 99, 
        totcond   =, 
        trtnord   = 99,
        pctfmt    = pctmf.
        );

data extrow (keep = aesoc aedecod soc_pt_disp trt_:); 
    length soc_pt_disp $ 200; 
    set outtab;
    by SOCord_NP SOCord_EV aesoc;

    if first.aesoc then do;
        if aesoc = 'ANY' then soc_pt_disp = 'Subjects with at least one AE leading to death';
        else soc_pt_disp = aesoc;
        output;
    end;
/*    if aedecod = 'ANY' then aedecod = 'At least one event';*/
    soc_pt_disp = aedecod;
    if aesoc ^= 'ANY' & aedecod ^= 'ANY' then output;
run;

data final (drop = i);
    set extrow;
    array trtcounts $ trt_:;
    if aesoc = soc_pt_disp then do i = 1 to dim(trtcounts);
        trtcounts[i] = '';
    end;
    if aedecod = soc_pt_disp then indent = 'Y';
    else indent = 'N';
run;

%p_mcrAddPageVar(dataset_in = final, dataset_out = final1, txt = soc_pt_disp, txt_col_width = 40, max_rows_per_page = 25)


/*===========================================================================*/
/*    Creating count data                                                    */
/*===========================================================================*/

data tflw.&dddatanam (drop = aesoc aedecod page indent trt_99:
                      rename = (trt_0_npp = col1 trt_54_npp = col3 trt_81_npp = col5
                                trt_0_ev  = col2 trt_54_ev  = col4 trt_81_ev  = col6
                                soc_pt_disp = rowlbl1 ));
    set final1;
    label soc_pt_disp = "System Organ Class~|R'    'Preferred Term"
          trt_0_npp = 'n (%)'
          trt_54_npp = 'n (%)'
          trt_81_npp = 'n (%)'
          trt_0_ev = 'Total ~events'
          trt_54_ev = 'Total ~events'
          trt_81_ev = 'Total ~events';
         
          
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
title4 justify=c "Summary of Treatment-Emergent Adverse events leading to death by System Organ Class and Preferred term" ;

footnote1 justify=l "Treatment-emergent events are defined as adverse events following the first administration of the intervention that is either new or a worsening of an existing AE.";
footnote2 justify=l "Adverse Events are coded using MedDRA version xx.x.";
footnote3 justify=l "Total Events represent the total number of times an event was recorded within each treatment group.";
footnote4 justify=l "Percentages are based on the number of subjects in the safety population within each treatment group." ;
footnote5 justify=l "TEAE= Treatment-Emergent Adverse Event, MedDRA= Medical Dictionary for Regulatory Activities." ;
footnote6 ;
footnote7 justify=l "Source: &__full_path, %sysfunc(date(),date9.) %sysfunc(time(),tod5.)" ;
proc report data = final1 split = '~'
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
                   ("|S={bordertopcolor = black bordertopwidth =2}Placebo~(N=&N_0)~ ~ " trt_0_npp trt_0_ev)
                   ("|S={bordertopcolor = black bordertopwidth =2}Xanomeline Low Dose~(N=&N_54)~ ~ " trt_54_npp trt_54_ev)
                   ("|S={bordertopcolor = black bordertopwidth =2}Xanomeline High Dose~(N=&N_81)~ ~ " trt_81_npp trt_81_ev)
                   ;

            define page         / order order = data noprint;
            define aesoc        / order order = data noprint;
            define aedecod      / order order = data noprint;
            define indent       / order order = data noprint;
            define soc_pt_disp  / order order = data  "System Organ Class~|R'    'Preferred Term"
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 27% just = l};
            define trt_0_npp  / display 'n (%)'
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 12%} style(column) = {leftmargin = 1%};
            define trt_0_ev     / display 'Total ~events'
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 12%} style(column) = {leftmargin = 3%};
            define trt_54_npp / display 'n (%)'
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 12%} style(column) = {leftmargin = 1%};
            define trt_54_ev    / display 'Total ~events'
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 12%} style(column) = {leftmargin = 3%};
            define trt_81_npp / display 'n (%)'
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 12%} style(column) = {leftmargin = 1%};
            define trt_81_ev    / display 'Total ~events'
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 12%} style(column) = {leftmargin = 3%};
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
**%scanlog;
********;
