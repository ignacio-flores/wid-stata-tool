// -------------------------------------------------------------------------- //
// Input validation and local command resolution tests
// -------------------------------------------------------------------------- //

clear all
discard

if "$root" == "" {
	global root "/Users/iflores/Documents/GitHub/wid-stata-tool"
}

cd "$root"
sysdir set PERSONAL "$root"

which wid

findfile wid.ado
local wid_ado "`r(fn)'"
assert "`wid_ado'" == "./wid.ado" | strpos("`wid_ado'", "$root") == 1

findfile wid.jar
local wid_jar "`r(fn)'"
assert "`wid_jar'" == "./wid.jar" | strpos("`wid_jar'", "$root") == 1

// Data-loss protection
clear
set obs 1
capture noisily wid, areas(FR) indicator(sptinc)
assert _rc == 4

// Required country/indicator selection
clear
capture noisily wid, clear
assert _rc == 198

// Invalid indicator codes
capture noisily wid, indicators(foo) areas(FR) clear
assert _rc == 198

capture noisily wid, indicators(SPTINC) areas(FR) clear
assert _rc == 198

capture noisily wid, indicators(sptincx) areas(FR) clear
assert _rc == 198

// Invalid percentile, age, and population codes
capture noisily wid, indicators(sptinc) areas(FR) perc(foo) clear
assert _rc == 198

capture noisily wid, indicators(sptinc) areas(FR) perc(99p100) clear
assert _rc == 198

capture noisily wid, indicators(sptinc) areas(FR) age(99) clear
assert _rc == 198

capture noisily wid, indicators(sptinc) areas(FR) age(adults) clear
assert _rc == 198

capture noisily wid, indicators(sptinc) areas(FR) pop(x) clear
assert _rc == 198

// Removed extrapolation option
capture noisily wid, areas(FR) indicator(sptinc) exclude clear
assert _rc == 198
