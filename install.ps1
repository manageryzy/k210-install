Add-Type -AssemblyName System.IO.Compression.FileSystem
function Unzip($zipfile, $outpath)
{
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}

Function Get-Folder($title)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")|Out-Null

    $foldername = New-Object System.Windows.Forms.FolderBrowserDialog
    $foldername.Description = $title
    $foldername.rootfolder = "MyComputer"
    $foldername.SelectedPath = pwd

    if($foldername.ShowDialog() -eq "OK")
    {
        $folder += $foldername.SelectedPath
    }

    if(-not $folder)
    {
        throw "no folder select"
    }

    return $folder
}

Function Test-Command($cmd)
{
    if (-not (Get-Command $cmd -errorAction SilentlyContinue))
    {
        throw "$cmd not exist"
    }
}

function DownloadFile($url, $targetFile)
{
    $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $targetFile, Create
    if(-not $targetStream)
    {
        throw "can not open $targetFile"
    }

    $uri = New-Object "System.Uri" "$url"
    $request = [System.Net.HttpWebRequest]::Create($uri)
    $request.set_Timeout(15000) #15 second timeout
    $response = $request.GetResponse()
    $totalLength = [System.Math]::Floor($response.get_ContentLength()/1024)
    $responseStream = $response.GetResponseStream()


    $buffer = new-object byte[] 10KB
    $count = $responseStream.Read($buffer,0,$buffer.length)
    $downloadedBytes = $count

    if($totalLength -le 0)
    {
        $totalLength = 1024
    }


    while ($count -gt 0)
    {
        $targetStream.Write($buffer, 0, $count)
        $count = $responseStream.Read($buffer,0,$buffer.length)
        $downloadedBytes = $downloadedBytes + $count
        Write-Progress -activity "Downloading file '$($url.split('/') | Select -Last 1)'" -status "Downloaded ($([System.Math]::Floor($downloadedBytes/1024))K of $($totalLength)K): " -PercentComplete ((([System.Math]::Floor($downloadedBytes/1024)) / $totalLength)  * 100)
    }

    Write-Progress -activity "Finished downloading file '$($url.split('/') | Select -Last 1)'"

    $targetStream.Flush()
    $targetStream.Close()
    $targetStream.Dispose()
    $responseStream.Dispose()

}

Function install_freertos()
{
    DownloadFile $FREERTOS_SDK_LINK $FREERTOS_SDK_PKG
    Unzip $FREERTOS_SDK_PKG $INSTALL_PREFIX
    mv "$FREERTOS_SDK_DIR-master" $FREERTOS_SDK_DIR
    rm $FREERTOS_SDK_PKG
}


Function install_standalone()
{
    DownloadFile $STANDALONE_SDK_LINK $STANDALONE_SDK_PKG
    Unzip $STANDALONE_SDK_PKG $INSTALL_PREFIX
    mv "$STANDALONE_SDK_DIR-master" $STANDALONE_SDK_DIR
    rm $STANDALONE_SDK_PKG
}

Function install_openocd()
{
    DownloadFile $OPENOCD_LINK $OPENOCD_PKG
    Unzip $OPENOCD_PKG $INSTALL_PREFIX
    $MSG="Run 'zadig-2.4.exe' in 'tool/', 'Options' - 'List all devices', select your JTAG simulator and convert the vendor drivers to WinUSB drivers."
    echo $MSG
    "$OPENOCD_DIR\tool\zadig-2.4.exe"
    rm $OPENOCD_PKG
}

Function install_toolchain()
{
    DownloadFile $TOOLCHAIN_LINK $TOOLCHAIN_PKG
    Unzip $TOOLCHAIN_PKG $INSTALL_PREFIX
    rm $TOOLCHAIN_PKG
}


Function install_freertos_demo()
{
    $ORI_PWD=pwd
    if(Test-Path -Path $FREERTOS_DEMO_DIR){
        cd ${FREERTOS_DEMO_DIR}
        git reset --hard 2>$null
        git clean -fxd 2>$null
        git fetch 2>$null
        git checkout origin/master 2>$null
        cd $ORI_PWD
    }else{
        git clone ${FREERTOS_DEMO_REPO} ${FREERTOS_DEMO_DIR} 2>$null
    }
}

Function install_standalone_demo()
{
    $ORI_PWD=pwd
    if(Test-Path -Path $STANDALONE_DEMO_DIR){
        cd ${STANDALONE_DEMO_DIR}
        git reset --hard 2>$null
        git clean -fxd 2>$null
        git fetch 2>$null
        git checkout origin/master 2>$null
        cd $ORI_PWD
    }else{
        git clone ${STANDALONE_DEMO_REPO} ${STANDALONE_DEMO_DIR} 2>$null
    }
}

##########################################################################

echo "install in current dir ? $pwd/kendryte (Default yes)"
$read = Read-Host " ( y / n ) "
switch($read)
{
    Y { $INSTALL_PREFIX = "$pwd/kendryte" }
    N { $INSTALL_PREFIX = Get-Folder("Select install folder") }
    Default { $INSTALL_PREFIX = "$pwd/kendryte" }
}


echo "test in current dir ? $pwd/test (Default yes)"
$read = Read-Host " ( y / n ) "
switch($read)
{
    Y { $TEST_PREFIX = "$pwd/test" }
    N { $TEST_PREFIX = Get-Folder("Select test folder") }
    Default { $TEST_PREFIX = "$pwd/test" }
}

if(!(Test-Path -Path $INSTALL_PREFIX)){
    New-Item $INSTALL_PREFIX -ItemType Directory -ErrorAction Continue
}

if(!(Test-Path -Path $TEST_PREFIX)){
    New-Item $TEST_PREFIX -ItemType Directory -ErrorAction Continue
}

"" | Out-File "$($INSTALL_PREFIX)\.test_access" -Append
"" | Out-File "$($TEST_PREFIX)\.test_access" -Append

$OPENOCD_VER="0.1.3"


$FREERTOS_SDK_PKG="${INSTALL_PREFIX}/kendryte-freertos-sdk.zip"
$STANDALONE_SDK_PKG="${INSTALL_PREFIX}/kendryte-standalone-sdk.zip"
$OPENOCD_PKG="${INSTALL_PREFIX}/kendryte-openocd-${OPENOCD_VER}.zip"
$TOOLCHAIN_PKG="${INSTALL_PREFIX}/kendryte-toolchain.tar.gz"

$FREERTOS_SDK_DIR="${INSTALL_PREFIX}/kendryte-freertos-sdk"
$STANDALONE_SDK_DIR="${INSTALL_PREFIX}/kendryte-standalone-sdk"
$OPENOCD_DIR="${INSTALL_PREFIX}/kendryte-openocd"
$TOOLCHAIN_DIR="${INSTALL_PREFIX}/kendryte-toolchain"
$FREERTOS_DEMO_DIR="${INSTALL_PREFIX}/kendryte-freertos-demo"
$STANDALONE_DEMO_DIR="${INSTALL_PREFIX}/kendryte-standalone-demo"

$OPENOCD_SERVER_NAME="win32.zip"
$FREERTOS_SDK_LINK="https://github.com/kendryte/kendryte-freertos-sdk/archive/master.zip"
$STANDALONE_SDK_LINK="https://github.com/kendryte/kendryte-standalone-sdk/archive/master.zip"
$OPENOCD_LINK="https://s3.cn-north-1.amazonaws.com.cn/dl.kendryte.com/documents/kendryte-openocd-${OPENOCD_VER}-${OPENOCD_SERVER_NAME}"
$TOOLCHAIN_LINK="https://s3.cn-north-1.amazonaws.com.cn/dl.kendryte.com/documents/kendryte-toolchain.zip"
$FREERTOS_DEMO_REPO="https://github.com/kendryte/kendryte-freertos-demo.git"
$STANDALONE_DEMO_REPO="https://github.com/kendryte/kendryte-standalone-demo.git"

$OPENOCD_EXEC="openocd.exe"
$OPENOCD_CFG="$OPENOCD_DIR/tcl/openocd.cfg"

Test-Command "cmake"
Test-Command "git"

if(Test-Path -Path $FREERTOS_SDK_DIR){
    echo "reinsall freertos (Default NO)"
    $read = Read-Host " ( y / n ) "
    switch($read)
    {
        Y {
            rm -Recurse -Force $FREERTOS_SDK_DIR
            install_freertos
        }
        N { }
        Default { }
}
}else{
    install_freertos
}

if(Test-Path -Path $STANDALONE_SDK_DIR){
    echo "reinsall standalone (Default NO)"
    $read = Read-Host " ( y / n ) "
    switch($read)
    {
        Y {
            rm -Recurse -Force $STANDALONE_SDK_DIR
            install_standalone
        }
        N { }
        Default { }
}
}else{
    install_standalone
}

if(Test-Path -Path $OPENOCD_DIR){
    echo "reinsall openocd (Default NO)"
    $read = Read-Host " ( y / n ) "
    switch($read)
    {
        Y {
            rm -Recurse -Force $OPENOCD_DIR
            install_openocd
        }
        N { }
        Default { }
}
}else{
    install_openocd
}



if(Test-Path -Path $TOOLCHAIN_DIR){
    echo "reinsall toolchain (Default NO)"
    $read = Read-Host " ( y / n ) "
    switch($read)
    {
        Y {
            rm -Recurse -Force $TOOLCHAIN_DIR
            install_toolchain
        }
        N { }
        Default { }
}
}else{
    install_toolchain
}


install_freertos_demo
install_standalone_demo

write-output "REM K210 ENV CMD
SET PATH=$INSTALL_PREFIX\kendryte-openocd\bin;$INSTALL_PREFIX\kendryte-toolchain\bin;%PATH%

DOSKEY k210gdb=riscv64-unknown-elf-gdb.exe --eval-command='target remote localhost:3333'
DOSKEY k210openocd=START $OPENOCD_EXEC -f $OPENOCD_CFG
DOSKEY k210openocd-m0=START $OPENOCD_EXEC -f $OPENOCD_CFG -m0
DOSKEY k210openocd-m1=START $OPENOCD_EXEC -f $OPENOCD_CFG -m1
DOSKEY k210freertos-cmake=cmake.exe -DSDK_ROOT=%FREERTOS_SDK_DIR% -DTOOLCHAIN=%K210_TOOLCHAIN%
DOSKEY k210standalone-cmake=cmake.exe -DSDK_ROOT=%STANDALONE_SDK_DIR% -DTOOLCHAIN=%K210_TOOLCHAIN%
DOSKEY k210cmake=COPY $INSTALL_PREFIX\CMakeLists_DEMO.txt CMakeLists.txt

SET FREERTOS_SDK_DIR=$FREERTOS_SDK_DIR
SET STANDALONE_SDK_DIR=$STANDALONE_SDK_DIR
SET K210_TOOLCHAIN=$TOOLCHAIN_DIR\bin

echo 'k210 env setup'

" | out-file "$INSTALL_PREFIX/ENV.CMD" -encoding ascii

write-output "
CMD /K ENV.cmd
" | out-file "$INSTALL_PREFIX/K210START.CMD" -encoding ascii


write-output "cmake_minimum_required(VERSION 3.0)

set(BUILDING_SDK `"yes`" CACHE INTERNAL `"`")

include(`${SDK_ROOT}/cmake/common.cmake)
project(k210-test)

# config self use headers
include(`${SDK_ROOT}/cmake/macros.internal.cmake)
INCLUDE_DIRECTORIES(`${SDK_ROOT}/lib/arch/include `${SDK_ROOT}/lib/utils/include)
header_directories(`${SDK_ROOT}/lib)

# build library first
add_subdirectory(`${SDK_ROOT}/lib lib)


# compile project
add_source_files(src/*.c src/*.s src/*.S src/*.cpp)
include(`${SDK_ROOT}/cmake/executable.cmake)
" | out-file "$INSTALL_PREFIX/CMakeLists_DEMO.txt" -encoding ascii
