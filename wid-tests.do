// -------------------------------------------------------------------------- //
// Test runner for the WID Stata command
// Usage from the repository root:
//     do wid-tests.do off
//     do wid-tests.do on
// An optional second argument supplies the repository path.
// -------------------------------------------------------------------------- //

version 15
args varabbrev_setting project_root

clear all
discard

local varabbrev_setting = lower(trim("`varabbrev_setting'"))
if ("`varabbrev_setting'" == "") {
	local varabbrev_setting off
}
if (!inlist("`varabbrev_setting'", "on", "off")) {
	display as error "varabbrev setting must be on or off"
	exit 198
}

if (`"`project_root'"' == "") {
	local project_root = c(pwd)
}
global root `"`project_root'"'

capture confirm file "$root/ssc/wid.ado"
if (_rc) {
	display as error "run wid-tests.do from the repository root or pass the repository path as its second argument"
	exit 601
}

set varabbrev `varabbrev_setting'
set more off
display as text "Running WID tests with varabbrev `varabbrev_setting'"

do "$root/tests/test_input_validation.do"
do "$root/tests/test_quality_filter_parser.do"
do "$root/tests/test_wid_integration_small.do"
do "$root/tests/test_wid_integration_large.do"

display as result "WID tests passed with varabbrev `varabbrev_setting'"
