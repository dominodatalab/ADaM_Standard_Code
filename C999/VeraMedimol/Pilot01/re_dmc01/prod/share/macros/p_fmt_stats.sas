/*****************************************************************************\
*        O
*       /
*  O---O     _  _ _  _ _  _  _|
*       \ \/(/_| (_|| | |(/_(_|
*        O
* _____________________________________________________________________________
* Sponsor              : Orchard
* Study                : OTL-103
* Program              : u_fmt_stats
* Purpose              : Round raw numeric stats results to the correct number
*                        of decimals based on the raw data and align the results
* _____________________________________________________________________________
* DESCRIPTION
*
* Input files: Work datasets to be read in
*
* Output files: Work dataset to be created
*
* Macros: N/A
*
* Assumptions: Statistics dataset is in wide form
*
* _____________________________________________________________________________
* PROGRAM HISTORY
*  09MAR2020  |  Emily Berrett       |  Original
* -----------------------------------------------------------------------------
*
\*****************************************************************************/

%macro p_fmt_stats(dsetinall=   /*Dataset containing all records that went into the summary*/
                  ,dsetinstats= /*Dataset containing statistics in wide form*/
                  ,dsetout=     /*Dataset to output with formatted stats*/
                  ,groupbyvars= /*Variables to group by when determining decimal precision separated by spaces*/
                  ,alignbyvars= /*Variables to group by when determining alignment separated by spaces*/
                  ,analyvar=    /*Analysis variable stats were done on*/
                  ,statsvars=   /*Statistics variables in the stats summary dataset separated by spaces*/
                  ,statsdps=    /*Number of decimals exact (number) or to add (+number) corresponding to each statistic variable separated by spaces*/
                  ,rawdps=      /*Override decimals in the data by specifying condition#[new raw decimals] for each case separated by spaces*/
                  ,tidyupyn=N   /*Tidy up temporary datasets*/
                  );

  %let pref = __dps;

  /**Check datasets going in**/
  %if &dsetinall = %str() %then %do;
    %put %str(E)RROR: Dataset with all data has not been specified. Macro will abort.;
    %goto exit;
  %end;
  %else %do;
    %if %sysfunc(exist(&dsetinall)) = 0 %then %do;
      %put %str(E)RROR: Dataset with all data %upcase(&dsetinall) does not exist. Check data. Macro will abort.;
      %goto exit;
    %end;
  %end;

  %if &dsetinstats = %str() %then %do;
    %put %str(E)RROR: Dataset with stats data has not been specified. Macro will abort.;
    %goto exit;
  %end;
  %else %do;
    %if %sysfunc(exist(&dsetinstats)) = 0 %then %do;
      %put %str(E)RROR: Dataset with stats data %upcase(&dsetinstats) does not exist. Check data. Macro will abort.;
      %goto exit;
    %end;
  %end;

  /**Check and count variables going in and turn into numbered parameters**/

  /*Group by variables*/
  %if &groupbyvars = %str() %then %do;
    %put %str(E)RROR: No group by variables are defined. At least one group by variable required. Macro will abort.;
    %goto exit;
  %end;
  %else %do;
    %let groupbyvarsn = %sysfunc(countw(&groupbyvars));
    %do ii = 1 %to &groupbyvarsn;
      %let groupbyvar&ii = %upcase(%scan(&groupbyvars,&ii));
    %end;
  %end;

  /*Align by variable*/
  %if &alignbyvars = %str() %then %do;
    %put %str(E)RROR: No variable to align by is defined. At least one variable to align by is required. Macro will abort.;
    %goto exit;
  %end;
  %else %do;
    %let alignbyvarsn = %sysfunc(countw(&alignbyvars));
    %do ii = 1 %to &alignbyvarsn;
      %let alignbyvar&ii = %upcase(%scan(&alignbyvars,&ii));
    %end;
  %end;

  /*Analysis variable*/
  %if &analyvar = %str() %then %do;
    %put %str(E)RROR: No analysis variable has been defined. One analysis variable required. Macro will abort.;
    %goto exit;
  %end;
  %else %do;
    %let analyvarn = %sysfunc(countw(&analyvar));
    %if &analyvarn > 1 %then %do;
      %put %str(E)RROR: More than one analysis variable has been defined. Only one analysis variable can be processed at one time. Macro will abort.;
      %goto exit;
    %end;
    %else %do;
      %let analyvar = %upcase(&analyvar);
    %end;
  %end;

  /*Stats variables*/
  %if &statsvars = %str() %then %do;
    %put %str(E)RROR: No statistics variables are defined. At least one statistic variable required. Macro will abort.;
    %goto exit;
  %end;
  %else %do;
    %let statsvarsn = %sysfunc(countw(&statsvars));
    %do ii = 1 %to &statsvarsn;
      %let statsvar&ii = %upcase(%scan(&statsvars,&ii));
    %end;
  %end;

  /*Check the same number of stats decimals are defined as the number of stats*/
  %if &statsdps = %str() %then %do;
    %put %str(E)RROR: No decimals for statistics variables are defined. There must be one number define for each statistic. Macro will abort.;
    %goto exit;
  %end;
  %else %do;
    %let statsdpsn = %sysfunc(countw(&statsdps));
    %if &statsdpsn < &statsvarsn %then %do;
      %put %str(E)RROR: There are fewer statistics decimals defined than statistics. These must match 1 to 1. Macro will abort.;
      %goto exit;
    %end;
    %else %if &statsdpsn > &statsvarsn %then %do;
      %put %str(E)RROR: There are more statistics decimals defined than statistics. These must match 1 to 1. Macro will abort.;
      %goto exit;
    %end;
    %else %do;
      %do ii = 1 %to &statsdpsn;
        %let statsdp&ii = %qscan(&statsdps,&ii,%str( ));
      %end;
    %end;
  %end;

  /**Check datasets coming in have all variables expected**/
  /*Group by variables*/
  %do ii = 1 %to &groupbyvarsn;
    proc sql noprint;
      select count(name)
      into :varchk trimmed
      from dictionary.columns
      where libname = "WORK" and upcase(memname) = upcase("&dsetinall.") and upcase(name) = "&&groupbyvar&ii";
    quit;
    %if &varchk = 0 %then %do;
      %put %str(E)RROR: Group by variable &&groupbyvar&ii is not in %upcase(&dsetinall.). All specified group by variables must be in the dataset. Macro will abort.;
      %goto exit;
    %end;
  %end;

  %do ii = 1 %to &groupbyvarsn;
    proc sql noprint;
      select count(name)
      into :varchk trimmed
      from dictionary.columns
      where libname = "WORK" and upcase(memname) = upcase("&dsetinstats.") and upcase(name) = "&&groupbyvar&ii";
    quit;
    %if &varchk = 0 %then %do;
      %put %str(E)RROR: Group by variable &&groupbyvar&ii is not in %upcase(&dsetinstats.). All specified group by variables must be in the dataset. Macro will abort.;
      %goto exit;
    %end;
  %end;

  /*Align by variables*/
  %do ii = 1 %to &alignbyvarsn;
    proc sql noprint;
      select count(name)
      into :varchk trimmed
      from dictionary.columns
      where libname = "WORK" and upcase(memname) = upcase("&dsetinstats.") and upcase(name) = "&&alignbyvar&ii";
    quit;
    %if &varchk = 0 %then %do;
      %put %str(E)RROR: Variable to align by, &&alignbyvar&ii is not in %upcase(&dsetinstats.). All specified variables to align by must be in the dataset. Macro will abort.;
      %goto exit;
    %end;
    /*Determine variable type*/
    data _null_;
      set &dsetinstats;
      call symputx("&&alignbyvar&ii..typ",vtype(&&alignbyvar&ii));
    run;
  %end;

  /*Analysis variable*/
  proc sql noprint;
    select count(name)
    into :varchk trimmed
    from dictionary.columns
    where libname = "WORK" and upcase(memname) = upcase("&dsetinall.") and upcase(name) = "&analyvar";
  quit;
  %if &varchk = 0 %then %do;
    %put %str(E)RROR: Analysis variable &analyvar is not in %upcase(&dsetinall.). Specified analysis variable must be in the dataset. Macro will abort.;
    %goto exit;
  %end;

  /*Statistics variables*/
  %do ii = 1 %to &statsvarsn;
    proc sql noprint;
      select count(name)
      into :varchk trimmed
      from dictionary.columns
      where libname = "WORK" and upcase(memname) = upcase("&dsetinstats.") and upcase(name) = "&&statsvar&ii";
    quit;
    %if &varchk = 0 %then %do;
      %put %str(E)RROR: Statistic variable &&statsvar&ii is not in %upcase(&dsetinstats.). All specified statistic variables must be in the dataset. Macro will abort.;
      %goto exit;
    %end;
  %end;

  /*Cycle through user-defined decimals to pull these values as needed*/
  %if &rawdps ^= %str() %then %do;
    %let rawdpsn = %sysfunc(countw(&rawdps));
    %do ii = 1 %to &rawdpsn;
      %let rawdps&ii = %upcase(%scan(&rawdps,&ii));
      %let rawdps&ii.n = %sysfunc(countw(&&rawdps&ii,#));
      %if &&rawdps&ii.n ^= 2 %then %do;
        %put %str(E)RROR: Parameter rawdps is not formatted correctly. Check required syntax. Macro will abort.;
        %goto exit;
      %end;
      %else %do;
        %let cond&ii = %scan(&&rawdps&ii,1,#);
        %let dps&ii = %scan(&&rawdps&ii,2,#);
      %end;
    %end;
  %end;


  /*For each parameter identify number of decimals on each record for the analysis variable across all treatments and visits*/
  data &pref._rawdps (keep = &groupbyvars rawdps);
    set &dsetinall;
    if index(put(&analyvar,best12.),'.') > 0 then rawdps = length(scan(put(&analyvar,best12.),2,'.'));
    else rawdps = 0;
    /*Reduce down any decimals too large*/
    %if %upcase(&analyvar) = AVAL %then %do;
      if rawdps > 6 then rawdps = 2;
    %end;
    %else %if %upcase(&analyvar) = CHG %then %do;
      if rawdps > 6 then rawdps = 3;
    %end;
    %else %if %upcase(&analyvar) = PCHG %then %do;
      rawdps = 1;
    %end;
    /*Cycle through user-defined decimals*/
    %if &rawdps ^= %str() %then %do;
      %do ii = 1 %to &rawdpsn;
        if &&cond&ii then rawdps = &&dps&ii;
      %end;
    %end;
  run;

  /*Now determine the maximum number of decimals for each parameter*/
  proc sql noprint;
    create table &pref._maxdps as
    select distinct %do ii = 1 %to &groupbyvarsn;
                      &&groupbyvar&ii,
                    %end;
           max(rawdps) as __maxdps
    from &pref._rawdps
    group by 
      %if &groupbyvarsn > 1 %then %do;
        %do ii = 1 %to %eval(&groupbyvarsn - 1);
          &&groupbyvar&ii,
        %end;
      %end;
      &&groupbyvar&groupbyvarsn
    order by
      %if &groupbyvarsn > 1 %then %do;
        %do ii = 1 %to %eval(&groupbyvarsn - 1);
          &&groupbyvar&ii,
        %end;
      %end;
    &&groupbyvar&groupbyvarsn
    ;
  quit;

  /*Merge on this information with stats data to process formatting of results*/
  proc sort data = &dsetinstats out = &pref._statsin;
    by &groupbyvars;
  run;

  data &pref._stats_all;
    merge &pref._statsin (in = a) &pref._maxdps;
    by &groupbyvars;
    
    if a;
  run;

  data &pref._stats_dps;
    set &pref._stats_all;

    %do ii = 1 %to &statsvarsn;
      __dp_&&statsvar&ii = "&&statsdp&ii";
    %end;

  run;

  /*Formatting of results*/
  data &pref._stats_calcs (drop = __ii &statsvars __maxdps __dp_: __r_: __f_:);
    set &pref._stats_dps;

    /*Array of stats variables*/
    array stat{&statsvarsn} %do ii = 1 %to &statsvarsn;
                              &&statsvar&ii
                            %end;
                            ;
    /*Array of decimal places to add or define for each stats variable*/
    array stat_dp{&statsvarsn} $ %do ii = 1 %to &statsvarsn;
                                   __dp_&&statsvar&ii
                                 %end;
                                 ;
    /*Array of rounding precision for each stats variable*/
    array stat_r{&statsvarsn} %do ii = 1 %to &statsvarsn;
                                __r_&&statsvar&ii
                              %end;
                              ;
    /*Array of actual number of decimals for each stats variable to form latter part of format*/
    array stat_d{&statsvarsn} $ %do ii = 1 %to &statsvarsn;
                                  __d_&&statsvar&ii
                                %end;
                                ;
    /*Array of format to apply to each stats variable*/
    array stat_f{&statsvarsn} $ %do ii = 1 %to &statsvarsn;
                                  __f_&&statsvar&ii
                                %end;
                                ;
    /*Array of rounded (new numeric) results for stats variable*/
    array stat_n{&statsvarsn} %do ii = 1 %to &statsvarsn;
                                __n_&&statsvar&ii
                              %end;
                              ;
    /*Array of length of rounded value for each stats variable*/
    array stat_l{&statsvarsn} %do ii = 1 %to &statsvarsn;
                                __l_&&statsvar&ii
                              %end;
                              ;

    /*Array of length of integer part of rounded value for each stats variable*/
    array stat_il{&statsvarsn} %do ii = 1 %to &statsvarsn;
                                 __il_&&statsvar&ii
                               %end;
                               ;
 
    /*Cycle through each stats variable*/
    %do ii = 1 %to &statsvarsn;
       if __maxdps ^= . then do;
          /*Determine actual max decimals - either add to raw or overwrite as defined in macro call*/
          if substr(stat_dp{&ii},1,1) = "+" then __maxdps_ = __maxdps+input(substr(stat_dp{&ii},2),best12.);
          else __maxdps_ = input(substr(stat_dp{&ii},1),best12.);

          /*Determine rounding precision (10 to negative power of number of decimals)*/
          stat_r{&ii} = 10**-(__maxdps_);

          /*Determine decimal part of format - missing if 0*/
          if __maxdps_ ^= 0 then stat_d{&ii} = strip(put(__maxdps_,30.));
          else stat_d{&ii} = "";

          /*Create format to apply to variable after rounding*/
          if __maxdps_ ^= 0 then stat_f{&ii} = "32."||strip(put(__maxdps_,30.));
          else stat_f{&ii} = "32.";
       end;
    %end;

    /*Round each value and determine length for later alignment*/
    do __ii = 1 to &statsvarsn;
      if stat{__ii} ^= . then do;
         /*Round results*/
         stat_n{__ii} = round(stat{__ii},stat_r{__ii});
         /*Length of rounded result*/
         stat_l{__ii} = length(strip(putn(stat_n{__ii},stat_f{__ii})));
         /*Length of integer part of result*/
         stat_il{__ii} = stat_l{__ii} - ifn(stat_d{__ii}^="",input(stat_d{__ii},best.),-1) - 1;
      end;
    end;

  run;

  /*Combine alignment variables values into one variable*/
  data &pref._stats_align;
    set &pref._stats_calcs;

    length __align $200;
    __align = "";
    %do ii = 1 %to &alignbyvarsn;
      %if &&&&&&alignbyvar&ii..typ = C %then %str(__align = strip(__align)||strip(&&alignbyvar&ii););
      %else %if &&&&&&alignbyvar&ii..typ = N %then %str(__align = strip(__align)||strip(put(&&alignbyvar&ii,best32.)););
    %end;

  run;

  proc sql noprint;
    select distinct __align into :align1 - from &pref._stats_align;
  quit;

  %let alignobs = &sqlobs;

  /*Sequential values of each variable to align by*/
  %do ii = 1 %to &statsvarsn;
    proc sql noprint;
      select max(__il_&&statsvar&ii)
      into :__il_&&statsvar&ii.._1 -
      from &pref._stats_align
      group by __align;
    quit;
  %end;

  /*Final formatting of stats for output*/
  data &dsetout (drop = __ii __maxdps_ __align __l_: __d_: __f_: __n_: __il_: __rl_:);
    set &pref._stats_align;

    /*Array of actual number of decimals for each stats variable to form latter part of format*/
    array stat_d{&statsvarsn} $ %do ii = 1 %to &statsvarsn;
                                  __d_&&statsvar&ii
                                %end;
                                ;
    /*Array of format to apply to each stats variable*/
    array stat_f{&statsvarsn} $ %do ii = 1 %to &statsvarsn;
                                  __f_&&statsvar&ii
                                %end;
                                ;
    /*Array of rounded (numeric) results for stats variable*/
    array stat_n{&statsvarsn} %do ii = 1 %to &statsvarsn;
                                __n_&&statsvar&ii
                              %end;
                              ;
    /*Array of final length for the result for each stats variable*/
    array stat_rl{&statsvarsn} %do ii = 1 %to &statsvarsn;
                                 __rl_&&statsvar&ii
                               %end;
                               ;
     /*Array of final formatted character stats variables - same name as original variables*/
    array stat{&statsvarsn} $32 %do ii = 1 %to &statsvarsn;
                                  &&statsvar&ii
                                %end;
                                ;

    /*New format for each stat*/
    %do ii = 1 %to &alignobs;
       if __align = "&&align&ii" then do;
          %do jj = 1 %to &statsvarsn;
            stat_rl{&jj} = ifn(stat_d{&jj}^="",input(stat_d{&jj},best.),-1) + &&&&__il_&&statsvar&jj.._&ii.. + 1;
            if __maxdps_ ^= . then stat_f{&jj} = strip(put(stat_rl{&jj},best.))||"."||strip(stat_d{&jj});
          %end;
       end;
    %end;

    /*Creation of columns with formatting applied*/
    do __ii = 1 to &statsvarsn;
       if stat_n{__ii} ^= . then stat{__ii} = trim(putn(stat_n{__ii},stat_f{__ii}));
    end;

  run;

  %if %upcase(&tidyupyn) = Y %then %do;
    
      proc datasets lib = work nolist memtype = data;
        delete &pref._:;
      quit;

  %end;

  %exit: %str();

%mend p_fmt_stats;
