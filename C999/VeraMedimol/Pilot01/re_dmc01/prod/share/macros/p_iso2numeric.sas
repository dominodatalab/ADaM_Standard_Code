/*****************************************************************************\
*        O                                                                     
*       /                                                                      
*  O---O     _  _ _  _ _  _  _|                                                
*       \ \/(/_| (_|| | |(/_(_|                                                
*        O                                                                     
* ____________________________________________________________________________
* Sponsor              : Evelo
* Study                : EDP1867-101
* Analysis             : Primary
* Program              : p_iso2numeric.sas                   
* ____________________________________________________________________________
* Macro to convert the date and time in ISO8601 format to numeric day, month,
* year, date, hour, minutes, seconds, time and or datetime values                                                   
*                                                                   
* Input files: None                                                   
*                                                                   
* Output files: None                                                  
*                                                                
* Macros: p_iso2numeric                                                        
*                                                                   
* Assumptions: None                                                   
*                                                                   
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  26JUL2021  |   Kaja Najumudeen | Original version of the code
*-----------------------------------------------------------------------------
*  06OCT2021  |   Kaja Najumudeen | Updated the sequence of date time assignment
*             |                   | and to handle the full time but partial dates
*             |                   | cases
\*****************************************************************************/

%macro p_iso2numeric(isodate=,nyr=,nmn=,ndy=,ndt=,nhr=,nms=,nss=,ntm=,ndttm=)/mindelimiter=' ';
option validvarname=v7 MAUTOSOURCE minoperator;
length _date_ $10. _time_ $8.;
%if %bquote(%superq(nyr)) eq %then %let nyr=&isodate._yr;
%if %bquote(%superq(nmn)) eq %then %let nmn=&isodate._mn;
%if %bquote(%superq(ndy)) eq %then %let ndy=&isodate._dy;
%if %bquote(%superq(ndt)) eq %then %let ndt=&isodate._dt;
%if %bquote(%superq(nhr)) eq %then %let nhr=&isodate._hr;
%if %bquote(%superq(nms)) eq %then %let nms=&isodate._ms;
%if %bquote(%superq(nss)) eq %then %let nss=&isodate._ss;
%if %bquote(%superq(ntm)) eq %then %let ntm=&isodate._tm;
%if %bquote(%superq(ndttm)) eq %then %let ndttm=&isodate._dttm;

%if &isodate. ne %then %do;
  call missing(dpart_n,dpart_yr,dpart_mn,dpart_dy);
  call missing(tpart_n,tpart_hr,tpart_ms,tpart_ss);
  if &isodate ne '' then do;
    if index(strip(&isodate.),"T") >0 then do;
      _date_=scan(strip(&isodate.),1,"T");
	  _time_=scan(strip(&isodate.),2,"T");
	end;
	else do;
      _date_=strip(&isodate.);
	  _time_='';
	end;
	array &isodate._dp dpart_yr dpart_mn dpart_dy;
	array &isodate._tp tpart_hr tpart_ms tpart_ss;
/*    do while (index(_date_,'-') ne 0); */
	do over &isodate._dp;
	  if substr(_date_,1,2)="--" then do;
        &isodate._dp=.;
		_date_=substr(_date_,index(_date_,'-')+1);
	  end;
	  else &isodate._dp=input(scan(_date_,1,"-"),best.);
      if index(_date_,"-") gt 0 then _date_=substr(_date_,index(_date_,'-')+1);
	  else call missing(_date_);
    end;
	do over &isodate._tp;
	  if substr(_time_,1,1)="-" then do;
        &isodate._tp=.;
	  end;
	  else &isodate._tp=input(scan(_time_,1,":"),best.);
      if index(_time_,":") gt 0 then _time_=substr(_time_,index(_time_,':')+1);
	  else call missing(_time_);
    end;
    if length(compress(&isodate)) not in (10,16,19) then do;
      put "UNOTE: The input variable &isodate. is either partial or not in correct format " &isodate.=;
	end;
/*    yr=substr(&isodate,1,4);mn=substr(&isodate,6,2);dy=substr(&isodate,9,2);*/
    if length(compress(&isodate)) in (10,16,19) then do;
      dpart_n=input(substr(&isodate,1,10),?? yymmdd10.);

      if length(compress(&isodate)) eq 16 then do;
        tpart_n=input(scan(&isodate,2,'T'),?? time5.);
	  end;
      else if length(compress(&isodate)) eq 19 then do;
        tpart_n=input(scan(&isodate,2,'T'),?? time8.);
	  end;
    %if &ndttm ne %then %do;
      if length(compress(scan(&isodate,2,'T'))) eq 5 then &ndttm=input(trim(&isodate)||':00',?? anydtdtm.);
      else &ndttm=input(&isodate,?? anydtdtm.);
	  format &ndttm datetime19.;
    %end; 
    end;
	else if length(compress(scan(&isodate,2,'T'))) eq 5 then do;
      tpart_n=input(scan(&isodate,2,'T'),?? time5.);
	end;
	else if length(compress(scan(&isodate,2,'T'))) eq 8 then do;
      tpart_n=input(scan(&isodate,2,'T'),?? time8.);
	end;
    %if &ndt. ne %then %do;
      &ndt.=dpart_n; 
	  format &ndt date9.;
    %end;
    %if &ntm. ne %then %do;
      &ntm.=tpart_n;
	  format &ntm. time8.;
    %end;

/*    else do;*/
	  *Individual Date component;
	  %if &nyr. ne %then %do;
        &nyr.=dpart_yr;
	  %end;
	  %if &nmn. ne %then %do;
        &nmn.=dpart_mn;
	  %end;
	  %if &ndy. ne %then %do;
        &ndy.=dpart_dy;
	  %end;
      *Individual Time component;
      %if &nhr. ne %then %do;
        &nhr.=tpart_hr;
      %end;
      %if &nms. ne %then %do;
        &nms.=tpart_ms;
      %end;
      %if &nss. ne %then %do;
        &nss.=tpart_ss;
      %end;
/*	end;*/
	/*Validate the ISO dates during its conversion to numeric*/
    &isodate._vdp=catx("-",
                   ifc(nmiss(dpart_yr)=0,strip(put(dpart_yr,best.)),'-'),
                   ifc(nmiss(dpart_mn)=0,strip(put(dpart_mn,z2.)),'-'),
                   ifc(nmiss(dpart_dy)=0,strip(put(dpart_dy,z2.)),'-'));
	&isodate._vdp=strip(&isodate._vdp);
    &isodate._vtp=catx(":",
                   ifc(nmiss(tpart_hr)=0,strip(put(tpart_hr,z2.)),'-'),
                   ifc(nmiss(tpart_ms)=0,strip(put(tpart_ms,z2.)),'-'),
                   ifc(nmiss(tpart_ss)=0,strip(put(tpart_ss,z2.)),'-'));
    &isodate._vtp=strip(&isodate._vtp);
	if strip(&isodate._vtp)="-:-:-" then &isodate._vtp='';
	else if substr(reverse(strip(&isodate._vtp)),1,2)="-:" then &isodate._vtp=reverse(substr(reverse(strip(&isodate._vtp)),3));
    if &isodate._vtp='' then do;
	  if strip(&isodate._vdp)="-----" then &isodate._vdp='';
	  else if substr(reverse(strip(&isodate._vdp)),1,4)="----" then &isodate._vdp=reverse(substr(reverse(strip(&isodate._vdp)),5));
	  else if substr(reverse(strip(&isodate._vdp)),1,2)="--" then &isodate._vdp=reverse(substr(reverse(strip(&isodate._vdp)),3));
    end;

    &isodate._vdtp=catx("T", &isodate._vdp,&isodate._vtp);
	if strip(&isodate._vdtp) ne strip(&isodate.) then 
	put "UWA" "RNING: Dates are not as per ISO8601 format " &isodate.= &isodate._vdtp=;
    call missing(dpart_n,dpart_yr,dpart_mn,dpart_dy);
    drop dpart_n dpart_yr dpart_mn dpart_dy;
    call missing(tpart_n,tpart_hr,tpart_ms,tpart_ss);
    drop tpart_n tpart_hr tpart_ms tpart_ss;
	drop _date_ _time_;
	drop &isodate._vdp &isodate._vtp &isodate._vdtp;
  end;
 
%end;
%else %put ERROR: The ISO8601 datetime variable is not supplied. Please check the argument;
%mend p_iso2numeric;

