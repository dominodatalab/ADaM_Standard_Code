/*****************************************************************************\
*        O                                                                     
*       /                                                                      
*  O---O     _  _ _  _ _  _  _|                                                
*       \ \/(/_| (_|| | |(/_(_|                                                
*        O                                                                     
* ____________________________________________________________________________
* Sponsor              : Evelo
* Study                : 1867-101
* Analysis             : Final Analysis
* Program              : p_align.sas  
* Purpose              : Macro to align on decimal point 
* ____________________________________________________________________________                                                
*                                                                   
* Input files: dsetin
*                                                                            
* Output files: dsetout                                                   
*                                                                
* Macros:                                          
*                                                                   
* Assumptions: alignvars are character variables present in dsetin                                          
*                                                                   
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
* 20AUG2021  |  Natalie Thompson  | Copied from 1815-201.                                                        
* ----------------------------------------------------------------------------
*  ddmmmyyyy  |   <<name>>       | ..description of change..         
\*****************************************************************************/

%macro p_align(
   dsetin  = , /* Input dataset */
   dsetout = , /* Output dataset */
   varsin  = , /* Space separated list of character variables to be aligned e.g. result1 resul2 result3 */
   varsout =   /* Space separated list of variables to contain aligned values e.g. aligned1 aligned2 aligned3 */
   );



/*****************************************************************************\
| PARAMETER CHECKS
\*****************************************************************************/

/* Dataset dsetin exists? */
%if %sysfunc(exist(&dsetin.)) eq 0 %then %do;
   %put %str(ERR)OR: Dataset &dsetin. does not exist or is invalid.;
   %goto exit;
%end;

/* Number of variables in varsin and varsout match? */
%if %sysfunc(countw(&varsin.,%str( ))) ne %sysfunc(countw(&varsout.,%str( ))) %then %do;
   %put %str(ERR)OR: Number of variables in VARSIN and VARSOUT should match.;
   %goto exit;
%end;

/* Variables in varsin exist and are character type? */
%let dsid = %sysfunc(open(&dsetin.));
%do _i = 1 %to %sysfunc(countw(&varsin.,%str( )));
   %let varin  = %scan(&varsin.,&_i.,%str( ));
   %let varnum = %sysfunc(varnum(&dsid.,&varin.));
   %if &varnum. eq 0 %then %do;
      %put %str(ERR)OR: Variable &varin. not present in &dsetin..;
      %let rc = %sysfunc(close(&dsid.));
      %goto exit;
   %end;
   %if %sysfunc(vartype(&dsid.,&varnum.)) eq N %then %do;
      %put %str(ERR)OR: Variable &varin. is numeric. All variables in VARSIN should be character.;
      %let rc = %sysfunc(close(&dsid.));
      %goto exit;
   %end;
%end;
%let rc = %sysfunc(close(&dsid.));



/*****************************************************************************\
| START OF PROCESSING
\*****************************************************************************/

/* For each variable to be aligned, select:
   - Max number of characters to the left of the decimal point
   - Max number of characters to the right of the decimal point
   - Whether a decimal point exists in any record (adds 1 or 0 to total length) */

%do _i = 1 %to %sysfunc(countw(&varsin.,%str( )));
   %let varin = %scan(&varsin.,&_i.,%str( ));
   proc sql noprint;
      select max(lengthn(strip(scan(&varin.,1,'.')))), 
             max(lengthn(strip(scan(&varin.,2,'.')))), 
             max((index(&varin.,'.') gt 0)) into :&varin._intlength, :&varin._declength, :&varin._dec
      from &dsetin.;
   quit;
%end;


/* Apply alignment to data:
   - For each variable set the total length required
   - Then join the left and right sides around the decimal point
   - If no decimal point is present then the left side will capture the whole integer value */

data &dsetout.;
   set &dsetin.;
   length %do _i = 1 %to %sysfunc(countw(&varsin.,%str( )));
             %let varin  = %scan(&varsin.,&_i.,%str( ));
             %let varout = %scan(&varsout.,&_i.,%str( ));
             &varout. $%eval(&&&varin._intlength. + &&&varin._declength. + &&&varin._dec.)
          %end;;

   %do _i = 1 %to %sysfunc(countw(&varsin.,%str( )));
      %let varin  = %scan(&varsin.,&_i.,%str( ));
      %let varout = %scan(&varsout.,&_i.,%str( ));
      %if &&&varin._dec. %then %do;
         if index(&varin.,'.') then &varout. = right(put(strip(scan(&varin.,1,'.')), &&&varin._intlength..)) || '.' || left(put(strip(scan(&varin.,2,'.')), &&&varin._declength..));
         else 
      %end; 
      &varout. = right(put(strip(scan(&varin.,1,'.')), &&&varin._intlength..));
   %end;

run;



/*****************************************************************************\
| FAILED PARAMETER CHECK SKIPS TO HERE
\*****************************************************************************/
%exit:

%mend p_align;
