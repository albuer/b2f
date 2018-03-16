#!/system/bin/sh

######################################################
#
# Query file name from sector number
#
# Authors: cmy@rock-chips.com
#
######################################################
# dmesg -c
# echo 1 > /proc/sys/vm/block_dump
# dd if=/dev/zero of=/data/local/tmp/test.bin bs=4096 count=1000
# echo 0 > /proc/sys/vm/block_dump
# dmesg > /data/local/tmp/kernel.log

sector_size=512
log_file="/data/local/tmp/kernel.log"
debugfs_exec="/data/local/tmp/debugfs"

if [ x"$1" != x"" ]; then
      log_file=$1
fi

echo "Read from file: $log_file"

cat $log_file | grep -E " block.*on " | while read strline
do
    echo $strline

    IFS=' '
#    arr=(${strline##*:})
    arr=(${strline})
#for x in ${arr[@]}; do
#  echo $x
#done
    if [ x"${arr[1]:0:3}" == x"jbd" ]; then
        continue
    fi
    sec_num=${arr[4]}
    blk_dev=${arr[6]}

# get block size
    blk_size=`eval echo '$'blk_size_$blk_dev`
    if [ x"$blk_size" == x"" ]; then
        eval blk_size_$blk_dev=`$debugfs_exec -R "show_super_stats" /dev/block/$blk_dev 2>&1 | busybox grep "Block size:" | busybox awk '{print $3}'`
        blk_size=`eval echo '$'blk_size_$blk_dev`
        echo "blk_dev=$blk_dev  blk_size=$blk_size"    
    fi
    if [ x"$blk_size" == x"" ]; then
        echo "Block size is empty, SKIP it!"
        continue
    fi

    blk2sec=$(($blk_size/$sector_size))

    blk_num=$(($sec_num/$blk2sec))
#echo "blk_dev=$blk_dev  sec_num=$sec_num  blk_num=$blk_num"
    # query inode from block number
    inode_num=`$debugfs_exec -R "icheck $blk_num" /dev/block/$blk_dev 2>&1 | busybox sed -n 3p | busybox awk '{print $2}'`
    if [ x"$inode_num" != x"<block" ]; then
    	# query file name from inode
        file_name=`$debugfs_exec -R "ncheck $inode_num" /dev/block/$blk_dev 2>&1 | busybox sed -n 3p | busybox awk '{print $2}'`
        if [ x"$file_name" == x"" ]; then
            file_name="[NULL]"
        fi
        echo "    >> TARGET(blk=$blk_num inode=$inode_num): $blk_dev:$file_name"
    fi
done

