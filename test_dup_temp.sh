#!/bin/bash

# Test duplicate hashe cases.
#
# Hashes are only two kinds, expressed as: 0 or 1.
# (Accordingly the file contens are either: 'zero' or 'one').
#
# Files in src directory is: file1, file2, file3, file4.
# Files in dest directory is: file2, file3, file4, file5.
# So after running rsync-prelude, in dest directory,
# file1 will be added, file5 removed, and file2-4 moved to fix hashes, if necessary.
#
# Some combinations are unable to be fixed. E.g.
#
#       file1   file2   file3   file4   file5
# src   0       0       0       1
# dest          0       1       1       1
#
# file2 and file4 are the same sizes, so their hash calculations are skipped,
# so dest gets hashs from file3 and file5, that is, only hash 1,
# unable to move or copy hash 0 files from somewhere, to modify file3.
#
# So tests are filtered so that dest gets both hashes
# (74 tests from 128 cases).
#
# Note:
#
# To simplify tests,
# move command is changed to 'mv' from 'mv -n' (by arg '--mv-cmd')
# copy command is changed to 'cp' from 'cp -n' (by arg '--cp-cmd')


set -euo pipefail
IFS=$' \n\t'

RSYNC_PRELUDE="$(pwd)/rsync-prelude"

# Specify environment variable 'RSYNC_PRELUDE_TEST_TEMPDIR', if necessary
TEMPDIR=${RSYNC_PRELUDE_TEST_TEMPDIR:=/tmp/rsync-prelude-test}
mkdir -p $TEMPDIR
cd $TEMPDIR

if [ -e test-root-tmp/source ]; then
    chmod -R +w test-root-tmp/source
    rm -r test-root-tmp
fi
mkdir -p test-root-tmp/source/folder
mkdir -p test-root-tmp/target/folder

run() {
    test_id="$1"
    test_script="$2"
    test_dir="$3"
    test_src="$4"
    test_dst="$5"
    shift
    shift
    shift
    shift
    shift

    pushd "${test_dir}" > /dev/null
    if [ "${test_script}" = "y" ]; then
        "${RSYNC_PRELUDE}" -f ' --recursive'  "$@" "${test_src}" "${test_dst}" | bash
    else
        "${RSYNC_PRELUDE}" -f ' --recursive' "$@" "${test_src}" "${test_dst}"
    fi
    set +e # because of grep
    remaining=$(rsync --dry-run --itemize-changes --recursive "${test_src}" "${test_dst}" | grep '^.f')
    rem_count=$(printf '%s' "$remaining" | grep -c '^')
    set -e
    popd > /dev/null

    if [ "$rem_count" -eq 0 ]
    then
        echo "Test ${d:0:4} ${d:4:4} ($TEST_COUNT) PASSED"
    else
        echo "== rsync diff =="
        echo "$remaining"
        echo "== rhash diff =="
        set +e
        diff <(cd test-root-tmp/source; rhash -r -p '%c %s %{mtime} %p\n' .) \
             <(cd test-root-tmp/target; rhash -r -p '%c %s %{mtime} %p\n' .)
        set -e
        echo "Test ${d:0:4} ${d:4:4} ($TEST_COUNT) FAILED"
        echo 12345
        echo ${d:0:4}
        echo '' ${d:4:4}
        exit 1
    fi
}

TEST_COUNT=0
DATA=($(echo {0,1}{0,1}{0,1}{0,1}{0,1}{0,1}{0,1}{0,1}))
DATA=(${DATA[@]:0:128})

for d in ${DATA[@]}; do

    # 1. filter unable to modiy hash combinations
    OK=0
    file5=${d:7:1}
    for (( i=4; i<7; i++ )); do
        j=$(($i-3))
        if [ ${d:i:1} == ${d:j:1} ]; then  # same filename and same hash
            continue
        fi
        if [ ${d:i:1} != $file5 ]; then  # got both hashes 0 and 1
            OK=1
            break
        fi
    done
    if [ $OK == 0 ]; then
        continue
    fi

    TEST_COUNT=$(($TEST_COUNT+1))

    # 2. create files
    pushd test-root-tmp/source/folder > /dev/null
    for (( i=0; i<4; i++ )); do
        n=${d:i:1}
        filename=file$(($i+1))
        if [ $n == 0 ]; then
            echo zero > $filename; touch -t 202201010100 $filename
        else
            echo one > $filename;  touch -t 202201010101 $filename
        fi
    done
    popd > /dev/null

    pushd test-root-tmp/target/folder > /dev/null
    for (( i=4; i<8; i++ )); do
        j=$(($i-3))
        n=${d:i:1}
        filename=file$(($i-2))

        if [ ${d:i:1} == ${d:j:1} ]; then  # same filename and same hash, so same timestamp
            if [ $n == 0 ]; then
                echo zero > $filename; touch -t 202201010100 $filename
            else
                echo one > $filename;  touch -t 202201010101 $filename
            fi
        else
            timestamp=$((202201010000+i))
            if [ $n == 0 ]; then
                echo zero > $filename; touch -t $timestamp $filename
            else
                echo one > $filename; touch -t $timestamp $filename
            fi
        fi
    done
    popd > /dev/null

    # 3. run actual test
    run  $TEST_COUNT n "." "test-root-tmp/source/folder" "test-root-tmp/target" -q --mv-cmd mv --cp-cmd cp
done
