/*****************************************************************************\
*        O                                                                      
*       /                                                                       
*  O---O     _  _ _  _ _  _  _|                                                 
*       \ \/(/_| (_|| | |(/_(_|                                                 
*        O                                                                      
* ____________________________________________________________________________
* Sponsor              : Evelo
* Study                : EDP1867-101
* Analysis             : 
* Program              : q_attrib.sas
* Purpose              : QC macro for applying dataset attributes and sorts by 
                         key variables
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files:   Appropriate specifcation for SDTMs or ADaMs                                                    
*                                                                   
* Output files:  Final SDTM or ADaM with attributes and sort order as indicated 
*                in specifcation used as input                                                 
*                                                                 
* Macros:        None                                                 
*                                                                   
* Assumptions:   DOMAIN = e.g DM, AE, SUPPAE, ADSL, ADAE
*                IN     = input dataset
*                OUT    = output dataset  
*                LOC    = folder location of csvs 
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  28JUL2021  |   Craig Thompson    | Copied from 201, updated for Evelo
* ----------------------------------------------------------------------------  
*  31AUG2021  |   Kaja Najumudeen   | Updated the code to handle the logical
*             |                     | condition for variable type check independent
*             |                     | of case.
* ----------------------------------------------------------------------------  
*  18AUG2021  |   Kaja Najumudeen   | Included the code to apply the dataset description 
*             |                     | from the spec
* ----------------------------------------------------------------------------  
\*****************************************************************************/

%macro q_attrib(domain=, in=, out=, loc=);


	*Read in spec - ADaM - OTL-103;
	proc import out= spec datafile= "&loc.\Variables.csv" 
	            dbms=csv replace; guessingrows=max;
				
	run;

	proc import out= sortvars datafile= "&loc.\Datasets.csv" 
	            dbms=csv replace; guessingrows=max;
	run;

	proc sql noprint;
		select compress(Key_Variables,',') into: keyvars
	         from sortvars where dataset=upcase("&domain.");
		select strip(description) into: tbldesc
		     from sortvars where dataset=upcase("&domain.");
	quit;

	*Filter for domain;
	proc sort data=spec(where=(upcase(dataset)="&domain.")) out=spec2;
		by dataset order;
	run;

	*Fetch attributes;
	data spec3;
		set spec2;
		by dataset order;
		orderc=strip(put(order,best.));
		call symput ("var"||strip(orderc), strip(variable)); /*Variable Name*/
		call symput ("typ"||strip(orderc), strip(data_type)); /*Data Type*/;
		call symput ("lbl"||strip(orderc), strip(label)); /*Label*/
        call symput ("for"||strip(orderc), strip(format));/*Format*/
	run;

	/*Select maximum number of variables*/
	proc sql noprint;
		select max(order) into: maxord
	         from spec2;
	quit;

	/*Select lengths*/
	%do i=1 %to &maxord.;
		proc sql noprint;
			select length into: len&i.
	         from spec2 where order=&i.;
		quit;

	%end;


	*Create template dataset with all attributes;
	data &domain._template;
		
		%do i=1 %to &maxord.;
			label  &&var&i..= "&&lbl&i..";
		    %if %lowcase("&&typ&i..") = "text" %then %do;
			    length &&var&i.. $&&len&i..;
				&&var&i..='';
/*				format &&var&i.. $&&for&i...;*/ /*Assuming no text formats*/
			%end;
			%else %if %lowcase("&&typ&i..") = "integer" or  %lowcase("&&typ&i..") = "float" %then %do;
				&&var&i..=.;
				format &&var&i.. &&for&i..;
			%end;
			%else %put "(User) WA" "RNING: Unexpected data type in spec &&typ&i..";
		%end;


		*Remove blank row;
		%if %lowcase("&typ1.") = "text" %then %do;
				if &var1. ne '';
				

		%end;
		%else %if %lowcase("&typ1.") = "integer" or  %lowcase("&typ1.") = "float" %then %do;
				if &var1. ne .;
		%end;
	
	run;

	*Set on attributes;
	data &out(label="&tbldesc.");
	    %do i=1 %to &maxord.;
	        %if %lowcase("&&typ&i..") = "text" %then %do;
			    length &&var&i.. $&&len&i..;
		    %end;
		%end;
		set &domain._template
	        &in.;

		*Only keep vars in spec;
		keep 
		%do i=1 %to &maxord.;
			&&var&i..
        
		%end;
		;

	run;

	proc sort data=&out.;
		by &keyvars.;
	run;
		

%mend q_attrib;
*Example call;
/*%q_attrib(domain=DM, in=dm2, out=final, loc=Z:\Evelo\EDP1867\EDP1867-101\documents\Dataset Specs\csvs);*/
/*%q_attrib(domain=ADSL, in=all7, out=final, adam=Y);*/
