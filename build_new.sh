#!/bin/bash
FFMPEG_PATH=~/space/FFmpeg
#BASE_DIR=$(pwd)
BASE_DIR="$( cd "$( dirname "$0" )" && pwd )"

cd $FFMPEG_PATH
git checkout -b 4.3 origin/release/4.3

HOST_NPROC=6
BUILD_DIR=${BASE_DIR}/build
BUILD_DIR_FFMPEG=${BUILD_DIR}/ffmpeg
BUILD_DIR_EXTERNAL=${BUILD_DIR}/external
export PKG_CONFIG_EXECUTABLE=$(which pkg-config)
#ANDROID_ABI=arm64-v8a
ANDROID_ABI=armeabi-v7a
DESIRED_ANDROID_API_LEVEL=21
ANDROID_NDK_HOME=~/space/ffmpeg_maker/android-ndk-r21d
HOST_TAG=linux-x86_64

# All FREE libraries that are supported
SUPPORTED_LIBRARIES_FREE=(
  "libaom"
  "libdav1d"
  "libmp3lame"
  "libopus"
  "libwavpack"
  "libtwolame"
  "libspeex"
  "libvpx"
  "libfreetype"
  "libfribidi"
)

# All GPL libraries that are supported
SUPPORTED_LIBRARIES_GPL=(
  "libx264"
)

SUPPORTED_LIBRARIES_ANDROID=(
)

EXTERNAL_LIBRARIES=()
#EXTERNAL_LIBRARIES+=("libaom")
#EXTERNAL_LIBRARIES+=("libdav1d")
#EXTERNAL_LIBRARIES+=("libmp3lame")
#EXTERNAL_LIBRARIES+=("libopus")
#EXTERNAL_LIBRARIES+=("libwavpack")
#EXTERNAL_LIBRARIES+=("libtwolame")
#EXTERNAL_LIBRARIES+=("libspeex")
#EXTERNAL_LIBRARIES+=("libvpx")
#EXTERNAL_LIBRARIES+=("libfreetype")
#EXTERNAL_LIBRARIES+=("libfribidi")
#EXTERNAL_LIBRARIES+=("libx264")
#EXTERNAL_LIBRARIES+=" ${SUPPORTED_LIBRARIES_FREE[@]}"
#EXTERNAL_LIBRARIES+=" ${SUPPORTED_LIBRARIES_GPL[@]}"
EXTERNAL_LIBRARIES+=" ${SUPPORTED_LIBRARIES_ANDROID[@]}"
export FFMPEG_EXTERNAL_LIBRARIES=${EXTERNAL_LIBRARIES[@]}
echo "FFMPEG_EXTERNAL_LIBRARIES: $FFMPEG_EXTERNAL_LIBRARIES"

export MAKE_EXECUTABLE=$(which make)

if [ $ANDROID_ABI = "arm64-v8a" ] || [ $ANDROID_ABI = "x86_64" ] ; then
  # For 64bit we use value not less than 21
  #export ANDROID_PLATFORM=$(max ${DESIRED_ANDROID_API_LEVEL} 21)
  export ANDROID_PLATFORM=${DESIRED_ANDROID_API_LEVEL}
else
  export ANDROID_PLATFORM=${DESIRED_ANDROID_API_LEVEL}
fi

export TOOLCHAIN_PATH=${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${HOST_TAG}
export SYSROOT_PATH=${TOOLCHAIN_PATH}/sysroot

TARGET_TRIPLE_MACHINE_CC=
CPU_FAMILY=
export TARGET_TRIPLE_OS="android"

case $ANDROID_ABI in
  armeabi-v7a)
    #cc       armv7a-linux-androideabi16-clang
    #binutils arm   -linux-androideabi  -ld
    export TARGET_TRIPLE_MACHINE_BINUTILS=arm
    TARGET_TRIPLE_MACHINE_CC=armv7a
    export TARGET_TRIPLE_OS=androideabi
    ;;
  arm64-v8a)
    #cc       aarch64-linux-android21-clang
    #binutils aarch64-linux-android  -ld
    export TARGET_TRIPLE_MACHINE_BINUTILS=aarch64
    ;;
  x86)
    #cc       i686-linux-android16-clang
    #binutils i686-linux-android  -ld
    export TARGET_TRIPLE_MACHINE_BINUTILS=i686
    CPU_FAMILY=x86
    ;;
  x86_64)
    #cc       x86_64-linux-android21-clang
    #binutils x86_64-linux-android  -ld
    export TARGET_TRIPLE_MACHINE_BINUTILS=x86_64
    ;;
esac

# If the cc-specific variable isn't set, we fallback to binutils version
[ -z "${TARGET_TRIPLE_MACHINE_CC}" ] && TARGET_TRIPLE_MACHINE_CC=${TARGET_TRIPLE_MACHINE_BINUTILS}
export TARGET_TRIPLE_MACHINE_CC=$TARGET_TRIPLE_MACHINE_CC

[ -z "${CPU_FAMILY}" ] && CPU_FAMILY=${TARGET_TRIPLE_MACHINE_BINUTILS}
export CPU_FAMILY=$CPU_FAMILY

# Common prefix for ld, as, etc.
if [ "$DESIRED_BINUTILS" = "gnu" ] ; then
  export CROSS_PREFIX=${TARGET_TRIPLE_MACHINE_BINUTILS}-linux-${TARGET_TRIPLE_OS}-
else
  export CROSS_PREFIX=llvm-
fi

export CROSS_PREFIX_WITH_PATH=${TOOLCHAIN_PATH}/bin/${CROSS_PREFIX}

# Exporting Binutils paths, if passing just CROSS_PREFIX_WITH_PATH is not enough
# The FAM_ prefix is used to eliminate passing those values implicitly to build systems
export FAM_ADDR2LINE=${CROSS_PREFIX_WITH_PATH}addr2line
export        FAM_AS=${CROSS_PREFIX_WITH_PATH}as
export        FAM_AR=${CROSS_PREFIX_WITH_PATH}ar
export        FAM_NM=${CROSS_PREFIX_WITH_PATH}nm
export   FAM_OBJCOPY=${CROSS_PREFIX_WITH_PATH}objcopy
export   FAM_OBJDUMP=${CROSS_PREFIX_WITH_PATH}objdump
export    FAM_RANLIB=${CROSS_PREFIX_WITH_PATH}ranlib
export   FAM_READELF=${CROSS_PREFIX_WITH_PATH}readelf
export      FAM_SIZE=${CROSS_PREFIX_WITH_PATH}size
export   FAM_STRINGS=${CROSS_PREFIX_WITH_PATH}strings
export     FAM_STRIP=${CROSS_PREFIX_WITH_PATH}strip

export TARGET=${TARGET_TRIPLE_MACHINE_CC}-linux-${TARGET_TRIPLE_OS}${ANDROID_PLATFORM}
# The name for compiler is slightly different, so it is defined separatly.
export FAM_CC=${TOOLCHAIN_PATH}/bin/${TARGET}-clang
export FAM_CXX=${FAM_CC}++
export FAM_LD=${FAM_CC}

# TODO consider abondaning this strategy of defining the name of the clang wrapper
# in favour of just passing -mstackrealign and -fno-addrsig depending on
# ANDROID_ABI, ANDROID_PLATFORM and NDK's version

# Special variable for the yasm assembler
export FAM_YASM=${TOOLCHAIN_PATH}/bin/yasm

# A variable to which certain dependencies can add -l arguments during build.sh
export FFMPEG_EXTRA_LD_FLAGS=

export INSTALL_DIR=${BUILD_DIR_EXTERNAL}/${ANDROID_ABI}

# Forcing FFmpeg and its dependencies to look for dependencies
# in a specific directory when pkg-config is used
export PKG_CONFIG_LIBDIR=${INSTALL_DIR}/lib/pkgconfig

case $ANDROID_ABI in
  x86)
    # Disabling assembler optimizations, because they have text relocations
    EXTRA_BUILD_CONFIGURATION_FLAGS=--disable-asm
    ;;
  x86_64)
    EXTRA_BUILD_CONFIGURATION_FLAGS=--x86asmexe=${FAM_YASM}
    ;;
esac

if [ "$FFMPEG_GPL_ENABLED" = true ] ; then
    EXTRA_BUILD_CONFIGURATION_FLAGS="$EXTRA_BUILD_CONFIGURATION_FLAGS --enable-gpl"
fi

# Preparing flags for enabling requested libraries
ADDITIONAL_COMPONENTS=
for LIBARY_NAME in ${FFMPEG_EXTERNAL_LIBRARIES[@]}
do
  ADDITIONAL_COMPONENTS+=" --enable-$LIBARY_NAME"
done

# Referencing dependencies without pkgconfig
DEP_CFLAGS="-I${BUILD_DIR_EXTERNAL}/${ANDROID_ABI}/include"
DEP_LD_FLAGS="-L${BUILD_DIR_EXTERNAL}/${ANDROID_ABI}/lib $FFMPEG_EXTRA_LD_FLAGS"

echo "./configure \ "
echo "  --prefix=${BUILD_DIR_FFMPEG}/${ANDROID_ABI} \ "
echo "  --enable-cross-compile \ "
echo "  --target-os=android \ "
echo "  --arch=${TARGET_TRIPLE_MACHINE_BINUTILS} \ "
echo "  --sysroot=${SYSROOT_PATH} \ "
echo "  --cc=${FAM_CC} \ "
echo "  --cxx=${FAM_CXX} \ "
echo "  --ld=${FAM_LD} \ "
echo "  --ar=${FAM_AR} \ "
echo "  --as=${FAM_CC} \ "
echo "  --nm=${FAM_NM} \ "
echo "  --ranlib=${FAM_RANLIB} \ "
echo "  --strip=${FAM_STRIP} \ "
echo "  --extra-cflags="-O3 -fPIC $DEP_CFLAGS" \ "
echo "  --extra-ldflags="$DEP_LD_FLAGS" \ "
echo "  --enable-shared \ "
echo "  --disable-static \ "
echo "  --pkg-config=${PKG_CONFIG_EXECUTABLE} \ "
echo "  ${EXTRA_BUILD_CONFIGURATION_FLAGS} \ "
echo "  $ADDITIONAL_COMPONENTS || exit 1 "

./configure \
  --prefix=${BUILD_DIR_FFMPEG}/${ANDROID_ABI} \
  --enable-cross-compile \
  --target-os=android \
  --arch=${TARGET_TRIPLE_MACHINE_BINUTILS} \
  --sysroot=${SYSROOT_PATH} \
  --cc=${FAM_CC} \
  --cxx=${FAM_CXX} \
  --ld=${FAM_LD} \
  --ar=${FAM_AR} \
  --as=${FAM_CC} \
  --nm=${FAM_NM} \
  --ranlib=${FAM_RANLIB} \
  --strip=${FAM_STRIP} \
  --extra-cflags="-O3 -fPIC $DEP_CFLAGS" \
  --extra-ldflags="$DEP_LD_FLAGS" \
  --enable-shared \
  --disable-static \
  --pkg-config=${PKG_CONFIG_EXECUTABLE} \
  ${EXTRA_BUILD_CONFIGURATION_FLAGS} \
  $ADDITIONAL_COMPONENTS || exit 1

${MAKE_EXECUTABLE} clean
${MAKE_EXECUTABLE} -j${HOST_NPROC}
${MAKE_EXECUTABLE} examples
${MAKE_EXECUTABLE} install
