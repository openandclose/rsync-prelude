
set -euo pipefail
IFS=$'\n\t'

RSYNC_PRELUDE="$(pwd)/rsync-prelude"

SLEEPTIME=2
if [ $# = 1 ] ; then
    SLEEPTIME="$1"
fi

# Specify environment variable 'RSYNC_PRELUDE_TEST_TEMPDIR', if necessary
TEMPDIR=${RSYNC_PRELUDE_TEST_TEMPDIR:=/tmp/rsync-prelude-test}
mkdir -p $TEMPDIR
pushd $TEMPDIR > /dev/null
