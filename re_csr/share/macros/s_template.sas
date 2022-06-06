 /*****************************************************************************\
*        O                                                                      
*       /                                                                       
*  O---O     _  _ _  _ _  _  _|                                                 
*       \ \/(/_| (_|| | |(/_(_|                                                 
*        O                                                                      
* ____________________________________________________________________________
* Sponsor              : Veramed
* Study                : <STUDY>
* Program              : s_template
* Purpose              : Standard Veramed PROC Template
* ____________________________________________________________________________
* DESCRIPTION   
*           Standard macro for storing PROC TEMPLATES
*           These will be hels as WORK templates
*    
* Input Macro Parameters
*
* Input files: None
*              
* Output files: none
*               
* Macros: None
*         
*
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*          |         |         
\*****************************************************************************/

%macro s_template();

    %PUT TRACE: [Macro: s_template] Started;

    %** DEFAULT Veramed Style **;
    %** Copy and rename is newe clinet style needed **;

    proc template;
        define style VeraRTF;
            parent = Styles.RTF;

        replace Body from Document /
            bottommargin = 1.54cm
            topmargin    = 2.54cm
            rightmargin  = 2.54cm
            leftmargin   = 2.54cm;

        replace fonts /
               'TitleFont2'          = ("Courier New",9pt)
               'TitleFont'           = ("Courier New",9pt)           /* titles */
               'StrongFont'          = ("Courier New",9pt)
               'EmphasisFont'        = ("Courier New",9pt,Italic)
               'FixedEmphasisFont'   = ("Courier New, Courier",9pt,Italic)
               'FixedStrongFont'     = ("Courier New, Courier",9pt)
               'FixedHeadingFont'    = ("Courier New, Courier",9pt)
               'BatchFixedFont'      = ("SAS Monospace, Courier New, Courier",9pt)
               'FixedFont'           = ("Courier New, Courier",9pt)
               'headingEmphasisFont' = ("Courier New",9pt,Bold Italic)
               'headingFont'         = ("Courier New",9pt)            /* header block */
               'docFont'             = ("Courier New",9pt);           /* table cells */

         replace color_list
             "Colors used in the default style" /
             'link' = blue
             'bgH' = white     /* header background */
             'fg' = black
             'bg' = _undef_;



        end;



    run ;


    %PUT TRACE: [Macro: s_template] Complete;

%mend s_template;
