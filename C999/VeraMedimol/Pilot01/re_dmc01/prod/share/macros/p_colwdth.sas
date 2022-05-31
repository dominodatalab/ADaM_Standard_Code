 /*****************************************************************************\
*        O                                                                      
*       /                                                                       
*  O---O     _  _ _  _ _  _  _|                                                 
*       \ \/(/_| (_|| | |(/_(_|                                                 
*        O                                                                      
* ____________________________________________________________________________
* Sponsor              : Orchard
* Study                : OTL-103 GENERAL
* Program              : u_colwdth
* Purpose              : Creates global macro variables which hold the widths of columns to use in PROC REPORT
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files: None
*              
* Output files: None
*               
* Macros: None
*         
* Assumptions: 
*
* 1. If IDCOLs has columns specified in it, then the number of pages to split the output across (IDPAGES) must also be specified
* 2. MANUAL_W is specified like so: varname1 xx varname2 xx ...etc...
* 3. If IDPages is specified, then the non-ID columns will be divided automatically across the pages, with any "excess" columns going to the last page
*    For example: If we have 10 columns, 1 of which is an ID and want 2 pages, then 4 columns will go to the first page and then 5 will go to the next;
* 4. The order of the columns to be assigned widths must be the order they are going into the report;
* 5. If, for a given linesize there is excess linesize left over, then this is additonally added to the last column on that page
* 6. By default, the percentage will be returned for use in style(column)
*              
* As from 02MAR2020, the non-id columns can be distributed as per user specifications for the number of columns wanted per page;
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  17FEB2020  | Otis Rimmer  | Original version
*  18FEB2020  | Otis Rimmer  | Update to return percentages to be used in style(column) by default, 
*             |              | rather than widths just to be used in width= argument in define statement
*  19FEB2020  | Otis Rimmer  | Widths were being overassigned for pages >1 in IDPAGES, so this is corrected.
*  21FEB2020  | Otis Rimmer  | Update to prevent columns which share text with columns that have manual widths from having their names messed up
*             |              | (previously, if COL1 is a manual width assignment and we have COL10, previously the name of COL10 would go to 0 in a TRANWRD statement);
*  02MAR2020  | Otis Rimmer  | (1)  Allow percentages to be non-integer
*             |              | (2)  Produce an err-or if all widths are specified for page X are bigger than available space
*             |              | (3)  Allow all widths to be specified in a page
*             |              | (4)  Allow specification of how many columns to go on each page if ID is specified.
*  14MAY2020  | Otis Rimmer  | Add in input around the scan to prevent char-num conv note
\*****************************************************************************/


/* EXAMPLE MACRO CALL - 

These will all produce RTF Percentages by default

Simple example of no idcolumns and a manual width assignment - COL1, COL2, COL3 and COL4 
with COL1 and COL2 having a manual width of 30% and 25% respectively assigned

%u_colwdth(cols = COL1 COL2 COL3 COL4,
manual_w = COL1 30 COL2 25);

The global macro variables produced are COL1WIDTH,COL2WIDTH,COL3WIDTH,COL4WIDTH

Example with One ID column COL1, which is to be split across 2 pages with a manual width of 30% being assigned for COL1

%u_colwdth(cols = COL1 COL2 COL3 COL4 COL5,
manual_w = COL1 30,
idcols = COL1,
idpages=2);

Note here that COL2 and COL3 will go to the first page, and COL4/COL5 will go to the next

The global macro variables produced are COL1WIDTH,COL2WIDTH,COL3WIDTH,COL4WIDTH,COL5WIDTH
*/


%macro p_colwdth(cols=,manual_w=,idcols=,idpages=,colsperidpage=,rtfpercent=Y,percavail=99.4,tidyup=Y);

%local _i ;

%********************************************************************************************** MACRO PARAMETER STANDARDIZATION AND RTFPERCENT CHECKS;

%let tidyup = %upcase(&tidyup);
%let rtfpercent = %upcase(&rtfpercent);
%let idcols = %upcase(&idcols);
%let cols = %upcase(&cols);
%let manual_w = %upcase(&manual_w);

%* Check if rtfpercent is specified as Y or N;
%if &rtfpercent ^= Y and &rtfpercent ^= N %then %do;

  %put %str(ERR)OR: RTFPERCENT should be specified as Y (to return percentages for use as column widths in RTF PROC REPORT in STYLE(COLUMN)); 
  %put %str(ERR)OR: or N (to return a width to be used in WIDTH statement in DEFINE for standard non-RTF PROC REPORT);
  %goto leave;

%end;
%******************************************************************************************* INITIALIZATION OF LINESIZE (IF NEEDED);


%if ^%symexist(ls) %then %do;

   data _null_;
     set sashelp.voption(where=(optname="LINESIZE"));
     call symputx("ls",setting,"l");
   run;

%end;

%******************************************************************************************* MACRO PARAMETER CHECKS;

%* Check populated;


%if %nrbquote(&cols.) = %then %do;
  %put %str(ERR)OR: Please specify an output dataset name in macro parameter COLS;
  %goto leave;
%end;

%* Check if the ID column is specified that it is inside one of the cols listed;
%* Check also that ID Pages has been specified;
%if %nrbquote(&idcols.) ne %then %do;

  %do _i = 1 %to %sysfunc(countw(&idcols.,%str( )));

    %local _idcol&_i. ;

    %let _idcol&_i. = %scan(&idcols.,&_i.,%str( ));

    %if ^%index(&cols.,&&_idcol&_i.) %then %do;
      %put %str(ERR)OR: &&_idcol&_i is not specified in macro parameter COLS;
      %goto leave;
    %end;

  %end;


  %if %nrbquote(&idpages) = %then %do;
    %put %str(ERR)OR: If IDCOLS is specified, then the number of pages to split the output across (IDPAGES) should be specified;
    %goto leave;
  %end;

  %if ^(%nrbquote(&idpages) > 1) %then %do;
    %put %str(ERR)OR: If IDCOLS is specified, then the number of pages to split the output across should be more than 1;
    %goto leave;
  %end;

  %* Check IDcols are specified at the beginning;
  data _null_;

    cols = compbl(upcase("&cols"));
    idcols = compbl(upcase("&idcols"));

    if index(cols,idcols) ne 1 then do;
      put "ERR" "OR: Please specify IDCOLs at the beginning of the COLS statement";
      call symputx("_leave",1);
    end;

    else call symputx("_leave",0);
  run;

  %if &_leave %then %goto leave;

%end;

%* Check that if manual column widths are specified, that the actual column is contained in COLs;
%* Also check if it is specified with sensible widths ;

%if %nrbquote(&manual_w.) ne %then %do;

  %do _i = 1 %to %sysevalf ( %sysfunc(countw(&manual_w.,%str( ))) / 2);

    data _null_;
      x = countw("&manual_w"," ")/2;
      if int(x) ne x then call symputx("_manwnoni",1,"l");
      else call symputx("_manwnoni",1,"l");
    run;

    %* If there is an even number of words (i.e. strings separated by spaces) specified;
    %if &_manwnoni = 1 %then %do;

      %local _chkcol&_i. _wdth&_i ;

      %let _chkcol&_i = %scan(&manual_w.,%eval(2*&_i. - 1),%str( ));
      %let _wdth&_i   = %scan(&manual_w.,%eval(2*&_i.    ),%str( ));

      %if ^%index(&cols.,&&_chkcol&_i.) %then %do;
        %put %str(ERR)OR: &&_chkcol&_i. is not specified in macro parameter COL;
        %goto leave;
      %end;

      %* If dealing with widths to use in WIDTH statement;
      %* Check not specified as 0, non-integer or with unexpected characters;
      %* Or if the width is given as linesize and it is not the only column;

      %if &rtfpercent = N %then %do;
        %if %nrbquote(&&_wdth&_i) = 0 or 
            (%nrbquote(&&_wdth&_i) = &ls. and %sysfunc(countw(&cols,%str( ))) > 1) or 
            (%index(%nrbquote(&&_wdth&_i),%str(-)) or %index(%nrbquote(&&_wdth&_i),%str(.))) or
             %length ( %sysfunc(compress(%nrbquote(&&_wdth&_i),,d)) ) > 0 %then %do;

          %put %str(ERR)OR: Width for &&_chkcol&_i. (specified as &&_wdth&_i) is not specified correctly, expect this to be an integer between 0 and linesize &ls. (not inclusive);
          %goto leave;
        %end;
      %end;

      %* Otherwise if dealing with percentages;
      %* Check that they are between 0 and 100, not 100 if not the only column;
      %* And that there are no other characters like percent included;

      %else %if &rtfpercent = Y %then %do;
        %if %nrbquote(&&_wdth&_i) = 0 or 
            (%nrbquote(&&_wdth&_i) = 100 and %sysfunc(countw(&cols,%str( ))) > 1) or 
            (%index(%nrbquote(&&_wdth&_i),%str(-)) ) or
             %length ( %sysfunc(compress(%nrbquote(&&_wdth&_i),%str(.),d)) ) > 0 %then %do;

          %put %str(ERR)OR: Percentage width for &&_chkcol&_i. (specified as %nrbquote(&&_wdth&_i.)%nrstr(%)) is not specified correctly, expect this to be between 0 and 100. (not inclusive);
          %goto leave;
        %end;
      %end;

    %end;

    %else %do;
      
      %put %str(ERR)OR: Expect MANUAL_W argument to be specified as <varname> width etc, please check if a column has specified without a width or double entering of widths;
      %goto leave;

    %end;

  %end;

%end;

%* Check for PERCAVAIL (if RTFPERCENT=Y) - Check that the area available is specified;

%if &rtfpercent = Y %then %do;
  
  data _null_;

    if ^prxmatch("/(\d\d)(\.\d)?/","&percavail") or index("&percavail","%") then do;
      put "ERR" "OR: Macro parameter PERCAVAIL should be of form XX<.X>. This usually should not need to be changed";
      call symputx("_leave",1);
    end;
    else call symputx("_leave",0);

  run;

  %if &_leave %then %goto leave;

%end;

%* OR 02MAR2020 - Add in checks for the number of columns specified per page, that it is the same as number of columns in COLs;
%*              - Including the additional ID columns that would be presented;

%if %nrbquote(&colsperidpage) ne %then %do;
  %if %nrbquote(&idpages) ne %then %do;

    data _null_;
  
      %* OR 14MAY2020 - Add in input around the scan to prevent char-num conv note;
      colcnt = 0;
      do j = 1 to countw("&colsperidpage.");   
        colcnt = sum(colcnt,input(scan("&colsperidpage.",j," "),best.));
      end;

      extra_idcolcnt = countw("&idcols"," ") ;

      if colcnt ne ( countw("&cols"," ") + (&idpages. - 1) * extra_idcolcnt) then call symputx("_err",1,'l');
      else call symputx("_err",0,'l');

    run;

    %if &_err %then %do;
    
      %put %str(ERR)OR: If COLSPERIDPAGE is specified, then it needs to be specified, in list form, as number of columns per IDPAGE for every IDPAGE (including ID columns);
      %goto leave;

    %end;

  %end;
%end;

%********************************************************************************************* ASSIGNMENT OF WIDTHS;

%* Create a dataset which holds all the column names and possible widths;
%* Note for manual widths this will be assigned straight away, and the excess widths will be assigned out equally amongst the remaining columns;

%* Approach for idcolS will be slightly different;

%* This assigns the width per idpage - in the case that IDCOLS is blank, then this macro will run just once;

%if %nrbquote(&idcols.) = %then %let page = 1;
%else %if %nrbquote(&idcols.) ^= %then %let page = &idpages.;

%local _k _i _l _numremaincols new_cols new_manual_w;

%do _k = 1 %to &page;

  %if %nrbquote(&idcols.) ^= %then %do;

    %* Count how many columns we have which are not ID columns, and count how many columns can go across the pages;
    %* The aim of this section is to return the index for a scan function for columns to select on the i-th page;
    %if &_k = 1 %then %do;

      data _colsten;

        cols_per_page_auto = int( (countw("&cols") - countw("&idcols")) / &idpages. );

        do i = 1 to &idpages.;

          %* This gives the first non-id column number specified in COLs on the i-th page;
          %* For example, if we have 2 ids columns and want 4 non-id columns per page (2 pages), the start position is 3 and end position is 6;
          %* The next position (for page 2) is 7 and 10;
          %* Then for page 3 it is is 11 and 14 etc..;

          %* OR 02MAR2020 - Update if a manual number of columns per ID page has been specified;

          if ^missing("&colsperidpage") then cols_per_page = input(scan("&colsperidpage",i," "),best.);
          else cols_per_page = cols_per_page_auto;

          if i = 1 then startcol = countw("&idcols") + 1;
          else startcol = endcol + 1;

          %* The last non-id column number on the i-th page is given below;
          if ^missing("&colsperidpage") then do;

            endcol = 0;
            do _j = 1 to i;

              endcol = sum(endcol,input(scan("&colsperidpage",_j," "),best.));

            end;

          end;

          else do;
           endcol = startcol + (cols_per_page - 1);
          end;

          %* If the last page and we have some columns "left-over", then ensure they go on the last page;
          if i = &idpages. then endcol = max(endcol,countw("&cols."));

          output;

        end;

        rename i = page;

      run;
    %end;

    %* Put the start and end of indexs to return the columns for into macro variables;
    data _null_;
      set _colsten(where=(page=&_k.));

      call symputx("_start",startcol);
      call symputx("_end",endcol);
    run;

    %* Return all the columns that will go on the particular page;

      data _null_;

        length cols new_cols $20000.;
        cols = "&cols.";
        new_cols = "&idcols";

        do j = &_start. to &_end.;
          new_cols = catx(" ",new_cols,scan(cols,j," "));
        end;

        %* NEW_COLS MACRO VARIABLE DECLARED HERE;
        call symputx("new_cols",new_cols);

      run;

    %* Now return the columns with manual widths which are to be included on the page;

      data _null_;
        
        length var new_manual_w _truncstring $20000.;

        call missing(new_manual_w,_truncstring);

        %* Check to see if any columns specified for inclusion at the page had a manual width specified;
        do j = 1 to countw("&new_cols");

          var = scan("&new_cols",j);
          if find("&manual_w",var,"it") then do;

            %* Start the string at the position that the particular column for inclusion was found, so the 2nd word can be returned (which is the width);
            _truncstring = substr("&manual_w",find("&manual_w",var,"it"));

            %* OR 19FEB2020 - Ensure that percentage symbol not taken across;
            new_manual_w = catx(" ",new_manual_w,catx(" ",var,compress(scan(_truncstring,2," "),".","kd") ));

           end;
        end;

        %* NEW_COLS MACRO VARIABLE DECLARED HERE;
        call symputx("new_manual_w",new_manual_w);

      run;


            


    %* Once a width has been assigned to the IDCOL (done in the first idpage loop if IDPAGE specified), then;
    %* keep the length consistent - this is if the length has not already been specified in the initation of u_colwdth call;

    %if &_k > 1 %then %do;

      %do _l = 1 %to %sysfunc(countw(&idcols.));

        %if ^%index(&new_manual_w,%scan(&idcols,&_l,%str( ))) %then %do;

          %* OR 19FEB2020 - CONVERT width to just be numeric, in case we have XX.X%;
          data _null_;
            x = input(compress(symget("%scan(&idcols,&_l,%str( ))width"),".","kd"),best.);
            call symputx("_wdth",x);
          run;

          %let new_manual_w = &new_manual_w %scan(&idcols,&_l,%str( )) &_wdth;

        %end;

      %end;

    %end; 

  %end; 



  %* When we have no ID variables - for consistency, manual_w and cols macro parameter arguments copied across;
  %else %if %nrbquote(&idcols.) = %then %do;
    
    %let new_manual_w = &manual_w.;
    %let new_cols     = &cols.;

  %end;

  %* OR 02MAR2020 - If manual widths have been specified for a page, then check if it is exceeds available space (given by PERCAVAIL);
  %*              - Or linesize for txt outputs;
  %*              - Also check if the number of manual widths per page (if all columns are manually assigned) is not equal to PERCAVAIL;

  %if %nrbquote(&new_manual_w) ne %then %do;

    data _null_;

      %* Obtain the sum of widths already provided;
      widthchecker = 0;
      do j = 2 to countw("&new_manual_w", " ") by 2;   
        widthchecker = sum(widthchecker,input(strip(scan("&new_manual_w",j," ")),best.));
      end;
      call symputx("widthcheck&_k",widthchecker);

      if fuzz(widthchecker - &percavail.) > 0 then call symputx("_err",1,'l');
      else call symputx("_err",0,'l');

      %* If all the cols on a page are manually assigned, then this must be equal to percavail;
      if countw("&new_manual_w", " ")/2 = countw("&new_cols."," ") then do;
        if fuzz(widthchecker-&percavail.) ne 0 then call symputx("_err",2,"l");
      end;

    run;

    %if &rtfpercent = Y %then %do;

      %if &_err = 1 %then %do;
        %put %str(ERR)OR: the total width manually assigned for page &_k is &&widthcheck&_k.%nrstr(%%) which is more than available space of &percavail.%nrstr(%%);
        %goto leave;
      %end;

      %else %if &_err = 2 %then %do;
        %put %str(ERR)OR: All columns widths are assigned manually on page &_k, with total width of &&widthcheck&_k.%nrstr(%%);
        %put %str(ERR)OR: which is not the available space of &percavail.%nrstr(%%). Total width should equal total available space on page &_k.;
        %goto leave;
      %end;

    %end;

    %else %do;

      %if &_err = 1 %then %do;
        %put %str(ERR)OR: the total width manually assigned for page &_k is &&widthcheck&_k which is more than available space of &ls;
        %goto leave;
      %end;

      %else %if &_err = 2 %then %do;
        %put %str(ERR)OR: All columns widths are assigned manually on page &_k, with total width of &&widthcheck&_k.;
        %put %str(ERR)OR: which is not the linesize &ls.;
        %goto leave;
      %end;

    %end;

  %end;


  data _colw;

    %* Assign all the manual widths first, and reduce the linesize by the widths assigned already;
    %if %nrbquote(&new_manual_w.) ne %then %do;

      %do _i = 1 %to %sysevalf ( %sysfunc(countw(&new_manual_w.,%str( ))) / 2);

        %local _col&_i _wdth&_i;

        %let _col&_i  = %scan(&new_manual_w.,%eval(2*&_i. - 1),%str( ));
        %let _wdth&_i = %scan(&new_manual_w.,%eval(2*&_i.    ),%str( )); 

        &&_col&_i = &&_wdth&_i;
        
        %* OR 18FEB2020 - If RTFPERCENT = N, then we define the width in terms of linesize available;
        %if &rtfpercent = N %then %do;

          %if &_i = 1 %then _spaceremain = &ls.;;

          _spaceremain = _spaceremain - &&_wdth&_i;

          ;

        %end;

        %* OR18FEB2020 - Otherwise, define it out of the percentage available;
        %else %if &rtfpercent = Y %then %do;
          
          %if &_i = 1 %then _spaceremain = &percavail.;;

          _spaceremain = _spaceremain - &&_wdth&_i;

        %end;

      %end;

    %end;

    %else %do;

      %* If no manual width assignments, then everything is still available;
      %if       &rtfpercent = N %then _spaceremain = &ls.;
      %else %if &rtfpercent = Y %then _spaceremain = &percavail.;
      ;

    %end;

    %* Once the manual widths have been assigned, then proceed to find out what columns still remain;

    %* Find all the cols we have already assigned widths to;
    length _man_asgn_cols $20000.;

    do _i = 1 to countw("&new_manual_w"," ");

      %* Expect columns to be the odd numbered "words" in the list;
      if int(_i/2) ne _i/2 then _man_asgn_cols = catx(" ",_man_asgn_cols,scan("&new_manual_w",_i," "));

    end;

    %* Then remove them from the list of columns to find those we still need to assign widths for;
    length _remaincols $20000.;
    _remaincols = "&new_cols";

    %* OR 21FEB2020 - only remove columns if they form the entire word (i.e. if COL1 has a manually assigned width, then prevent COL10 being truncated to 0 etc);
    do _j = 1 to countw(_man_asgn_cols," ");
      _remaincols = compbl(tranwrd(_remaincols,cat(" ",strip(scan(_man_asgn_cols,_j))," ")," "));

      %* Check if manual assignment column is at the start of a string, as checking for " name " will not remove it;
      if find(_remaincols,cat(strip(scan(_man_asgn_cols,_j))," "),"i") = 1 then 
        _remaincols = left(substr(_remaincols,lengthn(scan(_man_asgn_cols,_j))+1));

      %* Check also if manual assignment column is at the end of a string, for same reason;
      %* Force to start at the end of the string, and check that the find position is at the very last word (+1 to accomodate for the space;
      _remaincollen = lengthn(_remaincols);

      if find(_remaincols,cat(" ",strip(scan(_man_asgn_cols,_j))),"i",-1*(_remaincollen+1)) =
       (_remaincollen - lengthn(scan(_man_asgn_cols,_j))+1)
      then _remaincols = substr(_remaincols,1,(_remaincollen - lengthn(scan(_man_asgn_cols,_j))+1));

    end;

    %* Assign out the following macro variables - the remaining columns, the remaining linesize available;

    call symputx("_remaincols",_remaincols,"l");
    call symputx("_spaceremain",_spaceremain,"l");

  run;

  %* Count the number of remaining columns;
  %* If there are still columns without a width assigned, then assign an equal length from remaining width. Otherwise, leave;

  %if %nrbquote(&_remaincols.) ne %then %do;

    %let _numremaincols = %sysfunc(countw(&_remaincols.));

    data _colw2;
      set _colw(drop=_i _j _remaincols _spaceremain _man_asgn_cols);

      %if &rtfpercent = Y %then %do;

        %* Here the remaining columns are apportioned an equal width;
        _wdthassgn = (&_spaceremain./&_numremaincols.);

        %do _i = 1 %to &_numremaincols.;
          
          %let _col&_i = %scan(&_remaincols.,&_i,%str( ));

          &&_col&_i = _wdthassgn;

        %end;

        %* Check the sum of widths assigned is the same as percavail;
        %* If not (most likely due to floa-ting point issues), then add or subtract a correction to the last column width;
        array _sumchk {*} &new_cols.;

        _x = sum(of _sumchk{*});
        _remaindiff = strip(put(&percavail. - _x,best32.));
        put "Total Width assigned prior to correction = " _x;
        put "Total Width still to be assigned = " _remaindiff;

 
        if _x ne &percavail. then do;

          %scan(&_remaincols.,-1,%str( )) = %scan(&_remaincols.,-1,%str( )) + (&percavail. - _x );

        end;

      %end;

      %else %do;

        %* Here the remaining columns are apportioned an equal width;
        _extrawdth = mod(&_spaceremain.,&_numremaincols.);
        _wdthassgn = round( (_spaceremain. - _extrawdth) / &_numremaincols.,0.1);


        if _extrawdth > 0 then do;
            put "NOT" "E: " _extrawdth +(-1) " linesize remains, with 1 being additionally iteratively assigned to &_remaincols (from right to left)";
            put "NOT" "E: on page &_k until no excess remains";
        end;

        %do _i = 1 %to &_numremaincols.;
          
          %let _col&_i = %scan(&_remaincols.,&_i,%str( ));

          &&_col&_i = _wdthassgn;

        %end;

        %* Define the columns which can have excess length distributed out;
        array _excesscols {*} &_remaincols.;
        _pointer=dim(_excesscols);

        %* Process iteratively to assign out the excess amongst the aforementioned columns until none left;
        %* Once the array index (given by _pointer) falls to being 0, then it is reset to start at the end of the array;
        if excess > 0 then do until(excess=0);
          _excesscols(_pointer) = _excesscols(_pointer) + 1;
           excess = excess - 1;
          _pointer = _pointer - 1;
          if _pointer = 0 then _pointer = dim(_excesscols);
        end;
            

      %end;


    run;

  %end;

  %else %do;

    data _colw2;
      set _colw(drop=_i _j _remaincols _spaceremain _man_asgn_cols);;

    run;

  %end;


  data _null_;
    set _colw2;

    %do _i = 1 %to %sysfunc(countw(&new_cols.,%str( )));

      %* Note the column widths to be assigned are stored under the variable name itself in the _colw2 dataset;
      %* A global macro which holds the width is then outputted;


      %if &rtfpercent = N %then %do;

        %let _vname = %scan(&new_cols,&_i,%str( ));
        call symputx("&_vname.width",&_vname,"g");
        put "NO" "TE: CHECK HERE FOR WIDTH ASSIGNMENTS AND PAGE ASSIGNMENTS";
        put "NO" "TE: TO BE SPECIFIED IN WIDTH ARGUMENT FOR DEFINE STATEMENT";
        put "Page         = &_k";
        put "Column Name  = &_vname";
        put "Column Width = " &_vname +(-1); 

      %end;

      %else %if &rtfpercent = Y %then %do;

        %let _vname = %scan(&new_cols,&_i,%str( ));
        call symputx("&_vname.width",cats(&_vname,"%"),"g");
        put "NO" "TE: CHECK HERE FOR WIDTH ASSIGNMENTS AND PAGE ASSIGNMENTS";
        put "NO" "TE: PERCENTAGES PROVIDED FOR USE IN CELLWIDTH= ARGUMENT for STYLE(COLUMN) ARGUMENT";
        put "NO" "TE: % PROVIDED WITH WIDTH, % DOES NOT NEED TO BE SPECIFIED IN STYLE(COLUMN) AFTER &_vname.WIDTH MACRO VARIABLE";
        put "Page         = &_k";
        put "Column Name  = &_vname";
        put "Column Width = " &_vname +(-1) "%"; 

      %end;

    %end;

  run;

  %if &tidyup = Y %then %do;
    proc datasets nolist mt=data lib=work;
      delete _colw: %if &_k = &idpages. %then _colsten;;
    quit;
  %end;

%end;

%leave:

%mend p_colwdth;
