/*****************************************************************************\
*        O                                                                     
*       /                                                                      
*  O---O     _  _ _  _ _  _  _|                                                
*       \ \/(/_| (_|| | |(/_(_|                                                
*        O                                                                     
* ____________________________________________________________________________
* Sponsor              :  Veramed
* Study                :  Efficiencies/Technology
* Analysis             :  
* Program              :  mass_rtf_pdf_combine_3.sas
* ____________________________________________________________________________
* Macro to combine individual RTF files into a combined, bookmarked PDF file                                                  
*                                                                   
* Input files: &inpath\*.rtf, &list.csv
*                                                                   
* Output files: &outfile.pdf                                                
*                                                                
* Macros: None                                                       
*                                                                   
* Assumptions: 
*    1. The Excel reference sheet is set up correctly (documentation needed)
*    2. For each output in the Excel reference sheet, the first non-missing
*       file entered is present in the folder &dir. This will most likely be 
*       the RTF file for tables and listings, or the PDF file for figures.
*    3. The folder &dir does not have security checks that will stop the
*       scripts from running (to be investigated in the future)
*                                                                   
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  26MAR2020  |  Hector Leitch   | Original Program                             
* ----------------------------------------------------------------------------
*  09APR2020  |  Hector Leitch   | Added Drive macro parameter
* ----------------------------------------------------------------------------
*  14MAY2020  |  Hector Leitch   | Added Ghostscript Path macro parameter
* ----------------------------------------------------------------------------
*  29MAY2020  |  Hector Leitch   | Added index to imported data
* ----------------------------------------------------------------------------
*  04FEB2021  |  Emily Berrett   | Improving robustness of call system routines
\*****************************************************************************/

%macro p_mass_rtf_pdf_combine_4(
   gspath=, /* File path of the Ghostscript executable */
   drive=, /* Drive the folder directory is under, e.g. C:, X: */
   dir=, /* Directory containing TFL files */
   refsheet=, /* Full path to Excel reference sheet */
   outfile=combined.pdf /* Name of combined PDF file */
   );

/*****************************************************************************\
* Options and reference import
\*****************************************************************************/
options noxwait;

proc import datafile="&refsheet" out=ref_import dbms=xlsx replace;
run;

data ref_import_i;
   set ref_import;
   index = _n_;
run;

/*****************************************************************************\
* Section 1: Convert RTF files to PDF
* -> Write VBS script to automate saving RTF files as PDFs using Word
\*****************************************************************************/
filename vbscript "&dir.\vbscript.vbs";

/* Write .vbs script */
data _null_;
   set ref_import_i(where=(not missing(rtf)));
   file vbscript;
   if _n_=1 then put "Const WORD_PDF = 17";
   put
      "Const WORD_IN_" _n_ "=" '"' "&dir.\" rtf '"'
    / "Const PDF_OUT_" _n_ "=" '"' "&dir.\" pdf '"'
    / "Set objWord = CreateObject(""Word.Application"")"
    / "objWord.Visible = False"
    / "Set objDocument = objWord.Documents.Open(WORD_IN_" _n_ ",,False)"
    / "objDocument.SaveAs PDF_OUT_" _n_ ", WORD_PDF"
    / "objDocument.Close False"
    / "objWord.Quit"
    ;
run;
filename vbscript;

/* Execute .vbs script then delete */
data _null_;
   call system("""&dir.\vbscript.vbs""");
   call system("del /q ""&dir.\vbscript.vbs""");
run;

/*****************************************************************************\
* Section 2: Add bookmarks to individual PDFs
* -> Write a text file for each PDF that fixed the desired bookmark on page 1
* -> Write a BAT script that attached the bookmark to the PDF using Ghostscript
\*****************************************************************************/
proc sql noprint;
   select distinct index, pdf, temp into :index_list, :pdf_list separated by ' ', :temp_list separated by ' '
   from ref_import_i
   where not missing(pdf) and not missing(temp)
   order by index;
quit;

%do i=1 %to %sysfunc(countw(&pdf_list., %str( )));
   %let input = %scan(&pdf_list., &i., %str( ));
   %let output = %scan(&temp_list., &i., %str( ));
   %let batscript = &dir.\batscript&i..bat;
   %let bookmark = &dir.\bookmark&i..txt;

/* Write .txt file */
   data _null_;
      file "&bookmark.";
      set ref_import_i(where=(pdf eq "&input."));
      line = '[/Title  (' || strip(bookmark) || ')  /Page ' || compress(put(1,8.)) || ' /OUT pdfmark';
      put line;
   run;

/* Write .bat script */
   data _null_;
      file "&batscript.";
      put 
         "cd \"
       / "&drive."
       / "cd &dir."
       / '"' "&gspath." '"' " -sDEVICE=pdfwrite -dNOPAUSE -dBATCH -dSAFER -sOutputFile=&output. &input. bookmark&i..txt"
       ;
   run;


/* Run .bat script and delete */
   data _null_;
      call system("""&batscript.""");
      call system("del /q ""&batscript.""");
      call system("del /q ""&bookmark.""");
   run;

%end;


/*****************************************************************************\
* Section 3: Combine bookmarked PDFs
* -> Write a BAT script that combines bookmarked PDFs using Ghostscript
\*****************************************************************************/

/* Write .bat script */
data _null_;
   file "&dir.\batscript.bat";
   put 
      "cd \"
    / "&drive."
    / "cd &dir."
    / '"' "&gspath." '"' " -sDEVICE=pdfwrite -dNOPAUSE -dBATCH -dSAFER -sOutputFile=&outfile. &temp_list."
    ;
run;


/* Run .bat script and delete */
data _null_;
   call system("""&dir.\batscript.bat""");
   call system("del /q ""&dir.\batscript.bat""");
run;


/* Create tidyup section? */
/*****************************************************************************\
* Section 4: Tidyup the created individual PDFs
* -> Determine which PDFs were created in Section 1 and Section 2 and delete
\*****************************************************************************/


%mend p_mass_rtf_pdf_combine_4;

/*
%mass_rtf_pdf_combine_3(
   gspath=C:\Program Files\gs\gs9.52\bin\gswin64.exe,
   drive=X:,
   dir=X:\Orchard\OTL-103\OTL-103-23\TFLs\output,
   refsheet=X:\Orchard\OTL-103\OTL-103-23\TFLs\output\tests\Bookmarks - 14.1 Demographics.xlsx,
   outfile=combined.pdf
   );
*/
