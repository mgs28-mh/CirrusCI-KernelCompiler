#!/usr/bin/env bash
#
# @Gabuters Team

# Needed Secret Variable
# TG_TOKEN | Your telegram bot token
# TG_CHAT_ID | Your telegram private ci chat id

echo "Downloading few Dependecies . . ."
# Kernel Sources
git clone --depth=1 https://github.com/mgs28-mh/kernel_xiaomi_ulysse-4.9.git -b a12/temp ulysse
git clone --depth=1 https://github.com/Gabuters-Dev/gabuters-clang -b master GABUTERSxTC

# Main Declaration
KERNEL_ROOTDIR=$(pwd)/ulysse # IMPORTANT ! Fill with your kernel source root directory.
DEVICE_DEFCONFIG=ulysse_defconfig # IMPORTANT ! Declare your kernel source defconfig file here.
CLANG_ROOTDIR=$(pwd)/GABUTERSxTC # IMPORTANT! Put your clang directory here.
export KBUILD_BUILD_USER=nobody # Change with your own name or else.
export KBUILD_BUILD_HOST=Gabuters-dev # Change with your own hostname.
export PROCS=$(nproc --all)
export DISTRO=$(source /etc/os-release && echo "${NAME}")

# Main Declaration
CLANG_VER="$("$CLANG_ROOTDIR"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
LLD_VER="$("$CLANG_ROOTDIR"/bin/ld.lld --version | head -n 1)"
export KBUILD_COMPILER_STRING="$CLANG_VER with $LLD_VER"
IMAGE=$(pwd)/ulysse/out/arch/arm64/boot/Image.gz-dtb
VERBOSE=0
DATE=$(date +"%F-%S")
START=$(date +"%s")

# Checking environtment
# Warning !! Dont Change anything there without known reason.
function check() {
echo ================================================
echo CI Build Triggered
echo version : rev2.0 - gaspoll
echo ================================================
echo DOCKER OS = ${DISTRO}
echo HOST CORE COUNT = ${PROCS}
echo BUILDER NAME = ${KBUILD_BUILD_USER}
echo BUILDER HOSTNAME = ${KBUILD_BUILD_HOST}
echo DEVICE_DEFCONFIG = ${DEVICE_DEFCONFIG}
echo TOOLCHAIN_VERSION = ${KBUILD_COMPILER_STRING}
echo CLANG_ROOTDIR = ${CLANG_ROOTDIR}
echo KERNEL_ROOTDIR = ${KERNEL_ROOTDIR}
echo ================================================
}

# Telegram
export BOT_MSG_URL="https://api.telegram.org/bot$token/sendMessage"

tg_post_msg() {
  curl -s -X POST "$BOT_MSG_URL" -d chat_id="$chat_id" \
  -d "disable_web_page_preview=true" \
  -d "parse_mode=html" \
  -d text="$1"

}

# Post Main Information
tg_post_msg "<b>CI Build Triggered</b>%0A<b>Docker OS : </b><code>${DISTRO}</code>%0A<b>Host Core Count : </b><code>${PROCS}</code>%0A</b>Builder Name : </b><code>${KBUILD_BUILD_USER}</code>%0A</b>Builder Host : </b><code>${KBUILD_BUILD_HOST}</code>%0A</b>Device Defconfig : </b><code>${DEVICE_DEFCONFIG}</code>%0A</b>Clang Version : </b><code>${KBUILD_COMPILER_STRING}</code>%0A</b>Clang Rootdir : </b><code>${CLANG_ROOTDIR}</code>%0A</b>Kernel Rootdir : </b><code>${KERNEL_ROOTDIR}</code>"

# Compile
compile(){
tg_post_msg "<b>CI Build Triggered : </b><code>Compilation has started</code>"
cd ${KERNEL_ROOTDIR}
make -j$(nproc) O=out ARCH=arm64 ${DEVICE_DEFCONFIG}
make -j$(nproc) ARCH=arm64 O=out \
    CC=${CLANG_ROOTDIR}/bin/clang \
    AR=${CLANG_ROOTDIR}/bin/llvm-ar \
  	NM=${CLANG_ROOTDIR}/bin/llvm-nm \
  	OBJCOPY=${CLANG_ROOTDIR}/bin/llvm-objcopy \
  	OBJDUMP=${CLANG_ROOTDIR}/bin/llvm-objdump \
    STRIP=${CLANG_ROOTDIR}/bin/llvm-strip \
    CROSS_COMPILE=${CLANG_ROOTDIR}/bin/aarch64-linux-gnu- \
    CROSS_COMPILE_ARM32=${CLANG_ROOTDIR}/bin/arm-linux-gnueabi- \
    V=$VERBOSE 2>&1 | tee error.log

   if ! [ -a "$IMAGE" ]; 
      then
	  push "error.log" "Build Throws Errors"
	  exit 1
      else
          tg_post_msg " Kernel Compilation Finished. Started Zipping "
   fi

  git clone --depth=1 https://github.com/ZilverQueen/AnyKernel3.git AnyKernel
	cp $IMAGE AnyKernel
}

# Push kernel to channel
function push() {
    cd AnyKernel
    ZIP=$(echo *.zip)
    curl -F document=@$ZIP "https://api.telegram.org/bot$token/sendDocument" \
        -F chat_id="$chat_id" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="Compile took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s). | For <b>ulysse</b> | <b>${KBUILD_COMPILER_STRING}</b> | <b>MD5 Checksum : </b><code>$MD5CHECK</code>"
}

# Zipping
function zipping() {
    cd AnyKernel || exit 1
    zip -r9 Kernel-Archipelago-ulysse-${DATE}.zip *
    MD5CHECK=$(md5sum "Kernel-Archipelago-ulysse-${DATE}.zip" | cut -d' ' -f1)
    cd ..
}
check
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push
