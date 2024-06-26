#!/bin/bash 
# Script by Edward Stoever for MariaDB Support
# Takes a archive old version of Mariadb Quick Review

EPOCH=$(date +%s)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source $SCRIPT_DIR/../vsn.sh

# if [ -f  "$SCRIPT_DIR/../SUPPORT/import_quick_review.sh" ]; then echo "Prepare the SUPPORT directory by running pack_me.sh"; exit 0; fi

cd $SCRIPT_DIR/../..
OUTDIR=${SCRIPT_DIR}/${SCRIPT_VERSION}
echo $OUTDIR

mkdir -p $OUTDIR
find ./start_replica_assistant \( -path ./start_replica_assistant/old_versions -o -path ./start_replica_assistant/.git -o -path ./start_replica_assistant/bin \) -prune -o -type f ! -name "*.tar.gz" | cpio -ov | bzip2 > ${OUTDIR}/quick_review_archive_${EPOCH}.cpio.bz2
if [ -f ${OUTDIR}/start_replica_assistant_archive_${EPOCH}.cpio.bz2 ]; then
echo "Archive created:"; ls -l ${OUTDIR}/quick_review_archive_${EPOCH}.cpio.bz2;
else
  echo "Something did not go as planned"; exit 1
fi
