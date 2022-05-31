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
* Program              :  p_ODS_open_fig.sas
* ____________________________________________________________________________
* DESCRIPTION
* Usage                 : %p_ODS_open_fig(TFL_ID=          - TFL ID of output
*                       :                ,PageVar=page  - Page number var in dataset
*                       :                ,DataSource=      - Data source (for audit footnote)
*                       :                 )
* Notes                 : - Parameter TFL_ID identifies output.
*                       : - Sets TITLE1 & TITLE2 with project name, page number
*                       :   (as "Page #ByVal(&PageVar) of _#NumPages#_") and DRAFT stamp
*                       : - Sets other TITLEs and FOONOTEs read from RefData.titles.
*                       : - Sets final footnote with audit information.
*                       : - Sets global MacroVar OutFileBaseName with base name 
*                       :   for output, derived from TITLE3 
*                       :   as (eg) "t14-01-02" (without quotes).
*                       :   If (global) MacroVar DevMode=Y then TFL_ID is 
*                       :   appended to the OutFileBaseName (value is NOTEd).
*                       : - Sets global MacroVar DDDataName, derived from 
*                       :   OutFileBaseName by replacing dashes with 
*                       :   underscores (value is NOTEd).
*                       : - Closes ODS LISTING destination is (to avoid 
*                       :   pagination issues).
*                       : - Opens ODS RTF destination, to file:
*                       :   "&path.\output\&OutFileBaseName..rtf", with 
*                       :   appropriate options.
* Assumptions           : - Dataset RefData.titles must exist with vars:
*                       :   Program              - Program name
*                       :   TFL_ID               - TFL output identifier
*                       :   TITLE3               - TFL type and number, e.g. "Table 14.1.2"
*                       :   TITLE4-TITLE10       - Other titles
*                       :   FOOTNOTE1-FOOTNOTE9  - Footnotes
*                       : - [1] Output file path in ODS RTF code and call execute section must be updated to reflect current study  
* _____________________________________________________________________________
* PROGRAM HISTORY
*  20NOV2020  |   Hector Leitch  | Copy of u_ODS_open updated for PDF
* ----------------------------------------------------------------------------
*  23NOV2020  |   Hector Leitch  | Updated file destination in final footnote
* ----------------------------------------------------------------------------
*  14JAN2021  |   Hector Leitch  | Updated file location to 201
* ----------------------------------------------------------------------------
*  14JAN2021  |   Emily Jones    | Added ods graphics options for no border and
*             |                  | height and width
* ----------------------------------------------------------------------------
*  22JAN2021  |   Hector Leitch  | Added scan for &model in titles
* ----------------------------------------------------------------------------
*  05FEB2021  |   Hector Leitch  | Added status to title 2
* ----------------------------------------------------------------------------
*  18MAR2021  |   Hector Leitch  | Updated file path for 201
* ----------------------------------------------------------------------------
*  19NOV2021  |   Craig Thompson  | Updated file path for 1867-101 and altered 
                                    population to be placed top left to match
                                    shells
\*****************************************************************************/

%macro p_ODS_open_fig(TFL_ID=,style=evelo,DataSource=,ListSource=%str(),type=F);

    **ods graphics options;
    ods graphics / noborder;
    ods graphics on / width=8.9in height=5in;

    option center;
    *-Temporarily set NOQUOTELENMAX system option so can have long footnotes without incurring a long quoted string warning;
    *------------------------------------------------------------------------------;
    %local _opts; %let _opts=%sysfunc(getoption(QUOTELENMAX)); options NOQUOTELENMAX;

    *-Get output details from Titles table and set titles and footnotes            ;
    *------------------------------------------------------------------------------;
    data _NULL_;
        set RefData.titles end=_LastObs;
        where TFL_ID="&TFL_ID" and upcase("&type.") = upcase(substr(TITLE3, 1, 1));

        *-Set up titles and footnotes (using call execute to get title/footnote statements executed after this data step);
/*        call execute('TITLE01 j=l "Study Number: &studynum" j=r "Page #ByVal(&PageVar) of _#NumPages#_";');*/

          call execute('TITLE01 j=l "Protocol: &study" j=r "Page (*ESC*){thispage} of (*ESC*){lastpage}";');
         
        if ~missing(TITLE5)    then do;
            call execute(cat(vname(TITLE2),   ' j=l "',trim(TITLE5),   '" j=r "&status.";'));
        end; 


          
        array TITLEs    {3:4} $ TITLE3    - TITLE4;
        do _i=03 to 04;
            if ~missing(TITLEs{_i})    then do;
                if index(TITLEs{_i},"#byval") > 0 or index(TITLEs{_i},'&model') > 0 then call execute(cat(vname(TITLEs{_i}),   ' j=l "',trim(TITLEs{_i}),   '";'));
                else call execute(cat(vname(TITLEs{_i}),   ' j=c "',trim(TITLEs{_i}),   '";'));
                end;    
            end;
        /*call execute('FOOTNOTE01 j=l "______________________________________________________________________________________________________________________________";');*/   
        array FOOTNOTEs {*   } $ FOOTNOTE1 - FOOTNOTE9;
        do _i=01 to 09;
            if ~missing(FOOTNOTEs{_i}) then do;
                call execute(cat(vname(FOOTNOTEs{_i}),' j=l "',trim(FOOTNOTEs{_i}),'";'));
                _LastFootnote = _i;
                end;    
            end;
        *-Derive base name for output file from "Table 14.#.#" text in TITLE3 as "t##_##_##" and save in global MacroVar;
        length OutFileBaseName $32;
        OutFileBaseName = PRXChange('s/^([[:alpha:]])\w* /\l\1/', 1,
                          PRXChange('s/\./_/'                   ,-1,
                          PRXChange('s/\.(\d)(?=\D)/.0\1/'      ,-1,
                                                                     TITLE3)));

       %IF "&DEVMODE"="Y" %then %do;
        OutFileBaseName= trim(OutFileBaseName)||'_'||tfl_id;
       %end;

        call symputx('OutFileBaseName',OutFileBaseName,'G');

        *-Derive base name for output DDData as "t##_##_##" and save in global MacroVar;
        DDDataName      = tranwrd(OutFileBaseName,'-','_');
        call symputx('DDDataName'     ,DDDataName     ,'G');

        *-Add final audit footnote;
        if _LastFootnote = . then final = 2;
        else if _LastFootnote < 9 then final = _LastFootnote + 2;
        else if _LastFootnote = 9 then final = _LastFootnote + 1;
        else put "W" "ARNING: Issue in footnote generation.";
				*-Update path [1];
        call execute(cat('FOOTNOTE',put(sum(_LastFootnote,2),Z2.), ' j=l h=9pt f="Courier New" "',
                         'Source: Evelo/EDP1867/EDP1867-101/prod/TFLs/code/'     , trim(Program)        , ', ',
                         "%sysfunc(date(),date9.) %sysfunc(time(),tod5.)",
                         '";'));

        *-Save concatenation of TITLE3 and TITLE4 in local MacroVar for output file title metadata;
        call symputx('OutFileTitle',   catx(': ',TITLE3,TITLE4),'L');

        *-Er-ror if more than one record found;
        %local _err;
        if _LastObs then do;
            if _N_^=1 then do;
                put 'ER' "ROR: Multiple records in RefData.Titles(where=(TFL_ID=""&TFL_ID""))";
                call symputx('_err',1,'L');
                end;
            else
                call symputx('_err',0,'L');
            end;
        run;
    %if &_err=   %then      %put %str(ER)ROR: No RefData.Titles(where=(TFL_ID="&TFL_ID")) records!;

    %*-Exit macro if er-rors;
    %if &_err^=0 %then %do; %put %str(WAR)%str(NING: Exiting macro due to er)%str(rors.); %goto exit; %end;

    %put %str(NO)TE: (Global) OutFileBaseName=&OutFileBaseName;
    %put %str(NO)TE: (Global) DDDataName     =&DDDataName     ;


    *-Open ODS PDF destination (and close listing destination)                     ;
    *------------------------------------------------------------------------------;
    ODS listing close;
		*-Update path [1];
    ODS PDF 
            file        = "Z:\Evelo\EDP1867\EDP1867-101\prod\TFLs\output\&OutFileBaseName..pdf"
            style       = &style
            author      = "Veramed"        /* Set RTF metadata Author field       */
            title       = "&OutFileTitle"  /* Set RTF Title field                 */
            /*BODYTITLE_AUX*/                  /* Put titles and footnotes in-line?   */
            /*StartPage   = on*/               /* Start new page for each item        */
            /*SectionData = "\sbkpage"*/       /* Make section breaks go to next page */
            nogtitle nogfootnote notoc;

    *-Re-set QUOTELENMAX system option to what it was at the start of the macro;
    *------------------------------------------------------------------------------;
    options &_opts;

%exit: %mend p_ODS_open_fig;
