<#
.SYNOPSIS
Automated test suite for SAS setup (init->verasetip->autoexec)

.DESCRIPTION
These tests can be run from a VIPER terminal:

VIPER> Invoke-Pester init.tests.ps1

Or to get more detailed output:

VIPER> Invoke-Pester -Output Detailed

#>


# pre-conditions..
BeforeAll {
    # must be running in VIPER environment
    $viper | should -not -BeNullorEmpty
}


# ===========================================================================
# Tests using init_test.sas SAS program (has single call to init)
# ===========================================================================

Describe "init_test.sas" {
    BeforeAll {
	    # define location of code/output/saslogs folders
        $code    = $PSScriptRoot
        $output  = resolve-path "$PSScriptRoot\..\output"
        $saslogs = resolve-path "$PSScriptRoot\..\saslogs"
        #
        # define the name of the SAS program the test uses (without .sas extension)
        #
        $sasprog = "init_test"

        # delete the SAS log file if it exists.
        if (test-path "$saslogs\$sasprog.log" ) {
           Remove-Item  "$saslogs\$sasprog.log"
        }

        # RUN THE SAS TEST PROGRAM
        { viper-run-sas $sasprog } | should -not -throw
        # check saslog exists and has no ERROR lines
        "$saslogs\$sasprog.log" | should -exist
        "$saslogs\$sasprog.log" | should -not -fileContentMatch "^ERROR"
    }#BeforeAll

	# -------------------------------------------------------------------
	# CALL CHAIN
	# Test that init, verasetup and autoexec are all called
	# -------------------------------------------------------------------
	Context "call chain" {
		It "init macro called" {
		  "$saslogs\$sasprog.log" | should -fileContentMatch ([regex]::Escape("TRACE: [Macro: init]"))
		}
		It "verasetup called" {
		  "$saslogs\$sasprog.log" | should -fileContentMatch ([regex]::Escape("TRACE: [Program: verasetup]"))
		}
		It "autoexec called" {
		  "$saslogs\$sasprog.log" | should -fileContentMatch ([regex]::Escape("TRACE: [Program: autoexec]"))
		}
	}#context call chain

	# -------------------------------------------------------------------
	# INIT Macro
	# test that the init macro runs as expected
	# -------------------------------------------------------------------
	Context "init macro" {
		It "SAS batch mode detected" {
			"$saslogs\$sasprog.log" | should -fileContentMatch ([regex]::Escape("TRACE: [Macro: init] Running in SAS VIPER batch"))
		}
		It "SAS execution mode" {
			"$saslogs\$sasprog.log" | should -not -fileContentMatch ([regex]::Escape("DEBUG: [Macro: init] Cannot determine SAS execution mode"))
		}
		It "fullpath global var" {
			"$saslogs\$sasprog.log" | should -FileContentMatchMultiline "__FULL_PATH:.*\n.*$($sasprog).sas"
		}
	}#context call chain
}#describe init

# ===========================================================================
# Tests using init_test_vars.sas to test global macro vars set by init/verasetup
# ===========================================================================

Describe "init_test_vars.sas" {
	Context "Viper Batch mode" {
		BeforeAll {
			# RUN the program in VIPER batch mode
			$result = viper-run-sas init_test_vars
			# test that there are no SAS ERROR in the log
			$result.contains("ERROR: 0 ") | should -be $true
		}
		# Data driven test to check each var equals expected value
		It "Var <var>" -ForEach @(
			@{ var = "__runmode"     ; val = "BATCH" }
			@{ var = "__exemode"     ; val = "VIPER_BATCH" }
			# add more var/val here as required..
		){
			# Test Results:
			# define the line that we expect to find in the sas log
			# which is written to the log by the init_test_vars.sas program 
			# NOTE the get-contents -replace which removed all return-newline chars
			#
			(Get-Content -Raw "..\saslogs\init_test_vars.log") -replace "[`r`n]+", "" | `
			  should -Match ([regex]::Escape("TEST: [Program: init_test_vars] [$($var): $($val)]"))
		}
	}
}

# ===========================================================================
# Tests that SASAUTOS contains the expected paths
# ===========================================================================

Describe "init_test_sasauto.sas" {
	#
	# Test the sasauto paths for a program running in share\test\code
	# the expected paths are:
	# - the gloabl path (to E:\project_tools\macros)
	# - the shared macro folder (__env_runtime\share\macros)
	#
	Context "Run in share folder" {
		BeforeAll {
			# RUN the program in the share\code folder
			$result = viper-run-sas init_test_sasauto
			# test that there are no SAS ERROR in the log
			$result.contains("ERROR: 0 ") | should -be $true
		}
		# check that the global path is set
		It "global macros" {
			"..\saslogs\init_test_sasauto.log" | `
			  should -fileContentMatch ([regex]::Escape("Z:\project_tools\Macros"))
		}
		# check that the shared macro folder is set
		It "shared macros" {
			$re_folder = (Get-Workspace).runtime.path
			"..\saslogs\init_test_sasauto.log" | `
			  should -fileContentMatch ([regex]::Escape("$($re_folder)\share\macros"))
		}
	}
	Context "Run in <level>\<type>" -ForEach @(
	    @{ level = "prod" ; type = "sdtm"}
		@{ level = "qc"   ; type = "tfl" }
	){
		BeforeAll {
		    # COPY the test SAS program to atemp file in the target location
			$tempname = "tmp-" + (New-GUID).GUID.toString()
			Write-Log -Level "INFO" -Message "Temp filename: $tempname"
			$re_path = (Get-Workspace).runtime.path
			$tempath = "$($re_path)\$($level)\$($type)"
			Write-Log -Level "INFO" -Message "Temp path: $tempath"
			Copy-Item .\init_test_sasauto.sas "$($tempath)\code\$($tempname).sas"
			# RUN the program in the share\code folder
			$result = viper-run-sas "$($tempath)\code\$($tempname).sas"
			# test that there are no SAS ERROR in the log
			$result.contains("ERROR: 0 ") | should -be $true
		}
		# check that the global path is set
		It "global macros" {
			"$($tempath)\saslogs\$($tempname).log" | `
			  should -fileContentMatch ([regex]::Escape("Z:\project_tools\Macros"))
		}
		# check that the shared macro path is set
		It "shared macros" {
			$re_folder = (Get-Workspace).runtime.path
			"$($tempath)\saslogs\$($tempname).log"  | `
			  should -fileContentMatch ([regex]::Escape("$($re_folder)\share\macros"))
		}
		# Check the prod/qc util path is set.. note that only the prod programs should
		# have prod\util path and not the qc\util path and vice versa for qc.
		It "local util path" {
		    # define the other level (qc->prod and prod->qc)
		    $re_folder = (Get-Workspace).runtime.path
			if ($level -eq "prod") {
			    $other = "qc"
			} else {
			    $other = "prod"
			}
			# create the path that we are looking for
			$expected = ([regex]::Escape("$($re_folder)\$level\util\macros"))
			# ..and not expecting to find the other one
			$not_expected = ([regex]::Escape("$($re_folder)\$other\util\macros"))
			# Test the SAS log file..
			"$($re_path)\$($level)\$($type)\saslogs\$($tempname).log"  | `
			  should -fileContentMatch $expected
			"$($re_path)\$($level)\$($type)\saslogs\$($tempname).log"  | `
			  should -not -fileContentMatch $not_expected			
		}
		AfterAll {
		    Remove-Item "$($tempath)\code\$($tempname).sas" -ErrorAction Ignore
		    Remove-Item "$($tempath)\saslogs\$($tempname).*" -ErrorAction Ignore
		    Remove-Item "$($tempath)\output\$($tempname).*" -ErrorAction Ignore
		}
	}

}



#EOF

