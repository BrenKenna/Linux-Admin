#!/bin/bash

#####################################################################################
#####################################################################################
# 
# ZFS Storage Pools from Loopback Devices
#
# => A server can offer its ZPool to a cluster.
#
# References:
# 1). https://ubuntu.com/tutorials/setup-zfs-storage-pool
# 2). https://arstechnica.com/information-technology/2020/05/zfs-101-understanding-zfs-storage-and-performance
# 3). https://klarasystems.com/articles/choosing-the-right-zfs-pool-layout/
# 4). https://docs.oracle.com/cd/E23824_01/html/821-1448/gaypw.html
# 
#####################################################################################
#####################################################################################

# Fetch centos img for vm
wget http://ftp.heanet.ie/pub/centos/7.9.2009/isos/x86_64/CentOS-7-x86_64-DVD-2009.iso
usermod -aG sudo < VM USER >
yum remove -y PackageKit* # after killing


# Install ZFS
yum update
yum install https://zfsonlinux.org/epel/zfs-release-2-3$(rpm --eval "%{dist}").noarch.rpm
yum install -y epel-release kernel-devel git
yum install -y zfs

# Enable module load on boot
echo zfs > /etc/modules-load.d/zfs.conf
/sbin/modprobe zfs


# Install the cockpit manager
cd ~
git clone https://github.com/optimans/cockpit-zfs-manager.git
cp -r cockpit-zfs-manager/zfs /usr/share/cockpit
rm -fr cockpit


##########################################################
##########################################################
# 
# 1). Setup Devices
# 
##########################################################
##########################################################

# Vars
DATE_NOW=$(date)
ZFS_TEST_HOME=/media/zfs_test
DEVICE_HOME=${ZFS_TEST_HOME}/devices
ZFS_MOUNT=/mnt/zfs_test/zfs_pool
mkdir -p $ZFS_MOUNT $DEVICE_HOME
cd $ZFS_TEST_HOME


# Configure 3 sets of 10 devices for ZFS storage pools
bash zfs-devices.sh
for i in {1..3}; do ls ${ZFS_TEST_HOME}/devices/zfs-set$i | wc -l | awk '{print "Dev Set-'$i':\t"$1}'; done

'''

--> Image count
Dev Set-1:      10
Dev Set-2:      10
Dev Set-3:      10

--> Script log
Setting up 3 sets of 10 devices for ZFS pool:   Thu Aug 24 14:09:22 IST 2023

Setting device set:     1
0+0 records in
0+0 records out
0 bytes copied, 8.9731e-05 s, 0.0 kB/s

...

0+0 records in
0+0 records out
0 bytes copied, 3.9685e-05 s, 0.0 kB/s

Completed device set:   3

Process completed displaying loopback devices:  Thu Aug 24 14:09:25 IST 2023
/dev/loop1: [2064]:54092 (/media/zfs_test/devices/zfs-set1/disk-2.img)
/dev/loop29: [2064]:54217 (/media/zfs_test/devices/zfs-set3/disk-10.img)
...
/dev/loop3: [2064]:54100 (/media/zfs_test/devices/zfs-set1/disk-4.img)
/dev/loop20: [2064]:54207 (/media/zfs_test/devices/zfs-set3/disk-1.img)
/dev/loop10: [2064]:54187 (/media/zfs_test/devices/zfs-set2/disk-1.img)
'''


##########################################################
##########################################################
# 
# 2). RAID-3Z Pool from Set-1
# 
##########################################################
##########################################################


# Vars
DATE_NOW=$(date)
ZFS_TEST_HOME=/media/zfs_test
DEVICE_HOME=${ZFS_TEST_HOME}/devices
ZFS_MOUNT=/mnt/zfs_test/zfs_pool
cd $ZFS_TEST_HOME


# Create a striped and parity set 
# that can tolerate three drive failures
DRIVE_SET1=$(losetup -a | grep "set1" | cut -d ':' -f 1 | xargs)
zpool create poolset1 raidz3 $DRIVE_SET1


# Check creation
zpool list poolset1


'''

--> Summary
NAME       SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
poolset1  19.5G   326K  19.5G        -         -     0%     0%  1.00x    ONLINE  -


--> Status

  pool: poolset1
 state: ONLINE
config:

	NAME        STATE     READ WRITE CKSUM
	poolset1    ONLINE       0     0     0
	  raidz3-0  ONLINE       0     0     0
	    loop0   ONLINE       0     0     0
	    loop1   ONLINE       0     0     0
	    loop2   ONLINE       0     0     0
	    loop3   ONLINE       0     0     0
	    loop4   ONLINE       0     0     0
	    loop5   ONLINE       0     0     0
	    loop6   ONLINE       0     0     0
	    loop7   ONLINE       0     0     0
	    loop8   ONLINE       0     0     0
	    loop9   ONLINE       0     0     0

errors: No known data errors

'''


# Test writing
df -h /poolset1 && cd /poolset1
fallocate -l 5G /poolset1/5GB-File-2.raw
md5sum 5GB-File.raw > 5GB-File.md5sum
md5sum -c 5GB-File.raw

'''

--> Usage breaks away
Filesystem      Size  Used Avail Use% Mounted on
poolset1         14G  128K   14G   1% /poolset1

'''



##########################################################
##########################################################
# 
# 3). ZFS Pool ontop of RAID-6 Arrays
# 
##########################################################
##########################################################


######################################
######################################
# 
# a). Create RAID Arrays
# 
######################################
######################################


# Vars
DATE_NOW=$(date)
ZFS_TEST_HOME=/media/zfs_test
DEVICE_HOME=${ZFS_TEST_HOME}/devices
ZFS_MOUNT=/mnt/zfs_test/zfs_pool
cd $ZFS_TEST_HOME


# Setup raid-6 arrays
bash raidZFS-Devices.sh
cat /proc/mdstat

"""

--> RAID States

Personalities : [raid6] [raid5] [raid4] 
md3 : active raid6 loop29[9] loop28[8] loop27[7] loop26[6] loop25[5] loop24[4] loop23[3] loop22[2] loop21[1] loop20[0]
      16752640 blocks super 1.2 level 6, 512k chunk, algorithm 2 [10/10] [UUUUUUUUUU]
      
md2 : active raid6 loop19[9] loop18[8] loop17[7] loop16[6] loop15[5] loop14[4] loop13[3] loop12[2] loop11[1] loop10[0]
      16752640 blocks super 1.2 level 6, 512k chunk, algorithm 2 [10/10] [UUUUUUUUUU]
      
md1 : active raid6 loop9[9] loop8[8] loop7[7] loop6[6] loop5[5] loop4[4] loop3[3] loop2[2] loop1[1] loop0[0]
      16752640 blocks super 1.2 level 6, 512k chunk, algorithm 2 [10/10] [UUUUUUUUUU]



--> Process

Setting up 3 RAID-6 Arrays of 10 loopback devices:	Fri Aug 25 02:15:09 PDT 2023

Creating RAID-6 Array '/dev/md1' from below drives
/dev/loop0 /dev/loop1 /dev/loop2 /dev/loop3 /dev/loop4 /dev/loop5 /dev/loop6 /dev/loop7 /dev/loop8 /dev/loop9
mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md1 started.


Creation of RAID array completed

Creating RAID-6 Array '/dev/md2' from below drives
/dev/loop10 /dev/loop11 /dev/loop12 /dev/loop13 /dev/loop14 /dev/loop15 /dev/loop16 /dev/loop17 /dev/loop18 /dev/loop19
mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md2 started.


Creation of RAID array completed

Creating RAID-6 Array '/dev/md3' from below drives
/dev/loop20 /dev/loop21 /dev/loop22 /dev/loop23 /dev/loop24 /dev/loop25 /dev/loop26 /dev/loop27 /dev/loop28 /dev/loop29
mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md3 started.

Creation of RAID array completed


Setup complete:	Fri Aug 25 02:15:09 PDT 2023

"""


######################################
######################################
# 
# b). Create ZFS Pool
# 
######################################
######################################


# Vars
DATE_NOW=$(date)
ZFS_TEST_HOME=/media/zfs_test
DEVICE_HOME=${ZFS_TEST_HOME}/devices
ZFS_MOUNT=/mnt/zfs_test/zfs_pool
cd $ZFS_TEST_HOME

# Create ZFS pool on the raid-6 arrays
RAID_DEVICES=$(ls /dev/md* | xargs)
zpool create raidpool raidz2 $RAID_DEVICES
zfs set compression=lzjb raidpool
zpool list
zpool status raidpool

'''

--> Display ZFS Pool
NAME       USED  AVAIL     REFER  MOUNTPOINT
raidpool   114K  15.3G     23.9K  /raidpool

NAME       SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
raidpool  47.5G  1.06G  46.4G        -         -     0%     2%  1.00x    ONLINE  -


--> ZPool Status
  pool: raidpool
 state: ONLINE
config:

	NAME        STATE     READ WRITE CKSUM
	raidpool    ONLINE       0     0     0
	  raidz2-0  ONLINE       0     0     0
	    md1     ONLINE       0     0     0
	    md2     ONLINE       0     0     0
	    md3     ONLINE       0     0     0

errors: No known data errors

'''


# Test write to check compression
tar -cf bin-dir.tar /bin/*
ls -lh bin-dir.tar 
md5sum bin-dir.tar
cp bin-dir.tar /raidpool/

ls -lh /raidpool
df -h /raidpool
zfs list
md5sum /raidpool/bin-dir.tar

'''
--> Data
-rw-r--r--. 1 root root 145M Aug 25 02:27 bin-dir.tar
c60863ce58031d98abf24859eb3c7b7c  bin-dir.tar


--> Disk Usage
total 89M
-rw-r--r--. 1 root root 145M Aug 25 02:29 bin-dir.tar

Filesystem      Size  Used Avail Use% Mounted on
raidpool         16G   89M   16G   1% /raidpool

NAME       USED  AVAIL     REFER  MOUNTPOINT
raidpool  88.2M  15.2G     88.1M  /raidpool

--> Fingerprint on ZFS Pool
c60863ce58031d98abf24859eb3c7b7c  /raidpool/bin-dir.tar
'''


######################################
######################################
# 
# c). Write Some Test Data
# 
######################################
######################################

# Vars
DATE_NOW=$(date)
ZFS_TEST_HOME=/media/zfs_test
DEVICE_HOME=${ZFS_TEST_HOME}/devices
ZFS_MOUNT=/mnt/zfs_test/zfs_pool
cd $ZFS_TEST_HOME


# Install tree
yum install -y tree


# Write load of test data before mucking
#  about with underlying raid arrays
bash writeTest-Data.sh

df -h /raidpool
du -sh /raidpool/batch* | cut -f 1 | sed 's/M//g' | awk 'BEGIN{sum=0} {sum+=$1} END {print "Total Size = \""sum"M\""}'

"""

--> Disk Usage After
Filesystem      Size  Used Avail Use% Mounted on
raidpool         16G  362M   15G   3% /raidpool

Total Size = "278M"


--> Process Log
Creating test files:	Fri Aug 25 02:54:09 PDT 2023

Generation mock data files for batch-1
Data generation for batch-1 completed

Generation mock data files for batch-2
Data generation for batch-2 completed

Data generation has completed for all batches. Creating a directory tree

Process completed with N Files generated = '5064'
"""


# Scan arrays after writing data
mdadm --detail /dev/md1
mdadm --detail /dev/md2
mdadm --detail /dev/md3


######################################
######################################
# 
# d). Kill a Drive from Each Array
# 
######################################
######################################


# Vars
DATE_NOW=$(date)
ZFS_TEST_HOME=/media/zfs_test
DEVICE_HOME=${ZFS_TEST_HOME}/devices
ZFS_MOUNT=/mnt/zfs_test/zfs_pool
cd $ZFS_TEST_HOME


# Mark a drive as failed from each raid array
mdadm --manage /dev/md1 --fail /dev/loop2
mdadm --manage /dev/md2 --fail /dev/loop13
mdadm --manage /dev/md3 --fail /dev/loop24

"""

mdadm: set /dev/loop2 faulty in /dev/md1
mdadm: set /dev/loop13 faulty in /dev/md2
mdadm: set /dev/loop24 faulty in /dev/md3

"""


# Check ZPool state
zpool list
zpool status raidpool

"""
NAME       SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
raidpool  47.5G  1.06G  46.4G        -         -     0%     2%  1.00x    ONLINE  -

  pool: raidpool
 state: ONLINE
config:

	NAME        STATE     READ WRITE CKSUM
	raidpool    ONLINE       0     0     0
	  raidz2-0  ONLINE       0     0     0
	    md1     ONLINE       0     0     0
	    md2     ONLINE       0     0     0
	    md3     ONLINE       0     0     0

errors: No known data errors

"""


######################################
######################################
# 
# e). Tank an Array
# 
######################################
######################################


# Vars
DATE_NOW=$(date)
ZFS_TEST_HOME=/media/zfs_test
DEVICE_HOME=${ZFS_TEST_HOME}/devices
ZFS_MOUNT=/mnt/zfs_test/zfs_pool
cd $ZFS_TEST_HOME


# Kill drives and check raid state
mdadm --manage /dev/md1 --fail /dev/loop8
mdadm --manage /dev/md1 --fail /dev/loop8
mdadm --manage /dev/md1 --fail /dev/loop1
mdadm --manage /dev/md1 --fail /dev/loop3
mdadm --manage /dev/md1 --fail /dev/loop4
mdadm --manage /dev/md1 --fail /dev/loop5
mdadm --manage /dev/md1 --fail /dev/loop6
mdadm --manage /dev/md1 --fail /dev/loop7
mdadm --manage /dev/md1 --fail /dev/loop0
mdadm --detail /dev/md1

'''

--> Tested incrementally
/dev/md1:
           Version : 1.2
     Creation Time : Fri Aug 25 02:15:09 2023
        Raid Level : raid6
        Array Size : 16752640 (15.98 GiB 17.15 GB)
     Used Dev Size : 2094080 (2045.00 MiB 2144.34 MB)
      Raid Devices : 10
     Total Devices : 10
       Persistence : Superblock is persistent

       Update Time : Fri Aug 25 04:02:24 2023
             State : clean, FAILED 
    Active Devices : 0
    Failed Devices : 10
     Spare Devices : 0

'''

# Check data state
df -h /raidpool
zpool list
zpool status /raidpool

"""

--> ZPool State
NAME       SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
raidpool  47.5G  1.06G  46.4G        -         -     0%     2%  1.00x  DEGRADED  -


--> Zpool Status
  pool: raidpool
 state: DEGRADED
status: One or more devices are faulted in response to persistent errors.
	Sufficient replicas exist for the pool to continue functioning in a
	degraded state.
action: Replace the faulted device, or use 'zpool clear' to mark the device
	repaired.
config:

	NAME        STATE     READ WRITE CKSUM
	raidpool    DEGRADED     0     0     0
	  raidz2-0  DEGRADED     0     0     0
	    md1     FAULTED     70   337     0  too many errors
	    md2     ONLINE       0     0     0
	    md3     ONLINE       0     0     0

errors: No known data errors

"""

# Check Data state
bash checkFilesLost.sh 
md5sum -c data-files-md5sums.txt | grep -c "OK" | awk '{print "Files Still OK:\t"$1}'
sort -R data-files-md5sums.txt | awk 'NR <= 10 { print $NF }' | while read line; do wc -l $line; done
sort -R data-files-md5sums.txt | awk '{ print $NF }' | while read line; do wc -l $line; done | wc -l

"""

--> Results make sense as the ZPool can tolerate 
    the loss of an underlining RAID-6 array


--> Fine after a corrupt array
Checking file states after drive failures:	Fri Aug 25 04:03:05 PDT 2023
5064 /media/zfs_test/data-file-tree.txt

Displaying Summary of File States:	Fri Aug 25 04:03:05 PDT 2023
Files Lost:	'0'
Files Kept:	'5000'


--> Confirm with md5sum check
Files Still OK:	5000


--> Physically read them, no errors

28610 /raidpool/batch-10/split-3/data-file-67.txt
32693 /raidpool/batch-6/split-5/data-file-44.txt
2862 /raidpool/batch-1/split-1/data-file-72.txt
4287 /raidpool/batch-9/split-5/data-file-2.txt
23465 /raidpool/batch-8/split-1/data-file-32.txt
25640 /raidpool/batch-1/split-2/data-file-10.txt
20045 /raidpool/batch-3/split-5/data-file-58.txt
13735 /raidpool/batch-8/split-2/data-file-15.txt
7665 /raidpool/batch-8/split-5/data-file-90.txt
5477 /raidpool/batch-6/split-5/data-file-58.txt


5000

"""



######################################
######################################
# 
# e). Tank Another Array
# 
######################################
######################################


# Vars
DATE_NOW=$(date)
ZFS_TEST_HOME=/media/zfs_test
DEVICE_HOME=${ZFS_TEST_HOME}/devices
ZFS_MOUNT=/mnt/zfs_test/zfs_pool
cd $ZFS_TEST_HOME


# Check status
zpool list
zpool status raidpool

"""

--> Degraded by can operate
NAME       SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
raidpool  47.5G  1.06G  46.4G        -         -     0%     2%  1.00x  DEGRADED  -


--> Degraded state because md1 is gone, but can function

  pool: raidpool
 state: DEGRADED
status: One or more devices are faulted in response to persistent errors.
	Sufficient replicas exist for the pool to continue functioning in a
	degraded state.
action: Replace the faulted device, or use 'zpool clear' to mark the device
	repaired.
config:

	NAME        STATE     READ WRITE CKSUM
	raidpool    DEGRADED     0     0     0
	  raidz2-0  DEGRADED     0     0     0
	    md1     FAULTED     70   337     0  too many errors
	    md2     ONLINE       0     0     0
	    md3     ONLINE       0     0     0

errors: No known data errors

"""


# Kill two drives from md2
mdadm --manage /dev/md2 --fail /dev/loop17
mdadm --detail /dev/md2

"""
mdadm: set /dev/loop17 faulty in /dev/md2

       Update Time : Fri Aug 25 04:14:32 2023
             State : clean, degraded 
    Active Devices : 8
   Working Devices : 8
    Failed Devices : 2
     Spare Devices : 0

       3       7       13        -      faulty   /dev/loop13
       7       7       17        -      faulty   /dev/loop17

"""

# Check ZPool status
zpool list
zpool status raidpool

"""

--> Still good

  pool: raidpool
 state: DEGRADED
status: One or more devices are faulted in response to persistent errors.
	Sufficient replicas exist for the pool to continue functioning in a
	degraded state.
action: Replace the faulted device, or use 'zpool clear' to mark the device
	repaired.
config:

	NAME        STATE     READ WRITE CKSUM
	raidpool    DEGRADED     0     0     0
	  raidz2-0  DEGRADED     0     0     0
	    md1     FAULTED     70   337     0  too many errors
	    md2     ONLINE       0     0     0
	    md3     ONLINE       0     0     0

errors: No known data errors

"""


# Check Data state
bash checkFilesLost.sh 
md5sum -c data-files-md5sums.txt | grep -c "OK" | awk '{print "Files Still OK:\t"$1}'
sort -R data-files-md5sums.txt | awk 'NR <= 10 { print $NF }' | while read line; do wc -l $line; done
sort -R data-files-md5sums.txt | awk '{ print $NF }' | while read line; do wc -l $line; done | wc -l


"""

--> Data is still ok

Checking file states after drive failures:	Fri Aug 25 04:15:51 PDT 2023
5064 /media/zfs_test/data-file-tree.txt

Displaying Summary of File States:	Fri Aug 25 04:15:52 PDT 2023
Files Lost:	'0'
Files Kept:	'5000'

Files Still OK:	5000

13466 /raidpool/batch-2/split-2/data-file-58.txt
3967 /raidpool/batch-3/split-5/data-file-68.txt
17155 /raidpool/batch-6/split-2/data-file-49.txt
25272 /raidpool/batch-5/split-5/data-file-68.txt
8080 /raidpool/batch-4/split-4/data-file-6.txt
23446 /raidpool/batch-3/split-4/data-file-59.txt
9420 /raidpool/batch-5/split-3/data-file-5.txt
7953 /raidpool/batch-3/split-2/data-file-70.txt
18337 /raidpool/batch-10/split-4/data-file-42.txt
14153 /raidpool/batch-8/split-4/data-file-40.txt

5000

"""


# Kill third drive
mdadm --manage /dev/md2 --fail /dev/loop11
mdadm --manage /dev/md2 --fail /dev/loop16
mdadm --manage /dev/md2 --fail /dev/loop15
mdadm --manage /dev/md2 --fail /dev/loop14
mdadm --detail /dev/md2

zpool list
zpool status raidpool

"""

--> RAID state is failed
       Update Time : Fri Aug 25 04:18:06 2023
             State : clean, FAILED 
    Active Devices : 7
   Working Devices : 7
    Failed Devices : 3
     Spare Devices : 0


       1       7       11        -      faulty   /dev/loop11
       3       7       13        -      faulty   /dev/loop13
       7       7       17        -      faulty   /dev/loop17

--> ZPool status is still the same
"""


# Check data state
bash checkFilesLost.sh 
md5sum -c data-files-md5sums.txt | grep -c "OK" | awk '{print "Files Still OK:\t"$1}'
sort -R data-files-md5sums.txt | awk 'NR <= 10 { print $NF }' | while read line; do wc -l $line; done
sort -R data-files-md5sums.txt | awk '{ print $NF }' | while read line; do wc -l $line; done | wc -l


"""

--> Data state with three drive failures is still the same, but ZPool state has changed.
     => This could be an artifact because of the size of the data on the pool.
	 => Still a nice find

  pool: raidpool
 state: DEGRADED
status: One or more devices are faulted in response to persistent errors.
	Sufficient replicas exist for the pool to continue functioning in a
	degraded state.
action: Replace the faulted device, or use 'zpool clear' to mark the device
	repaired.
config:

	NAME        STATE     READ WRITE CKSUM
	raidpool    DEGRADED     0     0     0
	  raidz2-0  DEGRADED     0     0     0
	    md1     FAULTED     70   337     0  too many errors
	    md2     FAULTED      1   176     0  too many errors
	    md3     ONLINE       0     0     0

errors: No known data errors

"""