#!/bin/bash

if [ ! -d "vcpkg" ]; then
    git clone --depth 1 https://github.com/microsoft/vcpkg
    ./vcpkg/bootstrap-vcpkg.sh
fi

./vcpkg/vcpkg install --overlay-triplets=custom-triplets --triplet=x64-osx-10.9 zlib libogg opus opusfile libvorbis
./vcpkg/vcpkg install --overlay-triplets=custom-triplets --triplet=arm64-osx zlib libogg opus opusfile libvorbis

mkdir -p libs_universal
lipo -create ./vcpkg/installed/x64-osx-10.9/lib/libogg.a ./vcpkg/installed/arm64-osx/lib/libogg.a -output ./libs_universal/libogg.a
lipo -create ./vcpkg/installed/x64-osx-10.9/lib/libopus.a ./vcpkg/installed/arm64-osx/lib/libopus.a -output ./libs_universal/libopus.a
lipo -create ./vcpkg/installed/x64-osx-10.9/lib/libopusfile.a ./vcpkg/installed/arm64-osx/lib/libopusfile.a -output ./libs_universal/libopusfile.a
lipo -create ./vcpkg/installed/x64-osx-10.9/lib/libvorbis.a ./vcpkg/installed/arm64-osx/lib/libvorbis.a -output ./libs_universal/libvorbis.a
lipo -create ./vcpkg/installed/x64-osx-10.9/lib/libvorbisenc.a ./vcpkg/installed/arm64-osx/lib/libvorbisenc.a -output ./libs_universal/libvorbisenc.a
lipo -create ./vcpkg/installed/x64-osx-10.9/lib/libvorbisfile.a ./vcpkg/installed/arm64-osx/lib/libvorbisfile.a -output ./libs_universal/libvorbisfile.a
lipo -create ./vcpkg/installed/x64-osx-10.9/lib/libz.a ./vcpkg/installed/arm64-osx/lib/libz.a -output ./libs_universal/libz.a