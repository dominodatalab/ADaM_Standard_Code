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
* Program              : p_attributes
* Purpose              : Pull in information from CSVs created from spec and apply attributes
* _____________________________________________________________________________
* DESCRIPTION
*
* Input files: CSVs created from specification file as defined in macro call,
*              dataset to apply attributes to
*
* Output files: Dataset with attributes applied
*
* Macros: u_adsvars
*
* Assumptions: None
*
* _____________________________________________________________________________
* PROGRAM HISTORY
*  11MAY2020  | James Mann       | Original, largely lifted from SG015
-------------------------------------------------------------------------------
\*****************************************************************************/

%macro   p_attributes(domain =        	   /*Domain to use from specs*/
                     ,csvsyn = Y 		   /*Use CSV files from specs Y/N*/
                     ,loc = %str(&csvpath) /*Full path of spec location excluding extension or CSV file location*/
                     ,ext =     		   /*Extension for file*/
                     ,dsetin = 			   /*Dataset to apply attributes to*/
                     ,dsetout = 		   /*Dataset to output with attributes applied*/
                     ,tidyupyn = Y 		   /*Tidy up of interim datasets Y/N*/
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

  /*shortern all lengths in datasets to the max lengths required*/

  %p_maxlength(inds = &dsetin., outds=&dsetin._ml );

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

  /*Read in Variables*/
  %let currfile = Datasets;
  %if %sysfunc(fileexist("&loc.\&currfile..csv")) %then %do;

    data &pref._&currfile. (where = (Dataset = "%upcase(&domain)"));
      infile "&loc.\&currfile..csv" delimiter = ',' MISSOVER DSD lrecl=32767 firstobs=2;
      length Order 8
             Dataset $32
             Description $200
             Class $40
             Structure $200
             Purpose $10
             Key_Variables $200
             Repeating $3
             Reference_Data $3
             Comment $1000
             ;
      input Order
            Dataset $
            Description $
            Class $
            Structure $
            Purpose $
            Key_Variables $
            Repeating $
            Reference_Data $
            Comment $
            ;
    run;

  %end;

  %else %do;
    %put %str(ER)ROR: &currfile..csv does not exist. File has not been imported. Macro will abort.;
    %goto exit;
  %end;

  /*Read in Variables*/
  %let currfile = Variables;
  %if %sysfunc(fileexist("&loc.\&currfile..csv")) %then %do;

    data &pref._&currfile. (where = (Dataset = "%upcase(&domain)"));
      infile "&loc.\&currfile..csv" delimiter = ',' MISSOVER DSD lrecl=32767 firstobs=2;
      length Order 8
             Dataset $32
             Variable $32
             Label $200
             Data_Type $18
             Length 8
             Significant_Digits 8
             Format $200
             Core $10
             Codelist $128
             Origin $40
             Pages $100
             Method $1000
             Predecessor $1000
             Role $200
             Comment $1000
             Reviewer_Comment $2000
             ;
      input Order
            Dataset $
            Variable $
            Label $
            Data_Type $
            Length
            Significant_Digits
            Format $
            Core $
            Codelist $
            Origin $
            Pages $
            Method $
            Predecessor $
            Role $
            Comment $
            Reviewer_Comment $
            ;
    run;

  %end;

  %else %do;
    %put %str(ER)ROR: &currfile..csv does not exist. File has not been imported. Macro will abort.;
    %goto exit;
  %end;

  %end;

  /*Adding in numeric num/char variable type for comparison with main data*/
  data &pref._vars_type;
    set &pref._variables;
    if data_type in ('integer' 'float') then type = 1;
    else if data_type in ('text' 'datetime') then type = 2;
    if data_type in ('integer' 'float') and (length < 3 or length > 8) then length = 8;
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
  proc contents data = &dsetin._ml out = &pref._curr_vars (keep = name type varnum length) noprint;
  run;

  /*Reset validvarname option to original setting*/
  option validvarname = &validvarname.;

  proc sort data = &pref._curr_vars;
    by name;
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
    merge &pref._curr_vars (rename = (name = variable type = origtype length = origlength) in = a) &pref._vars_type (in = b);
    by variable;

    *Check variables in specs but not in dataset;
    if b and not a then do;
       put "WA" "RNING: Variable " variable "is not in the original dataset and will be created with missing values.";
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

    *Check variable length against expected length;
    if origtype = 2 then do;
    /*  if origlength > length then do;
         put "WA" "RNING: Dataset length for variable " variable "is longer than spec length. Dataset length of " origlength "will be used.";
         length = origlength;
      end;
      else if origlength < length then do;
         put "WA" "RNING: Dataset length for variable " variable "is shorter than spec length. Dataset length of " origlength "will be used.";
         length = origlength;
      end;*/
	  length=origlength;
    end;
    else do;
       length = 8;
    end;

    *Check variable type in dataset matches expected type;
    if nmiss(origtype,type) = 0 and origtype ^= type then do;
       put "WA" "RNING: Variable type for variable " variable "does not not match between specs and dataset. Length and format will not be applied.";
       length = .;
       format = '';
    end;

    output &pref._var_checks;
  run;

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
    length attrib $200;
    call symput('var'||strip(put(_n_,8.)),strip(variable));
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
  data &pref._&dsetin._nofmt;
    set &dsetin._ml;
    format _all_;
    informat _all_;
  run;

  /*Apply attributes, keep relevant variables, create missing variables*/
  data &pref._apply_attrs (keep = &varlist);
    *Attributes for each dataset;
    attrib
      %do i = 1 %to &numvars;
        &&&&attr&&var&i..
      %end;
      ;

    set &pref._&dsetin._nofmt;

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

%mend p_attributes;
