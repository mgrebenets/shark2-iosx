#!/bin/bash
VERSION=2.3.4
DOWNLOAD=0
CLEAN=0
SHARK_ZIP="shark-${VERSION}.zip"
SRC_DIR=src
BUILD_DIR=build
OUTPUT_DIR=framework
LIB_DIR=lib
LIB_NAME=libshark.a

usage() {
	echo "usage: $(basename $0) [-d] [-c] <platform>"
	echo "options:"
	echo -e "\t-c\tClean build."
	echo -e "\t-d\tDownload source if doesn't exist."
	echo -e "<platform>\t'ios' or 'osx'"
	exit 1
}

doneSection()
{
    echo
    echo "  ================================================================="
    echo "  Done"
    echo
}

# usage: checkCmd <cmd>
checkCmd() {
	command -v $1 >/dev/null 2>&1 || { echo >&2 "$1 is required, but it's not installed. Aborting."; exit 1; }
}

# check dependencies
checkDeps() {
	echo Checking dependencies...
	checkCmd cmake
	checkCmd xcode-select
	checkCmd make
	doneSection
}

download() {
	if [ ! -s $SHARK_ZIP ]; then
        echo Downloading shark source code $SHARK_ZIP...
        curl -L --progress-bar -o $SHARK_ZIP "http://sourceforge.net/projects/shark-project/files/Shark%20Core/Shark%20${VERSION}/shark-${VERSION}.zip/download"

    else
    	echo Source code $SHARK_ZIP already downloaded...
    fi
    doneSection
}

clean() {
	echo Cleaning up...
	[ -d $SRCDIR ] && rm -rf $SRC_DIR
	[ -d $BUILD_DIR ] && rm -rf $BUILD_DIR
	[ -d $OUTPUT_DIR ] && rm -rf $OUTPUT_DIR
	[ -d $LIB_DIR ] && rm -rf $LIB_DIR
	doneSection
}

unpackSource() {
	echo Unpacking $SHARK_ZIP to $SRC_DIR...
	[ -d $SRC_DIR ] || unzip -q $SHARK_ZIP -d $SRC_DIR
	[ -d $SRC_DIR ] && echo " ...unpacked as $SRC_DIR"
	doneSection
}

patchSource() {
	echo Patching source code...
	patch -d $SRC_DIR/Shark -p1 --forward -r - -i ../../shark.patch
	doneSection
}

# building
PREFIX=/usr/local/shark/$VERSION
XCODE_ROOT=$(xcode-select -print-path)
XCODE_ARM_ROOT=$XCODE_ROOT/Platforms/iPhoneOS.platform/Developer
XCODE_ARM_BIN=$XCODE_ARM_ROOT/usr/bin
XCODE_SIM_ROOT=$XCODE_ROOT/Platforms/iPhoneSimulator.platform/Developer
XCODE_SIM_BIN=$XCODE_SIM_ROOT/usr/bin
XCODE_TOOLCHAIN_BIN=$XCODE_ROOT/Toolchains/XcodeDefault.xctoolchain/usr/bin
CXX_COMPILER=${XCODE_TOOLCHAIN_BIN}/clang++
C_COMPILER=${XCODE_TOOLCHAIN_BIN}/clang
GENERATOR="Unix Makefiles"

# cmakeInit <src-dir>
cmakeInit() {
	local src_dir=$1
	cmake $src_dir
}

# cmakeRun <src-dir> <sys-root> <cxx-flags>
cmakeRun() {
	local src_dir=$1
	local sys_root=$2
	local cxx_flags="$3"

	cmake -DCMAKE_INSTALL_PREFIX=$PREFIX \
		-DCMAKE_CXX_COMPILER=$CXX_COMPILER \
		-DCMAKE_OSX_SYSROOT="$sys_root" \
		-DCMAKE_C_COMPILER=$C_COMPILER \
		-DCMAKE_CXX_FLAGS="$cxx_flags" \
		-G "$GENERATOR" \
		$src_dir

}

# buildLibrary <target> <sys-root> <cxx-flags>
buildLibrary() {
	echo Building library...
	local target=$1
	local sys_root=$2
	local cxx_flags="$3"
	local target_dir=$BUILD_DIR/$1
	local shark_src=../../$SRC_DIR/Shark

	# create folder if not there yet
	[ -d $target_dir ] || mkdir -p $target_dir

	# navigate to target directory
	pushd $target_dir

	# initial cmake run to skip compiler test
	cmakeInit $shark_src

	echo Configuring makefiles with cmake...
	if [[ "$target" == "osx" ]]; then
		# just a single run with no sysroot or cxx flags
		cmakeRun $shark_src
	else
		# 2nd ccmake run with overriden vars
		cmakeRun $shark_src $sys_root "$cxx_flags"

		# 3rd run to set things like system root and cxx flags
		cmakeRun $shark_src $sys_root "$cxx_flags"
	fi

	echo Building with make...
	make -j16

	# pop the directory
	popd

	echo Done building library
}

buildIOS() {
	echo Building for iOS...

	echo Building for Device...
	buildLibrary ios ${XCODE_ARM_ROOT}/SDKs/iPhoneOS7.0.sdk "-arch armv7 -arch armv7s -arch arm64"

	echo Building for Simulator...
	buildLibrary sim ${XCODE_SIM_ROOT}/SDKs/iPhoneSimulator7.0.sdk "-arch i386 -arch x86_64 -mios-simulator-version-min=7.0"

	echo "Lipoing the fat library"
	[ -d $LIB_DIR/$PLATFORM ] || mkdir -p $LIB_DIR/$PLATFORM
	$XCODE_TOOLCHAIN_BIN/lipo -create $BUILD_DIR/ios/$LIB_NAME $BUILD_DIR/sim/$LIB_NAME -o $LIB_DIR/$PLATFORM/$LIB_NAME

	doneSection
}

buildOSX() {
	echo Building for OSX...
	buildLibrary osx
	# copy the library file
	[ -d $LIB_DIR/$PLATFORM ] || mkdir -p $LIB_DIR/$PLATFORM
	cp -f $BUILD_DIR/$PLATFORM/$LIB_NAME $LIB_DIR/$PLATFORM/$LIB_NAME
	doneSection
}

# making framework

# patch framework headers, usage: patchHeaders <headers-folder>
patchHeaders() {
    local folder=$1

    echo Patching framework headers...

    # avoid invalid character sequence errors
    export LC_TYPE=C
    export LANG=C

    # fix missing spaces in include directives
    # fix include path for SharkDefs.h
    # fix include paths for all components
    # use -E for modern regex syntax and avoid those gnu vs non-gnu sed issues
    local components="Array|Rng|LinAlg|FileUtil|EALib|MOO-EALib|ReClaM|Mixture|TimeSeries|Fuzzy"
    find $folder -type f -exec \
        sed -E -i '' \
        -e "s,#include([<\"]),#include \1,g" \
        -e "s,#include([ \t])([<\"])(SharkDefs.h),#include\1\2Shark/\3,g" \
        -e "s,#include([ \t])([<\"])(${components}/),#include\1\2Shark/\3,g" \
        {} +
}

# packageFramework <static-library-name> <framework-dir>
packageFramework() {
	local LIBRARY=$1
	local FRAMEWORK_DIR=$2

	echo Packaging framework for $FRAMEWORK_DIR...
	# TODO: copy-paste that script for making framework

	VERSION_TYPE=Alpha
	FRAMEWORK_NAME=Shark
	FRAMEWORK_VERSION=A

	FRAMEWORK_CURRENT_VERSION=$VERSION
	FRAMEWORK_COMPATIBILITY_VERSION=$VERSION

	FRAMEWORK_BUNDLE=$FRAMEWORK_DIR/$FRAMEWORK_NAME.framework
	echo "Framework: Building $FRAMEWORK_BUNDLE from $BUILDDIR..."

	rm -rf $FRAMEWORK_BUNDLE
	mkdir -p $FRAMEWORK_BUNDLE
	mkdir -p $FRAMEWORK_BUNDLE/Versions
	mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION
	mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Resources
	mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Headers
	mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Documentation

	echo "Framework: Creating symlinks..."
	ln -s $FRAMEWORK_VERSION				$FRAMEWORK_BUNDLE/Versions/Current
	ln -s Versions/Current/Headers			$FRAMEWORK_BUNDLE/Headers
	ln -s Versions/Current/Resources		$FRAMEWORK_BUNDLE/Resources
	ln -s Versions/Current/Documentation	$FRAMEWORK_BUNDLE/Documentation
	ln -s Versions/Current/$FRAMEWORK_NAME	$FRAMEWORK_BUNDLE/$FRAMEWORK_NAME

	FRAMEWORK_INSTALL_NAME=$FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/$FRAMEWORK_NAME

	cp $LIBRARY "$FRAMEWORK_INSTALL_NAME"

	echo "Framework: Copying includes..."
	cp -r $SRC_DIR/Shark/include/* $FRAMEWORK_BUNDLE/Headers/
	rm $FRAMEWORK_BUNDLE/Headers/statistics.h

	echo "Framework: Patching includes..."
	patchHeaders $FRAMEWORK_BUNDLE/Headers/

	echo "Framework: Creating plist..."
	cat > $FRAMEWORK_BUNDLE/Resources/Info.plist <<EOF
	<?xml version="1.0" encoding="UTF-8"?>
	<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
	<plist version="1.0">
	<dict>
	    <key>CFBundleDevelopmentRegion</key>
	    <string>English</string>
	    <key>CFBundleExecutable</key>
	    <string>${FRAMEWORK_NAME}</string>
	    <key>CFBundleIdentifier</key>
	    <string>dk.diku.image</string>
	    <key>CFBundleInfoDictionaryVersion</key>
	    <string>6.0</string>
	    <key>CFBundlePackageType</key>
	    <string>FMWK</string>
	    <key>CFBundleSignature</key>
	    <string>????</string>
	    <key>CFBundleVersion</key>
	    <string>${FRAMEWORK_CURRENT_VERSION}</string>
	</dict>
	</plist>
EOF

	doneSection
}

while getopts dcv opt
do
	case $opt in
	d)
		DOWNLOAD=1
		;;
	c)
		CLEAN=1
		;;
	v)
		VERBOSE=1
		;;
	\?)
		echo "Invalid option: -$OPTARG" >&2
		exit 1
		;;
	:)
		echo "Option -$OPTARG requires an argument." >&2
		exit 1
		;;
	esac
done
shift $((OPTIND-1))

# check args
PLATFORM="$1"
[ -z $PLATFORM ] && usage
[[ "$PLATFORM" != "ios" && "$PLATFORM" != "osx" ]] && usage

# Script body
checkDeps
[[ $DOWNLOAD -eq 1 ]] && download
[[ $CLEAN -eq 1 ]] && clean
unpackSource
patchSource
[[ "$PLATFORM" == "ios" ]] && buildIOS || buildOSX
packageFramework $LIB_DIR/$PLATFORM/$LIB_NAME $OUTPUT_DIR/$PLATFORM

