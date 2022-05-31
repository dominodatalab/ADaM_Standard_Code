##############################################################################
#        O
#       /                               
#  O---O     _  _ _  _ _  _  _|        
#       \ \/(/_| (_|| | |(/_(_|    
#        O                         
# ____________________________________________________________________________
<#
.SYNOPSIS
    sdtm.build.ps1 - VeraMedimol SDTM build script

.DESCRIPTION
    This is a powershell script that runs all the SAS programs required to
    create and test the SDTM datasets in batch mode.

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
    - import_transfer    run import_transfer if program changed or SDTM missing
    - conformance_checks run conformance checks SAS programs if needed
    - data_checks        run data checks SAS program if needed
    - checks             force conformance and data check programs to be run
    - scanlog            runs scanlog macro on all saslogs to create output\scanlog.pdf

.EXAMPLE
    VIPER:> build
    runs all the SDTM programs and checks and scanlog

.EXAMPLE
    VIPER:> build clean 
    Delete all SDTM datasets and re-run all SDTM programs to be re-run end-to-end.

    VIPER:> build
    All programs will be re-run in the correct order after the `build clean` command

.EXAMPLE
    VIPER:> build data_checks
    runs the data_checks.sas program if the SDTM has changed or the data_checks.sas
    program file has changed since last run.

.EXAMPLE
    VIPER:> build checks
    This will force the conformance_checks and data_checks to run even if the
    programs and input data (SDTM) has not changed.

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
$workspace = Get-Workspace

# ---------------------------------------------------------------------------------
# LOCATION AND CONTENTS OF TRANSFER
# ---------------------------------------------------------------------------------
# Define the location of the transfer\received data to use for the SDTM
# ..to change the build to use another transfer, simply change the YYYYMMDD and
# ..xpt_location in this task
#
# >>> THE TRANSFER RECEIVED FOLDER MUST NOT BE COMMITTED INTO GIT REPO <<<
#
# transfer\received data is always read from the CLIENT WORKSPACE 
# which is on Z:\client\compound\study\re_\
#
$script:YYYYMMDD = "20220310_CDISCPILOT01_SDTM_Data"
$xpt_location = "\sdtm-adam-pilot-project-master\updated-pilot-submission-package\900172\m5\datasets\cdiscpilot01\tabulations\sdtm"
$script:transfer = "$($workspace.client.path)\transfer\Received\" + $YYYYMMDD + $xpt_location
# get list of all the domain names.. these are the XPT filenames without extenstion
$script:domain_list = (get-childitem $transfer -Filter *.xpt).BaseName
# list of all the xpt files in the transfer/received folder
$script:xpt_list = $domain_list | %{ $script:transfer + "\" + $_+".xpt" }
# use the xpt file list to create similar list of .sas7bdat filenames
# ..use (regexp) to replace .xpt extension with .sas7bdat
$script:sas7bdat_list =  $domain_list | %{ "..\..\..\data\sdtm\"+$_+".sas7bdat" }


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
    assert($r.contains("ERROR: 0 "))
    write-build green $r
}


# =================================================================================
# DEFINE BUILD TASKS 
# =================================================================================

# ---------------------------------------------------------------------------------
# import_transfer
# ---------------------------------------------------------------------------------
# This task runs the import_transfer.sas program which is responsible for reading
# data from the transfer\received folder (in the reporting effort) into the SDTM
# library (in in data\sdtm).
# 
Task import_transfer @{
    Inputs = {
        $script:xpt_list + (Get-Item .\import_transfer.sas)
    }
    Outputs = { $script:sas7bdat_list + "..\saslogs\import_transfer.log" }
    Jobs = { run-SAS-program import_transfer }
}

# ---------------------------------------------------------------------------------
# conformance_checks
# ---------------------------------------------------------------------------------
# This is an incremental task - which means that the dependencies between inputs
# and outputs are defines and the build engine will only run the job if the inputs
# are missing or out of date compared with the outputs.
#
# conformance checks inputs:
# - SDTM sas7bdat files in the data\sdtm folder
# - SAS program (conformance_checks.sas) in the code folder
#
Task conformance_checks @{
    Inputs = {
        $script:sas7bdat_list + `
        (Get-Item .\conformance_checks.sas)
    }
    Outputs = "..\saslogs\conformance_checks.log"
    Jobs = { run-SAS-program conformance_checks }
}


# ---------------------------------------------------------------------------------
# data_checks
# ---------------------------------------------------------------------------------
# Incremental data checks tasks which only runs if outputs are mssing/out of date
# compared to the following inputs:
# - SDTM sas7bdat files in the data\sdtm folder
# - SAS program (conformance_checks.sas) in the code folder
#
Task data_checks @{
    Inputs = {
        $script:sas7bdat_list + `
        (Get-Item .\data_checks.sas)
    }
    Outputs = "..\saslogs\data_checks.log"
    Jobs = { run-SAS-program data_checks }
}

# ---------------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------------
# This task runs all the _checks tasks (i.e. conformance and data checks).
# It does this by deleting the log file and then running the incremental task
Task checks `
  { del ..\saslogs\*_checks.log }, conformance_checks, data_checks, summary


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
Task scanlog @{
    Inputs = { (Get-Item ..\saslogs\*.log) + ".\final.sas" }
    Outputs = "..\output\VERAMEDIMOL-PILOT01-RE_DMC01-PROD-SDTM-LOGSCAN.pdf"
    Jobs = { run-SAS-program final.sas }
}

# ---------------------------------------------------------------------------------
# Clean
# ---------------------------------------------------------------------------------
# remove all the SDTM datasets, saslogs and output files
#
Task Clean {
    Write-Build Magenta "Clean all SDTM sas7bdat files"
    del ..\..\..\data\sdtm\*.sas7bdat
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

Task . import_transfer, conformance_checks, data_checks, scanlog, summary


#EOF
