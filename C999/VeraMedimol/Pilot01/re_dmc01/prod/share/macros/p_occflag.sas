/*****************************************************************************\
*        O                                                                      
*       /                                                                       
*  O---O     _  _ _  _ _  _  _|                                                 
*       \ \/(/_| (_|| | |(/_(_|                                                 
*        O                                                                      
* ____________________________________________________________________________
* Sponsor              :           
* Study                :          
* Program              : p_occflag 
* Purpose              : Macro to create occurrence flags
* ____________________________________________________________________________
* DESCRIPTION         
*                                                     
*                                                                   
* Input files:                                           
*                                                                    
* Output files:                                              
*                                                                   
* Macros:        
*                                                                    
* Assumptions:                                                    
*                                                                   
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
* Dianne Weatherall  | Original             | 2022-03-28
* ----------------------------------------------------------------------------     
\*****************************************************************************/

* INDS     = input dataset name;
* NEWFLG   = occurrence flag (e.g. AOCCFL);
* SORTBY   = sort variables;
* BYVAR    = by variables used to choose the FIRSTVAR;
* FIRSTVAR = variable to flag the first record of;
* WHERECLS = where clause (recommend to use where variables as your first sort and by variables;

* Example call;
* %p_occflag (inds = adae, newflg = aoccfl,  sortby = trtemfl usubjid aebodsys aedecod aeseq, byvar = trtemfl usubjid aebodsys aedecod, firstvar = usubjid,  wherecls = trtemfl eq "Y");
* %p_occflag (inds = adae, newflg = aoccsfl, sortby = trtemfl usubjid aebodsys aedecod aeseq, byvar = trtemfl usubjid aebodsys aedecod, firstvar = aebodsys, wherecls = trtemfl eq "Y");
* %p_occflag (inds = adae, newflg = aoccpfl, sortby = trtemfl usubjid aebodsys aedecod aeseq, byvar = trtemfl usubjid aebodsys aedecod, firstvar = aedecod,  wherecls = trtemfl eq "Y");

%macro p_occflag (inds     = ,
                  newflg   = ,
                  sortby   = ,
                  byvar    = ,
                  firstvar = ,
                  wherecls = );
 
proc sort data = &inds.;
  by &sortby.;
run;
 
data &inds.;
  set &inds.;
    by &byvar.;
 
  length &newflg $ 200;
 
  if first.&firstvar. and &wherecls. then &newflg. = "Y";
 
run;
 
%mend p_occflag;
