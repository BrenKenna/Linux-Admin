#!/bin/bash

########################################################
########################################################
# 
# Check Files Lost/Kept After Drive Failures
# 
#########################################################
#########################################################


# Vars
DATE_NOW=$(date)
ZFS_TEST_HOME=/media/zfs_test
DEVICE_HOME=${ZFS_TEST_HOME}/devices
ZFS_MOUNT=/mnt/zfs_test/zfs_pool
cd $ZFS_TEST_HOME


# Check file states
echo -e "\\nChecking file states after drive failures:\\t$DATE_NOW"
FILES_LOST=0
FILES_KEPT=0
wc -l $ZFS_TEST_HOME/data-file-tree.txt
for testFile in $(grep -wo "/raidpool.*data-file.*.txt$" $ZFS_TEST_HOME/data-file-tree.txt | sort -R) 
do
	# Increment lost if gone
	if [ ! -f $testFile ]
	then
		FILES_LOST=$((${FILES_LOST} + 1))
	
	# Otherwise increment kept
	else
		FILES_KEPT=$((${FILES_KEPT} + 1))
	fi
done


# Display results
DATE_NOW=$(date)
echo -e "\\nDisplaying Summary of File States:\\t$DATE_NOW"
echo -e "Files Lost:\\t'$FILES_LOST'\\nFiles Kept:\\t'$FILES_KEPT'"