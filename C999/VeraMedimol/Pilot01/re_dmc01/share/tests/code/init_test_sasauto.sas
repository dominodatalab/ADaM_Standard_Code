/*****************************************************************************\
*        O                                                                     
*       /                                                                      
*  O---O     _  _ _  _ _  _  _|                                                
*       \ \/(/_| (_|| | |(/_(_|                                                
*        O                                                                     
* ____________________________________________________________________________
* Sponsor              : Veramed
* Study                : VeraMedimol
* Analysis             : re_dmc01
* Program              : init_test_sasautos.sas
* ____________________________________________________________________________
* DESCRIPTION
*
* This program is used to test that the init+verasetup SASAUTOS path
* This program is run by the init.tests.ps1 test suite which uses
* the SAS log file to check for expected results.
*
* Input files: none
*
* Output files: none
*                                                                
* Macros: init
*                                                                   
* Assumptions: none
*                                                                   
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  2022-03-25  |   stuart.malcolm      | Original                                    
* ----------------------------------------------------------------------------
*  YYYYMMDD  |  username        | ..description of change..         
\*****************************************************************************/

%init;

* Once init has been called, output the SASAUTOS option ;


* then output all the folders that SASAUTOS references ;
* this macro is from the SAS online documentation: ;
* https://support.sas.com/kb/42/654.html ;

%macro listautos;                                                                                                                       
%local autoref i ref refpath;  
/** Retrieve the value of the SASAUTOS option **/                                                                                                         
%let autoref = %qsysfunc(getoption(sasautos));                                                                                          
%let i=0;                                                                                                                               
%do %until(&ref eq); 
   /** Pull off the first item contained within SASAUTOS **/                                                                                                                   
   %let ref = %qscan(&autoref,&i+1,%str(() ,));   
   /** If everything has been read or if empty leave the macro **/                                                                                      
   %if &ref eq %then %return;     
    /** Check to see if the item returned contains quotes **/
    /** If it does not precede to the next %LET statement **/                                                                                                      
    %if %sysfunc(indexc(&ref,%str(%'),%str(%"))) eq 0 %then %do; 
    /** Return the path the fileref points to **/                                                                       
    %let refpath=%qsysfunc(pathname(&ref));                                                                                             
    %let i = %eval(&i + 1); 
    /** Print location fileref path **/                                                                                                            
    %put &i &ref &refpath;                                                                                                              
   %end;   
   /** We hit this %ELSE if the item contains quotes, not a fileref **/                                                                                                                             
   %else %do;                                                                                                                           
    %let i = %eval(&i + 1);  
    /** Print location path **/                                                                                                           
    %put &i &ref;                                                                                                                       
   %end;                                                                                                                                
%end;                                                                                                                                   
%mend listautos;                                                                                                                        
%listautos 
