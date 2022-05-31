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
* Program              : q_compy.sas
* Purpose              : QC macro to compare prod and QC datasets
* ____________________________________________________________________________
* DESCRIPTION                                                    
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
*  12AUG2021  |  Natalie Thompson  |  Original (Code copied from 1815-201 Setup)                                   
* ----------------------------------------------------------------------------
*  10NOV2021  |  Natalie Thompson  |  Updated for GPP.         
\*****************************************************************************/

%macro q_compy(arset = , /* Production dataset name */
             qcset = , /* QC dataset name */
            byvars = , /* Dataset sorting (key) variables */ 
         criterion = 0.00001,
            method = absolute,
         sourcelib = , /* Source library for production dataset e.g. adam, dddata, etc. */
           display = ,
       ignorelabel = N);

    options ps=max;

    proc sort data=&qcset out = qc_dset;
      by &byvars;
    run;

    proc compare base=&sourcelib..&arset compare=qc_dset listvar criterion=&criterion method=&method maxprint=(50,2000);
      title "PROC COMPARE of observations in &sourcelib (&arset) and QC dataset (&qcset)";
      id &byvars;
      %if &ignorelabel=Y %then attrib _all_ label=' ';;
    run;

    data anotb bnota both;
      merge &sourcelib..&arset(in=a) qc_dset(in=b);
      by &byvars;
      if a and b then output both;
      if a and not b then output anotb;
      if b and not a then output bnota;
    run;

    proc print data=anotb (obs=50);
      title "Observations in &sourcelib (&arset) but not QC dataset (&qcset)";
      %if &display^=ALL %then var &byvars;;
    run;

    proc print data=bnota (obs=50);
      title "Observations in QC (&qcset) but not Source dataset (&arset)";
      %if &display^=ALL %then var &byvars;;
    run;

%mend q_compy;
