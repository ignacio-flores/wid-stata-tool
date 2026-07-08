// -------------------------------------------------------------------------- //
// score_filter parser tests that fail before network/API requests
// -------------------------------------------------------------------------- //

clear all
discard

if "$root" == "" {
	global root "/Users/iflores/Documents/GitHub/wid-stata-tool"
}

cd "$root"
sysdir set PERSONAL "$root"

capture noisily wid, score_filter() clear
assert _rc == 198

capture noisily wid, score_filter(quality=3) clear
assert _rc == 198

capture noisily wid, score_filter(row_score=6) clear
assert _rc == 198

capture noisily wid, score_filter(row_score=-1) clear
assert _rc == 198

capture noisily wid, score_filter(row_score=5 3) clear
assert _rc == 198

capture noisily wid, score_filter(row_score=abc) clear
assert _rc == 198

capture noisily wid, score_filter(row_score=3 4 5) clear
assert _rc == 198

capture noisily wid, score_filter(series_score={min:4,max:2}) clear
assert _rc == 198

capture noisily wid, score_filter(row_score=3; row_score=4) clear
assert _rc == 198

capture noisily wid, score_filter(series_score=2; series_score=3) clear
assert _rc == 198
