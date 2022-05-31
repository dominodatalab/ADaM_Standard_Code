/*****************************************************************************\
*        O
*       /
*  O---O     _  _ _  _ _  _  _|
*       \ \/(/_| (_|| | |(/_(_|
*        O
* _____________________________________________________________________________
* Sponsor              :  Evelo
* Study                :  EDP1867-101
* Analysis             :  Final Analysis
* Program              :  p_ODS_close.sas
* Purpose              :  Standard ods rtf close call to be used for all tables and listings
* _____________________________________________________________________________
* DESCRIPTION
* Brief Description     : Macro to close ODS output destination 
*                       : and post-process RTF file
* Usage                 : %u_ODS_close(OutFileBaseName= - Base name of RTF file
*                       :             ,NumPages=        - Number of pages
*                       :              )
* Notes                 : - Closes ODS RTF destination.
*                       : - Opens ODS LISTING destination.
*                       : - Re-sets TITLEs and FOOTNOTEs.
*                       : - Post-processes RTF file "&path.\output\&OutFileBaseName..rtf"
*                       :   - Replaces ' of _#NumPages#_' with "\~of\~&NumPages"
*                       :   - Removes section breaks.
*                       : - Deletes global MacroVars OutFileBaseName & DDDataName.
* Assumptions           : - ODS RTF destination is open, to file 
*                       :   "&path.\output\&OutFileBaseName..rtf"
* _____________________________________________________________________________
* PROGRAM HISTORY
*  20AUG2021  |  Natalie Thompson  | Copied from 1815-201, Updated for 1867-101
\*****************************************************************************/

*-Macro to close ODS output destination and post-process RTF file;
*==============================================================================;
%macro p_ODS_close(OutFileBaseName=,NumPages=);
    
    *-Close RTF destination, re-open the listing destination, re-set titles and footnotes;
    *------------------------------------------------------------------------------;
    ODS RTF close;
    ODS listing;
    title; footnote;

    *-Post-process RTF file                                                        ;
    *------------------------------------------------------------------------------;

    *-Read RTF file into temporary dataset;
    /*data __RTF;
        length LineTxt $1000;
        infile "&path.\TFLs\output\&OutFileBaseName..rtf" length=LineLen lrecl=1000 end=eof;
        input @1 LineTxt $varying1000. LineLen;
        run;*/
    
    *-Replace strings and re-write RTF File;
    /*data _NULL_;
        set __RTF;
        file "&path.\TFLs\output\&OutFileBaseName..rtf" LineSize=1000;
        if (index(LineTxt,"\sect\sectd\linex0\endnhere") > 0)
            then LineTxt="{\fs2\pagebb\par}";
        LineTxt = TranWrd(LineTxt,' of _#NumPages#_',%if &NumPages= %then ' '; %else "\~of\~&NumPages";);
        put LineTxt;
        run;*/
    
    *-Delete temporary dataset;
    /*proc delete data=__RTF; run;*/
    

    *-Clean up MacroVars used                                                      ;
    *------------------------------------------------------------------------------;
    %SymDel OutFileBaseName DDDataName;
%exit: %mend p_ODS_close;