#!/bin/bash
# Version 1.0
echo 'Installing FreeFileSync'
FFS_ROOT='https://freefilesync.org'
FFS_FILENAME=$(curl --silent $FFS_ROOT/download.php | grep -Po "FreeFileSync.*Linux.tar.gz")
FFS_DL=$FFS_ROOT/download/$FFS_FILENAME
echo "Found at $FFS_DL"
wget $FFS_DL
tar xf $FFS_FILENAME
FFS_INST=$(echo $FFS_FILENAME | grep -Po "FreeFileSync_.*_")Install.run
./$FFS_INST
rm FreeFileSync*
echo 'Cleaning up install files'

