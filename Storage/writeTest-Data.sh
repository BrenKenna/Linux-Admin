#!/bin/bash


########################################################
########################################################
# 
# Write Loads of Test Data for Testing Data Loss
# 
#########################################################
#########################################################


# Vars
DATE_NOW=$(date)
ZFS_TEST_HOME=/media/zfs_test
ZFS_POOL=/raidpool
cd $ZFS_POOL

# Create 5000 test files
echo -e "\\nCreating test files:\\t$DATE_NOW"
rm $ZFS_TEST_HOME/data-files-md5sums.txt
touch $ZFS_TEST_HOME/data-files-md5sums.txt
for batch in {1..10}
do

    # Create set of files for batch
    echo -e "\\nGeneration mock data files for batch-$batch"
    for split in {1..5}
    do
        # Create directory for test files
        OUTDIR=$ZFS_POOL/batch-$batch/split-$split
        mkdir -p $OUTDIR && cd $OUTDIR
        for i in {1..100}
        do
            seq $RANDOM > data-file-$i.txt
            md5sum data-file-$i.txt | awk '{ print $1"  '$OUTDIR/'"$2}' >> $ZFS_TEST_HOME/data-files-md5sums.txt
        done
    done

    # Log batch completion
    echo -e "\\nData generation for batch-$batch completed"
done


# Log completion
DATE_NOW=$(date)
echo -e "\\n\\nData generation has completed for all batches. Creating a directory tree"
tree -fish $ZFS_POOL > $ZFS_TEST_HOME/data-file-tree.txt
N_FILES=$(wc -l $ZFS_TEST_HOME/data-file-tree.txt | cut -d ' ' -f 1)
echo -e "\\nProcess completed with N Files generated = '$N_FILES'"
