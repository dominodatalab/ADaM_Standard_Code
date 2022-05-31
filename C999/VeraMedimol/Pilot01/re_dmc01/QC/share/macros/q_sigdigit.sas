/*****************************************************************************\
*        O                                                                    | 
*       /                                                                     |
*  O---O     _  _ _  _ _  _  _|                                               | 
*       \ \/(/_| (_|| | |(/_(_|                                               | 
*        O                                                                    | 
* ____________________________________________________________________________|
* Sponsor              : Evelo                                                |
* Study                : EDP1867-101                                          |
* Analysis             : validation                                           |
* Program              : q_sigdigit.sas                                     |
* ____________________________________________________________________________|
* Macro to round to the significant digits for the given analysis variable    |                                       
*                                                                             |
* Input files:                                                                |
* Macro Parameters                                                            |
* ----------------------------------------------------------------------------|
* invar               = name of the input variable for which significant      |
*                       digit rounding is required                            |
* sigdgt              = value or variable referring to the significant digits |
* debug               = logical value specifying whether debug mode is        |
*                       on or off.                                            |
*                                                                             |
* Output files:                                                               |
* Macro Parameters                                                            |
* ----------------------------------------------------------------------------|
* outvar              = list of variable names in the dataset in DATA macro   |
*                       parameter to be used in byvar statement               |
*                                                                             |
* Macros: _qc_sigdigit                                                        |                    
*                                                                             |
* Assumptions:                                                                |                                            
*                                                                             |
* ____________________________________________________________________________|
* PROGRAM HISTORY                                                             |
*  29SEP2021  |   Kaja Najumudeen | Original version of the code              |
* ----------------------------------------------------------------------------|
\*****************************************************************************/
%macro q_sigdigit(invar=, sigdgt=, outvar=,debug=)/mindelimiter=' ';
option validvarname=v7 MAUTOSOURCE minoperator;
%if &invar. ^= %then %do;
  %if %bquote(&debug.) eq %then %let debug=0;
  %if %bquote(&debug.) in (y Y yes YES 1) %then %let debug=1;
  %if %bquote(&debug.) in (n N no NO 0) %then %let debug=0;

  %if &outvar. eq %then %do;
    %put %str(UER)ROR: output variable is missing. Macro will exit now from processing;
    %GOTO MSTOP;
  %end;
  %else %do;
    if &invar.^=. then do;
	  %if &debug. %then %do;
        %put %str(UN)OTE: The variable &invar. is processed for significant digits rounding;
	  %end;
      %if %bquote(%superq(sigdgt))= %then %do;
        %put %str(UER)ROR: Significant variable/value sigdgt is missing. Macro will exit now from processing;
        %GOTO MSTOP;
      %end;
      if &invar.=0 then &outvar.=0;
      else if int(&invar.) ne 0 then do;
	    %if %sysfunc(verify(&sigdgt.,.0123456789)) %then %do;
          &outvar.=round(&invar.,10**(int(log10(abs(&invar.)))-(&sigdgt.-1)));
		%end;
		%else %do;
          &outvar.=round(&invar.,10**(int(log10(abs(&invar.)))-%eval(&sigdgt.-1)));
		%end;
      end;
      else do;
        &outvar.=round(&invar.,10**(-1*(abs(int(log10(abs(&invar.))))+&sigdgt.)));
      end;
    end;
    %if ^ &debug. %then %do;
      %if &invar. = _sigdgt_ %then %do;
        drop _sigdgt_;
	  %end;
    %end;
  %end;  
%end;
%else %do;
  %put %str(UER)ROR: Input variable name is missing. Macro will exit now from processing;
%end;
%GOTO MSTOP;

*------------------------------------------;
* clean the processing if any          ; 
* -----------------------------------------;
%if ^ &debug. %then %do;

%end;

%MSTOP: ;
%mend q_sigdigit;
