/*****************************************************************************\
*        O
*       /
*  O---O     _  _ _  _ _  _  _|
*       \ \/(/_| (_|| | |(/_(_|
*        O
* _____________________________________________________________________________
* Sponsor              :  Evelo
* Study                :  EDP1867-101
* Analysis             :
* Program              :  u_dddataout.sas
* _____________________________________________________________________________
* DESCRIPTION
*
* Input files: N/A
*
* Output files: DDDataset in dddata folder
*
* Macros: N/A
*
* Assumptions: N/A
*
* _____________________________________________________________________________
* PROGRAM HISTORY
*  13SEP2021  |  Natalie Thompson  |  Copied from 1815-201 and updated for this study.
\*****************************************************************************/

%macro p_dddataout(dsetin= /*Final dataset to output for QC*/
                  ,droppageyn=Y /*Y/N value on whether to drop the page variable (=N if no variable)*/
                  ,stripblanksyn=Y /*Y/N value on whether to strip leading blanks from all character variables*/
                  ,compressvars= /*List of variables to compress all spaces from*/
                  );

  /*Check if dsetin is in one or two parts*/
  %if %index(&dsetin,.) > 0 %then %do;
    %let libname = %upcase(%scan(&dsetin,1,.));
    %let memname = %upcase(%scan(&dsetin,2,.));
  %end;

  %else %do;
    %let libname = WORK;
    %let memname = %upcase(&dsetin);
  %end;

  /*If dropping page variable check variable exists first*/
  %if %upcase(&droppageyn.) = Y %then %do;

    proc sql noprint;
      select name
      from dictionary.columns
      where libname = "&libname" and memname = "&memname" and upcase(name) = "PAGE";
    quit;

    %let pageexists = &sqlobs.;

    %if &pageexists. = 0 %then %do;
      %let droppageyn = N;
      %put %str(N)OTE: Page variable does not exist in the dataset so cannot be dropped.;
    %end;

  %end;

  /*Check validity of compress variables - only character variables allowed*/
  %let compvars = %str();

  %if &compressvars. ^= %str() %then %do;
  
    /*Assuming list defined correctly - no checks*/
    %let compressvarsn = %sysfunc(countw(&compressvars.));

    /*Cycle through each variable*/
    %do ii = 1 %to &compressvarsn.;

      %let compressvar&ii. = %scan(&compressvars,&ii.);

      /*Check for variable in data*/
      proc sql noprint;
        select name
        from dictionary.columns
        where libname = "&libname" and memname = "&memname" and upcase(name) = upcase("&&compressvar&ii.");
      quit;

      %let compressvarexists = &sqlobs.;

      %if &compressvarexists. = 0 %then %do;
        %put %str(N)OTE: Compress variable &&compressvar&ii. does not exist in the dataset so cannot be compressed.;
      %end;

      %else %do;

        /*Check variable type*/
        proc sql noprint;
          select type
          into :compressvartype trimmed
          from dictionary.columns
          where libname = "&libname" and memname = "&memname" and upcase(name) = upcase("&&compressvar&ii.");
        quit;

        %if %upcase(&compressvartype) ^= CHAR %then %do;
          %put %str(N)OTE: Compress variable &&compressvar&ii. is not character and so cannot be compressed.;
        %end;

        %else %do;
          /*If var exists and is character then add to list of valid variables to compress*/
          %let compvars = &compvars. &&compressvar&ii.;
        %end;

      %end;

    %end;

  %end;

  /*Check for any variables called SPACEn and list these to drop*/
  %let spacevars = %str();
  proc sql noprint;
    select name
    into :spacevars
    separated by ' '
    from dictionary.columns
    where libname = "&libname" and memname = "&memname" and upcase(substr(name,1,5)) = "SPACE" and compress(substr(name,6),,"d") = "";
  quit;

  /*Check for any variables called CONDn and list these to drop*/
  %let condvars = %str();
  proc sql noprint;
    select name
    into :condvars
    separated by ' '
    from dictionary.columns
    where libname = "&libname" and memname = "&memname" and upcase(substr(name,1,4)) = "COND" and compress(substr(name,5),,"d") = "";
  quit;

  /*Output dataset for QC*/
  data dddata.&DDDataName.;
    set &dsetin;
    %if %upcase(&stripblanksyn.) = Y %then %do;
      array charvar {*} _CHARACTER_;
      do __ii = 1 to dim(charvar);
         charvar{__ii} = left(charvar{__ii});
      end;
      drop __ii;
    %end;

    %if &compvars ^= %str() %then %do;
      array compvar {*} &compvars;
      do __jj = 1 to dim(compvar);
         compvar{__jj} = compress(compvar{__jj});
      end;
      drop __jj;
    %end;

    %if %upcase(&droppageyn.) = Y %then %str(drop page;);
    %if &spacevars. ^= %str() %then %str(drop &spacevars.;);
    %if &condvars. ^= %str() %then %str(drop &condvars.;);
  run;

%mend p_dddataout;
