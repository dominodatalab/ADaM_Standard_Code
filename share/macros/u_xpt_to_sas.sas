/*****************************************************************************\
*        O
*       /
*  O---O     _  _ _  _ _  _  _|
*       \ \/(/_| (_|| | |(/_(_|
*        O
* _____________________________________________________________________________
* Sponsor              : 
* Study                : 
* Analysis             : 
* Program              : u_xpt_to_sas.sas
* Purpose              : Convert XPT files back to SAS7BDAT data
* _____________________________________________________________________________
* DESCRIPTION
*
* Input files: XPT files listed in macro call
*
* Output files: SAS datasets output to library defined in macro call
*
* Macros: N/A
*
* Assumptions: All datasets are in the same library
*
* _____________________________________________________________________________
* PROGRAM HISTORY
*  07FEB2022  |  Emily Berrett      |  Original
* -----------------------------------------------------------------------------
*
\*****************************************************************************/

%macro u_xpt_to_sas(libin= /*Libname containing source XPT files*/
                   ,dsets= /*Space-delimited list of XPTs to convert to SAS dataset*/
                   ,libout= /*Libname to output SAS datasets*/
                   );

  %local ndsets currdset xptpath;

  /*Check libin has been assigned*/
  %if %sysfunc(libref(&libin.)) = 0 %then %do;

    /*Check libout has been assigned*/
    %if %sysfunc(libref(&libout.)) = 0 %then %do;

      /*Check list is as expected - only dataset names (alphanumeric, underscore) and spaces, abort otherwise*/
      %if %sysfunc(compress(&dsets.,,n)) ^= %str() %then %do;
        %put %str(E)RROR: Dataset list contains invalid characters. Check dataset list: &dsets.. Macro will abort.;
        %goto exit;
      %end;
      
      %let ndsets = %sysfunc(countw(&dsets.));

      /*Cycle through each dataset in validated list to convert to XPT*/
      %let xptpath = %sysfunc(pathname(&libin.));

      %do j = 1 %to &ndsets;

        %let currdset = %scan(&dsets.,&j.);

        /*Convert XPT to dataset*/
        libname xptin xport "&xptpath.\&currdset..xpt" access = readonly;
        proc copy in = xptin out = &libout;
        run;

      %end;

    %end;

    /*If libout not assigned then abort*/
    %else %do;
      %put %str(E)RROR: Libname &libout has not been assigned. Datasets cannot be read out. Macro will abort.;
      %goto exit;
    %end;

  %end;

  /*If libin not assigned then abort*/
  %else %do;
    %put %str(E)RROR: Libname &libin has not been assigned. Datasets cannot be read in. Macro will abort.;
    %goto exit;
  %end;

  %exit: %str();

%mend u_xpt_to_sas;
