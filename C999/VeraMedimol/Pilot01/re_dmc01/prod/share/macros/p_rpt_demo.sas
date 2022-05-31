/*****************************************************************************\
*        O                                                                     
*       /                                                                      
*  O---O     _  _ _  _ _  _  _|                                                
*       \ \/(/_| (_|| | |(/_(_|                                                
*        O                                                                     
* ____________________________________________________________________________
* Sponsor              : 
* Study                : 
* Analysis             : 
* Program              : p_rpt_demo.sas
* ____________________________________________________________________________
* DESCRIPTION
* Demonstration of macro used to create standard proc report 
*                                                                   
* Input files:                                                   
*                                                                   
* Output files:                                                   
*                                                                
* Macros: p_rpt                                                         
*                                                                   
* Assumptions:                                              
*                                                                   
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  2022-03-30  | Emily Gutleb     | Original                                    
* ----------------------------------------------------------------------------
*  YYYYMMDD  |  username        | ..description of change..         
\*****************************************************************************/


*********;
%init ;
*********;


ods escapechar = "^";


/*************************************************************/
/********* 1:Basic use                                       */
/*************************************************************/
**Make a simple report using a "long" structured dataset;

**create the data;
data demo1;
    infile datalines truncover;
    row = _n_;
    input rowlabel $200.;
    length trtp    $1
           str1 $40;
    trtp='A'; num1 =   01*_n_; num2 =num1/021; str1 =put(num1,3.)||'    '||put(num2,percentn6.); output;
    trtp='B'; num1 =10+14*_n_; num2 =num1/225; str1 =put(num1,3.)||'    '||put(num2,percentn6.); output;
    trtp='C'; num1 =90-15*_n_; num2 =num1/354; str1 =put(num1,3.)||'    '||put(num2,percentn6.); output;
    format num2 percentn6.;
    datalines;
        First row
        Second row
        Third row
        Fourth row
        Fifth row
        Sixth row
        ;
run;

** Call p_rpt to create a simple report;

ods listing close;
ods pdf file="%sysfunc(pathname(work,L))/p_rpt_Demo01.pdf";

*-Report with CellTxt as cell contents (default);
title '1.a: Simple use of p_rpt';
%p_rpt( inds = demo1
       , avar      = trtp
       , resultvar = str1 num1 num2
       , colwidths = 1in+0.5in+0.5in
       , rowlabelwidth = 1in
       )

*-Report with FnP as cell contents;
title '1.b: Simple use of p_rpt only displaying str1 as cell contents';
%p_rpt( inds = demo1
       , avar      = trtp
       , resultvar = str1
       , colwidths = 1in
       , rowlabelwidth = 1in
       )
title;
ods pdf close;
ods listing;



/*************************************************************/
/********* 2:Row Formating                                   */
/*************************************************************/
**Make a simple report using a "long" structured dataset with formated rows;

**create the data;
data demo2;

    Row = _N_;
    infile datalines TruncOver;
    input rowopt $13. rowlabel $200.;
    TRTP='A'; str1='####';
    datalines;
        0+0+0 No indent, not bold, no top border
        0+1+0 No indent, bold, no top border
        1+0+0 Indent 1, not bold, no top border
        1+1+0 Indent 1,     bold, no top border
        2+0+0 Indent 2, not bold, no top border
        0+1+0 No indent, bold, no top border
        1+0+0 Indent 1, not bold, no top border
        1+0+0 Indent 1, not bold, no top border
        2+0+0 Indent 2, not bold, no top border
        2+0+0 Indent 2, not bold, no top border
        ;
run;


** Call p_rpt to create a simple report;
ods listing close;
ods pdf file="%sysfunc(pathname(work,L))/p_rpt_Demo02.pdf";

title '2: Row formatting';
%p_rpt( inds = demo2
       , avar      = trtp
       , resultvar = str1
       , colwidths = 2in
       , rowlabelwidth = 5in
       ,tidyup = 0
       ,outds = test2
       )
title;
ods pdf close;
ods listing;


/*************************************************************/
/********* 3:Sections and Panels                             */
/*************************************************************/

data demo3;
    infile datalines DSD FirstObs=2 MissOver;
    input Section   SectionLabel:$40. Panel    Panelopt:$2.   PanelLabel:$40.            Row    RowLabel:$80.                                                         Rowopt:$2.    Page;
    TRTP='A'; str1='####';
    datalines;
        'Section', 'SectionLabel',   'Panel', 'PanelOpt'      , 'PanelLabel'           ,   'Row', 'RowLabel'                                                          , 'RowOpt', 'Page'
         1       , 'Section 1   ',    1     ,  '1'            , 'Section 1, Panel 1   ',    1   , 'Section 1 (  Label), Panel 1 (  Label, indent 1), Row 1 (indent 0)', '0'     , 1
         1       , 'Section 1   ',    1     ,  '1'            , 'Section 1, Panel 1   ',    2   , 'Section 1 (  Label), Panel 1 (  Label, indent 1), Row 2 (indent 0)', '0'     , 1
         1       , 'Section 1   ',    1     ,  '1'            , 'Section 1, Panel 1   ',    3   , 'Section 1 (  Label), Panel 1 (  Label, indent 1), Row 3 (indent 0)', '0'     , 1
         1       , 'Section 1   ',    2     ,  '2'            , '                     ',    1   , 'Section 1 (  Label), Panel 2 (NoLabel, indent 2), Row 1 (indent 0)', '0'     , 1
         1       , 'Section 1   ',    2     ,  '2'            , '                     ',    2   , 'Section 1 (  Label), Panel 2 (NoLabel, indent 2), Row 2 (indent 1)', '1'     , 1
         1       , 'Section 1   ',    2     ,  '2'            , '                     ',    3   , 'Section 1 (  Label), Panel 2 (NoLabel, indent 2), Row 3 (indent 2)', '2'     , 1
         2       , 'Section 2   ',    1     ,  '1'            , 'Section 2, Panel 1   ',    1   , 'Section 2 (  Label), Panel 1 (  Label, indent 1), Row 1 (indent 1)', '1'     , 1
         2       , 'Section 2   ',    1     ,  '1'            , 'Section 2, Panel 1   ',    2   , 'Section 2 (  Label), Panel 1 (  Label, indent 1), Row 2 (indent 1)', '1'     , 1
         2       , 'Section 2   ',    2     ,  '1'            , 'Section 2, Panel 2   ',    1   , 'Section 2 (  Label), Panel 2 (  Label, indent 1), Row 1 (indent 1)', '1'     , 1
         2       , 'Section 2   ',    2     ,  '1'            , 'Section 2, Panel 2   ',    2   , 'Section 2 (  Label), Panel 2 (  Label, indent 1), Row 2 (indent 1)', '1'     , 1
         3       , '            ',    1     ,  '0'            , 'Section 3, Panel 1   ',    1   , 'Section 3 (NoLabel), Panel 1 (  Label, indent 0), Row 1 (indent 0)', '0'     , 1
         3       , '            ',    1     ,  '0'            , 'Section 3, Panel 1   ',    2   , 'Section 3 (NoLabel), Panel 1 (  Label, indent 0), Row 2 (indent 0)', '0'     , 1
         3       , '            ',    2     ,  '1'            , '                     ',    1   , 'Section 3 (NoLabel), Panel 2 (NoLabel, indent 1), Row 1 (indent 0)', '0'     , 1
         3       , '            ',    2     ,  '1'            , '                     ',    2   , 'Section 3 (NoLabel), Panel 2 (NoLabel, indent 1), Row 2 (indent 0)', '0'     , 1
         4       , 'Section 4   ',    1     ,  '1'            , 'Section 4, Panel 1   ',    1   , 'Section 4 (  Label), Panel 1 (  Label, indent 1), Row 1 (indent 1)', '1'     , 1
         4       , 'Section 4   ',    1     ,  '1'            , 'Section 4, Panel 1   ',    2   , 'Section 4 (  Label), Panel 1 (  Label, indent 1), Row 2 (indent 1)', '1'     , 1
         4       , 'Section 4   ',    1     ,  '1'            , 'Section 4, Panel 1   ',    3   , 'Section 4 (  Label), Panel 1 (  Label, indent 1), Row 3 (indent 1)', '1'     , 1
         4       , 'Section 4   ',    1     ,  '1'            , 'Section 4, Panel 1   ',    4   , 'Section 4 (  Label), Panel 1 (  Label, indent 1), Row 4 (indent 1)', '1'     , 1
         4       , 'Section 4   ',    1     ,  '1'            , 'Section 4, Panel 1   ',    5   , 'Section 4 (  Label), Panel 1 (  Label, indent 1), Row 5 (indent 1)', '1'     , 1
         4       , 'Section 4   ',    1     ,  '1'            , 'Section 4, Panel 1   ',    6   , 'Section 4 (  Label), Panel 1 (  Label, indent 1), Row 6 (indent 1)', '1'     , 1
         4       , 'Section 4   ',    1     ,  '1'            , 'Section 4, Panel 1   ',    7   , 'Section 4 (  Label), Panel 1 (  Label, indent 1), Row 7 (indent 1)', '1'     , 1
         4       , 'Section 4   ',    1     ,  '1'            , 'Section 4, Panel 1   ',    8   , 'Section 4 (  Label), Panel 1 (  Label, indent 1), Row 8 (indent 1)', '1'     , 1
         4       , 'Section 4   ',    1     ,  '1'            , 'Section 4, Panel 1   ',    9   , 'Section 4 (  Label), Panel 1 (  Label, indent 1), Row 9 (indent 1)', '1'     , 1
         4       , 'Section 4   ',    1     ,  '1'            , 'Section 4, Panel 1   ',    10  , 'Section 4 (  Label), Panel 1 (  Label, indent 1), Row 10(indent 1)', '1'     , 1
         4       , 'Section 4   ',    1     ,  '1'            , 'Section 4, Panel 1   ',    11  , 'Section 4 (  Label), Panel 1 (  Label, indent 1), Row 11(indent 1)', '1'     , 2
         4       , 'Section 4   ',    1     ,  '1'            , 'Section 4, Panel 1   ',    12  , 'Section 4 (  Label), Panel 1 (  Label, indent 1), Row 12(indent 1)', '1'     , 2
         4       , 'Section 4   ',    1     ,  '1'            , 'Section 4, Panel 1   ',    13  , 'Section 4 (  Label), Panel 1 (  Label, indent 1), Row 13(indent 1)', '1'     , 2
         4       , 'Section 4   ',    1     ,  '1'            , 'Section 4, Panel 1   ',    14  , 'Section 4 (  Label), Panel 1 (  Label, indent 1), Row 14(indent 1)', '1'     , 2
         4       , 'Section 4   ',    1     ,  '1'            , 'Section 4, Panel 1   ',    15  , 'Section 4 (  Label), Panel 1 (  Label, indent 1), Row 15(indent 1)', '1'     , 2
         4       , 'Section 4   ',    1     ,  '1'            , 'Section 4, Panel 1   ',    16  , 'Section 4 (  Label), Panel 1 (  Label, indent 1), Row 16(indent 1)', '1'     , 2
         4       , 'Section 4   ',    1     ,  '1'            , 'Section 4, Panel 1   ',    17  , 'Section 4 (  Label), Panel 1 (  Label, indent 1), Row 17(indent 1)', '1'     , 2
         4       , 'Section 4   ',    1     ,  '1'            , 'Section 4, Panel 1   ',    18  , 'Section 4 (  Label), Panel 1 (  Label, indent 1), Row 18(indent 1)', '1'     , 2
        ;    
run;


** Call p_rpt to create a report with sections and panels;
ods listing close;
ods pdf file="%sysfunc(pathname(work,L))/p_rpt_Demo03a.pdf";
title '3: Sections and Panels';
footnote1 'Note Row indentation is in addition to Panel indentation.';
footnote3 'Note that no section line is produced if no SectionLabel is given.';
%p_rpt( inds = demo3
       , avar      = trtp
       , resultvar = str1 
       , colwidths = 1in+1in
       , rowlabelwidth = 5in
       )
title;
ods pdf close;
ods listing;



** Call p_rpt to create a report where these is page break on sections, defined by sectionbreak = page;
ods listing close;
ods pdf file="%sysfunc(pathname(work,L))/p_rpt_Demo03b.pdf";
title '3: Sections and Panels: SectionBreak=Page';
footnote1 'Note Row indentation is in addition to Panel indentation.';
footnote3 'Note that no section line is produced if no SectionLabel is given.';
%p_rpt( inds = demo3
       , avar      = trtp
       , resultvar = str1 
       , colwidths = 1in+1in
       , rowlabelwidth = 4in
       , sectionbreak  = page
           )
title; footnote;
ods pdf close;
ods listing;

** Call p_rpt to create a report where these is page break through sections using FLWs variable;
ods listing close;
ods pdf file="%sysfunc(pathname(work,L))/p_rpt_Demo03c.pdf";
title '3: Sections and Panels: SectionBreak=Page';
footnote1 'Note Row indentation is in addition to Panel indentation.';
footnote3 'Note that no section line is produced if no SectionLabel is given.';
%p_rpt( inds = demo3
       , avar      = trtp
       , resultvar = str1
       , colwidths = 1in+1in
       , rowlabelwidth = 4in
       , FLWs  = %str(by page;)
           )
title; footnote;
ods pdf close;
ods listing;



/*************************************************************/
/********* 4:Column order and header formatting              */
/*************************************************************/

data demo4;
    Row = _N_;
    infile datalines TruncOver;
    input RowLabel $200.;
    length TRTP    $1
           str1 $40;
    TRTP='C'; num1=90-15*Row; num2=num1/354; str1=put(num1,3.)||'    '||put(num2,percentn6.); output;
    TRTP='A'; num1=   01*Row; num2=num1/021; str1=put(num1,3.)||'    '||put(num2,percentn6.); output;
    TRTP='B'; num1=10+14*Row; num2=num1/225; str1=put(num1,3.)||'    '||put(num2,percentn6.); output;
    TRTP=' '; num1=100      ; num2=num1/600; str1=put(num1,3.)||'    '||put(num2,percentn6.); output;
    format num2 percentn6.;
    datalines;
        First row
        Second row
        Third row
        Fourth row
        Fifth row
        Sixth row
        ;
run;

**4a: Basic report with unformatted column headers;
ods listing close;
ods pdf file="%sysfunc(pathname(work,L))/p_rpt_Demo4a.pdf";
title '4a: Report with unformatted column headers';
footnote1 'Here TRTP is unformatted and columns are in order TRTP appeared in reporting dataset.';
%p_rpt( inds = demo4
       , avar      = trtp
       , resultvar = str1 num1 num2
       , colwidths = 0.8in+0.3in+0.5in
       , rowlabelwidth = 0.8in
           );
title; footnote;
ods pdf close;
ods listing;


**4b: Order (and label) column headers via format;
proc format;
    value $TRTP2ArmsO_SASOrder
                     'A' = 'Arm One#(N=021)'
                     'B' = 'Arm Two#(N=225)'
                     'C' = 'Arm Three#(N=354)'
                     ' ' = 'Overall#(N=600)'
                         ;
run;

*-Applying format on the fly via FLWs parameter.                               ;
ods listing close;
ods pdf file="%sysfunc(pathname(work,L))/p_rpt_Demo4b.pdf";
title '4b: Report with formatted column headers, default AOrder';
footnote1 'Columns are in order TRTP values are stored in the format applied to TRTP.';
footnote2 'By default SAS stores formats ordered by the values';
footnote3 'Overall comes first because it corresponds to TRTP blank, which sorts before A B C.';
footnote4 '(Also note use of # as split character in column labels.)';

%p_rpt( inds = demo4
       , avar      = trtp
       , resultvar = str1 num1 num2
       , colwidths = 0.8in+0.3in+0.5in
       , rowlabelwidth = 0.8in
       , FLWs      = %str(format TRTP $TRTP2ArmsO_SASOrder.;)
           );
title; footnote;
ods pdf close;
ods listing;

**4c: Order columns by formatted values;
ods listing close;
ods pdf file="%sysfunc(pathname(work,L))/p_rpt_Demo4c.pdf";
title '04c: Report with formatted column headers, AOrder=formatted';
footnote1 'Columns are in order of formatted TRTP values.';
%p_rpt( inds = demo4
       , avar      = trtp
       , aOrder    = formatted
       , resultvar = str1 num1 num2
       , colwidths = 0.8in+0.3in+0.5in
       , rowlabelwidth = 0.8in
       , FLWs      = %str(format TRTP $TRTP2ArmsO_SASOrder.;)
           );
title; footnote;
ods pdf close;
ods listing;


**4d: Control order of columns via NotSorted forma;
proc format;
    value $TRTP2ArmsO (NotSorted)
                     'A' = 'Arm One#(N=021)'
                     'B' = 'Arm Two#(N=225)'
                     'C' = 'Arm Three#(N=354)'
                     ' ' = 'Overall#(N=600)'
                         ;
    run;

ods listing close;
ods pdf file="%sysfunc(pathname(work,L))/p_rpt_Demo4d.pdf";
title '04d: Report with formatted column headers, default AOrder, NotSorted format';
footnote1 'Columns are in order of entries in TRTP2ArmsO format applied to TRTP.';
%p_rpt( inds = demo4
       , avar      = trtp
       , resultvar = str1 num1 num2
       , colwidths = 0.8in+0.3in+0.5in
       , rowlabelwidth = 0.8in
       , FLWs      = %str(format TRTP $TRTP2ArmsO.;)
           );
title; footnote;
ods pdf close;
ods listing;

**4e: Using a RowLabel (and specifying a Avar format via the reporting dataset);
data demo4e;
    set demo4;
    label RowLabel='Row label (from dataset)';
    format TRTP $TRTP2ArmsO.;
run;

ods listing close;
ods pdf file="%sysfunc(pathname(work,L))/p_rpt_Demo4e.pdf";
title '4e: Report from reporting dataset with RowLabel labelled and &Avar formatted';

%p_rpt( inds = demo4e
       , avar      = trtp
       , resultvar = str1 num1 num2
       , colwidths = 0.8in+0.3in+0.5in
       , rowlabelwidth = 0.8in
           );
title; footnote;
ods pdf close;
ods listing;

*4f: Specifying a RowLabelHeader, RowLabelWidth, ColWidths and overriding dataset formats;
proc format;
    value $TRTP2LapTrasO (NotSorted)
                     'C' = 'lap+tras (Arm C)#(N=354)'
                     'A' = 'lap (Arm A)#(N=021)'
                     'B' = 'tras (Arm B)#(N=225)'
                     ' ' = 'Overall#(N=600)'
                         ;
    run;

ods listing close;
ods pdf file="%sysfunc(pathname(work,L))/p_rpt_Demo4f.pdf";
title '04e: Report from reporting dataset with RowLabel labelled and &Avar formatted';
footnote1 'Format of &Avar overridden by format statement in FLWs parameter.';         
%p_rpt( inds = demo4e
       , avar      = trtp
       , resultvar = str1 num1 num2
       , colwidths = 0.8in+0.3in+0.5in
       , rowlabelwidth = 0.8in
       , FLWs      = %str(format TRTP $TRTP2LapTrasO.;)
       , RowLabelHeader = Row label header (from parameter)
           );
title; footnote;
ods pdf close;
ods listing;

/*************************************************************/
/********* 5:Cell contents formatting                        */
/*************************************************************/

data demo5;
    infile datalines DSD FirstObs=2 MissOver;
    input Row    RowLabel:$80. TRTP $ num1;
    N= 1000;
    num2 = num1/N;
    format num1 Z4.0;
    format num2 percentn9.1;
    datalines;
        'Row', 'RowLabel'               , 'TRTP', 'num1'
         1   , 'Row 1 :    -1  ( -0.1%)', 'A'   ,    -1
         2   , 'Row 2 :     0  (  0  %)', 'A'   ,     0
         3   , 'Row 3 :     5  (  0.5%)', 'A'   ,     5
         4   , 'Row 4 :    10  (  1  %)', 'A'   ,    10
         5   , 'Row 5 :   500  ( 50  %)', 'A'   ,   500
         6   , 'Row 6 :   990  ( 99  %)', 'A'   ,   990
         7   , 'Row 7 :   995  ( 99.5%)', 'A'   ,   995
         8   , 'Row 8 :  1000  (100  %)', 'A'   ,  1000
         9   , 'Row 9 :  1001  (100.1%)', 'A'   ,  1001
        ;                                                                                     
run;

** Make some formats for display;
/********************************************************************************/
**These are from the common code library "fmtPercent.sas".                      ;
* See the demo file "fmtPercent_TestScript.sas" for more details and examples.  ;
**Formats to print proportions as percentages to 0d.p.,                         ;
* with "improper" proportions (not in [0,1]) displayed as <0% or >100%, &       ;
* trimming proportions in (0,0.01) as "<1%" and those in (0.99,1) as ">99%".    ;
/********************************************************************************/

proc format;
    picture Pct (round min=7 max=7)
               .         = ' '         (NoEdit)
      low      - < 0     = '(<0%)'     (NoEdit)
               0         = '     '      
      0     <  - < 0.01  = '(<1%)'     (NoEdit)
      0.01     -   0.99  = '0009%)'    (Mult=100 prefix='(')
      0.99  <  - < 1     = '(>99%)'    (NoEdit)
               1         = '(100%)'    (NoEdit)
      1      < -   high  = '(>100%)'   (NoEdit)
                         ;

run;

**Create report;
ods listing close;
ods pdf file="%sysfunc(pathname(work,L))/p_rpt_Demo5.pdf";
title '5: Report using formatting for cell contents';

%p_rpt( inds = demo5
       , avar      = trtp
       , resultvar = num1 num2
       , colwidths = 1in+1in
       , rowlabelwidth = 3in
      , FLWs      = %str(format num2 Pct.;)
           );
title; footnote;
ods pdf close;
ods listing;




/*************************************************************/
/********* 6: Shift Table and subgroup table                 */
/*************************************************************/

data demo6;
    test = "A"; str1 = "XXXX"; row = 1; rowlabel = "Row";

    subgroup = "M"; subgroupn  = 1; trtp = "A"; base = "0"; bign = 20;
    denom = 10;
    output;

    base = "1"; denom = 10;
    output;

    trtp = "B"; base = "0";bign = 30;
    denom = 5;
    output;

    base = "1"; denom = 25;
    output;

    subgroup = "F"; subgroupn  = 2; trtp = "A"; base = "0"; bign = 25;
    denom = 10;
    output;

    base = "1"; denom = 15;
    output;

    trtp = "B"; base = "0"; bign = 40;
    denom = 15;
    output;

    base = "1"; denom = 25;
    output;
run;

**create a simple shift table;
options nobyline;
ods listing close;
ods rtf file="%sysfunc(pathname(work,L))/p_rpt_demo06a.rtf";
title01 '6a: Shift table report';
title02 'by: #byval(subgroup)';

%p_rpt    (  inds       = demo6 
            ,avar       = %str(trtp, base)
           , colwidths = 1in
           , rowlabelwidth = 3in
           ,dest           = rtf
           ,resultvar     = str1
           ,flws      = %str(by subgroupn subgroup ;)
             );
          
title; footnote;
ods rtf close;
ods listing;
options byline;

*add the N count to a label variable, this will now be used in place of trtp as an across variable;
data add_label;
    set demo6;
    trtp_label = cat(trtp," N = ",left(put(bign,best.)));
run;

options nobyline;
ods listing close;
ods rtf file="%sysfunc(pathname(work,L))/p_rpt_demo06b.rtf";
title01 '6v: Shift table report with Subgroup N count';
title02 'by: #byval(subgroup)';
%macro subgrp_rpt (subgrp = );

    %let z=1;  ** Define start of loop, k is the element within the include list; 
    %do %while (%scan("&subgrp.", &z.) ne ); ** Check if at the end of the include list;
      %let p = %scan(&subgrp., &z.);  ** Set i to the next group number in the list;
      %let z = &z.+1;  ** Increment include list element for the next loop;
      %do j=1 %to 2;

        %p_rpt    (  inds       = add_label   
                    ,avar       = %str(trtp_label, base )
                   , colwidths = 1in
                   , rowlabelwidth = 3in
                    ,dest           = rtf
                    ,resultvar     = str1
                    ,flws      = %str(where subgroupn = &j.; by subgroupn subgroup ;)
                     );              
      %end;
    %end;
%mend subgrp_rpt;

%subgrp_rpt(subgrp = Sex);
title; footnote;
ods rtf close;
ods listing;
options byline;

*add the N count to a label variable, this will now be used in place of trtp as an across variable;
data add_label;
    set demo6;
    trtp_label = cat("TRT ",trtp);
    base_label = cat(base," n = ",left(put(denom,best.)));
run;

options nobyline;
ods listing close;
ods rtf file="%sysfunc(pathname(work,L))/p_rpt_demo06b.rtf";
title01 '6b: Shift table report with Subgroup N count';
title02 'by: #byval(subgroup)';
%macro subgrp_rpt (subgrp = );

    %let z=1;  ** Define start of loop, k is the element within the include list; 
    %do %while (%scan("&subgrp.", &z.) ne ); ** Check if at the end of the include list;
      %let p = %scan(&subgrp., &z.);  ** Set i to the next group number in the list;
      %let z = &z.+1;  ** Increment include list element for the next loop;
      %do j=1 %to 2;

        %p_rpt    (  inds       = add_label   
                    ,avar       = %str(trtp_label, base )
                   , colwidths = 1in
                   , rowlabelwidth = 3in
                    ,dest           = rtf
                    ,resultvar     = str1
                    ,flws      = %str(where subgroupn = &j.; by subgroupn subgroup ;)
                     );              
      %end;
    %end;
%mend subgrp_rpt;

%subgrp_rpt(subgrp = Sex);
title; footnote;
ods rtf close;
ods listing;
options byline;



** This example shows a varied second level across vairable, this could be because of "n" count differences or different treatment groups in each Arm;
** An additional loop has been used, and where statement, to subset on each treatment group. This results in an output where page 1 has TRT A and base values
   and page 2 has TRT B with its base values.;

options nobyline;
ods listing close;
ods rtf file="%sysfunc(pathname(work,L))/p_rpt_demo06c.rtf";
title01 '6c: Shift table report with baseline score n count';
title02 'by: #byval(subgroup)';
%macro subgrp_rpt (subgrp =, label1 =);

    %let z=1;  ** Define start of loop, k is the element within the include list; 
    %do %while (%scan("&subgrp.", &z.) ne ); ** Check if at the end of the include list;
      %let p = %scan(&subgrp., &z.);  ** Set i to the next group number in the list;
      %let z = &z.+1;  ** Increment include list element for the next loop;
      %do j=1 %to 2;
          %let max = %eval(%sysfunc(countc("&label1.",'$'))+1);
          %do s=1 %to &max. ;
          %let t = %scan( "&label1.", &s., "$");  ** Set i to the next label in the list;
          %Put &t.;


            %p_rpt    (  inds       = add_label   
                        ,avar       = %str(trtp_label, base_label )
                       , colwidths = 2in
                       , rowlabelwidth = 5in
                        ,dest           = rtf
                        ,resultvar     = str1
                        ,flws      = %str(where subgroupn = &j. and trtp_label = "&t."; by subgroupn subgroup ;)
                        ,tidyup = 0 );              
         %end;         
      %end;
    %end;
%mend subgrp_rpt;

%subgrp_rpt(subgrp = Sex,  label1 = %str(TRT A $ TRT B));
title; footnote;
ods rtf close;
ods listing;
options byline;

