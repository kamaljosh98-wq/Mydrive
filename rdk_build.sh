#!/bin/bash
##########################################################################
# If not stated otherwise in this file or this component's LICENSE
# file the following copyright and licenses apply:
#
# Copyright 2019 RDK Management
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##########################################################################

#######################################
#
# Build Framework standard script for
#
# webrtc source code

# use -e to fail on any shell issue
# -e is the requirement from Build Framework
set -e

# default PATHs - use `man readlink` for more info
# the path to combined build
export RDK_PROJECT_ROOT_PATH=${RDK_PROJECT_ROOT_PATH-`readlink -m ..`}
export COMBINED_ROOT=$RDK_PROJECT_ROOT_PATH

# path to build script (this script)
export RDK_SCRIPTS_PATH=${RDK_SCRIPTS_PATH-`readlink -m $0 | xargs dirname`}

# path to components sources and target
export RDK_SOURCE_PATH=${RDK_SOURCE_PATH-`readlink -m .`}
export RDK_TARGET_PATH=${RDK_TARGET_PATH-$RDK_SOURCE_PATH}

#default component name
export RDK_COMPONENT_NAME=${RDK_COMPONENT_NAME-`basename $RDK_SOURCE_PATH`}
export BUILDS_DIR=$RDK_PROJECT_ROOT_PATH
export RDK_DIR=$BUILDS_DIR
export ENABLE_RDKC_LOGGER_SUPPORT=true
export DCA_PATH=$RDK_SOURCE_PATH

if [ "$XCAM_MODEL" == "SCHC2" ] || [ "$XCAM_MODEL" == "XHB1" ] || [ "$XCAM_MODEL" == "XHC3" ]; then
    echo "Enable xStreamer by default for xCam2 and DBC"
    export ENABLE_XSTREAMER=true
else
    echo "Disable xStreamer by default for xCam and iCam2"
    export ENABLE_XSTREAMER=false
fi

if [ "$XCAM_MODEL" == "SCHC2" ]; then
. ${RDK_PROJECT_ROOT_PATH}/build/components/amba/sdk/setenv2
else
. ${RDK_PROJECT_ROOT_PATH}/build/components/sdk/setenv2
fi

if [ "$XCAM_MODEL" == "XHB1" ]; then
    echo "Enabling delivery detection by default for DBC"
    export ENABLE_DELIVERY_DETECTION=true
fi

export PLATFORM_SDK=${RDK_TOOLCHAIN_PATH}
export FSROOT=$RDK_FSROOT_PATH
export STRIP=${RDK_TOOLCHAIN_PATH}/bin/arm-linux-gnueabihf-strip

# parse arguments
INITIAL_ARGS=$@

function usage()
{
    set +x
    echo "Usage: `basename $0` [-h|--help] [-v|--verbose] [action]"
    echo "    -h    --help                  : this help"
    echo "    -v    --verbose               : verbose output"
    echo
    echo "Supported actions:"
    echo "      configure, clean, build (DEFAULT), rebuild, install"
}

ARGS=$@


# This Function to perform pre-build configurations before building plugin code
function configure()
{
    echo "Pre-build configurations for code ..."

    cd $RDK_SOURCE_PATH

    # Clean old build directory if it exists
    if [ -d "build" ]; then
        clean
    fi

    # Create build directory and run CMake configuration
    mkdir -p build
    cd build

    cmake .. \
        -DCMAKE_C_COMPILER=${RDK_TOOLCHAIN_PATH}/bin/arm-linux-gnueabihf-gcc \
        -DCMAKE_CXX_COMPILER=${RDK_TOOLCHAIN_PATH}/bin/arm-linux-gnueabihf-g++ \
        -DCMAKE_INSTALL_PREFIX=${RDK_FSROOT_PATH}/usr \
        -DRDK_PROJECT_ROOT_PATH=${RDK_PROJECT_ROOT_PATH} \
        -DENABLE_DIRECT_FRAME_READ=true \
        -DENABLE_XSTREAMER=ON \
        -DXCAM_MODEL=${XCAM_MODEL} \
        -DINCLUDE_DIR_PATH=${RDK_FSROOT_PATH}/usr/include \
        -DLIB_PATH=${RDK_FSROOT_PATH}/usr/lib
        
    cd -

    echo "CMake configuration complete"
}

# This Function to perform clean the build if any exists already
function clean()
{
    echo "Start Clean"
    cd $RDK_SOURCE_PATH

    if [ -d "build" ]; then
        echo "Removing build directory..."
        rm -rf build
    fi

    echo "Clean complete"
}

# This Function peforms the build to generate the webrtc.node
function build()
{
    echo "RDK_SOURCE_PATH :::::: $RDK_SOURCE_PATH"

    cd $RDK_SOURCE_PATH

    # Ensure build directory exists and is configured
    if [ ! -d "build" ] || [ ! -f "build/Makefile" ]; then
        echo "Build not configured, running configure first..."
        configure
    fi

    cd build
    make all
    make install

    echo "thumbnail build is done"
}

# This Function peforms the rebuild to generate the webrtc.node
function rebuild()
{
    clean
    build
}

# This functions performs installation of webrtc-streaming-node output created into sercomm firmware binary
function install()
{
    echo "Start thumbnail Installation"

    cd $RDK_SOURCE_PATH

    if [ "$ENABLE_DELIVERY_DETECTION" == 'true' ]; then
        cp -r ./motion_notification/pre_built/mediapipe ${RDK_SDROOT}/etc
    fi

    if [ -f "./build/imagetools/rdkc_snapshooter" ]; then
        ${STRIP} ./build/imagetools/rdkc_snapshooter
        cp -rvf "${RDK_SOURCE_PATH}/build/imagetools/rdkc_snapshooter" $RDK_SDROOT/usr/local/bin/
    fi
    if [ -f "./build/imagetools/libimagetools.so" ]; then
        ${STRIP} ./build/imagetools/libimagetools.so
        cp -rvf "${RDK_SOURCE_PATH}/build/imagetools/libimagetools.so" $RDK_SDROOT/usr/lib
    fi

    echo "thumbnail Installation is done"
}

# This function enables delivery detection
function setDeliveryDetection()
{
    echo "setDeliveryDetection - Enable delivery detection"
    export ENABLE_DELIVERY_DETECTION=true
}

# This function enables TESTHARNESS
function setTH()
{
    echo "setTH - Enable delivery detection and TestHarness"
    export ENABLE_DELIVERY_DETECTION=true
    export ENABLE_TEST_HARNESS=true
}

# This function disables XSTREAMER flag for Hydra
function setHydra()
{
    echo "setHydra - Disable xStreamer"
    export ENABLE_XSTREAMER=false
}
# run the logic
#these args are what left untouched after parse_args
HIT=false

for i in "$@"; do
    case $i in
        enableHydra)  HIT=true; setHydra ;;
        enableDeliveryDetection)  HIT=true; setDeliveryDetection ;;
        enableTH)  HIT=true; setTH ;;
        configure)  HIT=true; configure ;;
        clean)      HIT=true; clean ;;
        build)      HIT=true; build ;;
        rebuild)    HIT=true; rebuild ;;
        install)    HIT=true; install ;;
        *)
            #skip unknown
        ;;
    esac
done

# if not HIT do build by default
if ! $HIT; then
  build
fi

