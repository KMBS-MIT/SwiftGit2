#!/bin/zsh

# TODO: This script could use a lot of cleanup. It should also put build artifacts in a subfolder.

export REPO_ROOT=`pwd`
export MACOSX_DEPLOYMENT_TARGET=13.0
LIBGIT2_VERSION=1.6.4

# Note: `xcodebuild` disallows `maccatalyst` and `macosx` in the same XCFramework.
AVAILABLE_PLATFORMS=(macosx macosx-arm64) # iphoneos iphonesimulator iphonesimulator-arm64 maccatalyst maccatalyst-arm64

# List of frameworks included in the XCFramework (= AVAILABLE_PLATFORMS without architecture specifications)
XCFRAMEWORK_PLATFORMS=(macosx) # iphoneos iphonesimulator maccatalyst

# List of platforms that need to be merged using lipo due to presence of multiple architectures
LIPO_PLATFORMS=(macosx) # iphonesimulator maccatalyst

### Setup common environment variables to run CMake for a given platform
### Usage:      setup_variables PLATFORM
### where PLATFORM is the platform to build for and should be one of
###    iphoneos  (implicitly arm64)
###    iphonesimulator, iphonesimulator-arm64
###    maccatalyst, maccatalyst-arm64
###    macosx, macosx-arm64
###
### After this function is executed, the variables
###    $PLATFORM
###    $ARCH
###    $SYSROOT
###    $CMAKE_ARGS
### providing basic/common CMake options will be set.
function setup_variables() {
  cd $REPO_ROOT
  PLATFORM=$1

  CMAKE_ARGS=(-DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER_WORKS=ON \
    -DCMAKE_CXX_COMPILER_WORKS=ON \
    -DCMAKE_INSTALL_PREFIX=$REPO_ROOT/install/$PLATFORM)

  case $PLATFORM in
    "iphoneos")
      ARCH=arm64
      SYSROOT=`xcodebuild -version -sdk iphoneos Path`
      CMAKE_ARGS+=(-DCMAKE_OSX_ARCHITECTURES=$ARCH \
        -DCMAKE_OSX_SYSROOT=$SYSROOT);;

    "iphonesimulator")
      ARCH=x86_64
      SYSROOT=`xcodebuild -version -sdk iphonesimulator Path`
      CMAKE_ARGS+=(-DCMAKE_OSX_ARCHITECTURES=$ARCH -DCMAKE_OSX_SYSROOT=$SYSROOT);;

    "iphonesimulator-arm64")
      ARCH=arm64
      SYSROOT=`xcodebuild -version -sdk iphonesimulator Path`
      CMAKE_ARGS+=(-DCMAKE_OSX_ARCHITECTURES=$ARCH -DCMAKE_OSX_SYSROOT=$SYSROOT);;

    "maccatalyst")
      ARCH=x86_64
      SYSROOT=`xcodebuild -version -sdk macosx Path`
      CMAKE_ARGS+=(-DCMAKE_C_FLAGS=-target\ $ARCH-apple-ios14.1-macabi);;

    "maccatalyst-arm64")
      ARCH=arm64
      SYSROOT=`xcodebuild -version -sdk macosx Path`
      CMAKE_ARGS+=(-DCMAKE_C_FLAGS=-target\ $ARCH-apple-ios14.1-macabi);;

    "macosx")
      ARCH=x86_64
      SYSROOT=`xcodebuild -version -sdk macosx Path`;;

    "macosx-arm64")
      ARCH=arm64
      SYSROOT=`xcodebuild -version -sdk macosx Path`
      CMAKE_ARGS+=(-DCMAKE_OSX_ARCHITECTURES=$ARCH);;

    *)
      echo "Unsupported or missing platform! Must be one of" ${AVAILABLE_PLATFORMS[@]}
      exit 1;;
  esac
}

### Build libgit2 for a single platform (given as the first and only argument)
### See @setup_variables for the list of available platform names
function build_libgit2() {
    setup_variables $1

    # Download libgit2
    rm -rf libgit2-v$LIBGIT2_VERSION
    test -f v$LIBGIT2_VERSION.zip || wget -q https://github.com/libgit2/libgit2/archive/refs/tags/v$LIBGIT2_VERSION.zip
    ditto -V -x -k --sequesterRsrc --rsrc v$LIBGIT2_VERSION.zip ./ >/dev/null 2>/dev/null
    cd libgit2-$LIBGIT2_VERSION

    rm -rf build && mkdir build && cd build

    CMAKE_ARGS+=(-DBUILD_CLAR=NO)
    CMAKE_ARGS+=(-DOPENSSL_ROOT_DIR=$REPO_ROOT/install/$PLATFORM)
    CMAKE_ARGS+=(-DUSE_SSH=OFF)
    CMAKE_ARGS+=(-DBUILD_CLI=OFF)
    CMAKE_ARGS+=(-DBUILD_TESTS=OFF)

    cmake "${CMAKE_ARGS[@]}" .. #>/dev/null 2>/dev/null

    cmake --build . --target install #>/dev/null 2>/dev/null
}

### Create xcframework for a given library
function build_xcframework() {
  local FWNAME=$1
  shift
  local PLATFORMS=( "$@" )
  local FRAMEWORKS_ARGS=()

  echo "--> Building" $FWNAME "XCFramework containing" ${PLATFORMS[@]}

  for p in ${PLATFORMS[@]}; do
    FRAMEWORKS_ARGS+=("-library" "install/$p/$FWNAME.a" "-headers" "install/$p/include")
  done

  cd $REPO_ROOT
  xcodebuild -create-xcframework ${FRAMEWORKS_ARGS[@]} -output $FWNAME.xcframework
}

### Copy SwiftGit2's module.modulemap to libgit2.xcframework/*/Headers
### so that we can use libgit2 C API in Swift (e.g. via SwiftGit2)
function copy_modulemap() {
    local FWDIRS=$(find Clibgit2.xcframework -mindepth 1 -maxdepth 1 -type d)
    for d in ${FWDIRS[@]}; do
        echo $d
        cp Clibgit2.modulemap $d/Headers/module.modulemap
    done
}

# TODO: Remove libgit2
### Build libgit2 and Clibgit2 frameworks for all available platforms
for p in ${AVAILABLE_PLATFORMS[@]}; do
  echo "--> Build libgit2 ($p)"
  build_libgit2 $p

  # Merge all static libs as libgit2.a since xcodebuild doesn't allow specifying multiple .a
  cd $REPO_ROOT/install/$p
  libtool -static -o libgit2.a lib/*.a
done

# Merge the libgit2.a for iphonesimulator & iphonesimulator-arm64 as well as maccatalyst & maccatalyst-arm64 using lipo
for p in ${LIPO_PLATFORMS[@]}; do
    cd $REPO_ROOT/install/$p
    lipo libgit2.a ../$p-arm64/libgit2.a -output libgit2_all_archs.a -create
    test -f libgit2_all_archs.a && rm libgit2.a && mv libgit2_all_archs.a libgit2.a
done

# Build raw libgit2 XCFramework for Objective-C usage
build_xcframework libgit2 ${XCFRAMEWORK_PLATFORMS[@]}
zip -r libgit2.xcframework.zip libgit2.xcframework/

# Build Clibgit2 XCFramework for use with SwiftGit2
mv libgit2.xcframework Clibgit2.xcframework
copy_modulemap
zip -r Clibgit2.xcframework.zip Clibgit2.xcframework/
