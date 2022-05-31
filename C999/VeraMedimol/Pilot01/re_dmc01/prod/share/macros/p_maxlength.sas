
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
* Program              :  p_maxlength.sas
* ____________________________________________________________________________
* DESCRIPTION     Assign Maximum lengths as per data.                                              
*                                                                   
* Input files: 	 Dataset                                               
*                                                                   
* Output files:                                              
*                                                                
* Macros:                                                         
*                                                                   
* Assumptions:                                                  
*                                                                   
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
* 05MAY2022  | James Mann       | Original, lifted from SG015
/*****************************************************************************/

%macro p_maxlength(inds=,outds=);

	proc contents data=&inds. out=cat_inds noprint;
	run;

	proc sql noprint;
		select distinct name into :vrlst separated by ' '
	  	from cat_inds
	  	where type=2;
	quit;

	%let nvr=&sqlobs;

 
    data &outds.;
      set &inds.;
    run;


	 %do i=1 %to &nvr;
	  %let var=%scan(&vrlst,&i,%str( ));
	  proc sql noprint;
	    select max(length(&var)) into :mxlen
	    from &inds.;

	  alter table &outds. 
	  modify &var char(&mxlen);
	  quit;
	%end;

%mend;
