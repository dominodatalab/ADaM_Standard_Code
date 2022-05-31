/*****************************************************************************\
*        O                                                                     
*       /                                                                      
*  O---O     _  _ _  _ _  _  _|                                                
*       \ \/(/_| (_|| | |(/_(_|                                                
*        O                                                                     
* ____________________________________________________________________________
* Sponsor              :  Evelo
* Study                :  EDP1867-101
* Analysis             :  Final Analysis
* Program              :  qc_logcheck.sas
* Purpose              :  Check QC Logs (Prod logs checked in individual QC programs)
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
* 22DEC2020  |  Nancy Carpenter  | Original                                   
* ----------------------------------------------------------------------------
* 09AUG2021  |  Laya Jacob       | copied from 1815-201      
* ----------------------------------------------------------------------------
* 12AUG2021  |  Natalie Thompson  |  Updated to include logchecker macro code.
* ----------------------------------------------------------------------------
* 13AUG2021  |  Natalie Thompson  |  Removed logchecker calls for all logs (now stored in qc_all_logs).
* ----------------------------------------------------------------------------
* 17AUG2021  |  Kaja Najumudeen   | Updated the name of the macro to be the same as that of the program name
\*****************************************************************************/

/* NT12AUG2021: Log-checker macro code to enable the calls below to run */
%macro q_logcheck(filelist,                            /* List of Logs to check */
                  _loc=&lib.\prod,                     /* Location of SAS logs  */
                  _type=TFLs,                          /* type of log to check  */
                  print=Y);

    %if &filelist=ALL %then %do;

         filename _logs "&_loc.\&_type.\saslogs";

         data arfiles;
           rc = DOPEN("_logs");
           nfiles = DNUM(rc);
           DO i = 1 TO nfiles;
             file = DREAD(rc,i);
             if index(upcase(file),".LOG") then do;
                file=scan(compress(file),1,".");
                output;
             end;
           END;
           rc=DCLOSE(rc);
         run;

         data _null_;
           set arfiles;
           call symput("file"!!compress(put(_n_,best.)),compress(file));
           call symput("allfiles",compress(put(_n_,best.)));
         run;

    %end;
    %else %do;

        data arfiles;
         files=lowcase("&filelist");
         do x=1 to 1000;
           file=scan(files,x," ");
           if file eq "" then leave;
           if index(file,".log") then file=scan(compress(file),1,".");
           output;
         end;
        run;

        data _null_;
          set arfiles;
          call symput("file"!!compress(put(_n_,best.)),compress(file));
          call symput("allfiles",compress(put(_n_,best.)));
        run;

    %end;

    %do j=1 %to &allfiles;

       filename _in_file "&_loc.\&_type.\saslogs\&&file&j...log";

       data _null_;
          call symput("fexist",fexist("_in_file"));

          fid=fopen("_in_file");
          call symput("fdate&j", tranwrd(finfo(fid, "Last Modified"), " o'clock", ""));
          close=fclose(fid);
       run;

       %if &fexist=1 %then %do;

       data &&file&j.._p(keep=string1);
        length string1  $98;
        infile _in_file lrecl=401 missover pad;
        input string1 $1-400;
        if  (         upcase(string1)=:"INFO:"
             or       upcase(string1)=:"ERROR"
             or       upcase(string1)=:"WARNING"
             or       upcase(string1)=:"NOTE: INVALID"
             or       upcase(string1)=:"NOTE: LIBRARY"
             or       upcase(string1)=:"NOTE: MERGE S"
             or       upcase(string1)=:"NOTE: A HARDW"
             or       upcase(string1)=:"NOTE: CHARACT"
             or       upcase(string1)=:"NOTE: MISSING"
             or       upcase(string1)=:"NOTE: DIVISIO"
             or       upcase(string1)=:"NOTE: MATHEMA"
             or       upcase(string1)=:"NOTE: INTERAC"
             or index(upcase(string1), "W.D FORMAT")
             or index(upcase(string1), "UNINI")
             or index(upcase(string1), "REPEATS"));

         if    index(upcase(string1),"WARNING: YOUR SYSTEM IS SCHEDULED TO EXPIRE")
            or index(upcase(string1),"WARNING: THE BASE SAS SOFTWARE PRODUCT")
            or index(upcase(string1),"PROC SETINIT TO OBTAIN") 
            or index(upcase(string1),"NATIVE TO ANOTHER HOST")
            or index(upcase(string1),"MLOGIC")
            or index(upcase(string1),"MPRINT")
         then delete; 
       run;

       proc sql noprint;
          select count(*) into: &&file&j.._a from &&file&j.._p;
       quit;

       %end;
       %else %do;

         data &&file&j.._p(keep=string1);
           length string1  $200;
           string1="!!LOGCHECKER!! SPECIFIED FILE DOES NOT EXIST - PLEASE CHECK MACRO CALL";
         run;

       %end;

    %end;

    data allprobs;
       length file fdate $30;
       %do j=1 %to &allfiles;
          file="&&file&j...log";
          fdate="&&fdate&j";
          probs=&&&&&&file&j.._a;
          output;
       %end;
    run;
    data allprobs_full;
       length file $30;
       set %do j=1 %to &allfiles;
              &&file&j.._p (in=_&j)
           %end;;
       %do j=1 %to &allfiles;
           if _&j then file="&&file&j";
       %end;
    run;

   proc print data=allprobs;
        title "SUMMARY OF LOG ISSUES (Location: &_loc.\&_type.\saslogs)";
   run;

   %if &print=Y %then %do;
     %do j=1 %to &allfiles;

       proc report data=&&file&j.._p nowd;
          title "LOG ISSUES (&_loc.\&_type.\saslogs\&&file&j...log)";
          column string1;
          define string1 / display "Log issue"  flow;
       run;

     %end;
   %end;

   title; footnote;
%mend;





