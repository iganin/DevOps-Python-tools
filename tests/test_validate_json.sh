#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2015-12-22 23:39:33 +0000 (Tue, 22 Dec 2015)
#
#  https://github.com/harisekhon/pytools
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback to help improve or steer this or other code I publish
#
#  https://www.linkedin.com/in/harisekhon
#

set -euo pipefail
[ -n "${DEBUG:-}" ] && set -x
srcdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd "$srcdir/..";

. ./tests/utils.sh

section "Testing validate_json.py"

until [ $# -lt 1 ]; do
    case $1 in
        -*) shift
    esac
done

data_dir="tests/data"
broken_dir="$data_dir/broken_json_data"

exclude='/tests/spark-\d+\.\d+.\d+-bin-hadoop\d+.\d+$|broken|error'

rm -fr "$broken_dir" || :
mkdir "$broken_dir"

./validate_json.py -vvv --exclude "$exclude" .
echo

echo "checking directory recursion (mixed with explicit file given)"
./validate_json.py -vvv "$data_dir/test.json" .
echo

echo "checking json file without an extension"
cp -iv "$(find "${1:-.}" -iname '*.json' | grep -v -e '/spark-.*-bin-hadoop.*/' -e 'broken' -e 'error' | head -n1)" "$broken_dir/no_extension_testfile"
./validate_json.py -vvv -t 1 "$broken_dir/no_extension_testfile"
echo

echo "checking json with embedded double quotes"
./validate_json.py -s "$data_dir/single_quotes_embedded_double_quotes.notjson"
echo

echo "checking json with embedded double quotes"
./validate_json.py -s "$data_dir/single_quotes_embedded_double_quotes.notjson"
echo

echo "checking json with embedded non-escaped double quotes"
./validate_json.py -s "$data_dir/single_quotes_embedded_double_quotes_unescaped.notjson"
echo

echo "testing stdin"
./validate_json.py - < "$data_dir/test.json"
./validate_json.py < "$data_dir/test.json"
echo "testing stdin and file mix"
./validate_json.py "$data_dir/test.json" - < "$data_dir/test.json"
echo "testing stdin with multi-record"
./validate_json.py -m - < "$data_dir/multirecord.json"
echo

echo "checking symlink handling"
ln -sfv "test.json" "$data_dir/testlink.json"
./validate_json.py "$data_dir/testlink.json"
rm "$data_dir/testlink.json"
echo

echo "Now trying broken / non-json files to test failure detection:"
check_broken(){
    filename="$1"
    expected_exitcode="${2:-2}"
    options="${3:-}"
    set +e
    ./validate_json.py $options "$filename" ${@:3}
    exitcode=$?
    set -e
    if [ $exitcode = $expected_exitcode ]; then
        echo "successfully detected broken json in '$filename', returned exit code $exitcode"
        echo
    #elif [ $exitcode != 0 ]; then
    #    echo "returned unexpected non-zero exit code $exitcode for broken json in '$filename'"
    #    exit 1
    else
        echo "FAILED, returned unexpected exit code $exitcode for broken json in '$filename'"
        exit 1
    fi
}

echo "checking normal json stdin breakage using --multi-record switch"
set +e
./validate_json.py - -m < "$data_dir/test.json"
exitcode=$?
set -e
if [ $exitcode = 2 ]; then
    echo "successfully detected breakage for --multi-record stdin vs normal json"
    echo
else
    echo "FAILED to detect breakage when feeding normal multi-record json doc to stdin with --multi-record (expecting one json doc per line), returned unexpected exit code $exitcode"
    exit 1
fi

echo blah > "$broken_dir/blah.json"
check_broken "$broken_dir/blah.json"

check_broken "$data_dir/single_quotes.notjson"
check_broken "$data_dir/single_quotes_multirecord.notjson"
check_broken "$data_dir/single_quotes_multirecord_embedded_double_quotes.notjson"
check_broken "$data_dir/single_quotes_multirecord_embedded_double_quotes_unescaped.notjson"

echo "checking invalid single quote detection"
set +o pipefail
./validate_json.py "$data_dir/single_quotes.notjson" 2>&1 | grep --color 'JSON INVALID.*found single quotes not double quotes' || { echo "Failed to find single quote message in output"; exit 1; }
set -o pipefail
echo

echo "checking --permit-single-quotes mode works"
./validate_json.py -s "$data_dir/single_quotes.notjson"
echo

echo "checking --permit-single-quotes mode works with embedded double quotes"
./validate_json.py -s "$data_dir/single_quotes_embedded_double_quotes.notjson"
echo

echo "checking --permit-single-quotes mode works with unescaped embedded double quotes"
./validate_json.py -s "$data_dir/single_quotes_embedded_double_quotes.notjson"
echo

echo "checking --permit-single-quotes mode works with multirecord"
./validate_json.py -s "$data_dir/single_quotes_multirecord.notjson" -m
echo

echo "checking --permit-single-quotes mode works with multirecord"
./validate_json.py -s "$data_dir/single_quotes_multirecord_embedded_double_quotes.notjson" -m
echo

echo "checking --permit-single-quotes mode works with multirecord"
./validate_json.py -s "$data_dir/single_quotes_multirecord_embedded_double_quotes_unescaped.notjson" -m
echo

echo "checking --permit-single-quotes mode works and auto retries to succeed with multirecord"
./validate_json.py -s "$data_dir/single_quotes_multirecord.notjson"
echo

echo "checking --permit-single-quotes mode works and auto retries to succeed with multirecord with embedded double quotes"
./validate_json.py -s "$data_dir/single_quotes_multirecord_embedded_double_quotes.notjson"
echo

echo "checking --permit-single-quotes mode works and auto retries to succeed with multirecord with unescaped embedded double quotes"
./validate_json.py -s "$data_dir/single_quotes_multirecord_embedded_double_quotes_unescaped.notjson"
echo

# ============================================================================ #
#                          Print Mode Passthrough Tests
# ============================================================================ #

echo "testing print mode"
[ "$(./validate_json.py -p "$data_dir/test.json" | cksum)" = "$(cksum < "$data_dir/test.json")" ] || { echo "print test failed!"; exit 1; }
echo "successfully passed out test json to stdout"
echo

echo "testing print mode failed"
set +e
output="$(./validate_json.py -p "$data_dir/single_quotes.notjson")"
result=$?
set -e
[ $result -eq 2 ] || { echo "print test failed with wrong exit code $result instead of 2!"; exit 1; }
[ -z "$output" ] || { echo "print test failed by passing output to stdout for records that should be broken!"; exit 1; }
echo "successfully passed test of print mode failure"
echo

echo "testing print mode with multi-record"
[ "$(./validate_json.py -mp "$data_dir/multirecord.json" | cksum)" = "$(cksum < "$data_dir/multirecord.json")" ] || { echo "print multi-record test failed!"; exit 1; }
echo "successfully passed out multi-record json to stdout"
echo

echo "testing print mode with --permit-single-quotes"
[ "$(./validate_json.py -sp "$data_dir/single_quotes.notjson" | cksum)" = "$(cksum < "$data_dir/single_quotes.notjson")" ] || { echo "print single quote json test failed!"; exit 1; }
echo

echo "testing print mode with --permit-single-quotes multirecord"
[ "$(./validate_json.py -sp "$data_dir/single_quotes_multirecord.notjson" | cksum)" = "$(cksum < "$data_dir/single_quotes_multirecord.notjson")" ] || { echo "print single quote multirecord json test failed!"; exit 1; }
echo

echo "testing print mode with --permit-single-quotes multirecord with embedded double quotes"
[ "$(./validate_json.py -sp "$data_dir/single_quotes_multirecord.notjson" | cksum)" = "$(cksum < "$data_dir/single_quotes_multirecord.notjson")" ] || { echo "print single quote multirecord json with embedded double quotes test failed!"; exit 1; }
echo

echo "testing print mode with --permit-single-quotes multirecord with unescaped embedded double quotes"
[ "$(./validate_json.py -sp "$data_dir/single_quotes_multirecord_embedded_double_quotes.notjson" | cksum)" = "$(cksum < "$data_dir/single_quotes_multirecord_embedded_double_quotes.notjson")" ] || { echo "print single quote multirecord json with unescaped embedded double quotes test failed!"; exit 1; }
echo

echo
# ============================================================================ #

echo '{ "name": "hari" ' > "$broken_dir/missing_end_quote.json"
check_broken "$broken_dir/missing_end_quote.json"

check_broken README.md

cat "$data_dir/test.json" >> "$broken_dir/multi-broken.json"
cat "$data_dir/test.json" >> "$broken_dir/multi-broken.json"
check_broken "$broken_dir/multi-broken.json"
rm -fr "$broken_dir"
echo

echo "checking for non-existent file"
check_broken nonexistentfile 2
echo

echo "======="
echo "SUCCESS"
echo "======="

echo
echo
