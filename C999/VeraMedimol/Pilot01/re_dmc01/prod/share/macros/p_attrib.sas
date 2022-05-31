/*****************************************************************************\
*        O
*       /
*  O---O     _  _ _  _ _  _  _|
*       \ \/(/_| (_|| | |(/_(_|
*        O
* _____________________________________________________________________________
* Sponsor              : Veramed
* Study                : Project Tools
* Program              : p_attrib.sas
* Purpose              : Pull in information from CSVs created from spec and apply attributes
* _____________________________________________________________________________
* DESCRIPTION
*
* Input files: CSVs created from specification file as defined in macro call,
*              dataset to apply attributes to
*
* Output files: Dataset with attributes applied
*
* Macros: None
*
* Assumptions: None
*
* _____________________________________________________________________________
* PROGRAM HISTORY
*  20Jan2020  |  Emily Berrett       | Original
*  02Jul2020  |  Emily Berrett       | Updates to differentiate between SDTM and ADaM CSVs,
*                                      to allow wa-rning or n-ote for variables created,
*                                      to ensure dsetin can include a libref
*  23Feb2021  |  Emily Berrett       | Updates throughout to ensure numeric variables are
*                                      always length 8 and max stripped length is used
*  09Mar2021  |  Emily Berrett       | Updates throughout to fix issue with creating variables
*                                    | in spec but not in data
*  15Mar2021  |  Emily Berrett       | Fixing bug so that datasets with no obs still run correctly
*                                      and only using variables in final dataset in processing max lengths
*  05Jul2021  |  Emily Berrett       | Ensuring max data lengths are used rather than lengths from spec,
*                                      change CSV import to be more robust, rename macro from p21_attributes to u_attrib
\*****************************************************************************/

%macro p_attrib(domain = /*Domain to use from specs*/
               ,csvsyn = N /*Use CSV files from specs Y/N*/
               ,loc = /*Full path of spec location excluding extension or CSV file location*/
               ,ext = xlsx /*Extension for file*/
               ,dsetin = /*Dataset to apply attributes to*/
               ,dsetout = /*Dataset to output with attributes applied*/
               ,missvarwarnyn = Y /*Warn if variables are created with missing values, otherwise a note is given*/
               ,tidyupyn = Y /*Tidy up of interim datasets Y/N*/
               );

  %let pref = _attr;

  /*Check population of required variables*/
  %if &domain = %str() %then %do;
      %put %str(ER)ROR: Domain has not been provided. Specifications cannot be subset on domain. Macro will abort.;
      %goto exit;
  %end;

  %if &dsetin = %str() %then %do;
      %put %str(ER)ROR: Input dataset has not been provided. Attributes cannot be applied to a datset. Macro will abort.;
      %goto exit;
  %end;

  %if &dsetout = %str() %then %do;
      %put %str(N)OTE: Output dataset has not been provided. Attributes will be applied to input dataset.;
      %let dsetout = &dsetin;
  %end;

  /*Split dataset in into library and dataset name*/
  %if %index(&dsetin,.) > 0 %then %do;
    %let dsetinlib = %scan(&dsetin,1,.);
    %let dsetinname = %scan(&dsetin,2,.);
  %end;
  %else %do;
    %let dsetinlib = WORK;
    %let dsetinname = &dsetin;
  %end;

  /*Identify if data is SDTM or ADaM*/
  %if %index(%upcase(&loc),SDTM) > 0 %then %do;
      %let type = SDTM;
  %end;
  %else %if %index(%upcase(&loc),ADAM) > 0 %then %do;
      %let type = ADAM;
  %end;
  %if %index(%upcase(&loc),SDTM) > 0 and %index(%upcase(&loc),ADAM) > 0 %then %do;
      %put %str(WA)RNING: File location contains both SDTM and ADAM in path. Assuming type is SDTM.;
  %end; 

  /*Processing for specs from Excel workbook*/
  %if %upcase(&csvsyn) = N %then %do;

    /*Check if file extension has been included on path and remove if so*/
    %if %index(&loc.,'.') > 0 %then %do;
      %let specpath = %scan(&loc.,1,.);
      /*Populating file extension from this if it is missing*/
      %if &ext = %str() %then %do;
          %let ext = %scan(&loc.,2,.);
      %end;
    %end;
    %else %do;
      %let specpath = &loc.;
    %end;

    /*Check if file extension is specified - assume xlsx otherwise*/
    %if &ext = %str() %then %do;
        %put %str(N)OTE: File extension for specifications has not been specified. Assuming xlsx file extension.;
        %let ext = xlsx;
    %end;

    /*Import datasets and variables tabs from spec*/
    %macro import_excel(sheet=);

      proc import datafile = "&specpath..&ext."
                  out = &pref._&sheet (where = (dataset = "%upcase(&domain)"))
                  replace
                  dbms = &ext.;
        sheet = "&sheet.";
        getnames = yes;
      run;

    %mend import_excel;

    /*Check if file exists and read it in else put an error and abort*/
    %if %sysfunc(fileexist("&specpath..&ext.")) %then %do;

      %import_excel(sheet=Datasets);
      %import_excel(sheet=Variables);

    %end;

    %else %do;
      %put %str(ER)ROR: Specified file does not exist - check path and file extension. Specifications have not been imported. Macro will abort.;
      %goto exit;
    %end;

  %end;

  /*Processing for specs from CSVs*/
  %else %if %upcase(&csvsyn) = Y %then %do;

    /*Import datasets and variables tabs from spec*/

    %let file = Datasets;
    %if %sysfunc(fileexist("&loc.\&file..csv")) %then %do;

      proc import datafile = "&loc.\&file..csv"
                  out = &pref._&file. (where = (Dataset = "%upcase(&domain)"))
                  dbms = csv replace;
                  guessingrows = max;
      run;

    %end;

    %else %do;
      %put %str(ER)ROR: &file..csv does not exist. File has not been imported. Macro will abort.;
      %goto exit;
    %end;

    %let file = Variables;
    %if %sysfunc(fileexist("&loc.\&file..csv")) %then %do;

      proc import datafile = "&loc.\&file..csv"
                  out = &pref._&file. (where = (Dataset = "%upcase(&domain)"))
                  dbms = csv replace;
                  guessingrows = max;
      run;

    %end;

    %else %do;
      %put %str(ER)ROR: &file..csv does not exist. File has not been imported. Macro will abort.;
      %goto exit;
    %end;

  %end;

  /*Adding in numeric num/char variable type for comparison with main data*/
  data &pref._vars_type;
    set &pref._variables;
    if data_type in ('integer' 'float') then type = 1;
    else if data_type in ('text' 'datetime') then type = 2;
    if data_type in ('integer' 'float') then length = 8;
    format _all_;
    informat _all_;
  run;

  proc sort data = &pref._vars_type;
    by variable;
  run;

  /*Current validvarname option value to reset later*/
  proc sql noprint;
    select distinct setting
    into :validvarname
    from sashelp.voption
    where optname = 'VALIDVARNAME';
  quit;

  /*Ensure all variables are read as uppercase*/
  option validvarname = upcase;

  /*Variable attributes of existing dataset*/
  proc contents data = &dsetin out = &pref._curr_vars_orig (keep = name type varnum length) noprint;
  run;

  /*Reset validvarname option to original setting*/
  option validvarname = &validvarname.;

  proc sort data = &pref._curr_vars_orig;
    by name;
  run;

  /*Dataset containing only common variables between input and final dataset*/
  data &pref._var_both;
    length variable $200;
    merge &pref._curr_vars_orig (rename = (name = variable type = origtype length = origlength) in = a) &pref._vars_type (in = b);
    by variable;
    if a and b;
  run;

  /*List of character variables in dataset being read in into macro variables*/
  proc sql noprint;
    select distinct variable
    into :origvarcharlist
    separated by ' '
    from &pref._var_both
    where origtype = 2;
  quit;

  %let origvarcharcount = &sqlobs;

  /*Get max length of each variable in turn (after removing trailing blanks)*/
  %do i = 1 %to &origvarcharcount;

    %let currvar = %scan(&origvarcharlist,&i);

    proc sql noprint;
      select max(length(strip(&currvar)))
      into :&currvar.len trimmed
      from &dsetin;
    quit;

    %if &&&currvar.len = %str() %then %do;
        %let &currvar.len = 1;
    %end;

  %end;

  /*Reset for later use*/
  %let currvar = %str();

  /*Put each variable length into a dataset*/
  data &pref._curr_vars_maxlen;
    length name $8;
    %do j = 1 %to &origvarcharcount;
      %let currvar = %scan(&origvarcharlist,&j);
      name = upcase("&currvar");
      maxlength = &&&currvar.len;
      output;
    %end;
  run;

  /*Merge on max lengths in actual data for character variables*/
  proc sql noprint;
    create table &pref._curr_vars_length as
    select a.name, a.type, a.length, a.varnum, b.maxlength
    from &pref._curr_vars_orig as a
    full join &pref._curr_vars_maxlen as b
    on a.name = b.name
    order by a.name;
  quit;

  /*Replace given lengths in data with max lengths*/
  data &pref._curr_vars (drop = maxlength);
    set &pref._curr_vars_length;
    if maxlength ^= . and length > maxlength then length = maxlength;
  run;

  /*Length of variable name to avoid truncation*/
  proc sql noprint;
    select length
    into :varnamelen
    separated by ''
    from sashelp.vcolumn
    where libname = 'WORK' and memname = upcase("&pref._curr_vars") and name = "NAME";
  quit;

  /*List of variables to keep*/
  proc sql noprint;
    select variable
    into :varlist
    separated by ' '
    from &pref._vars_type
    order by variable;
  quit;

  /*Number of variables to keep in final data*/
  %let numvars = &sqlobs;

  /*Check dataset against expected variables, types, lengths*/
  data &pref._var_checks (drop = missvar) &pref._missing_vars (keep = variable missvar) &pref._dropped_vars (keep = variable);
    length variable $&varnamelen.;
    merge &pref._curr_vars (rename = (name = variable type = origtype) in = a) &pref._vars_type (rename = (length = speclength) in = b);
    by variable;

    *Check variables in specs but not in dataset;
    if b and not a then do;
       %if %upcase(&missvarwarnyn) = Y %then %do;
           put "WA" "RNING: Variable " variable "is not in the original dataset and will be created with missing values.";
       %end;
       %else %do;
           put "N" "OTE: Variable " variable "is not in the original dataset and will be created with missing values.";
       %end;
       *Create code to be put into macro variable to run later to create empty variable of correct type;
       missvar = strip(variable)||' = '||ifc(type = 1,'.','""');
       output &pref._missing_vars;
    end;

    *Check variables in dataset but not in specs;
    if a and not b then do;
       put "N" "OTE: Variable " variable "is in the dataset but not in the specs and will be dropped.";
       output &pref._dropped_vars;
       delete;
    end;

    *Check variable type in dataset matches expected type;
    if nmiss(origtype,type) = 0 and origtype ^= type then do;
       put "WA" "RNING: Variable type for variable " variable "does not not match between specs and dataset. Length and format will not be applied.";
       length = .;
       format = '';
    end;

    output &pref._var_checks;
  run;

  /*Variables in both original and final data for SQL lengths later*/
  proc sql noprint;
    select distinct variable
    into :origfinvar1 -
    from &pref._var_checks
    where varnum ^= .;
  quit;

  %let origfinvarcount = &sqlobs;

  /*Put code for variables not in data in sequential macro variables for later use*/
  proc sql noprint;
    select missvar
    into :missvar1 - 
    from &pref._missing_vars;
  quit;

  /*Number of missing variables*/
  %let missvars = &sqlobs;

  proc sort data = &pref._var_checks;
    by order variable;
  run;

  /*Create attributes lists for each variable and assign to macro variables*/
  data &pref._var_attrs;
    set &pref._var_checks;
    length lengthsql attrib $200;
    call symput('var'||strip(put(_n_,8.)),strip(variable));
    *attrib string for lengths to be applied in sql;
    lengthsql = strip(variable)||ifc(length ^= .,' length = '||strip(put(length,best.)),strip(''));
    call symput('attrsql'||strip(variable),strip(lengthsql));
    *attrib string for label, length, and format as relevant;
    attrib = strip(variable)||' label = "'||strip(label)||'"'||
             ifc(length ^= .,' length = '||ifc(data_type in ('text' 'datetime'),'$',strip(''))||strip(put(length,best.)),strip(''))||
             ifc(format ^= '',' format = '||strip(format)||ifc(substr(format,length(strip(format)),1) = '.',strip(''),'.'),strip(''));
    call symput('attr'||strip(variable),strip(attrib));
  run;

  proc sort data = &pref._var_attrs;
    by variable;
  run;

  /*Remove all formats*/
  data &pref._&dsetinname._nofmt;
    set &dsetin;
    format _all_;
    informat _all_;
  run;

  %if &origfinvarcount > 0 %then %do;

    /*Cut down lengths using SQL to avoid log issues*/
    /*These will not be truncated due to checks earlier*/
    /*Only max stripped lengths in data will be applied*/
    proc sql noprint;
      create table &pref._apply_attrs_sql as
      select %do i = 1 %to %eval(&origfinvarcount - 1);
               &&&&attrsql&&origfinvar&i..,
             %end;
             &&&&attrsql&&origfinvar&origfinvarcount..
      from &pref._&dsetinname._nofmt;
    quit;

  %end;

  %else %do;

    data &pref._apply_attrs_sql;
      set &pref._&dsetinname._nofmt;
    run;

  %end;

  /*Apply attributes, keep relevant variables, create missing variables*/
  data &pref._apply_attrs (keep = &varlist);
    *Attributes for each dataset;
    attrib
      %do i = 1 %to &numvars;
        &&&&attr&&var&i..
      %end;
      ;

    set &pref._apply_attrs_sql;

    *Create variables with missing data for those in specs but not dataset;
    %do j = 1 %to &missvars;
      &&missvar&j.;
    %end;
  run;

  /*Take dataset label and sort order (key) from datasets tab and assign to macro variables*/
  data _null_;
    set &pref._datasets;
    call symput('dsetlabel',strip(description));
    call symput('sortorder',compbl(tranwrd(key_variables,',',' ')));
  run;

  /*Final dataset with all attributes applied*/
  proc sort data = &pref._apply_attrs out = &dsetout (label = "&dsetlabel");
    by &sortorder;
  run;

  /*Deletion of intermediate datasets*/
  %if %upcase(&tidyupyn) = Y %then %do;
    
    proc datasets lib = work nolist memtype = data;
      delete &pref._:;
    quit;

  %end;

  %exit: %str();

%mend p_attrib;
