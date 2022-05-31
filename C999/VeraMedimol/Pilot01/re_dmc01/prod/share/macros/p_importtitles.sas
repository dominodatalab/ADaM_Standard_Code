/*****************************************************************************\
*        O                                                                     
*       /                                                                      
*  O---O     _  _ _  _ _  _  _|                                                
*       \ \/(/_| (_|| | |(/_(_|                                                
*        O                                                                     
* ____________________________________________________________________________
* Sponsor              :  Evelo
* Study                :  EDP1815-201
* Program              :  p_importtitles.sas
* Purpose              :  Create refdata containing output titles and footnotes
* ____________________________________________________________________________
* DESCRIPTION                                                   
*                                                                   
* Input files: xml file containing titles and footnotes                                                  
*                                                                   
* Output files: refdata.titles
*                                                                
* Macros:                                                         
*                                                                   
* Assumptions:  titlename needs to update to reflect the current study title file name                                                  
*                                                                   
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  02DEC2020  |   Hector Leitch  | Copied from 1815-205, updated for 201
* ----------------------------------------------------------------------------
* 
\*****************************************************************************/


%macro p_importtitles(titlename=);


%let titlename=%str(EDP1867_101_Titles_v0_1);

*create xml libname;
%let refpath=%sysfunc(pathname(refdata));

data _null_;
  attrib line format=$200.;
  line="libname titles xml '&refpath.\&titlename..xml'";
  call symput('ttllib',strip(line));
run;

&ttllib.;

data refdata.titles;
  length PROGRAM TFL_ID 
         TITLE1 TITLE2 TITLE3 TITLE4 TITLE5 
         TITLE6 TITLE7 TITLE8 TITLE9 TITLE10  
         FOOTNOTE1 FOOTNOTE2 FOOTNOTE3 FOOTNOTE4 FOOTNOTE5 
         FOOTNOTE6 FOOTNOTE7 FOOTNOTE8 FOOTNOTE9 FOOTNOTE10 $400;
  call missing(PROGRAM,TFL_ID,
               TITLE1,TITLE2,TITLE3,TITLE4,TITLE5,
               TITLE6,TITLE7,TITLE8,TITLE9,TITLE10,
               FOOTNOTE1,FOOTNOTE2,FOOTNOTE3,FOOTNOTE4,FOOTNOTE5,
               FOOTNOTE6,FOOTNOTE7,FOOTNOTE8,FOOTNOTE9,FOOTNOTE10);
  set titles.record; 
  where not missing(program);
run;

libname titles;

*linesize check;
data _null_;
  set refdata.titles;
  ls=%sysfunc(getoption(ls));
  array ttls(*) title:;
  array fns(*) footnote:;
  do i=1 to dim(ttls);
    if length(ttls[i])>ls then put 'WARN' 'ING: Title ' i ' too long fot program ' program;
  end;
  do i=1 to dim(fns);
    if length(fns[i])>ls then put 'WARN' 'ING: Footnote ' i ' too long for program ' program;
  end;
run;

%mend p_importtitles;

%p_importtitles;

