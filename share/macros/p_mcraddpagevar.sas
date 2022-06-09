/*--------------------------------------------------------------------------------------------------------*
|         O                                                                                               |
|        /                                                                                                |
|   O---O     _  _ _  _ _  _  _|                                                                          |
|        \ \/(/_| (_|| | |(/_(_|                                                                          |
|         O                                                                                               |
|---------------------------------------------------------------------------------------------------------|
| Program              : p_mcrAddPageVar.sas                                                                |
| Purpose              : Derive a page-breaking variable for a report dataset.                            |
|---------------------------------------------------------------------------------------------------------|
| DESCRIPTION                                                                                             |
| The mcrAddPageVar macro generates code that reads an input dataset and writes out an output dataset     |
| that contains all the variables present in the input dataset plus an additional variable called PAGE.   |
| The row sort order of the output dataset matches that of the input dataset.                             |
| A call to this macro should be the final dataset preparation step before passing the output dataset to  |
| a Proc REPORT step to generate the Table or Listing display.                                            |
| Primarily intended for use with Listing programmes, but can be used with Table programmes too.          |
|                                                                                                         |
| The code mimics common Proc REPORT actions in order to assess the number of rows in the output display  |
| that each input dataset observation will take up. Those actions are:                                    |
| - Line-wrapping of text strings to fit the available column width, or line-wrapping triggered by        |
|   new-line characters in the text.                                                                      |
|   - This is calculated for each variable listed in the TXT parameter and the maximum row height is      |
|     taken as the row height required for that input observation.                                        |
| - Line-wrapping triggered by new-line characters in the text.                                           |
| - Breaking a page whenever a new value for a given variable is encountered (e.g. treatment group).      |
| - Grouping sets of observations together:                                                               |
|   - Assuming that for a set of identical values in the group-defining variable only the first value     |
|     will be shown in the output display. Therefore, line wrapping assessment is only carried out for    |
|     that first value. The row height requirement for that variable in subsequent rows in the group is   |
|     set to 1 row.                                                                                       |
|   - Overall group height is assessed to ensure that groups are not split across pages, unless the group |
|     requires more rows than are available in a single page, in which case the page is broken when the   |
|     page limit is reached.                                                                              |
| - Insertion of a blank row before or after a given variable changes value. If you intend to use the     |
|   Proc REPORT step to introduce these blank rows (e.g. via a compute block) then this option will take  |
|   into account the extra vertical space taken up by the blank row when assessing page breaking.         |
|                                                                                                         |
| The code was originally developed for a delivery where the output displays were using a non-monospaced  |
| font, so the width of each character was taken into account. Consult the additional documentation for   |
| more information about how to set up and use this macro for non-monospaced font outputs.                |
| #### TODO: ADD URL TO DOCUMENT. ####                                                                    |
|                                                                                                         |
| Description of the mcrAddPageVar macro parameters:                                                      |
| Key: [m] = Mandatory parameter, [o] = Optional parameter.                                               |
|                                                                                                         |
| DATASET_IN [m]                                                                                          |
|   The dataset that is ready to pass to Proc REPORT, with the exception of the PAGE variable.            |
|                                                                                                         |
| DATASET_OUT [m]                                                                                         |
|   The DATASET_IN dataset with the PAGE variable added.                                                  |
|                                                                                                         |
| TXT [m]                                                                                                 |
|   A space-delimited list of variables present in the DATASET_IN dataset that you want to assess for     |
|   line wrapping or that are listed in other mcrAddPageVar macro parameters (may include numeric         |
|   variables too for this reason).                                                                       |
|                                                                                                         |
| TXT_COL_WIDTH [m]                                                                                       |
|   Expected width (in number of monospaced characters) of each column listed in TXT.                     |
|   A space-delimited list, where the order of each number corresponds to the variable in that position   |
|   in the TXT parameter variable list.                                                                   |
|   Use a larger than needed number for any variables that do not need to be assessed for line wrapping.  |
|                                                                                                         |
| TXT_GROUPED [o]                                                                                         |
|   A space-delimited list of variables present in the TXT parameter list that will be displayed in the   |
|   report as groups, i.e. only the first row will display the variable value within a set of rows with   |
|   identical values for that variable. Adding a variable to this parameter tells the macro to only       |
|   calculate line wrapping for the value from the first row in the group. All subsequent rows for this   |
|   variable will have a line number requirement of 1 row.                                                |
|                                                                                                         |
| NEWLINE [o]                                                                                             |
|   Text string used to denote a new-line.                                                                |
|                                                                                                         |
| STANDARD_ROW_NUM_LINES [o]                                                                              |
|   Minimum number of text rows that a single record will require (a.k.a. one Standard Height row).       |
|                                                                                                         |
| MAX_ROWS_PER_PAGE [m]                                                                                   |
|   Maximum number of Standard Height rows that may be accommodated on the page.                          |
|                                                                                                         |
| PAGE_BY_VARS [o]                                                                                        |
|   Variables that should trigger a page break when their value changes relative to the previous record.  |
|   This variable should be the first variable to appear in the pre-sorted DATASET_IN sort definition.    |
|                                                                                                         |
| GROUP_ON_PAGE_VARS [o]                                                                                  |
|   Records with matching values for these variables will be grouped on the same page if space to do so.  |
|   The variables listed here should match the variable sort order applied to the DATASET_IN dataset.     |
|   It is possible to list fewer variables here than are used in the DATASET_IN sort definition, but the  |
|   concatenation of the PAGE_BY_VARS list and the GROUP_ON_PAGE_VARS list must together match the        |
|   left-most portion of the DATASET_IN sort definition.                                                  |
|   E.g. If you want to break the page by changes in TRTN variable value, and group rows together on a    |
|        page by changes in the MHBODSYS or MHDECOD variable value, then we would do the following:       |
|          DATASET_IN sorted by: trtn mhbodsys mhdecod                                                    |
|          PAGE_BY_VARS = trtn                                                                            |
|          GROUP_ON_PAGE_VARS = mhbodsys mhdecod                                                          |
|   It is possible to use GROUP_ON_PAGE_VARS without PAGE_BY_VARS and vice versa.                         |
|   In the example above, if you did not want to use the PAGE_BY_VARS option, but the DATASET_IN sort     |
|   order had to remain unchanged, you would have to include TRTN as the first variable in the            |
|   GROUP_ON_PAGE_BY var list:                                                                            |
|          GROUP_ON_PAGE_VARS = trtn mhbodsys mhdecod                                                     |
|                                                                                                         |
|   NOTE (TXT_GROUPED vs GROUP_ON_PAGE_BY):                                                               |
|     This parameter is deliberately separate to the TXT_GROUPED parameter to allow TXT_GROUPED to handle |
|     line-wrapping assessment (not sort-order-dependent) and GROUP_ON_PAGE_VARS to handle page-breaking  |
|     across those groups, using the variables that define each group (sort-order dependent). Therefore,  |
|     you can pass the group display text variable to TXT_GROUPED, and a separate, perhaps numeric, group |
|     variable to GROUP_ON_PAGE_VARS, allowing for alternative sorting strategies. E.g. if you want to    |
|     ensure that uncoded MH terms are presented first, then all coded terms, when grouping by SOC and    |
|     PT.                                                                                                 |
|                                                                                                         |
| TXT_SPACER_LINE [o]                                                                                     |
|   One or more variables listed in TXT that should trigger a blank line before or after when their value |
|   changes relative to the previous record. May be character or numeric.                                 |
|                                                                                                         |
| MONOSPACED_FONT [o]                                                                                     |
|   1 = Monospaced font, 0 = Non-monospaced font.                                                         |
|   Default = 1.                                                                                          |
|                                                                                                         |
| SPACE_CHAR_WIDTH [o]                                                                                    |
|   This is the width in Standard Character Units of a space character, where a Standard Character        |
|   Unit is a pipe (|) character. This is to allow the width of space characters to be added to the       |
|   total string length as it is not possible to store the value in the caracter width lookup format,     |
|   where the key is a space character.                                                                   |
|   This option is only applicable when using non-monospaced fonts.                                       |
|   If monospaced fonts are in use, the default width is 1.                                               |
|                                                                                                         |
| DEBUG_MODE [o]                                                                                          |
|   1 = On, 0 = Off.                                                                                      |
|   Default = 0.                                                                                          |
|   When on, debug mode will write more statements to the log to help identify where issues occur.        |
|                                                                                                         |
| A note on using order variables:                                                                        |
|   It can sometimes be helpful to create an order variable that is a concatenation of values from        |
|   multiple variables.                                                                                   |
|   E.g. In a Medical History Glossary listing, we want to apply the group-on-page option to the MHBODSYS |
|   and MHDECOD variables but need to show Uncoded MHBODSYS terms first in the listing, where the value   |
|   of Uncoded data has to be shown as <<Pending-coding>>. We do not want to use the PAGE_BY_VARS option, |
|   so the list of variables passed to the GROUP_ON_PAGE_VARS parameter needs to match the left-most      |
|   variables in the sort order specification applied to the DATASET_IN dataset. We could add an order    |
|   variable, such as ORD1 to denote a section number, where ORD1=1 for Uncoded terms and ORD1=2 for all  |
|   Coded terms. However, we would need to sort on that first, and so would need to include ORD1 as the   |
|   first variable in the GROUP_ON_PAGE_VARS parameter list. This means that as ORD1=2 will be treated as |
|   a group and that group will be too large to fit on one page, so will start on page 2. We do not want  |
|   this page break to occurr after the initial uncoded terms section.                                    |
|   Solution: Create an ORD2 variable, which is assigned the value of the concatenation of ORD1 and       |
|   MHBODSYS. Sort the DATASET_IN dataset by ORD2, MHDECOD and MHTERM. Set the GROUP_ON_PAGE_VARS         |
|   parameter value to ORD2 MHDECOD.                                                                      |
|---------------------------------------------------------------------------------------------------------|
| PROGRAM HISTORY                                                                                         |
|  28MAR2019  | Iain McKendrick  | Original version of the macro.                                         |
|  06SEP2019  | Iain McKendrick  | Added the TXT_SPACER_LINE option.                                      |
|  09OCT2019  | Iain McKendrick  | Combining component macros into one macro. Added parameter checking.   |
|  03MAR2020  | Emily Berrett    | Adding macro for number of pages and removing +0.1 for padding rows.   |
|  17AUG2020  | Emily Berrett    | Debugging line counts and page breaking for grouping variables.        |
*--------------------------------------------------------------------------------------------------------*/

%macro p_mcrAddPageVar(dataset_in=,
                     dataset_out=,
                     txt=,
                     txt_col_width=,
                     txt_grouped=,
                     newline=%nrstr(|n),
                     standard_row_num_lines=1,
                     max_rows_per_page=,
                     page_by_vars=,
                     group_on_page_vars=,
                     txt_spacer_line=%str( ),
                     monospaced_font=1,
                     space_char_width=1,
                     debug_mode=0);


 %*====================================================*
  | ##########  Parameter checking section  ########## |
  *====================================================*;
  
 %*---------------------------------------------------------------------------------*
  | Check that the value passed to the DATASET_IN parameter is a valid SAS dataset. |
  *---------------------------------------------------------------------------------*;
  %put %str(NO)TE: Checking that the value passed to the DATASET_IN parameter (%upcase(&dataset_in.)) is a valid SAS dataset.;

  %if %sysfunc(exist(&dataset_in.)) eq 0 %then %do;
    %put %str(ERR)OR: Dataset &dataset_in. does not exist or is invalid.;
    %goto exit;
  %end;

  %put %str(NO)TE: Check OK;

 %*---------------------------------------------------------------------------------*
  | Find the number of space-delimited values that have been passed to the TXT,     |
  | TXT_COL_WIDTH, PAGE_BY_VARS, GROUP_ON_PAGE_VARS and TXT_SPACER_LINE parameters. |
  *---------------------------------------------------------------------------------*;
  %let num_txt_vars             = %sysfunc(countw(%bquote(&txt.),                %bquote( )));
  %let num_txt_col_width        = %sysfunc(countw(%bquote(&txt_col_width.),      %bquote( )));
  %let num_txt_grouped          = %sysfunc(countw(%bquote(&txt_grouped.),        %bquote( )));
  %let num_page_by_vars         = %sysfunc(countw(%bquote(&page_by_vars.),       %bquote( )));
  %let num_group_on_page_vars   = %sysfunc(countw(%bquote(&group_on_page_vars.), %bquote( )));
  %let num_txt_spacer_line_vars = %sysfunc(countw(%bquote(&txt_spacer_line.),    %bquote( )));

  %put num_txt_vars=&num_txt_vars.;
  %put num_txt_col_width=&num_txt_col_width.;
  %put num_txt_grouped=&num_txt_grouped.;
  %put num_page_by_vars=&num_page_by_vars.;
  %put num_group_on_page_vars=&num_group_on_page_vars.;
  %put num_txt_spacer_line_vars=&num_txt_spacer_line_vars.;

 %*--------------------------------------------------------------------------------*
  | Check that the number of values passed to the TXT parameter is greater then 0. |
  *--------------------------------------------------------------------------------*;
  %put %str(NO)TE: Checking that the number of values passed to the TXT parameter is greater than 0.;

  %if &num_txt_vars. eq 0 %then %do;
    %put %str(ERR)OR: You need to provide at least one space-delimited value to the TXT parameter.;
    %goto exit;
  %end;

  %put %str(NO)TE: Check OK;

 %*-------------------------------------------------------------------------------*
  | Check that the number of values passed to the TXT_COL_WIDTH parameter matches |
  | the number of values passed to the TXT parameter.                             |
  *-------------------------------------------------------------------------------*;
  %put %str(NO)TE: Checking that the number of values passed to the TXT_COL_WIDTH parameter matches the number of values passed to the TXT parameter.;

  %if &num_txt_vars. ne &num_txt_col_width. %then %do;
    %put %str(ERR)OR: You need to provide a space-delimited column width value for each of the corresponding variables passed to the TXT parameter.;
    %goto exit;
  %end;

  %put %str(NO)TE: Check OK;

 %*--------------------------------------------------------------------------------------*
  | Check that values passed to the TXT_COL_WIDTH parameter contain only numeric values. |
  *--------------------------------------------------------------------------------------*;
  %put %str(NO)TE: Checking that values passed to the TXT_COL_WIDTH parameter contain only numeric values.;

  %if %sysfunc(compress(%bquote(&txt_col_width.), %bquote( ), %bquote(d))) ne %str( ) %then %do;
    %put %str(ERR)OR: Parameter TXT_COL_WIDTH should only contain just spaces and numbers.;
    %put txt_col_width=&txt_col_width.;
    %goto exit;
  %end;

  %put %str(NO)TE: Check OK;

 %*------------------------------------------------------------------------*
  | Identify the variables present in the DATASET_IN dataset and store the |
  | variable names as a space-delimited list in a macro variable for use   |
  | in param checks and DATA step KEEP= option specifications.             |
  *------------------------------------------------------------------------*;
  proc sql noprint;
    select name, count(name) as numvars 
    into :dsin_vars separated by ' ', :num_dsin_vars
    from sashelp.vcolumn
    where libname eq 'WORK' and 
          memname eq upcase("&dataset_in.");
  quit;
  %let num_dsin_vars=&num_dsin_vars.; %** To remove extra whitespace that Proc SQL randomly adds. **;
  %put dsin_vars=&dsin_vars.;
  %put num_dsin_vars=&num_dsin_vars.;

 %*-----------------------------------------------------------------------------*
  | Check that the variable names passed to the TXT, TXT_GROUPED, PAGE_BY_VARS, |
  | GROUP_ON_PAGE_VARS and TXT_SPACER_LINE parameters are variables that exist  |
  | in the DATASET_IN dataset.                                                  |
  *-----------------------------------------------------------------------------*;
  %macro chk_vars_in_dsin(param=, num_param_vars=);
    %put %str(NO)TE: Checking &param. parameter values are variable names in the %upcase(&dataset_in.) dataset.;
    %global chk_vars_in_dsin_fail;
    %let chk_vars_in_dsin_fail=0;

    %do i=1 %to &num_param_vars.;
      %let var_in_ds=0;
      %let var_&i. = %upcase(%sysfunc(scan(%bquote(&&&param.), &i., %bquote( ))));

      %do j=1 %to &num_dsin_vars.;
        %let ds_var = %upcase(%sysfunc(scan(%bquote(&dsin_vars.), &j., %bquote( ))));
        %if %bquote(&&var_&i.) eq %bquote(&ds_var) %then %do;
          %let var_in_ds=1;
        %end;
      %end;

      %if %bquote(&var_in_ds.) eq %bquote(0) %then %do;
        %put %str(ERR)OR: &param. variable &i. (&&var_&i.) does not exist in the DATASET_IN dataset.;
        %let chk_vars_in_dsin_fail=1;
      %end;
    %end;
  %mend chk_vars_in_dsin;

  %chk_vars_in_dsin(param=TXT, num_param_vars=&num_txt_vars.)
  %if %bquote(&chk_vars_in_dsin_fail.) eq %bquote(1) %then %goto exit;
  %put %str(NO)TE: Check OK.;

  %chk_vars_in_dsin(param=TXT_GROUPED, num_param_vars=&num_txt_grouped.)
  %if %bquote(&chk_vars_in_dsin_fail.) eq %bquote(1) %then %goto exit;
  %put %str(NO)TE: Check OK.;

  %chk_vars_in_dsin(param=PAGE_BY_VARS, num_param_vars=&num_page_by_vars.)
  %if %bquote(&chk_vars_in_dsin_fail.) eq %bquote(1) %then %goto exit;
  %put %str(NO)TE: Check OK.;

  %chk_vars_in_dsin(param=GROUP_ON_PAGE_VARS, num_param_vars=&num_group_on_page_vars.)
  %if %bquote(&chk_vars_in_dsin_fail.) eq %bquote(1) %then %goto exit;
  %put %str(NO)TE: Check OK.;

  %chk_vars_in_dsin(param=TXT_SPACER_LINE, num_param_vars=&num_txt_spacer_line_vars.)
  %if %bquote(&chk_vars_in_dsin_fail.) eq %bquote(1) %then %goto exit;
  %put %str(NO)TE: Check OK.;

 %*---------------------------------------------------------------------*
  | Check that the values passed to the TXT_GROUPED and TXT_SPACER_LINE |
  | parameter values exist within the set of TXT parameter values.      |
  *---------------------------------------------------------------------*;
  %macro chk_vars_in_txt(param=, num_param_vars=);
    %put %str(NO)TE: Checking &param. parameter values exist within the set of TXT parameter values.;
    %global chk_vars_in_txt_fail;
    %let chk_vars_in_txt_fail=0;

    %do i=1 %to &num_param_vars.;
      %let var_in_txt=0;
      %let var_&i. = %upcase(%sysfunc(scan(%bquote(&&&param.), &i., %bquote( ))));

      %do j=1 %to &num_txt_vars.;
        %let txt_var = %upcase(%sysfunc(scan(%bquote(&txt.), &j., %bquote( ))));
        %if %bquote(&&var_&i.) eq %bquote(&txt_var.) %then %do;
          %let var_in_txt=1;
        %end;
      %end;

      %if %bquote(&var_in_txt.) eq %bquote(0) %then %do;
        %put %str(ERR)OR: &param. variable &i. (&&var_&i.) does not exist within the set of TXT parameter values.;
        %let chk_vars_in_txt_fail=1;
      %end;
    %end;
  %mend chk_vars_in_txt;

  %chk_vars_in_txt(param=TXT_GROUPED, num_param_vars=&num_txt_grouped.)
  %if %bquote(&chk_vars_in_txt_fail.) eq %bquote(1) %then %goto exit;
  %put %str(NO)TE: Check OK.;

  %chk_vars_in_txt(param=TXT_SPACER_LINE, num_param_vars=&num_txt_spacer_line_vars.)
  %if %bquote(&chk_vars_in_txt_fail.) eq %bquote(1) %then %goto exit;
  %put %str(NO)TE: Check OK.;

 %*-----------------------------------------------------------------------------------------*
  | Check that variables listed in PAGE_BY_VARS plus GROUP_ON_PAGE_VARS match the left-most |
  | sort order specification in the DATASET_IN dataset.                                     |
  *-----------------------------------------------------------------------------------------*;
  %if &num_page_by_vars. gt 0 or &num_group_on_page_vars. gt 0 %then %do;
    %put %str(NO)TE: Checking that variables listed in PAGE_BY_VARS plus GROUP_ON_PAGE_VARS match the left-most sort order specification in the %upcase(&dataset_in.) dataset.;

    proc sql noprint;
      select name, sortedby 
      into :dsin_sort_list separated by ' ', :dsin_sort_order separated by ' '
      from dictionary.columns
      where libname='WORK' and memname=upcase("&dataset_in.") and sortedby gt 0
      order by sortedby;

      %let num_sorted_vars = &sqlobs.;
    quit;

    %put num_sorted_vars=&num_sorted_vars.;

    %if &num_sorted_vars. eq 0 %then %do;
      %put %str(ERR)OR: The DATASET_IN dataset (&dataset_in.) has not been sorted.;
      %goto exit;
    %end;
    %else %do;
      %put dsin_sort_list=&dsin_sort_list.;

      %if &num_page_by_vars. gt 0 and &num_group_on_page_vars. gt 0 %then %do;
        %let by_vars = %upcase(%sysfunc( catx(%bquote( ), %bquote(&page_by_vars.), %bquote(&group_on_page_vars.)) ));
      %end;
      %else %if &num_page_by_vars. gt 0 and &num_group_on_page_vars. eq 0 %then %do;
        %let by_vars = %upcase(&page_by_vars.);
      %end;
      %else %if &num_page_by_vars. eq 0 and &num_group_on_page_vars. gt 0 %then %do;
        %let by_vars = %upcase(&group_on_page_vars.);
      %end;
      
      %let by_vars_length = %sysfunc(length(%bquote(&by_vars.)));
      %let dsin_sort_list_ss = %upcase(%sysfunc( substr(%bquote(&dsin_sort_list.), %bquote(1), %bquote(&by_vars_length.)) ));
      
      %if %bquote(&by_vars.) ne %bquote(&dsin_sort_list_ss.) %then %do;
        %put %str(ERR)OR: The variables listed in PAGE_BY_VARS plus GROUP_ON_PAGE_VARS parameters must match the left-most variables specified in the sort order specification of the DATASET_IN dataset.;
        %put by_vars=&by_vars.;
        %put by_vars_length=&by_vars_length.;
        %put dsin_sort_list_ss=&dsin_sort_list_ss.;
        %goto exit;
      %end;

      %put %str(NO)TE: Check OK;
    %end;
  %end;

 %*-------------------------------------------------------------------------------*
  | Check that the STANDARD_ROW_NUM_LINES, MAX_ROWS_PER_PAGE and SPACE_CHAR_WIDTH |
  | parameters contains a numeric value greater than 0.                           |
  *-------------------------------------------------------------------------------*;
  %macro chk_num_gt_zero(param=);
    %put %str(NO)TE: Checking &param. parameter value contains a numeric value greater than 0.;
    %global chk_num_gt_zero_fail;
    %let chk_num_gt_zero_fail = 1;

    %if %sysfunc( prxmatch(%bquote(/^\s*[0-9.]+\s*$/), %bquote(&&&param.)) ) eq 1 %then %do;
      %if %bquote(&&&param.) gt %bquote(0) %then %let chk_num_gt_zero_fail = 0;
    %end;

    %if &chk_num_gt_zero_fail. eq 1 %then %do;
      %put %str(ERR)OR: Param &param. value (&&&param.) is not a numeric value greater than zero.;
    %end;
  %mend chk_num_gt_zero;

  %chk_num_gt_zero(param=STANDARD_ROW_NUM_LINES)
  %if %bquote(&chk_num_gt_zero_fail.) eq %bquote(1) %then %goto exit;
  %put %str(NO)TE: Check OK;

  %chk_num_gt_zero(param=MAX_ROWS_PER_PAGE)
  %if %bquote(&chk_num_gt_zero_fail.) eq %bquote(1) %then %goto exit;
  %put %str(NO)TE: Check OK;

  %chk_num_gt_zero(param=SPACE_CHAR_WIDTH)
  %if %bquote(&chk_num_gt_zero_fail.) eq %bquote(1) %then %goto exit;
  %put %str(NO)TE: Check OK;

 %*------------------------------------------------------------------------------------*
  | Check that the MONOSPACED_FONT and DEBUG_MODE parameters contain the value 0 or 1. |
  *------------------------------------------------------------------------------------*;
  %macro chk_num_flag(param=);
    %put %str(NO)TE: Checking that the value of flag parameter &param. (&&&param.) is 0 or 1.;
    %global chk_num_flag_fail;
    %let chk_num_flag_fail = 0;

    %if %sysfunc( prxmatch(%bquote(/^\s*[01]\s*$/), %bquote(&&&param.)) ) ne 1 %then %do;
      %let chk_num_flag_fail = 1;
      %put %str(ERR)OR: The value of flag parameter &param. (&&&param.) is not 0 or 1.;
    %end;
  %mend chk_num_flag;

  %chk_num_flag(param=MONOSPACED_FONT)
  %if %bquote(&chk_num_flag_fail.) eq %bquote(1) %then %goto exit;
  %put %str(NO)TE: Check OK;

  %chk_num_flag(param=DEBUG_MODE)
  %if %bquote(&chk_num_flag_fail.) eq %bquote(1) %then %goto exit;
  %put %str(NO)TE: Check OK;


 %*--------------------------------------------------------------------------------*
  | Additional setup step when using non-monospaced fonts in the display output.   |
  | Defining the MAP_CHAR informat, containing the width of each type of character |
  | in Standard Width Character units, where the Standard Width Character is a     |
  | narrow character such as a pipe (|).                                           |
  | See separate document for more info on how to set this up.                     |
  *--------------------------------------------------------------------------------*;
  %** E.g. Define the MAP_CHAR informat to use for the Times 10pt font in RTF output. **;
  /*%include "&mpath.\map_char_width_times_10pt.sas" / source;*/


 %*========================================================================================================*
  | ##########  Identify line-breaking and therefore row height required for each observation.  ########## |
  *========================================================================================================*;

  %if &monospaced_font. eq 1 %then %do;
    %put %str(NO)TE: ######## USING MONOSPACED FONT ########;
    proc format;
      invalue map_char 'A' = 1
                     other = 1;
    run;
  %end;

 %*----------------------------------------------------------------------------------------------*
  | Create a macro variable for each variable listed in the TXT parameter to say whether it is   |
  | a Compute Blank Row (CBR) variable, as defined by the vars in the TXT_SPACER_LINE parameter. |
  | Also identify the variable listed in the TXT parameter that is the first variable listed in  |
  | the txt_spacer_line parameter.                                                               |
  *----------------------------------------------------------------------------------------------*;
  %do i=1 %to &num_txt_vars.;
    %let is_cbr_var = 0;
    %let first_var_in_txt_spacer_line = 0;
    %let txt_token = %sysfunc(scan(%bquote(&txt.), &i., %bquote( )));

    %do j=1 %to &num_txt_spacer_line_vars.;
      %if %bquote(&txt_token.) eq %sysfunc(scan(%bquote(&txt_spacer_line.), &j., %bquote( ))) %then %do;
        %let is_cbr_var = 1;
        %if &j. eq 1 %then %let first_var_in_txt_spacer_line = 1;
      %end;
    %end;

    %let txt&i._is_cbr_var = &is_cbr_var.;
    %let txt&i._is_first_cbr_var = &first_var_in_txt_spacer_line.;
  %end;

 %*------------------------------------------------------------------------------------------------------------*
  | For each text variable supplied in the TXT parameter list:                                                 |
  | - Store each text variable name and corresponding report table column width as macro variables.            |
  | - Identify whether the text variable is to be presented as a grouped variable in the Proc REPORT step.     |
  | - Identify whether the text variable is to be used to compute an extra blank line in the Proc REPORT step. |
  | - Get the length of the current text variable being assessed.                                              |
  *------------------------------------------------------------------------------------------------------------*;
  %do i=1 %to &num_txt_vars.;

    %** Store each text variable name and corresponding report table column width as macro variables. **;
    %let txt&i.           = %sysfunc(scan(%bquote(&txt.),           &i., %bquote( )));
    %let txt&i._col_width = %sysfunc(scan(%bquote(&txt_col_width.), &i., %bquote( )));

    %** Identify whether the text variable is to be presented as a grouped variable in the Proc REPORT step. **;
    %let txt&i._grouped_in_report = 0;
    %do j=1 %to &num_txt_grouped.;
      %if %bquote(&&txt&i.) eq %sysfunc(scan(%bquote(&txt_grouped.), &j., %bquote( ))) %then %let txt&i._grouped_in_report = 1;
    %end;

    %** Identify whether the text variable is to be used to compute an extra blank line in the Proc REPORT step. **;
    %let txt&i._compute_blank_row = 0;
    %do j=1 %to &num_txt_spacer_line_vars.;
      %if %bquote(&&txt&i.) eq %sysfunc(scan(%bquote(&txt_spacer_line.), &j., %bquote( ))) %then %let txt&i._compute_blank_row = 1;
    %end;

    %** Get the length of the current TXT parameter variable being assessed. **;
    %* 1. Identify the type of the TXT variable and store as a macro variable. *;
    data _null_;
      obs = 1;
      set &dataset_in. point=obs;
      type = vtype(&&txt&i.);
      call symputx("txt&i._var_type", type);
      stop;
    run;

    %* 2. Identify the length of the TXT variable and store as a macro variable. *;
    data _null_;
      set &dataset_in.;
      length txt&i._length 8;
      if (_n_ eq 1) then do;
        %if "&&txt&i._var_type." eq "C" %then %do;
          txt&i._length = lengthc(&&txt&i.);  ** Character type variable. **;
        %end;
        %else %do;
          txt&i._length = 12;                 ** Numeric type variable. **;
        %end;
        call symputx("txt&i._length", txt&i._length);
      end;
    run;

  %end;

  %** Write the values of the macro variables set above to the log for review. **;
  %do i=1 %to &num_txt_vars.;
    %put txt&i.=&&txt&i.;
    %put >>> txt&i._col_width=&&txt&i._col_width;
    %put >>> txt&i._grouped_in_report=&&txt&i._grouped_in_report;
    %put >>> txt&i._compute_blank_row=&&txt&i._compute_blank_row;
    %put >>> txt&i._var_type=&&txt&i._var_type.;
    %put >>> txt&i._length=&&txt&i._length.;
  %end;

 %*-------------------------------------------------------------------------------------------------*
  | In the main DATA step below, it is assumed that each variable in the TXT parameter list will be |
  | a character type variable.                                                                      |
  | If the variable in the TXT parameter list is a numeric type variable, then create an equivalent |
  | character variable contining the character representation of the numeric variable value.        |
  | Update the macro variable holding the name of the input TXT parameter variable for the current  |
  | position in that list to hold the name of the equivalent character variable.                    |
  | This should avoid automatic numeric to character conversion.                                    |
  *-------------------------------------------------------------------------------------------------*;
  data _x_&dataset_in._1;
    set &dataset_in.;
    %do i=1 %to &num_txt_vars.;
      %if "&&txt&i._var_type." eq "N" %then %do;
        length _&&txt&i.._c $12;
        _&&txt&i.._c = strip(left(put(&&txt&i., best.)));
        call symputx("txt&i.", "_&&txt&i.._c");
      %end;
    %end;
  run;

  %do i=1 %to &num_txt_vars.;
    %put C_TEXT_VARS: txt&i.=&&txt&i.;
  %end;

 %*-------------------------------------------------------------------------------*
  | Get the maximum length found across the set of text variables being assessed. |
  | This will be the upper length limit of all line and word substring variables. |
  *-------------------------------------------------------------------------------*;
  %let max_txt_length = 0;
  %do i=1 %to &num_txt_vars.;
    %if &&txt&i._length. gt &max_txt_length. %then %let max_txt_length = &&txt&i._length.;
  %end;
  %put max_txt_length=&max_txt_length.;


 %*=================================================================================*
  | Calculate the number of text lines that the current variable will occupy in its |
  | corresponding report table column.                                              |
  *=================================================================================*;
  data _x_page (keep=&dsin_vars.
                     max_line_count  max_line_count_txt_grouped  num_standard_height_rows  num_standard_height_rows_gp
                     line_count_:  assess_line_wrap:);
    set _x_&dataset_in._1;

    length txt_len line_start line_end delimiter_length found_last_newline 8 
           word_num found_last_word word_break_pos word_length line_length line_count 8
           max_line_count max_line_count_txt_grouped num_standard_height_rows num_standard_height_rows_gp 8
           line word $ &max_txt_length.;

    delimiter_length = length("&newline.");

    %if (&debug_mode. eq 1) %then %do;
      put "NOTE: ========== Start of processing of observation " _n_ " ==========";
    %end;

   %*---------------------------------------------------------------------*
    | Loop through each text variable supplied in the TXT parameter list. |
    *---------------------------------------------------------------------*;
    %do i=1 %to &num_txt_vars.;

      %if (&debug_mode. eq 1) %then %do;
        put "NOTE: -------- Start of processing of var &&txt&i.. ---------";
      %end;

      line_count = 0;

     %*---------------------------------------------------------------------------------------*
      | If this text variable is to be grouped in the Proc REPORT step we only want to assess |
      | line wrapping for the first unique value in each group of observations as all         |
      | subsequent observations in the group will show blank cells, so will only require 1    |
      | row of text in row height.                                                            |
      | Get the value of this variable in the previous observation to identify the first in   |
      | each group without relying on BY group processing, as this would require resorting    |
      | of the dataset.                                                                       |
      *---------------------------------------------------------------------------------------*;
      %if &&txt&i._grouped_in_report eq 1 %then %do;
        if _n_ eq 1 then first_&&txt&i. = 1;
        else do;
          prev_obs = _n_ - 1;
          set _x_&dataset_in._1 (keep=&&txt&i. rename=(&&txt&i.=prev_&&txt&i.)) point=prev_obs;
          if &&txt&i. ne prev_&&txt&i. then first_&&txt&i. = 1;
          else first_&&txt&i. = 0;
        end;
      %end;

     %*-------------------------------------------------------------------------------------*
      | As previous code block, but for vars listed in the TXT_SPACER_LINE parameter, again |
      | avoiding BY group processing.                                                       |
      *-------------------------------------------------------------------------------------*;
      %if &&txt&i._compute_blank_row eq 1 %then %do;
        if _n_ eq 1 then first_cbr_&&txt&i. = 1; ** CBR = compute blank row. **;
        else do;
          prev_obs = _n_ - 1;
          set _x_&dataset_in._1 (keep=&&txt&i. rename=(&&txt&i.=prev_&&txt&i.)) point=prev_obs;
          if &&txt&i. ne prev_&&txt&i. then first_cbr_&&txt&i. = 1;
          else first_cbr_&&txt&i. = 0;
        end;
      %end;

     %*-----------------------------------------------------------------------------------*
      | A flag variable to determine whether to use the calculated line-wrapping-based    |
      | line count in row height assessment for this report variable, or to use a value   |
      | of 1, indicating cells that are likely to be blank in the report when Proc REPORT |
      | grouping is in use for this report variable.                                      |
      | Used to derive the MAX_LINE_COUNT_TXT_GROUPED variable.                           |
      *-----------------------------------------------------------------------------------*;
      assess_line_wrap = 1;
      %** Avoiding creation of unnecessary FIRST_TXTn variables by only including the condition testing FIRST_TXTn if the text variable is to be grouped in the report. **;
      %if &&txt&i._grouped_in_report eq 1 %then %do;
        if &&txt&i._grouped_in_report eq 1 and first_&&txt&i. eq 0 then do;
          assess_line_wrap = 0;
        end;
      %end;

      assess_line_wrap_&&txt&i. = assess_line_wrap; ** ###### TESTING ONLY ###### **;


     %*======================================================*
      | Split the text by the new-line delimiter into lines. |
      *======================================================*;
      line_start = 1;
      found_last_newline = 0;

     %*------------------------------------------------------------------*
      | Trim off any trailing new-line delimiters as these do not result |
      | in a new line being shown in the RTF output document.            |
      *------------------------------------------------------------------*;
      txt_len = length(&&txt&i.);
      %if (&debug_mode. eq 1) %then %do;
        put &&txt&i.=;
        put delimiter_length= txt_len=;
      %end;
      
      if (txt_len ge delimiter_length) then do;
        if (substr(&&txt&i., ((txt_len - delimiter_length) + 1)) eq "&newline.") then do;
          &&txt&i. = substr(&&txt&i., 1, (txt_len - delimiter_length));
          %if (&debug_mode. eq 1) %then %do;
            put 'Trimmed trailing newline delimiter.';
            put &&txt&i.=;
          %end;
        end;
      end;

     %*---------------------------------------------------------------------------------*
      | Handle text values that only contain blanks or newline delimiters.              |
      | Line count should be 1 as a minimum as the row will still need to be presented. |
      *---------------------------------------------------------------------------------*;
      if (compress(tranwrd(&&txt&i., "&newline.", ' ')) eq ' ') then do;
        found_last_newline = 1;
        line_count = 1;
      end;

     %*-------------------------------------------------------------------------------*
      | Iterate loop for each newline-delimited line within the current TXT variable. |
      *-------------------------------------------------------------------------------*;
      do while (not found_last_newline);
        %** Extract one newline-delimited line substring from the text variable. **;
        line_end = find(&&txt&i., "&newline.", line_start, 't');
        if (line_end eq 0) then do;
          line = substr(&&txt&i., line_start);
          found_last_newline = 1;
        end;
        else do;
          line = substr(&&txt&i., line_start, (line_end - line_start));
        end;
        %if (&debug_mode. eq 1) %then %do;
          put line_start= line_end= line=;
        %end;
        %** Increment line counter for each newline string found. **;
        line_count + 1;

       %*==================================================================*
        | Calculate the length of the current newline-delimited text line. |
        *==================================================================*;
       %*----------------------------------------------------------------------------------*
        | Monospaced font: line length is a count of the number of characters in the line. |
        *----------------------------------------------------------------------------------*;
        if (&monospaced_font. eq 1) then do;
          full_line_length = length(line);
        end;
       %*---------------------------------------------------------------------------------------------------*
        | Non-monospaced font: line length is the sum of the widths of the characters in the line.          |
        | This is measured in Standard Character Width units, where the Standard Character is a Pipe (|).   |
        | NOTE: Requires the map_char format to already be set up and loaded from a study-specific library. |
        *---------------------------------------------------------------------------------------------------*;
        else do;
          full_line_length = 0;
          do i=1 to length(line);
            char_width = input(strip(substr(line, i, 1)), map_char.);
            full_line_length + char_width;
          end;
        end;

       %*======================================================================================*
        | Split each line into words. Add the length of each word onto the total line length.  |
        | If the total line length exceeds the column width limit, increment the line counter. |
        *======================================================================================*;
        word_num = 1;
        line_length = 0; %** Length increases as length of component words is added. Used to identify when line width limit is reached. **;
        found_last_word = 0;

       %*---------------------------------------------------------------------------------*
        | Iterate for each word found.                                                    |
        | NOTE: Only using space and comma characters as word delimiters currently.       |
        | NOTE: The (word_num le length(line)) part is there to prevent infinite looping. |
        |       Should not be needed, but defensive coding.                               |
        *---------------------------------------------------------------------------------*;
        do while ((not found_last_word) and (word_num le length(line)));
          word = scan(line, word_num, ' ,');
          if (word eq ' ') then do;
            found_last_word = 1;
          end;
          else do;
           %*===========================================*
            | Calculate the length of the current word. |
            *===========================================*;
            if (&monospaced_font. eq 1) then do;
             %*----------------------------------------------------------------------------------*
              | Monospaced font: word length is a count of the number of characters in the word. |
              *----------------------------------------------------------------------------------*;
              word_length = length(word);
            end;
            else do;
             %*---------------------------------------------------------------------------------------------------*
              | Non-monospaced font: word length is the sum of the widths of the characters in the word.          |
              | This is measured in Standard Character Width units, where the Standard Character is a Pipe (|).   |
              | NOTE: Requires the map_char format to already be set up and loaded from a study-specific library. |
              *---------------------------------------------------------------------------------------------------*;
              word_length = 0;
              do i=1 to length(word);
                char_width = input(strip(substr(word, i, 1)), map_char.);
                word_length + char_width;
              end;
            end;

           %*======================================================================*
            | Add length of the current word onto a building line length variable. |
            *======================================================================*;
           %*-------------------------------------------------------------------------------------------*
            | Current word can be accommodated within the current line within its report output column. |
            *-------------------------------------------------------------------------------------------*;
            if ((line_length + word_length) le &&txt&i._col_width.) then do;
              line_length + word_length + &space_char_width.;
            end;
           %*---------------------------------------------------------------------------------*
            | Current word is longer than the column width limit so need to break the word up |
            | to wrap across multiple lines whenever the column width limit is reached.       |
            *---------------------------------------------------------------------------------*;
            else if (word_length gt &&txt&i._col_width.) then do;
             %*-------------------------------------------------------------------------------------*
              | Determine where to break the word and wrap to a new line.                           |
              |-------------------------------------------------------------------------------------|
              | If MONOSPACED font is in use, the position to break to a new line is determined by  |
              | the number of monospaced characters that can fit into that column on a single line. |
              | This will be consistent regardless of the characters encountered so this step can   |
              | sit outside the word-breaking loop.                                                 |
              *-------------------------------------------------------------------------------------*;
              if (&monospaced_font. eq 1) then do;
                word_break_pos = &&txt&i._col_width.;
              end;

             %*--------------------------------------------------------------------*
              | Loop iterates for each line wrap required to accommodate the word. |
              *--------------------------------------------------------------------*;
              do while (word_length gt &&txt&i._col_width.);
               %*----------------------------------------------------------------------------------------*
                | Determine where to break the word and wrap to a new line.                              |
                |----------------------------------------------------------------------------------------|
                | If NON-MONOSPACED font is in use, the point at which to break the word onto a new line |
                | will depend on the widths of the characters at the start of each new line, so need to  |
                | assess that within this loop.                                                          |
                *----------------------------------------------------------------------------------------*;
                if (&monospaced_font. eq 0) then do;
                  word_ss_length = 0;
                  do i=1 to length(word);
                    char_width = input(strip(substr(word, i, 1)), map_char.);
                    word_ss_length + char_width;
                    if (word_ss_length gt &&txt&i._col_width.) then do;
                      word_break_pos = (i - 1);
                      i = length(word) + 1; %** Stop the loop. **;
                    end;
                  end; %** End of loop processing each character in the current word. **;
                end;

                word_ss = substr(word, 1, word_break_pos); %** Just used for writing to the log for testing. **;
                line_count + 1;
                word = substr(word, (word_break_pos + 1));
               %*-------------------------------------------------------------------------------------------------------*
                | Calculate the length of the current word, ready for the next loop iteration if required.              |
                |-------------------------------------------------------------------------------------------------------|
                | - Monospaced font: word length is a count of the number of characters in the word.                    |
                | - Non-monospaced font: word length is the sum of the widths of the characters in the word.            |
                |   This is measured in Standard Character Width units, where the Standard Character is a Pipe (|).     |
                |   NOTE: Requires the map_char informat to already be set up and loaded from a study-specific library. |
                *-------------------------------------------------------------------------------------------------------*;
                if (&monospaced_font. eq 1) then do;
                  word_length = length(word);
                end;
                else do;
                  word_length = 0;
                  do i=1 to length(word);
                    char_width = input(strip(substr(word, i, 1)), map_char.);
                    word_length + char_width;
                  end;
                end;
                %if (&debug_mode. eq 1) %then %do;
                  put word_ss= word_length= line_length= line_count=;
                %end;
              end; %** End of the DO WHILE loop handling the wrapping of a single word that is wider than the column width. **;
            end; %** End of the ELSE IF block handling cases where word length is greater than the column width. **;
           %*--------------------------------------------------------------------*
            | Current word takes overall line length over the column width limit |
            | so line will wrap at the start of this word.                       |
            *--------------------------------------------------------------------*;
            else do;
              line_count + 1;
              line_length = word_length + &space_char_width.;
            end;
            %if (&debug_mode. eq 1) %then %do;
              put word= word_length= line_length= line_count=;
            %end;
          end; %** End of Else block (section processing one word where the value of WORD is not missing). **;
          word_num + 1;
        end; %** End of loop processing each word in the current line. **;

       %*---------------------------------------------------------------------------------*
        | Find the starting position from which to search for the next newline-delimiter. |
        *---------------------------------------------------------------------------------*;
        line_start = line_end + delimiter_length;
      end; %** End of loop processing newline-delimited lines. **;

     %*------------------------------------------------------------------------------------------*
      | Show line count for each input text variable in the output dataset (only in debug mode). |
      *------------------------------------------------------------------------------------------*;
      %if (&debug_mode. eq 1) %then %do;
        &&txt&i.._line_count = line_count;
      %end;

     %*----------------------------------------------------------------------------*
      | Only keep variables associated with processing the variables listed in the |
      | GROUP_ON_PAGE_VARS parameter if debug mode is on.                          |
      *----------------------------------------------------------------------------*;
      %if ((&&txt&i._grouped_in_report eq 1) and (&debug_mode. eq 0)) %then %do;
        drop first_&&txt&i. prev_&&txt&i.;
      %end;

     %*-----------------------------------------------------------------------------------*
      | Find the maximum number of lines required across the text variables assessed.     |
      | This will differ depending on whether or not line-wrapping variables are to be    |
      | grouped in the Proc REPORT step. Therefore, creating two variables to calculate   |
      | max lines required when no grouping is in use, and when grouping is in use.       |
      | These will both be used by the GET_PAGE_BREAK_VAR macro, as we need to know       |
      | when the page breaks are to know when such grouped variable values are displayed, |
      | and therefore to know how much vertical space is required.                        |
      *-----------------------------------------------------------------------------------*;
      if (line_count > max_line_count) then max_line_count = line_count;

      if (assess_line_wrap eq 1) then do;
        ** Using line-wrapping-calculated line count. **;
        if (line_count > max_line_count_txt_grouped) then max_line_count_txt_grouped = line_count;
      end;
      else do;
        ** Using line count of 1 (even if text wraps) as text will not be displayed in this row of the report table. **;
        if max_line_count_txt_grouped gt 1 or max_line_count_txt_grouped = . then max_line_count_txt_grouped = 1;
      end;

      %** Showing line count for each TXT variable in the _X_PAGE dataset just for testing purposes. **;
      line_count_&&txt&i. = line_count;

    %end; %** End of loop that assesses each requested TXT variable. **;

   %*------------------------------------------------------------------------*
    | Calculate the number of <<Standard height>> rows that this observation |
    | will require in the output report. (No rounding at this stage.)        |
    | Again, two versions of this variable depending on whether or not       |
    | Proc REPORT grouping will be applied to this report variable.          |
    *------------------------------------------------------------------------*;
    %if &txt_spacer_line. ne %str() %then %do;
      ** Each new value of one of the TXT_SPACER_LINE variables will trigger the addition of a padding row to separate groups of rows. **;
      ** UPDATED - ADD 1, NO DIFFERENCE - Add 1.1 to the max line count variables to take account of the space taken up by the padding row. **;
      ** UPDATED - ADD 1, NO DIFFERENCE - Using 1.1 as padding rows seem to be slightly taller than normal rows. **;
      if 
        %do i=1 %to &num_txt_vars.;
          %if &&txt&i._is_cbr_var. eq 1 %then %do;
            %if &&txt&i._is_first_cbr_var. ne 1 %then %do;
              or
            %end;
            first_cbr_&&txt&i..
          %end;
        %end;
      then do;
        max_line_count = max_line_count + 1.1;
        max_line_count_txt_grouped = max_line_count_txt_grouped + 1.1;
      end;
    %end;

    num_standard_height_rows = max_line_count / &standard_row_num_lines.;
    num_standard_height_rows_gp = max_line_count_txt_grouped / &standard_row_num_lines.;

    %if &txt_spacer_line. ne %str() %then %do;
      drop first_: prev_: _:;
    %end;

  run;


 %*=======================================*
  | ##########  PAGE BREAKING  ########## |
  *=======================================*;
 %*-----------------------------------------------------------------------------------*
  | Store each PAGE_BY_VAR variable as a macro variable named: page_by_var<<i>>,      |
  | where <<i>> is the position in the list.                                          |
  *-----------------------------------------------------------------------------------*;
  %do i=1 %to &num_page_by_vars.;
    %let page_by_var&i. = %sysfunc(scan(%bquote(&page_by_vars.), &i., %bquote( )));
    %put page_by_var&i.=&&page_by_var&i.;
  %end;

 %*------------------------------------------------------------------------------------------*
  | Store each GROUP_ON_PAGE_VAR variable as a macro variable named: group_on_page_var<<i>>, |
  | where <<i>> is the position in the list.                                                 |
  *------------------------------------------------------------------------------------------*;
  %do i=1 %to &num_group_on_page_vars.;
    %let group_on_page_var&i. = %sysfunc(scan(%bquote(&group_on_page_vars.), &i., %bquote( )));
    %put group_on_page_var&i.=&&group_on_page_var&i.;
  %end;

 %*-------------------------------------------------------------------------------*
  | Keep track of the name of the Main dataset.                                   |
  | Initially, this is the dataset name provided via the DATASET_IN parameter.    |
  | Subsequently, this may change as each GROUP_ON_PAGE_VARS variable is assessed |
  | for the number of Standard-Height rows required to accommodate that group of  |
  | observations, then that info is merged back into a new Main dataset.          |
  *-------------------------------------------------------------------------------*;
  %let MAIN_DS=_x_page;
  %put main_ds=&main_ds.;

 %*---------------------------------------------------------------------------------------------------*
  | For each variable specified in the GROUP_ON_PAGE_VARS parameter:                                  |
  | - Create a macro variable to hold all the GROUP_ON_PAGE_VAR variables encountered so far.         |
  |   This allows for correct listing of variables on the BY statement and therefore correct merging. |
  | - Calculate the number of Standard Height rows that are required to accommodate all of the        |
  |   observations with the same GROUP_ON_PAGE_VARS variable value in that group of equal-value       |
  |   observations.                                                                                   |
  | - Store in a dataset containing one observation per set of equal values in the pre-sorted input   |
  |   dataset. Variable name to hold this value is: n_rows_per_<<GROUP_ON_PAGE_VAR>>.                 |
  | - Merge the n_rows_per_<<GROUP_ON_PAGE_VAR>> back into the MAIN_DS dataset.                       |
  *---------------------------------------------------------------------------------------------------*;
  %do i=1 %to &num_group_on_page_vars.;

    %** Construct list of GROUP_ON_PAGE_VAR variables to use in BY lines. **; 
    %if (&i. eq 1) %then %let GROUP_VARS_SO_FAR=&&group_on_page_var&i.;
    %else                %let GROUP_VARS_SO_FAR=&group_vars_so_far. &&group_on_page_var&i.;

    %** Dataset to hold the number of Standard Height rows required to accommodate each group of observations in the current GROUP_ON_PAGE_VAR variable. **;
    data _x_n_rows_per_group_&&group_on_page_var&i. (keep=&page_by_vars. &group_vars_so_far. n_rows_for_&&group_on_page_var&i.);
      set _x_page;
      by &page_by_vars. &group_vars_so_far.;
      length n_rows_for_&&group_on_page_var&i. 8;

      %** Accumulate the number of Standard-Height table rows required to accommodate all observations in the current GROUP_ON_PAGE_VAR group. **;
      n_rows_for_&&group_on_page_var&i. + num_standard_height_rows_gp;

      %** When the last obs for the current GROUP_ON_PAGE_VAR value is reached, output the total. **;
      if last.&&group_on_page_var&i. then do;
        output;
        n_rows_for_&&group_on_page_var&i. = 0;
      end;
    run;

    %** Preserve the name of the previous Main dataset (input to merge), and update the name of the new Main dataset (output from merge). **;
    %let PREVIOUS_MAIN_DS=&main_ds.;
    %let MAIN_DS=_x_page_&i.;
    %put previous_main_ds=&previous_main_ds.  main_ds=&main_ds.;

    %** Merge the count back in to the report dataset. **;
    data &main_ds.;
      merge &previous_main_ds. (in=a) _x_n_rows_per_group_&&group_on_page_var&i. (in=b);
      by &page_by_vars. &group_vars_so_far.;
      if a;
    run;
  
  %end;

 %*------------------------------------------------------------------------------------------*
  | Derive a page-breaking variable called PAGE, using the NUM_STANDARD_HEIGHT_ROWS variable |
  | values calculated above.                                                                 |
  |                                                                                          |
  | Page will break when:                                                                    |
  | - Any new value is seen within the PAGE_BY_VAR variables.                                |
  | - A group of observations with equal GROUP_ON_PAGE_VAR variable values cannot fully fit  |
  |   onto the remaining space on the current page.                                          |
  | - Current observation would take the total number of Standard Height Rows over the       |
  |   max-standard-height-rows-per-page limit. E.g. If there are more observations in the    |
  |   current GROUP_ON_PAGE_VAR group than could fit onto a single page.                     |
  *------------------------------------------------------------------------------------------*;
  data _x_&dataset_out._pre_1;
    set &main_ds.;

    %if ((&num_page_by_vars. gt 0) or (&num_group_on_page_vars. gt 0)) %then %do;
      by &page_by_vars. &group_on_page_vars.;
    %end;

    attrib page      length=8 label='Page-breaking variable'
           row_on_pg length=8 label='Row number on the current page';

    if (_n_ eq 1) then do;
      page = 0;
      row_on_pg = 0;
    end;

    %do i=1 %to &num_group_on_page_vars.;
      if first.&&group_on_page_var&i. then do;
        row_on_pg_plus_gp_&&group_on_page_var&i. = row_on_pg + n_rows_for_&&group_on_page_var&i.;
      end;
    %end;

    row_on_pg + num_standard_height_rows_gp; ** Row on the page after the current observation has been added. **;

    if
      %do i=1 %to &num_page_by_vars.;
        first.&&page_by_var&i. or
      %end;
      %do i=1 %to &num_group_on_page_vars.;
        (first.&&group_on_page_var&i. and (row_on_pg_plus_gp_&&group_on_page_var&i. gt &max_rows_per_page.)) or
      %end;
        (row_on_pg gt &max_rows_per_page.) then do;
      page + 1;
      row_on_pg = num_standard_height_rows_gp;
    end;
  run;

  %** If PAGE values start at 0, update PAGE to start from 1. **;
  data _x_&dataset_out._pre_2 (drop=first_page);
    length first_page 8;
    retain first_page;
    set _x_&dataset_out._pre_1;

    if _n_ eq 1 then first_page = page;

    if first_page eq 0 then page = page + 1;
  run;

 %*----------*
  | Clean up |
  *----------*;
  %** Keep only the variables found in the DATASET_IN dataset and the newly-created PAGE variable. **;
  data &dataset_out.;
    set _x_&dataset_out._pre_2 (keep=&dsin_vars. page);
  run;

  %** Get maximum number of pages in data. **;
  %global numpages;
  proc sql noprint;
    select distinct max(page)
    into :numpages trimmed
    from &dataset_out.;
  quit;

  %** Delete temporary datasets created by this macro programme (dataset names with _x_ prefix). **;
  %if &debug_mode. eq 0 %then %do;
    %let tmp_ds_tag = _X_;
    proc sql noprint;
      select distinct memname 
      into :ds_to_delete separated by ' '
      from sashelp.vcolumn
      where libname eq 'WORK' and
            memname like "&tmp_ds_tag.%";
    quit;
    %put ds_to_delete=&ds_to_delete.;

    proc delete data=&ds_to_delete;
    run;
  %end;

 %*-------------------------------------------------------------------------*
  | If any parameter checks fail, code branches (junps) to this EXIT label. |
  *-------------------------------------------------------------------------*;
  %exit:

%mend p_mcrAddPageVar;
