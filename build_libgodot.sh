#!/bin/bash

set -eux

BASE_DIR="$( cd "$(dirname "$0")" ; pwd -P )"

GODOT_DIR="$BASE_DIR/godot"
GODOT_CPP_DIR="$BASE_DIR/godot-cpp"
SWIFT_GODOT_DIR="$BASE_DIR/SwiftGodot"
SWIFT_GODOT_KIT_DIR="$BASE_DIR/SwiftGodotKit"
BUILD_DIR=$BASE_DIR/build

host_system="$(uname -s)"
host_arch="$(uname -m)"
host_target="editor"
target="editor"
target_arch=""
host_build_options=""
target_build_options=""
lib_suffix="so"
host_debug=1
debug=1
force_host_rebuild=0
force_regenerate=0

case "$host_system" in
    Linux)
        host_platform="linuxbsd"
        cpus="$(nproc)"
        target_platform="linuxbsd"
    ;;
    Darwin)
        host_platform="macos"
        cpus="$(sysctl -n hw.logicalcpu)"
        target_platform="macos"
        lib_suffix="dylib"
    ;;
    *)
        echo "System $host_system is unsupported"
        exit 1
    ;;
esac


while [ "${1:-}" != "" ]
do
    case "$1" in
        --host-rebuild)
            force_host_rebuild=1
        ;;
        --host-debug)
            host_debug=1
        ;;        
        --regenerate)
            force_regenerate=1
        ;;
        --debug)
            debug=1
        ;;
        --target)
            shift
            target_platform="${1:-}"
        ;;
        *)
            echo "Usage: $0 [--host-debug] [--host-rebuild] [--debug] [--regenerate] --target <target platform>"
            exit 1
        ;;
    esac
    shift
done

if [ "$target_platform" = "ios" ]
then
    target_arch="arm64"
    target="template_debug"
    lib_suffix="a"
fi

if [ "$target_arch" = "" ]
then
    target_arch="$host_arch"
fi

host_godot_suffix="$host_platform.$host_target"

if [ $host_debug -eq 1 ]
then
    host_build_options="$host_build_options dev_build=yes"
    host_godot_suffix="$host_godot_suffix.dev"
fi

host_godot_suffix="$host_godot_suffix.$host_arch"

target_godot_suffix="$target_platform.$target"

if [ $debug -eq 1 ]
then
    target_build_options="$target_build_options dev_build=yes"
    target_godot_suffix="$target_godot_suffix.dev"
fi

target_godot_suffix="$target_godot_suffix.$target_arch"

host_godot="$GODOT_DIR/bin/godot.$host_godot_suffix"
target_godot="$GODOT_DIR/bin/libgodot.$target_godot_suffix.$lib_suffix"

if [ ! -x $host_godot ] || [ $force_host_rebuild -eq 1 ]
then
    rm -f $host_godot
    cd $GODOT_DIR
    scons p=$host_platform target=$host_target $host_build_options
fi

mkdir -p $BUILD_DIR

if [ ! -f $BUILD_DIR/extension_api.json ] || [ $force_regenerate -eq 1 ]
then
    cd $BUILD_DIR
    $host_godot --dump-extension-api
fi

cd $GODOT_DIR
scons p=$target_platform target=$target $target_build_options library_type=shared_library
cp -v $target_godot $BUILD_DIR/libgodot.$lib_suffix

cp -v $BUILD_DIR/extension_api.json $GODOT_CPP_DIR/gdextension/
cp -v $GODOT_DIR/core/extension/gdextension_interface.h $GODOT_CPP_DIR/gdextension/

if [ "$target_platform" = "ios" ]
then
    $SWIFT_GODOT_DIR/scripts/make-libgodot.framework $GODOT_DIR $BUILD_DIR
    cp -v $BUILD_DIR/extension_api.json $SWIFT_GODOT_DIR/Sources/ExtensionApi/
    cp -v $GODOT_DIR/core/extension/gdextension_interface.h $SWIFT_GODOT_DIR/Sources/GDExtension/include/
fi