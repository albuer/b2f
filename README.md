# b2f
It's a shell script for transform block number to filename

### 1. 获取一个android上可运行的debugfs
在b2f目录下已经有提供了一个静态链接的debugfs程序，for ARM32版本，你可直接使用，也可自行下载源码编译，以下简单介绍下debugfs编译步骤

* 1.1 下载e2fsprogs源码
我直接在ubuntu系统中通过apt-get获得e2fsprogs源码
```shell
apt-get source e2fsprogs
```
在我机器上得到的是e2fsprogs-1.42.9

* 1.2 配置及编译debugfs
使用arm交叉编译器，静态编译debugfs
```shell
cd e2fsprogs-1.42.9
./configure --host=arm-linux-gnueabi CC=arm-linux-gnueabi-gcc LDFLAGS=--static
make
arm-linux-gnueabi-strip -s debugfs/debugfs
```
至此，得到一个静态编译的debugfs/debugfs可以实现块号反查文件名

### 2. 把需要的文件推送到Android设备上
```shell
adb push b2f.sh /data/local/tmp/
adb push debugfs /data/local/tmp/
adb shell chmod 0755 /data/local/tmp/b2f.sh
adb shell chmod 0755 /data/local/tmp/debugfs
```

### 3. 获取文件读写的扇区号
注： 需要root权限
* 开启block dump功能
```shell
echo 1 > /proc/sys/vm/block_dump
```
* 接下来，做一些读写文件的操作，比如
```shell
echo 3 > /proc/sys/vm/drop_caches
dd if=/dev/zero of=/data/local/tmp/test.bin bs=4096 count=1000
```
* 关闭block dump功能
```shell
echo 0 > /proc/sys/vm/block_dump
```
* 保存block读写的信息
查看kernel log，在文件读写时候会有类似如下的信息输出：
```
....
<7>[100046.203955] kworker/u8:1(19754): WRITE block 813784 on mmcblk0p12 (256 sectors)
<7>[100046.204715] kworker/u8:1(19754): WRITE block 814040 on mmcblk0p12 (256 sectors)
<7>[100046.205444] kworker/u8:1(19754): WRITE block 814296 on mmcblk0p12 (256 sectors)
<7>[100046.206180] kworker/u8:1(19754): WRITE block 814552 on mmcblk0p12 (256 sectors)
<7>[100046.206922] kworker/u8:1(19754): WRITE block 814808 on mmcblk0p12 (256 sectors)
<7>[100046.207518] kworker/u8:1(19754): WRITE block 815064 on mmcblk0p12 (64 sectors)
<7>[100049.369541] jbd2/mmcblk0p12(160): WRITE block 25608 on mmcblk0p12 (8 sectors)
<7>[100049.369695] jbd2/mmcblk0p12(160): WRITE block 25616 on mmcblk0p12 (8 sectors)
<7>[100049.369794] jbd2/mmcblk0p12(160): WRITE block 25624 on mmcblk0p12 (8 sectors)
....
```
把这些kernel log保存到文件中，比如/data/local/tmp/kernel.log
现在已经得到文件读写的扇区号信息了，下一步就可以用b2f.sh脚本反查扇区号，得到目标文件名称。

### 4. 反查扇区号，获取文件名
调用b2f.sh脚本程序从block number反查得到文件名称：
```
/data/local/tmp/b2f.sh /data/local/tmp/kernel.log
```
查询的结果如下：
```
<7>[100046.206922] kworker/u8:1(19754): WRITE block 814808 on mmcblk0p12 (256 sectors)
    >> TARGET(blk=101851 inode=8210): mmcblk0p12:/local/tmp/test.bin
<7>[100046.207518] kworker/u8:1(19754): WRITE block 815064 on mmcblk0p12 (64 sectors)
    >> TARGET(blk=101883 inode=8210): mmcblk0p12:/local/tmp/test.bin
<7>[100049.369541] jbd2/mmcblk0p12(160): WRITE block 25608 on mmcblk0p12 (8 sectors)
<7>[100049.369695] jbd2/mmcblk0p12(160): WRITE block 25616 on mmcblk0p12 (8 sectors)
```

