#!/bin/bash

####################################
# 
# 1). Config Vars & Log
# 
####################################


# Vars
LOG_FILE=/var/log/raid-array-md0.log.txt
LOG_DATE=$(date)
RAID_TEST_HOME=/media/raid
DEVICE_HOME=${RAID_TEST_HOME}/devices
RAID_MOUNT=/mnt/raid_test/raid_array


# Handle log
if [ ! -f $LOG_FILE ]
then
    echo "\\nInitializing RAID Restart Log:\\t$LOG_DATE" > $LOG_FILE
else 
    echo "\\n\\n\\nAppending to RAID Restart Log:\\t$LOG_DATE" >> $LOG_FILE
fi


####################################
# 
# 2). Manage Devices for Array
# 
####################################


# Find loop back devices
echo "\\nFindings looback devices\\n" >> $LOG_FILE
for i in $(seq 10)
do
    losetup -f ${DEVICE_HOME}/disk-${i}.img > $LOG_FILE
done


# Exit if all devices cannot be found
echo "\\nFetching device information" >> $LOG_FILE
losetup -a > /tmp/losetup-status
N_DEVICES=$(wc -l /tmp/losetup-status | cut -d ' ' -f 1)
if [ $N_DEVICES -lt 10 ]
then
    echo "\\nStopping loopback devices could be found for RAID array" >> $LOG_FILE
    echo "\\nNumber of devices '$N_DEVICES' is less than 10" >> $LOG_FILE
    echo "\\nDisplaying output from 'losetup -a'" >> $LOG_FILE
    rm -f /tmp/losetup-status
    exit 1

# Otherwise proceed
else
    echo "\\nProceeding to assembling array with the below devices" >> $LOG_FILE
    cat /tmp/losetup-status >> $LOG_FILE
fi
rm -f /tmp/losetup-status


####################################
# 
# 2). Reassemble the Array
# 
####################################

# Assemble array and wait until state change
echo "\\n\\n\\nAssembling the md0 RAID-6 Array" >> $LOG_FILE
mdadm --assemble /dev/md0 >> $LOG_FILE
RAID_STATE=$(mdadm --detail /dev/md0 | grep -i "State :" | cut -d ':' -f 2 | sed 's/ //g')
echo "\\n\\nEvaluating raid state of:\\t'$RAID_STATE'" >> $LOG_FILE
if [ "$RAID_STATE" == "clean"  || "$RAID_STATE" == "active" ]
then

    # Proceed if online
    echo "\\nRAID array has been brought up, proceeding to mount the array" >> $LOG_FILE
    mdadm --query /dev/md0 >> $LOG_FILE

# Wait until the array is no longer syncing or recovering
elif [ "$RAID_STATE" == "resyncing" || "$RAID_STATE" == "recovering" ]
then
    while [ "$RAID_STATE" == "resyncing" || "$RAID_STATE" == "recovering" ]
        do

        # Log state
        echo "\\nWaiting for RAID to be assembled. Current state:\\t$RAID_STATE" >> $LOG_FILE
        sleep 1m

        # Fetch current state
        RAID_STATE=$(mdadm --detail /dev/md0 | grep -i "State :" | cut -d ':' -f 2 | sed 's/ //g')
    done

# Otherwise log issue with array and exit
else
    echo "\\nExiting on error reassembling raid array. Displaying raid detail below\\n" >> $LOG_FILE
    mdadm --detail /dev/md0 >> $LOG_FILE
    exit 1
fi


####################################
# 
# 3). Mount the Array
# 
####################################

# Mount array and display disk usage
echo "\\n\\nMounting the array and displaying its dsk usage" >> $LOG_FILE
mount -o rw /dev/md0 $RAID_MOUNT >> $LOG_FILE
df -h $RAID_MOUNT >> $LOG_FILE
LOG_DATE=$(date)
echo "\\n\\nReboot script completed:\\t$LOG_DATE" >> $LOG_FILE