# Shared macro test code README

This folder contains programs used to test the shared macros.
There are two sets of programs in this folder - automated test suites and
SAS test programs.

The test suites are Powershell files which are run in VIPER. Typically 
test suites run one or more SAS test programs and check for expected results.


## Naming conventions

SAS programs are named:
```
<macro>_test[_case].sas
```
Where:
- **macro** is the name of the shared macro being tested
- **case** (optional) identifies a specific test case/feature the program tests


So, for example:
- `init_test.sas` is general-purpose SAS test program for the %init macro
- `init_test_libname.sas` tests the SAS libraries that %init has defined


Test suites run all the SAS test programs and are named:
```
<macro>.tests.ps1
```

## SAS Test programs

Test programs start with a call to the `%init` macro to 
ensure a standard setup. The macros being tested are in the
`share\macros` folder which is on the SASAUTOS path.

There are no permanent test data folders. Test programs are expected
to create their own test data and cleanup afterwards.

## How to run test suites

Test suites can be run from the VIPER command line, for example:
```
VIPER:[branch  +4 ~0 -0 | +6 ~1 -0 !] Z:\Users\yourname\veramedimol\C006\VeraMedimol\Pilot01\re_dmc01\share\tests
> .\init.tests.ps1

Starting discovery in 1 files.
Discovery found 6 tests in 16ms.
Running tests.
[+] Z:\Users\yourname\veramedimol\C006\VeraMedimol\Pilot01\re_dmc01\share\tests\code\init.tests.ps1 484ms (405ms)
Tests completed in 488ms
Tests Passed: 6, Failed: 0, Skipped: 0 NotRun: 0
```


