/*****************************************************************************\
*  ____                  _
* |  _ \  ___  _ __ ___ (_)_ __   ___
* | | | |/ _ \| '_ ` _ \| | '_ \ / _ \
* | |_| | (_) | | | | | | | | | | (_) |
* |____/ \___/|_| |_| |_|_|_| |_|\___/
* ____________________________________________________________________________
* Sponsor              : C999
* Study                : PILOT01
* Program              : t_disp_all.SAS
* Purpose              : Create disposition table for all population
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files: None
*              
* Output files: t_13_01_01_disp_all
*               
* Macros: init scanlog
*         
* Assumptions: 
*
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  22MAR2022  | Lindsey Megarry-Jones | Original version
* ----------------------------------------------------------------------------
\*****************************************************************************/

*********;
%include "!DOMINO_WORKING_DIR/config/domino.sas";
*********;

%let linesperpage = 25 ;
%let flag = ittfl ;
%let dddata = t_disp_all ;
%let tflid = t_13_01_01_disp_all ;
%let shell=TDISP1 ;
%let shell_file = Z:\Users\lindsey.megarry\veramedimol\C006\VeraMedimol\Pilot01\re_dmc01\documents\SAP_and_shells\Shells v0.2.xlsx ;
%let tfl_style=C999 ;

/*get report totals*/
data total ;
   set adamw.adsl ;
    output ;
   trt01pn=99 ;
   trt01p='Total' ;
    output ;
run ;

/*get bigns*/
proc sql noprint ;
   select count(distinct usubjid) into :pop1 - :pop4 
   from total
   group by trt01pn
   ;

   create table popt as
   select trt01pn, trt01p, count(distinct usubjid) as popt 
   from total
   group by trt01pn, trt01p
   ;

quit ;
%put &=pop1 &=pop2 &=pop3 &=pop4 ;

/*first line of report*/
%macro poptot (pop=) ;
proc sql noprint ;
   create table &pop. as
   select trt01pn, trt01p, count(distinct usubjid) as &pop.
   from total
   where &pop. = 'Y'
   group by trt01pn, trt01p
   order by trt01pn
   ;
quit ;

/*merge in pop totals to get %*/
data &pop.2 ;
   merge &pop. 
         popt ;
   by trt01pn trt01p ;
   length &pop.2 $200 ;
   if &pop./popt*100=100 then do ;
      &pop.perc= &pop./popt*100 ;
      &pop.2=put(&pop., 3.)||" (100% )" ;
   end ;
   else do ;
      &pop.perc = round(&pop./popt*100, 0.1) ;
      &pop.2=put(&pop., 3.)||" ("||put(&pop.perc, 4.1)||"%)" ;
   end ;
run ;

proc transpose data=&pop.2
               out= tran_&pop. 
               prefix=_;
   var &pop.2; /*numerical vars that were across but now down*/
   id trt01pn ;
   idlabel trt01p ;
run ;
   
%mend ;
%poptot(pop=ittfl) ;
%poptot(pop=saffl) ;
%poptot(pop=efffl) ;

data rep1 ;
   set tran_: ;
   length text $200 TRT1-TRT4 $100 ;
   if _NAME_='ittfl2' then do ;text='Intent-to-treat set [a]'; order=1; end ;
   else if _NAME_='saffl2' then do ;text='Safety set [b]'; order=2; end ;
   else if _NAME_='efffl2' then do ;text='Efficacy set [c]'; order=4; end ;

   TRT1=_0 ;
   TRT2=_54 ;
   TRT3=_81 ;
   TRT4=_99 ;

   keep text TRT: order;
run ;

proc sort data = rep1 ;
   by order ;
run ;
/*=====================================================================================*/
/*patients randomized who did not receive treatment*/
data no_trt ;
   merge total (where=(ittfl = 'Y')
                in=itt)
         total (keep=usubjid trt01pn trt01p saffl
                rename=(saffl=saffl2)
                where=(saffl2 = 'Y')
                in=saf) ;
   by usubjid trt01pn trt01p ;
   if (itt) and ^(saf) ;
run ;

/*dummy with same columns*/
proc sql noprint ;
   create table no_trt2 as
   select * from rep1 where 1=2
   ;

   insert into no_trt2 (text, TRT1, TRT2, TRT3, TRT4, order)
   values ("Patients who did not receive treatment", "  0","  0","  0","  0",3) 
   ;
quit ;

/*=====================================================================================*/
/*need to do some pre-work before using u_freq*/
proc format;
   picture pctmf (round)
               .     = ' '        (noedit)
        low-0.001    = ' '        (noedit)
        0.001-<0.1   = '(<0.1%)'  (noedit)
              0.1-<1 =   '9.9%)'  (prefix='(')
         1-<99.90001 =  '00.0%)'  (prefix='(')
       99.90001-<100 = '(>99.9%)' (noedit)
                 100 = '(100%)'   (noedit)
   ;

   invalue nyn
      'Y'=1
      'N'=2
      ' '=.
   ;
   value $nytxt
      'Y'="Patients who completed week 24"
      'N'='Patients who terminated prior to week 24 (Early Termination)'
      ' '=' '
   ;

run ;

%let numtrt=4 ;


data freq ;
   set total ;
   if trt01pn=0 then trt01pn2=1 ;
   else if trt01pn=54 then trt01pn2=2 ;
   else if trt01pn=81 then trt01pn2=3 ;
   else if trt01pn=99 then trt01pn2=4 ;
run ;
%u_pop(inds=freq, trtvarn=trt01pn2) ;

%u_freq(     inds=freq,
             outds=comp24,
             countvar=complfl,
             trtvarn=trt01pn2,
             display=COUNTPERC,
             denom=POP,
             percfmt=pctmf,
             order=5,
             sorderfmt=nyn,
             textfmt=nytxt
      );

/*reasons for termination*/
proc format ;
   value $reas
      'Adverse Event' = '   Adverse event'
      'Death' = '   Death'
      'Lack of Efficacy' = '   Lack of efficacy [d]'
      'Lost to Follow-up' = '   Lost to follow-up'
      'Withdrew Consent' = '   Subject decided to withdraw'
      'Physician Decision' = '   Physician decided to withdraw subject'
      'I/E Not Met' = '   Protocol criteria not met'
      'Protocol Violation' = '   Protocol violation'
      'Sponsor Decision' = '   Sponsor decision'
      ;
   invalue reasn
      'Adverse Event' = 1
      'Death' = 2
      'Lack of Efficacy' = 3
      'Lost to Follow-up' = 4
      'Withdrew Consent' = 5
      'Physician Decision' = 6
      'I/E Not Met' = 7
      'Protocol Violation' = 8
      'Sponsor Decision' = 9
      ;

run ;

%u_freq(     inds=freq,
             outds=reas,
             countvar=dcsreapl,
             where=COMPLFL = 'N',
             trtvarn=trt01pn2,
             display=COUNTPERC,
             denom=POP,
             percfmt=pctmf,
             forcefmt=$reas,
             order=6,
             sorderfmt=reasn,
             textfmt=$reas
      );

/*stck together and provide labels*/
data _null_ ;
   set popt ;
   call symputx('lab'||strip(put(trt01pn,2.-l)), trt01p) ;
run ;

data rep2 ;
   set rep1 
       no_trt2
       comp24 (drop= counttype complfl _name_ )
       reas (drop= counttype dcsreapl _name_);
   by order ;

   label trt1 = "&lab0. $(N=&pop1.)"
         trt2 = "&lab54. $(N=&pop2.)"
         trt3 = "&lab81. $(N=&pop3.)"
         trt4 = "&lab99. $(N=&pop4.)"
        ;
run ;

/*=====================================================================================*/
data tflw.&dddata. ;
   set rep2 ;
run ;

/*style*/
proc template;
   define style Styles.C999RTF;
      parent = Styles.RTF;

   replace Body from Document /
      bottommargin = 1.54cm
      topmargin = 2.54cm
      rightmargin = 2.54cm
      leftmargin = 2.54cm;

   replace fonts /
           'TitleFont2' = ("Courier New",9pt)
           'TitleFont' = ("Courier New",9pt/*,Bold*/)     /* titles */
           'StrongFont' = ("Courier New",9pt/*,Bold*/)
           'EmphasisFont' = ("Courier New",9pt,Italic)
           'FixedEmphasisFont' = ("Courier New, Courier",9pt,Italic)
           'FixedStrongFont' = ("Courier New, Courier",9pt/*,Bold*/)
           'FixedHeadingFont' = ("Courier New, Courier",9pt/*,Bold*/)
           'BatchFixedFont' = ("SAS Monospace, Courier New, Courier",9pt)
           'FixedFont' = ("Courier New, Courier",9pt)
           'headingEmphasisFont' = ("Courier New",9pt,Bold Italic)
           'headingFont' = ("Courier New",9pt/*,Bold*/)   /* header block */
           'docFont' = ("Courier New",9pt);           /* table cells */


   replace color_list
         "Colors used in the default style" /
         'link' = blue
         'bgH' = white     /* header background */
         'fg' = black
         'bg' = _undef_;

end;

run ;

ods escapechar="~" ;

title1 justify=l "Protocol: CDISCPILOT01" j=r "Page ~{thispage} of ~{lastpage}" ;
title2 justify=l "Population: Intent-to-treat" ;
title3 justify=c "Table 13.01.01 Summary of Patient Disposition (ITT)" ;

footnote1 justify=l "[a] All patients randomized." ;
footnote2 justify=l "[b] All randomized subjects known to have taken at least one dose of randomized study drug.";
footnote3 justify=l "[c] All subjects in the receiving treatment who also have at least one post-baseline ADAS-Cog and CIBIC+ assessment." ;
footnote4 justify=l "[d] Based on either patient/caregiver perception or physician perception." ;
footnote5 justify=l "Percentages are calculated from the number of patients randomized.";
footnote6 ;
footnote7 justify=l "Source: Z:\Users\lindsey.megarry\veramedimol\C999\VeraMedimol\Pilot01\re_dmc01\prod\tfl\code\t_dips_all.sas, %sysfunc(date(),date9.) %sysfunc(time(),tod5.)" ;


options nofontembedding noquotelenmax nodate nonumber orientation=landscape ls=132 ps=52 center missing=' ' ;

ods listing close;
ods rtf file= "Z:\Users\lindsey.megarry\veramedimol\C999\VeraMedimol\Pilot01\re_dmc01\prod\tfl\output\&tflid..rtf" 
       style=&tfl_style.rtf ;
*------------------------------------------------------------------------------;
proc report data=tflw.&dddata. split='$' nowindows spacing=2 missing 
   style(report)=[width=100% just=center] 
   style(header)=[borderbottomcolor=black borderbottomwidth=2 
                  bordertopcolor=black bordertopwidth=2just=center] style=&tfl_style.rtf ;

  column order text TRT1-TRT4;


  define order  /order order=data noprint;

  define text   / display  flow "" style(column)=[asis=on just=left width=55%] style(header)=[asis=on just=left] ;
  define trt1   / display  style(column)=[just=left width=11% asis=on leftmargin = 1%] style(header)=[asis=on just=c ] ;
  define trt2   / display  style(column)=[just=left width=11% asis=on leftmargin = 1%] style(header)=[asis=on just=c] ;
  define trt3   / display  style(column)=[just=left width=11% asis=on leftmargin = 1%] style(header)=[asis=on just=c] ;
  define trt4   / display  style(column)=[just=left width=11% asis=on leftmargin = 1%] style(header)=[asis=on just=c] ;

  compute before;
     if order = 1;
     line '';
  endcomp;

  compute after _PAGE_	/style=[borderbottomcolor=black borderbottomwidth=2];
    line ' ';
  endcomp;

run;

*------------------------------------------------------------------------------;
ODS RTF close;
ODS listing;
title; footnote;



**** END OF USER DEFINED CODE **;

********;
%s_scanlog;
********;

