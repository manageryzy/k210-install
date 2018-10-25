#!/bin/bash

read -r -p "INSTALL_PREFIX:($(pwd)) " response
if [ -z "$response" ]
then
    INSTALL_PREFIX=$(pwd)
else
    INSTALL_PREFIX=$response
fi

if [ ! -d "$INSTALL_PREFIX" ]; then
    echo "$INSTALL_PREFIX do not exist!"
    exit -1
fi

INSTALL_PREFIX=$INSTALL_PREFIX/kendryte

if [ -e "$INSTALL_PREFIX" ]; then
    echo "$INSTALL_PREFIX exist!"
else
    mkdir $INSTALL_PREFIX
fi

if [ ! -G "$INSTALL_PREFIX" ]; then
    echo "please check you have right to write $INSTALL_PREFIX "
    exit -1
fi

read -r -p "TEST_PREFIX:($(pwd)) " response
if [ -z "$response" ]
then
    TEST_PREFIX=$(pwd)
else
    TEST_PREFIX=$response
fi

if [ ! -d "$TEST_PREFIX" ]; then
    echo "$TEST_PREFIX do not exist!"
    exit -1
fi

TEST_PREFIX=$TEST_PREFIX/test

if [ -e "$TEST_PREFIX" ]; then
    echo "$TEST_PREFIX exist!"
else
    mkdir $TEST_PREFIX
fi

if [ ! -G "$TEST_PREFIX" ]; then
    echo "please check you have right to write $TEST_PREFIX "
    exit -1
fi


OPENOCD_VER="0.1.3"


FREERTOS_SDK_PKG="${INSTALL_PREFIX}/kendryte-freertos-sdk.zip"
STANDALONE_SDK_PKG="${INSTALL_PREFIX}/kendryte-standalone-sdk.zip"
OPENOCD_PKG="${INSTALL_PREFIX}/kendryte-openocd-${OPENOCD_VER}.tar.gz"
TOOLCHAIN_PKG="${INSTALL_PREFIX}/kendryte-toolchain.tar.gz"


FREERTOS_SDK_DIR="${INSTALL_PREFIX}/kendryte-freertos-sdk"
STANDALONE_SDK_DIR="${INSTALL_PREFIX}/kendryte-standalone-sdk"
OPENOCD_DIR="${INSTALL_PREFIX}/kendryte-openocd"
TOOLCHAIN_DIR="${INSTALL_PREFIX}/kendryte-toolchain"
FREERTOS_DEMO_DIR="${INSTALL_PREFIX}/kendryte-freertos-demo"
STANDALONE_DEMO_DIR="${INSTALL_PREFIX}/kendryte-standalone-demo"


if grep -q Microsoft /proc/version; then
    echo "you are running on wsl. only newer version wsl is supported"

    OPENOCD_SERVER_NAME="win32.zip"
    TMP_DIR=$(cmd.exe /c "echo %TMP%")
    TMP_DIR=$(/bin/wslpath $TMP_DIR)
    TMP_DIR=${TMP_DIR::-1}

    if ! /bin/wslpath -w $INSTALL_PREFIX ;then
        echo "you are running on wsl! your install path must be accessible by windows"
        exit -1
    fi
    OPENOCD_EXEC=$(/bin/wslpath -w "$OPENOCD_DIR/bin/openocd.exe")
    OPENOCD_CFG=$(/bin/wslpath -w $OPENOCD_DIR/tcl/openocd.cfg)
    CMD_RAPPER_1="cmd.exe /C \""
    CMD_RAPPER_2="\""
else
    OPENOCD_SERVER_NAME="ubuntu64.tar.gz"
    OPENOCD_EXEC="openocd"
    OPENOCD_CFG="$OPENOCD_DIR/tcl/openocd.cfg"
    CMD_RAPPER_1=""
    CMD_RAPPER_2=""
fi


FREERTOS_SDK_LINK="https://github.com/kendryte/kendryte-freertos-sdk/archive/master.zip"
STANDALONE_SDK_LINK="https://github.com/kendryte/kendryte-standalone-sdk/archive/master.zip"
OPENOCD_LINK="https://s3.cn-north-1.amazonaws.com.cn/dl.kendryte.com/documents/kendryte-openocd-${OPENOCD_VER}-${OPENOCD_SERVER_NAME}"
TOOLCHAIN_LINK="https://s3.cn-north-1.amazonaws.com.cn/dl.kendryte.com/documents/kendryte-toolchain.tar.gz"
FREERTOS_DEMO_REPO="https://github.com/kendryte/kendryte-freertos-demo.git"
STANDALONE_DEMO_REPO="https://github.com/kendryte/kendryte-standalone-demo.git"


test_exist()
{
if ! type "$1" > /dev/null; then
  # install foobar here
  echo error: "$1" not exist
  exit -1
fi
}

download()
{
    echo "downloading $1"
    if ! wget -O $2 $1 2> /dev/null; then
        echo "fail to download $1"
    fi
    echo "download finish"
}

install_freertos()
{
    download $FREERTOS_SDK_LINK $FREERTOS_SDK_PKG
    unzip -qq $FREERTOS_SDK_PKG -d $INSTALL_PREFIX
    if [ -d $FREERTOS_SDK_DIR ] ; then
        rm -rf $FREERTOS_SDK_DIR
    fi
    mv -f $FREERTOS_SDK_DIR-master $FREERTOS_SDK_DIR
    rm -f $FREERTOS_SDK_PKG
}

install_standalone()
{
    download $STANDALONE_SDK_LINK $STANDALONE_SDK_PKG
    unzip -qq $STANDALONE_SDK_PKG -d $INSTALL_PREFIX
    if [ -d $STANDALONE_SDK_DIR ] ; then
        rm -rf $STANDALONE_SDK_DIR
    fi
    mv -f $STANDALONE_SDK_DIR-master $STANDALONE_SDK_DIR
    rm -f $STANDALONE_SDK_PKG
}

install_openocd()
{
    download $OPENOCD_LINK $OPENOCD_PKG
    if grep -q Microsoft /proc/version; then
        unzip $OPENOCD_PKG -d $INSTALL_PREFIX
        mv $OPENOCD_DIR $OPENOCD_DIR-$OPENOCD_VER
    else
        tar xf $OPENOCD_PKG -C $INSTALL_PREFIX
        mv $OPENOCD_DIR $OPENOCD_DIR-$OPENOCD_VER
    fi

    ln -s -f $OPENOCD_DIR-$OPENOCD_VER $OPENOCD_DIR
    rm -f $OPENOCD_PKG

    sed -i -e 's/jlink serial .*//g' $OPENOCD_DIR/tcl/openocd.cfg

    if grep -q Microsoft /proc/version; then
        MSG="Run 'zadig-2.4.exe' in 'tool/', 'Options' - 'List all devices', select your JTAG simulator and convert the vendor drivers to WinUSB drivers."
        cmd.exe /C "msg %username% $MSG"
        echo $MSG
        cp $OPENOCD_DIR/tool/zadig-2.4.exe $TMP_DIR
        cmd.exe /C "%TMP%\\zadig-2.4.exe"
        rm $TMP_DIR/zadig-2.4.exe
    fi
}

install_toolchain()
{
    download $TOOLCHAIN_LINK $TOOLCHAIN_PKG
    tar xzf $TOOLCHAIN_PKG -C $INSTALL_PREFIX
    rm -rf $TOOLCHAIN_PKG
}

install_freertos_demo()
{
    ORI_PWD=$(pwd)
    if [ -d "${FREERTOS_DEMO_DIR}" ]; then
        cd ${FREERTOS_DEMO_DIR}
        git reset --hard
        git clean -fxd
        git fetch
        git checkout origin/master
        cd $ORI_PWD
    else
        git clone ${FREERTOS_DEMO_REPO} ${FREERTOS_DEMO_DIR}
    fi
}

install_standalone_demo()
{
    ORI_PWD=$(pwd)
    if [ -d "${STANDALONE_DEMO_DIR}" ]; then
        cd ${STANDALONE_DEMO_DIR}
        git reset --hard
        git clean -fxd
        git fetch
        git checkout origin/master
        cd $ORI_PWD
    else
        git clone ${STANDALONE_DEMO_REPO} ${STANDALONE_DEMO_DIR}
    fi
}



test_exist "tar"
test_exist "wget"
test_exist "unzip"
test_exist "cmake"
test_exist "git"

if [  -d "$FREERTOS_SDK_DIR" ]; then
read -r -p "reinstall freertos [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY])
        install_freertos
        ;;
    *)
        ;;
esac
else
    install_freertos
fi


if [  -d "$STANDALONE_SDK_DIR" ]; then
read -r -p "reinstall standalone [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY])
        install_standalone
        ;;
    *)
        ;;
esac
else
    install_standalone
fi


if [  -d "$OPENOCD_DIR" ]; then
read -r -p "reinstall openocd [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY])
        install_openocd
        ;;
    *)
        ;;
esac
else
    install_openocd
fi

if [  -d "$TOOLCHAIN_DIR" ]; then
read -r -p "reinstall toolchain [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY])
        install_toolchain
        ;;
    *)
        ;;
esac
else
    install_toolchain
fi

install_freertos_demo
install_standalone_demo

echo "#!/bin/bash
export PATH=$INSTALL_PREFIX/kendryte-openocd/bin:$INSTALL_PREFIX/kendryte-toolchain/bin:\$PATH
alias k210gdb='riscv64-unknown-elf-gdb --eval-command=\"target remote localhost:3333\"'
alias k210openocd='$CMD_RAPPER_1$OPENOCD_EXEC -f $OPENOCD_CFG $CMD_RAPPER_2'
alias k210openocd-m0='$CMD_RAPPER_1$OPENOCD_EXEC -f $OPENOCD_CFG -m0 $CMD_RAPPER_2'
alias k210openocd-m1='$CMD_RAPPER_1$OPENOCD_EXEC -f $OPENOCD_CFG -m1 $CMD_RAPPER_2'
alias k210freertos-cmake='cmake -DSDK_ROOT=\$FREERTOS_SDK_DIR -DTOOLCHAIN=\$K210_TOOLCHAIN'
alias k210standalone-cmake='cmake -DSDK_ROOT=\$STANDALONE_SDK_DIR -DTOOLCHAIN=\$K210_TOOLCHAIN'
alias k210cmake='cp $INSTALL_PREFIX/CMakeLists_DEMO.txt CMakeLists.txt'

export FREERTOS_SDK_DIR=$FREERTOS_SDK_DIR
export STANDALONE_SDK_DIR=$STANDALONE_SDK_DIR
export K210_TOOLCHAIN=$TOOLCHAIN_DIR/bin

echo 'k210 env setup'
" > $INSTALL_PREFIX/ENV
chmod +x $INSTALL_PREFIX/ENV

echo "cmake_minimum_required(VERSION 3.0)

set(BUILDING_SDK \"yes\" CACHE INTERNAL \"\")

include(\${SDK_ROOT}/cmake/common.cmake)
project(k210-test)

# config self use headers
include(\${SDK_ROOT}/cmake/macros.internal.cmake)
INCLUDE_DIRECTORIES(\${SDK_ROOT}/lib/arch/include \${SDK_ROOT}/lib/utils/include)
header_directories(\${SDK_ROOT}/lib)

# build library first
add_subdirectory(\${SDK_ROOT}/lib lib)


# compile project
add_source_files(src/*.c src/*.s src/*.S src/*.cpp)
include(\${SDK_ROOT}/cmake/executable.cmake)
" > $INSTALL_PREFIX/CMakeLists_DEMO.txt


test_toolchain()
{
source $INSTALL_PREFIX/ENV
echo $TEST_PREFIX

cd $TEST_PREFIX
rm -rf freertos-test standalone-test

mkdir freertos-test
cd freertos-test
mkdir build
mkdir src
echo "#include <stdio.h>
int main()
{
    printf(\"hello world\\n\");
    return 0;
}
" > src/main.c

cp $INSTALL_PREFIX/CMakeLists_DEMO.txt CMakeLists.txt

for i in $INSTALL_PREFIX/kendryte-freertos-demo/* ; do
  if [ -d "$i" ]; then
    PROJ=$(basename "$i")
    echo "project($PROJ)
# compile project $PROJ
unset(SOURCE_FILES CACHE)
add_source_files($FREERTOS_DEMO_DIR/$PROJ/*.c $FREERTOS_DEMO_DIR/$PROJ/*.s $FREERTOS_DEMO_DIR/$PROJ/*.S $FREERTOS_DEMO_DIR/$PROJ/*.cpp)
include(\${SDK_ROOT}/cmake/executable.cmake)
" >> CMakeLists.txt
  fi
done

cd $TEST_PREFIX

cp -rf freertos-test standalone-test

cp -f $INSTALL_PREFIX/CMakeLists_DEMO.txt CMakeLists.txt
# TODO: fix it after sdk change

# for i in $INSTALL_PREFIX/kendryte-standalone-demo/* ; do
#   if [ -d "$i" ]; then
#     PROJ=$(basename "$i")
#     echo "project($PROJ)
# # compile project $PROJ
# unset(SOURCE_FILES CACHE)
# add_source_files($STANDALONE_DEMO_DIR/$PROJ/*.c $STANDALONE_DEMO_DIR/$PROJ/*.s $STANDALONE_DEMO_DIR/$PROJ/*.S $STANDALONE_DEMO_DIR/$PROJ/*.cpp)
# include(\${SDK_ROOT}/cmake/executable.cmake)
# " >> standalone-test/CMakeLists.txt
#   fi
# done

cd ./freertos-test/build
cmake -DSDK_ROOT=$FREERTOS_SDK_DIR -DTOOLCHAIN=$K210_TOOLCHAIN ..
make -j

cd $TEST_PREFIX
cd ./standalone-test/build
cmake -DSDK_ROOT=$STANDALONE_SDK_DIR -DTOOLCHAIN=$K210_TOOLCHAIN ..
make -j
}


read -r -p "test toolchain [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY])
        test_toolchain
        ;;
    *)
        ;;
esac


echo "please source ENV if you need it.

command add:
k210gdb - gdb for jlink debug. ussage : k210gdb <elf_file>
k210openocd - openocd without -mn param
k210openocd-m0 - openocd with -m0 param
k210openocd-m1 - openocd with -m1 param

you can run 'cmake -DSDK_ROOT=\$FREERTOS_SDK_DIR -DTOOLCHAIN=\$K210_TOOLCHAIN'
or
'cmake -DSDK_ROOT=\$STANDALONE_SDK_DIR -DTOOLCHAIN=\$K210_TOOLCHAIN'
in test dir
"
