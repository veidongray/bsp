#!/bin/bash
##########################################################################################
# Author: Ray
# Email: veidongray@qq.com
# Description: This script is used to build the root filesystem for arm64 architecture.
##########################################################################################

### Configurations and global variables ###
# 支持的参数列表
ARGSLIST="hHrRcCd:D:s:S:m:M:"
# 主机需要安装的依赖和软件包
HOST_DEPENDS="debootstrap qemu-user qemu-user-static qemu-system"
# 获取主机名称，如：Ubuntu
HOST_NAME=$(grep '^NAME=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
# 获取主机发行版版本号，如：24.04
HOST_VERID=$(grep '^VERSION_ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
# 输出目录
OUTDIR="output"
# 日志目录
LOGDIR="logs"
# 根文件系统构建目录
ROOTFSDIR=""
# 在chroot里面运行的脚本路径
SCRIPTDIR="scripts"
# Default script name for rootfs
SCRIPT="script.sh"
# Default file name for mirror
MIRRORFILE="mirrors.txt"
# 用于debootstrap下载的mirror
DEBMIRROR="https://mirrors.aliyun.com/ubuntu-ports/"

### Functions ###

function rootfs () {
    log_info "Run debootstrap"
    #if ! debootstrap --arch=arm64 \
    #    --components=main,universe,restricted,multiverse \
    #    --include=ubuntu-minimal \
    #    $TARGET $ROOTFSDIR $DEBMIRROR; then
    #        log_err "debootstrap failed!"
    #        return 1
    #fi

    log_info "Copy script to rootfs"
    cp -v configs/$TARGET/$SCRIPTDIR/$SCRIPT $ROOTFSDIR
    chmod -v a+x $ROOTFSDIR/$SCRIPT

    log_info "Configure apt mirror"
    mirror_ubuntu="configs/$TARGET/mirrors/$MIRRORFILE"
    cp -v $mirror_ubuntu $ROOTFSDIR/etc/apt/sources.list

    log_info "chroot to rootfs"
    chroot $ROOTFSDIR /bin/bash $SCRIPT
    log_info "Logout from chroot"

    log_info "Create rootfs image to $PWD/$OUTDIR/$TARGET/disk.img"
    dd if=/dev/zero of=$OUTDIR/$TARGET/disk.img bs=1G count=10 conv=sync
    mkfs.ext4 -v $OUTDIR/$TARGET/disk.img
    mkdir -pv $OUTDIR/$TARGET/mnt
    mount -v -t ext4 $OUTDIR/$TARGET/disk.img $OUTDIR/$TARGET/mnt

    log_info "Package rootfs to $PWD/$OUTDIR/$TARGET/disk.tar"
    if ! tar --numeric-owner \
        --preserve-permissions \
        --exclude="dev/*" \
        --exclude="proc/*" \
        --exclude="sys/*" \
        --exclude="tmp/*" \
        -cf $OUTDIR/$TARGET/disk.tar -C $ROOTFSDIR .; then
            umount -v -t ext4 $OUTDIR/$TARGET/mnt
            return 1
    fi

    log_info "Extract rootfs to $PWD/$OUTDIR/$TARGET/mnt"
    if ! tar --numeric-owner \
        --preserve-permissions \
        -xf $OUTDIR/$TARGET/disk.tar -C $OUTDIR/$TARGET/mnt; then
            umount -v -t ext4 $OUTDIR/$TARGET/mnt
            return 1
    fi
    umount -v -t ext4 $OUTDIR/$TARGET/mnt

    log_info "Resize rootfs image"
    e2fsck -f -y $OUTDIR/$TARGET/disk.img
    resize2fs -M $OUTDIR/$TARGET/disk.img

    log_info "Done!"
}


function help () {
    echo "usage: $0 -$ARGSLIST"
    echo -e "\t-h|-H Show help infomations"
    echo -e "\t-d|-D [arguments...] TARGET in configs/*"
    echo -e "\t-r|-R Build RootFS"
    echo -e "\t-s|-S Script path"
    echo -e "\t-m|-M Mirror path"
    echo -e "\t-c|-C Clean"
    echo -e "\n"
    echo -e "Example: $0 -r -d focal"
}

function log_info () {
    local str="[\033[32m$0\033[0m] [I] $(date): $1"
    echo -e $str
    echo -e "[I] $(date): $1" >> $LOGDIR/$(date +%Y%m%d).log
}

function log_err () {
    local str="[\033[31m$0\033[0m] [E] $(date): $1"
    echo -e "$str"
    echo -e "[E] $(date): $1" >> $LOGDIR/$(date +%Y%m%d).log
}

function clean() {
    log_info "rm -rf $OUTDIR $LOGDIR"
    rm -rf $OUTDIR $LOGDIR
}

function check_host() {
    if [ "$HOST_VERID" != "20.04" ] \
        && [ "$HOST_VERID" != "22.04" ] \
        && [ "$HOST_VERID" != "24.04" ] \
        && [ "$HOST_NAME" != "Ubuntu" ]; then
            log_err "Only supports building on Ubuntu 20.04/22.04/24.04!"
            return 1
    fi
    return 0
}

function main()
{
    local time_start=""
    local time_end=""
    local time_hour=""
    local time_min=""
    local time_sec=""
    local time_total=""
    local rootfs_flag=false
    local target_flag=false

    if (( $# > 0 )); then
        while getopts "$ARGSLIST" opt; do
            case "$opt" in
                h|H)
                    help
                    return 0
                    ;;
                r|R)
                    rootfs_flag=true
                    ;;
                d|D)
                    TARGET="$OPTARG"
                    ROOTFSDIR="$OUTDIR/$TARGET/rootfs"
                    for dir in configs/*; do
                        if [ -d "$dir" ]; then
                            if [ "$(basename $dir)" == "$TARGET" ]; then
                                target_flag=true
                            fi
                        fi
                    done
                    if [ $target_flag != true ]; then
                        help
                        return 1
                    fi
                    ;;
                s|S)
                    SCRIPT="$OPTARG"
                    ;;
                m|M)
                    MIRRORFILE="$OPTARG"
                    ;;
                c|C)
                    clean
                    return 0
                    ;;
                *)
                    help
                    return 1
                    ;;
            esac
        done
    else
        help
        return 1
    fi

    if [ $rootfs_flag == true ] && [ $target_flag == true ]; then
        log_info "Start building"
        log_info "Check host environment"
        if ! check_host; then
            return 1
        fi
        log_info "Host environment check passed"

        log_info "Install host depends"
        apt install -y $HOST_DEPENDS

        log_info "Host: $HOST_NAME $HOST_VERID"
        log_info "Arguments: $*"
        log_info "Output directory: $OUTDIR"
        log_info "RootFS directory: $ROOTFSDIR"
        log_info "Script directory: $SCRIPTDIR"
        log_info "Mirror for debootstrap: $DEBMIRROR"

        local time_tmp=""
        local time_msg=""
        time_start=$(date +%s)
        mkdir -pv $OUTDIR/$TARGET
        rootfs
        time_end=$(date +%s)
        time_total=$(echo "$time_end - $time_start" | bc)
        time_hour=$(echo "$time_total / 3600" | bc)
        time_min=$(echo "($time_total - (3600 * $time_hour)) / 60" | bc)
        time_sec=$(echo "($time_total - (3600 * $time_hour) - (60 * $time_min))" | bc)
        printf -v time_msg "%02d:%02d:%02d" $time_hour $time_min $time_sec
        log_info "Total time ${time_msg}"
    else
        help
        return 1
    fi
    return 0
}

######## Begin ########
if [ "$(id -u)" -eq 0 ]; then
    echo "Running as root"
    CURRENTDIR=$(pwd)
    # 进入脚本所在目录运行
    cd "$(dirname "$0")"
    mkdir -p $LOGDIR
    mkdir -p $OUTDIR
    main "$@"
    # 回到原来的目录
    cd "$CURRENTDIR"
    exit 0
else
    echo "Not running as root"
    exit 1
fi
########  End  ########
