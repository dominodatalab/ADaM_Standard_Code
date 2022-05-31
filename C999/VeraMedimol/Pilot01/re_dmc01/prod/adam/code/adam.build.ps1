##############################################################################
#        O
#       /                               
#  O---O     _  _ _  _ _  _  _|        
#       \ \/(/_| (_|| | |(/_(_|    
#        O                         
# ____________________________________________________________________________
<#
.SYNOPSIS
    adam.build.ps1 - VeraMedimol ADaM build script

.DESCRIPTION
    This is a powershell script that runs all the SAS programs required to
    create the ADaM datasets in batch mode.

    Each SAS program is run in a new session, and log and outputs are sent
    to the appropriate \saslogs and \output directories.

    Generally, this build script implements 'incremental' builds, which means
    that programs are only run if they need to be, e.g. if
    - the program file has been edited since the outputs were last created,
    - the inputs have changed since the last time the outputs were created

    The build engine will resolve input/output dependencies, so if one
    program inputs datasets that are created as output from another program
    then those programs will be run in the correct order. 

    This script must be run in a VIPER terminal. To run it use the command:

    VIPER> build [task]

    Without a task, all programs will be run if they need to be. 

    Supported tasks are:
    - clean              delete all SDTM sas7bdat, saslog and output files. This
                         ..will force everything to be re-run at the next 'build'
    - scanlog            runs scanlog macro on all saslogs to PDF in the ..\output

.EXAMPLE
    VIPER:> build
    runs all the ADaM programs and checks and scanlog

.EXAMPLE
    VIPER:> build clean 
    Delete all ADaM datasets and re-run all programs to re-create

    VIPER:> build
    All programs will be re-run in the correct order after the `build clean` command

.EXAMPLE
    VIPER:> build checks
    This will force the conformance_checks and data_checks to run even if the
    programs and input data (ADaM) has not changed.

#>

# =================================================================================
# setup build environment variables
# =================================================================================
# The results from the SAS log files are accumulated into the
# results vector, which is used to provide a summary report
$script:results = @()

# use the location of this script to get the workspace..
# ..this is a data structure that contains runtime and client paths
# ..along with the names of client/study/path/etc.
#
# Build scripts always run with current directory set to location of script so no
# ..need to pass a path parameter to get-workspace (defualt is to use current dir)
$ws = Get-Workspace

# =================================================================================
# UTILITY FUNCTION
# =================================================================================
# Run a SAS program using the viper-run-sas command, log the results for 
# summary reporting at end of build, and check there are no SAS error log lines.
# If there are ERROR in the saslogs then Asert will force the build to stop.
#
function run-SAS-program ([string]$progname) {
    $r = viper-run-sas $progname
    $script:results += $r
#    assert($r.contains("ERROR: 0 "))
    write-build green $r
}


# =================================================================================
# DEFINE BUILD TASKS 
# =================================================================================

# ---------------------------------------------------------------------------------
# formats
# ---------------------------------------------------------------------------------
# This task runs the formats.sas utility program (if required) which generates
# the format catalog (in the data\util folder)
#
# ASSUMPTIONS:
#
# - The formats.sas program is located in the ..\..\util\code folder
# - the program has no other dependencies than itself (i.e is NOT data driven)
# - the program writes the format catalog to ..\..\data\util\formats.sas7?dat
#
Task formats @{
    Inputs = "..\..\util\code\formats.sas"
    Outputs = @(
	    "..\..\..\data\util\formats.sas7bcat"
	    "..\..\..\data\util\formats.sas7dcat"
	    )
    Jobs = { run-SAS-program ..\..\util\code\formats.sas }
}

# ---------------------------------------------------------------------------------
# ADSL
# ---------------------------------------------------------------------------------
Task ADSL @{
    Inputs = @(
	    "..\..\..\data\sdtm\dm.sas7bdat"
	    "..\..\..\data\sdtm\ex.sas7bdat"
	    "..\..\..\data\sdtm\ds.sas7bdat"
	    "..\..\..\data\sdtm\sv.sas7bdat"
	    "..\..\..\data\sdtm\mh.sas7bdat"
	    "..\..\..\data\sdtm\qs.sas7bdat"
	    "..\..\..\data\sdtm\vs.sas7bdat"
	    "..\..\..\data\sdtm\sc.sas7bdat"
		".\adsl.sas"
		)
    Outputs = @(
	    "..\..\..\data\adam\adsl.sas7bdat"
	    )
    Jobs = { run-SAS-program adsl.sas }
}

# ---------------------------------------------------------------------------------
# ADAE
# ---------------------------------------------------------------------------------
Task ADAE @{
    Inputs = @(
	    "..\..\..\data\adam\adsl.sas7bdat"
	    "..\..\..\data\sdtm\ex.sas7bdat"
	    "..\..\..\data\sdtm\ae.sas7bdat"
		".\adae.sas"
		)
    Outputs = @(
	    "..\..\..\data\adam\adae.sas7bdat"
	    )
    Jobs = { run-SAS-program adae.sas }
}

# ---------------------------------------------------------------------------------
# ADAE
# ---------------------------------------------------------------------------------
Task ADCM @{
    Inputs = @(
	    "..\..\..\data\adam\adsl.sas7bdat"
	    "..\..\..\data\sdtm\cm.sas7bdat"
		".\adcm.sas"
		)
    Outputs = @(
	    "..\..\..\data\adam\adcm.sas7bdat"
	    )
    Jobs = { run-SAS-program adcm.sas }
}

# ---------------------------------------------------------------------------------
# ADAM TASKS - summary of all the individual adams
# ---------------------------------------------------------------------------------
Task adam ADSL, ADAE, ADCM

# ---------------------------------------------------------------------------------
# scanlog
# ---------------------------------------------------------------------------------
# This task invokes the SAS %scanlogs macro (defined in shared\macros)
# which scans all the saslogs files and writes a summary PDF report
#
# This task depends on the saslogs files as input
# The program that is run is a temp SAS program that is created to
# invoke the macro. Its a two liner that calls %init then %scanlog
#
# ASSUME the name of the output PDF is COMPOUND-STUDY-RE-prod-adam-logscan.pdf
#
Task scanlog @{
    Inputs = { (Get-Item ..\saslogs\*.log) + ".\final.sas" }
    Outputs = "..\output\$($ws.name.compound)-$($ws.name.study)-$($ws.name.re)-PROD-ADAM-LOGSCAN.pdf"
    Jobs = { run-SAS-program final.sas }
}


# ---------------------------------------------------------------------------------
# Clean
# ---------------------------------------------------------------------------------
# remove all the SDTM datasets, saslogs and output files
#
Task Clean {
    Write-Build Magenta "Clean all ADaM sas7bdat files"
    del ..\..\..\data\adam\*.sas7bdat
    Write-Build Magenta "Clean all saslogs files"
    del ..\saslogs\*.log
    Write-Build Magenta "Clean output TXT and LST files"
    del ..\output\*.txt
    del ..\output\*.lst
    Write-Build Magenta "Clean scanlog output"
    del ..\output\scanlog.*
}

# =================================================================================
# Summary
# =================================================================================
Task summary {
	write-build yellow "----------------------------------------------------------"
	write-build yellow "SUMMARY OF PROGRAMS EXECUTED:"
	write-build yellow "TOTAL: $($script:results.count) Programs"
	foreach ($r in $script:results) { write-build yellow $r }
	write-build yellow "----------------------------------------------------------"
}

# =================================================================================
# DEFAULT TASK
# =================================================================================

Task . formats, adam, scanlog, summary


#EOF
