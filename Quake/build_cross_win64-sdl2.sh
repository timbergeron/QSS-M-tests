#!/bin/sh

# Change this script to meet your needs and/or environment.

TARGET=x86_64-w64-mingw32
PREFIX=/opt/cross_win64

PATH="$PREFIX/bin:$PATH"
export PATH

MAKE_CMD=make

CC="$TARGET-gcc"
AS="$TARGET-as"
RANLIB="$TARGET-ranlib"
AR="$TARGET-ar"
WINDRES="$TARGET-windres"
STRIP="$TARGET-strip"
if command -v "$TARGET-pkg-config" >/dev/null 2>&1; then
	PKG_CONFIG="$TARGET-pkg-config"
elif command -v "$TARGET-pkgconf" >/dev/null 2>&1; then
	PKG_CONFIG="$TARGET-pkgconf"
else
	PKG_CONFIG="pkg-config"
fi
if [ "$PKG_CONFIG" = "pkg-config" ]; then
	if [ -d "$PREFIX/$TARGET/lib/pkgconfig" ] || [ -d "$PREFIX/$TARGET/share/pkgconfig" ]; then
		PKG_CONFIG_LIBDIR="$PREFIX/$TARGET/lib/pkgconfig:$PREFIX/$TARGET/share/pkgconfig"
	elif [ -d "/usr/$TARGET/lib/pkgconfig" ] || [ -d "/usr/$TARGET/share/pkgconfig" ]; then
		PKG_CONFIG_LIBDIR="/usr/$TARGET/lib/pkgconfig:/usr/$TARGET/share/pkgconfig"
	elif [ -d "/usr/lib/$TARGET/pkgconfig" ]; then
		PKG_CONFIG_LIBDIR="/usr/lib/$TARGET/pkgconfig"
	fi
fi
export PATH CC AS AR RANLIB WINDRES STRIP PKG_CONFIG PKG_CONFIG_LIBDIR

exec $MAKE_CMD USE_SDL2=1 CC=$CC AS=$AS RANLIB=$RANLIB AR=$AR WINDRES=$WINDRES STRIP=$STRIP -f Makefile.w64 $*
