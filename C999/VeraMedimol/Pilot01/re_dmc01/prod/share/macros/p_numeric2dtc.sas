/*****************************************************************************\
*        O                                                                      
*       /                                                                       
*  O---O     _  _ _  _ _  _  _|                                                 
*       \ \/(/_| (_|| | |(/_(_|                                                 
*        O                                                                      
* ____________________________________________________________________________
* Sponsor              :  Evelo
* Study                :  EDP1815-201
* Analysis             :  -
* Program              :  p_numeric2iso
* Purpose              :  create character date for full and partial dates
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files: input dataset                                                   
*                                                                   
* Output files: output dataset                                                 
*                                                                 
* Macros: None                                                         
*                                                                   
* Assumptions: Missing dates will have month and year, just year or nothing 
*       and missing parts will be in the format UN UNK UNKN  
*       both character and numeric date variables will be provided 
*                                                                   
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  06NOV2020  |  Emily Jones      | Original                                    
* ----------------------------------------------------------------------------
*  14JAN2021  |  Natalie Thompson  |  Updated missing year to be in the form "UNKN" as well as "0000".
*                                     Updated so all missing dates are now displayed missing . (NT14JAN)
\*****************************************************************************/

%macro p_numeric2dtc( dsetin = /*input dataset*/,
            dtin = /*numeric input date*/,
            time = N /*set to Y if numeric date includes time*/,
            dtinc = /*character input date*/,
            dtoutc = /*character output date*/,
            dsetout = /*output dataset*/,
            tidyup = Y /*set to N to stop day month year vars to be dropped*/,
            prefix = _ /*prefix for day month variables - default _*/
          );

  **create month format;
  proc format;
      value $ month
        "JAN" = "01"
        "FEB" = "02"
        "MAR" = "03"
        "APR" = "04"
        "MAY" = "05"
        "JUN" = "06"
        "JUL" = "07"
        "AUG" = "08"
        "SEP" = "09"
        "OCT" = "10"
        "NOV" = "11"
        "DEC" = "12"
        ;
  run;

  data &dsetout. %if "&tidyup" = "Y" %then %do; (drop = &prefix:) %end;;
    length &dtoutc. $10.;
    set &dsetin.;

    **dates;
    **full date;


    if &dtin. ~= . then do;
        *take date part if numeric datetime var;
        if "&time." = "Y" then do;
          &prefix.dtin = datepart(&dtin.);
        end;

        else do;
          &prefix.dtin = &dtin.;
        end;
        **character date; 
        &dtoutc. = put(&prefix.dtin,e8601da.);
    end;

     **partial date;
    else if &dtinc. ~= "" then do;
        &prefix.day = substr(&dtinc.,1,2);

        &prefix.month = substr(&dtinc.,4,3);
        &prefix.year =  substr(&dtinc.,8,4);

        **character date (NT14JAN: added UNKN);
        if &prefix.day = "UN" and &prefix.month ~= "UNK" and &prefix.year not in ("0000", "UNKN") then do;
          &dtoutc.  = catt(&prefix.year,"-",put(&prefix.month,$month.),"-XX");
        end;
        ** date and month missing (NT14JAN: added UNKN);
        else if &prefix.day = "UN" and &prefix.month = "UNK" and &prefix.year not in ("0000", "UNKN") then do;
          &dtoutc.  = catt(&prefix.year,"-XX-XX");
        end;

		** NT14JAN: if completely missing date **;
        else &dtoutc.  = "";

    end;
  run;

%mend p_numeric2dtc;
    
        
