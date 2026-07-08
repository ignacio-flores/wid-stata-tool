// -------------------------------------------------------------------------- //
// Test runner for the WID Stata command
// -------------------------------------------------------------------------- //

clear all
discard

global root "/Users/iflores/Documents/GitHub/wid-stata-tool"

cd "$root"
sysdir set PERSONAL "$root"

do tests/test_input_validation.do
do tests/test_score_filter_parser.do
do tests/test_wid_integration_small.do
do tests/test_wid_integration_large.do
