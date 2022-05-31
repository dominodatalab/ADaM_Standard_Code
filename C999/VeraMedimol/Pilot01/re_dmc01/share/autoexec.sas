/*****************************************************************************\
*        O
*       /
*  O---O     _  _ _  _ _  _  _|
*       \ \/(/_| (_|| | |(/_(_|
*        O
* ____________________________________________________________________________
* Sponsor              : Veramed
* Study                : study_01
* Analysis             : re_dmc01
* Program              : autoexec.sas
* ____________________________________________________________________________
* DESCRIPTION
*
* This is the reporting effort SAS autoexec file. All study/reporting effort
* specific configuration should be done here.
*
* Input files:
* - [TODO]
*
* Output files:
* - [TODO]
*
* Macros:
* - [TODO]
*
* Assumptions:
* - this autoexec assumes that the verasetup.sas program has been run as
*   part of the standard program init.
*   Verasetup will configure the following
*         - Libnames
*         - Macro SASAUTO search paths (driven by PROD or QC)
*         - SAS format search path (driven by PROD or QC)
*         - Additional standard global variables for use within programs
* ____________________________________________________________________________
* PROGRAM HISTORY
*  2022-03-11  |   StuartMalcolm      | Created placeholder
* ----------------------------------------------------------------------------
*  YYYYMMDD  |  username        | ..description of change..
\*****************************************************************************/


%put TRACE: [Program: autoexec] Program start;

 ********************************************************************;
 ** Study specific variables items to be set by lead - apply to ALL programs **;
 ********************************************************************;
 
%global _studyid _status _dco _split _relabel; 

%let _studyid =VERA-C999;              ** Study ID / name to be presented on outputs **;
%let _status  =Test: DUMMY Rand List;  ** Status to indicate detail of run.  DUMMY Rand List / Dry Run / Final etc.. **;
%let _dco     =Data Cut: DDMMYYYY;     ** Data cut Off Date.  Label for use in standard footnote e.g. Data Cut: DDMMMYYYY **;
%let _split   =|;                      ** Split character for used in output.  Also feeds into S_COMPARE as allowable difference **;
%let _relabel =%substr(&__RE,4);       ** Label to be applied to LOG/COMPARE PDFs.  Default from folder name, or define as neccessary **;


** Initial Default SAS options / configuration **;
options
      compress=yes
      papersize=letter
      orientation=landscape
      missing=' '
      validvarname=upcase
      ;

 ** ODS specific options **;
ods results off;
ods listing;
ods escapechar='|';


********************************************************;
* [TODO] add other standard AUTOEXEC configuration here ;
********************************************************;







* TODO - put study/reporting effort specific configuration here ;


%put TRACE: [Program: autoexec] Program end;

