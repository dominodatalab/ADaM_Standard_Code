dm 'out;clear;';
dm 'log;clear;';
 /*****************************************************************************\
*        O                                                                      
*       /                                                                       
*  O---O     _  _ _  _ _  _  _|                                                 
*       \ \/(/_| (_|| | |(/_(_|                                                 
*        O                                                                      
* ____________________________________________________________________________
* Sponsor              : Veramed
* Study                : <STUDY>
* Program              : QC_<TFL>.SAS
* Purpose              : 
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
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  <DATE>             | <NAME>          | Original version
\*****************************************************************************/

********;
%__init;
********;



** TFL CODE **;





** Inline interactive compare - per output **;
%s_compare(base=TFL.<TFLNAME>,comp=TFLQC.Q_<TFLNAME>,TFL=Y);

********;
%s_scanlog;
********;
