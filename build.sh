#!/bin/bash
#
# This script can build U-Boot, the Kernle, the RootFS, or all of above on arm64.
# 

### Configurations and global variables ###
# 支持的参数列表
ARGSLIST="hHrRcCd:D:"
# 主机需要安装的依赖和软件包
HOST_DEPENDS="debootstrap qemu-user qemu-user-static qemu-system"
# 获取主机名称，如：Ubuntu
HOST_NAME=$(grep '^NAME=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
# 获取主机发行版版本号，如：24.04
HOST_VERID=$(grep '^VERSION_ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
# 输出目录
OUTDIR="$PWD/output"
# 根文件系统构建目录
ROOTFSDIR="$OUTDIR/rootfs"
# 在chroot里面运行的脚本路径
SCRIPTDIR="$PWD/scripts"
# 具体的根文件系统配置脚本名称
SCRIPT="script_focal.sh"
# 对应版本apt mirror文件
MIRRORSDIR="$PWD/mirrors"
mirror_ubuntu_2004="$MIRRORSDIR/mirror_ubuntu_2004.txt"
mirror_ubuntu_2204="$MIRRORSDIR/mirror_ubuntu_2204.txt"
mirror_ubuntu_2404="$MIRRORSDIR/mirror_ubuntu_2404.txt"
# 用于debootstrap下载的mirror
DEBMIRROR="https://mirrors.aliyun.com/ubuntu-ports/"

### Functions ###

function rootfs () {
    log_info "Create output directory"
    mkdir -pv $OUTDIR

    log_info "Install host depends"
    sudo apt install -y $HOST_DEPENDS

    log_info "Run debootstrap"
    #if ! sudo debootstrap --arch=arm64 \
    #    --components=main,universe,restricted,multiverse \
    #    --include=ubuntu-standard \
    #    $TARGET $ROOTFSDIR $DEBMIRROR; then
    #        exit 1
    #fi

    log_info "Copy script to rootfs"
    sudo cp -v $SCRIPTDIR/$SCRIPT $ROOTFSDIR
    sudo chmod -v a+x $ROOTFSDIR/$SCRIPT

    if [ "$TARGET" == "focal" ]; then
        log_info "Configure apt mirror"
        sudo cp -v $mirror_ubuntu_2004 $ROOTFSDIR/etc/apt/sources.list
    elif [ "$TARGET" == "jammy" ]; then
        log_info "Configure apt mirror"
        sudo cp -v $mirror_ubuntu_2204 $ROOTFSDIR/etc/apt/sources.list
    elif [ "$TARGET" == "noble" ]; then
        log_info "Configure apt mirror"
        sudo cp -v $mirror_ubuntu_2404 $ROOTFSDIR/etc/apt/sources.list.d/ubuntu.sources
    fi

    log_info "chroot to rootfs"
    sudo chroot $OUTDIR/rootfs /bin/bash $SCRIPT

    log_info "Logout from chroot"

    log_info "Create rootfs image to $OUTDIR/disk.img"
    sudo dd if=/dev/zero of=$OUTDIR/disk.img bs=1G count=10 conv=sync
    sudo mkfs.ext4 -v $OUTDIR/disk.img
    mkdir -pv $OUTDIR/mnt
    sudo mount -v -t ext4 $OUTDIR/disk.img $OUTDIR/mnt

    log_info "Package rootfs to $OUTDIR/disk.tar"
    if ! sudo tar \
        --numeric-owner \
        --preserve-permissions \
        --exclude="dev/*" \
        --exclude="proc/*" \
        --exclude="sys/*" \
        --exclude="tmp/*" \
        -cf $OUTDIR/disk.tar -C $ROOTFSDIR/ .; then
            exit 1
    fi

    log_info "Extract rootfs to $OUTDIR/mnt"
    sudo tar -xf $OUTDIR/disk.tar -C $OUTDIR/mnt
    sudo umount -v -t ext4 $OUTDIR/mnt

    log_info "Resize rootfs image"
    sudo e2fsck -f -y $OUTDIR/disk.img
    sudo resize2fs -M $OUTDIR/disk.img

    log_info "Done!"
}


function help () {
    echo "usage: $0 -$ARGSLIST"
    echo -e "\t-h|-H Show help infomations"
    echo -e "\t-d|-D [arguments...] TARGET [focal|jammy|noble]"
    echo -e "\t-r|-R Build RootFS"
    echo -e "\t-c|-C Clean"
}

function log_info () {
    local str="[\033[32m$0\033[0m] $(date): $1"
    echo -e "$str"
    echo -e "$(date): $1" >> $PWD/logs/$(date +%Y%m%d).log
}

function log_err () {
    local str="[\033[31m$0\033[0m] $(date): $1"
    echo -e "$str"
    echo -e "$(date): $1" >> $PWD/logs/$(date +%Y%m%d).log
}

function clean() {
    log_info "Clean $OUTDIR"
    sudo rm -rvf $OUTDIR
}

function check_host() {
    if [ "$HOST_VERID" != "20.04" ] \
        && [ "$HOST_VERID" != "22.04" ] \
        && [ "$HOST_VERID" != "24.04" ] \
        && [ "$HOST_NAME" != "Ubuntu" ]; then
            log_err "Only supports building on Ubuntu 20.04/22.04/24.04!"
            exit 1
    fi
}

function main()
{
    local rootfs_flag=false
    local target_flag=false

    check_host
    if (( $# > 0 )); then
        while getopts "$ARGSLIST" opt; do
            case "$opt" in
                h|H)
                    help
                    exit 0
                    ;;
                r|R)
                    rootfs_flag=true
                    ;;
                d|D)
                    TARGET="$OPTARG"
                    target_flag=true
                    ;;
                c|C)
                    clean
                    exit 0
                    ;;
                *)
                    help
                    exit 1
                    ;;
            esac
        done
    else
        help
        exit 1
    fi

    if [ $rootfs_flag == true ] && [ $target_flag == true ]; then
        rootfs
    else
        help
        exit 1
    fi
    exit 0
}

main "$@"
