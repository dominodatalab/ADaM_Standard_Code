/*****************************************************************************\
*        O
*       /
*  O---O     _  _ _  _ _  _  _|
*       \ \/(/_| (_|| | |(/_(_|
*        O
* _____________________________________________________________________________
* Sponsor              : Evelo
* Study                : EDP1815-201
* Program              : p_create_xpts.sas
* Purpose              : Create XPT files from list of SAS datasets
* _____________________________________________________________________________
* DESCRIPTION
*
* Input files: SAS datasets in library
*
* Output files: XPT files output to library defined in macro call
*
* Macros: 
*
* Assumptions: All datasets are in the same library
*
* _____________________________________________________________________________
* PROGRAM HISTORY
*  25JUN2021  |  Daniil Trunov      |  Based on reference code from another 
*									   sponsor's study
* -----------------------------------------------------------------------------
*  17AUG2021  |  Kaja Najumudeen    |  Commented the lines of code which is referring
*                                      to recursive macro call with in the scope of
*                                      macro itself and was also referring to 201 in 101
\*****************************************************************************/

%macro p_create_xpts(libin= /*Libname containing source SAS datasets*/ 
                    ,libout= /*Libname to output XPT files*/
                    ,preprocess=
                    );

  %local dsetlist ndsets removedsets currdset xptpath;

  /*Check libin has been assigned*/
  %if %sysfunc(libref(&libin.)) = 0 %then %do;

    /*Check libout has been assigned*/
    %if %sysfunc(libref(&libout.)) = 0 %then %do;

        proc sql noprint;
          select distinct memname
          into :dsetlist
          separated by " "
          from sashelp.vtable
          where libname = upcase("&libin.");
        quit;

        %let ndsets = %sysfunc(countw(&dsetlist.));

      /*Cycle through each dataset in validated list to convert to XPT*/
      %let xptpath = %sysfunc(pathname(&libout.));

      %do j = 1 %to &ndsets;

        %let currdset = %scan(&dsetlist.,&j.);

		/*Copying dataset to work lib*/
		data work.&currdset.;
			set &libin..&currdset.;
		run;

        /*Remove sortedby information*/
        proc datasets library = work nolist;
          modify &currdset. (sortedby = _NULL_);
        run;

        /*Additional pre-processing before creating XPTs if required*/
        %unquote(&preprocess);

        /*Convert dataset to XPT*/
        libname xptout xport "&xptpath.\&currdset..xpt";
        proc copy in = work out = xptout memtype = data;
          select &currdset.;
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

%mend p_create_xpts;




					
