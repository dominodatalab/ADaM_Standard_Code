/*****************************************************************************\
*        O
*       /
*  O---O     _  _ _  _ _  _  _|
*       \ \/(/_| (_|| | |(/_(_|
*        O
* _____________________________________________________________________________
* Sponsor              : Orchard
* Study                : OTL-103
* Program              : u_breakvar.sas
* Purpose              : Macro to add in breaks to variables to force flow 
*                        across rows on a space or a '/' in output
* _____________________________________________________________________________
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
* Usage notes: (1) var = variable that needs to break across lines
*                  newvar = new variable to output var + breaks
*                  break = character/string to use as a break, default |n
*                  length = max length of text before a break
*                  slashyn = Y/N break on a forward slash if no other options
*              (2) Macro should be used within a data step, can be used multiple times in one step
*              (3) If &var and &newvar are the same, a note is put out that &var will be overwritten.
*                  In this case you should make sure the original variable has a big enough
*                  length to accommodate an unknown number of break characters being added
*              (4) You should set the length of the new variable prior to calling the macro
*              (5) If there are multiple spaces between words and it breaks here, all spaces are removed
*              (6) A '/' is only used to break if there are no available spaces in a substring - optional
_____________________________________________________________________________
* PROGRAM HISTORY
*  19FEB2020  |  Emily Berrett       |  Original
* -----------------------------------------------------------------------------
*
\*****************************************************************************/

%macro p_breakvar(var=,newvar=,break=|n,length=,slashyn=N);

  length __temp __sub1 __rem1 $200 __len1 8 __sub2 __rem2 $200;

  /*Set temporary var for manipulation of values*/
  __temp = &var;

  /*If original variable will be overwritten, set to blank so it's not duplicated*/
  %if &newvar = &var %then %do;
      %put %str(N)OTE: Original variable &var will be replaced. Ensure length is long enough to avoid truncation with addition of breaks.;
      &var = '';
  %end;

  do until (__temp = ''); /*Stop when temporary var is empty*/
    __sub1 = '';
    __rem1 = '';
    __len1 = .;
    __sub2 = '';
    __rem2 = '';
    __sub1 = substr(__temp,1,&length); /*Substring to max number of characters to break at*/
    __rem1 = substr(__temp,&length+1); /*Set remainder of string in another variable*/
    if substr(__temp,&length,1) ^= '' and substr(__rem1,1,1) ^= '' then do; /*Check if break is at a space already*/
       __len1 = findc(__sub1,'',1,'bst'); /*If not then find length of string up to previous space before max*/
    end;
    %if %upcase(&slashyn)= Y %then %do;
      if substr(__temp,&length,1) ^= '' and substr(__rem1,1,1) ^= '' and index(strip(__sub1),'') = 0 then do; /*If there is no space to break on try to break on a slash instead */
         __len1 = findc(__sub1,'/',1,'bst'); /*Get length upto previous slash instead*/
      end;
    %end;
    if __len1 in (0 .) then __len1 = length(__sub1); /*If not already covered, don't need to move break so keep length of current substring*/
    __sub2 = substr(__temp,1,__len1); /*New substring taking only to last space within max characters*/
    __rem2 = strip(substr(__temp,__len1+1)); /*And substring of remainder at space*/

    if __sub1 ^= __temp then do; /*If not at the last instance of needing to break*/
       &newvar = strip(&newvar)||trim(__sub2)||"&break"; /*Create new variable with cumulative concatenation of new value and current substring plus breaking character*/
       __temp = __rem2; /*Temporary var now becomes the remainder not yet processed*/
    end;
    else do; /*If at the last instance*/
       &newvar = strip(&newvar)||trim(__sub2); /*Concatentate final string without breaking space at end*/
       __temp = ''; /*Set temporary var to missing to leave cycle*/
    end;
  end;

  drop __temp __sub1 __rem1 __len1 __sub2 __rem2;

%mend p_breakvar;
