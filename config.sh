#!/bin/sh

# Minimum Profit autoconfiguration script

DRIVERS=""
APPNAME="mp-4"

# gets program version
VERSION=`cut -f2 -d\" VERSION`

# default installation prefix
PREFIX=/usr/local

# parse arguments
while [ $# -gt 0 ] ; do

	case $1 in
	--without-curses)	WITHOUT_CURSES=1 ;;
	--without-gtk)		WITHOUT_GTK=1 ;;
	--without-win32)	WITHOUT_WIN32=1 ;;
	--without-unix-glob)	WITHOUT_UNIX_GLOB=1 ;;
	--with-included-regex)	WITH_INCLUDED_REGEX=1 ;;
	--with-pcre)		WITH_PCRE=1 ;;
	--without-gettext)	WITHOUT_GETTEXT=1 ;;
	--without-iconv)	WITHOUT_ICONV=1 ;;
	--without-wcwidth)	WITHOUT_WCWIDTH=1 ;;
	--help)			CONFIG_HELP=1 ;;

	--debian)		BUILD_FOR_DEBIAN=1
				PREFIX=/usr
				APPNAME=mped
				;;

	--prefix)		PREFIX=$2 ; shift ;;
	--prefix=*)		PREFIX=`echo $1 | sed -e 's/--prefix=//'` ;;
	esac

	shift
done

if [ "$CONFIG_HELP" = "1" ] ; then

	echo "Available options:"
	echo "--prefix=PREFIX       Installation prefix ($PREFIX)."
	echo "--without-curses      Disable curses (text) interface detection."
	echo "--without-gtk         Disable GTK interface detection."
	echo "--without-win32       Disable win32 interface detection."
	echo "--without-unix-glob   Disable glob.h usage (use workaround)."
	echo "--with-included-regex Use included regex code (gnu_regex.c)."
	echo "--with-pcre           Enable PCRE library detection."
	echo "--without-gettext     Disable gettext usage."
	echo "--without-iconv       Disable iconv usage."
	echo "--without-wcwidth     Disable system wcwidth() (use workaround)."
	echo "--debian              Build for Debian ('make deb')."

	echo
	echo "Environment variables:"
	echo "CC                    C Compiler."
	echo "CFLAGS                Compile flags (i.e., -O3)."
	echo "WINDRES               MS Windows resource compiler."

	exit 1
fi

echo "Configuring..."

echo "/* automatically created by config.sh - do not modify */" > config.h
echo "# automatically created by config.sh - do not modify" > makefile.opts
> config.ldflags
> config.cflags
> .config.log

# set compiler
if [ "$CC" = "" ] ; then
	CC=cc
	# if CC is unset, try if gcc is available
	which gcc > /dev/null && CC=gcc
fi

echo "CC=$CC" >> makefile.opts

# set cflags
if [ "$CFLAGS" = "" ] ; then
	CFLAGS="-g -Wall"
fi

echo "CFLAGS=$CFLAGS" >> makefile.opts

# Add CFLAGS to CC
CC="$CC $CFLAGS"

# add version
cat VERSION >> config.h

# add installation prefix and application name
echo "#define CONFOPT_PREFIX \"$PREFIX\"" >> config.h
echo "#define CONFOPT_APPNAME \"$APPNAME\"" >> config.h

################################################################

# mpdm
echo -n "Looking for mpdm... "

for MPDM in ./mpdm ../mpdm NOTFOUND ; do
	if [ -d $MPDM ] && [ -f $MPDM/mpdm.h ] ; then
		break
	fi
done

if [ "$MPDM" != "NOTFOUND" ] ; then
	echo "-I$MPDM" >> config.cflags
	echo "-L$MPDM -lmpdm" >> config.ldflags
	echo "OK ($MPDM)"
else
	echo "No"
	exit 1
fi

# If mpdm is not configured, do it
if [ ! -f $MPDM/Makefile ] ; then
	CONF_ARGS="--prefix=$PREFIX"
	[ "$WITHOUT_WIN32" = 1 ] && CONF_ARGS="$CONF_ARGS --without-win32"
	[ "$WITHOUT_UNIX_GLOB" = 1 ] && CONF_ARGS="$CONF_ARGS --without-unix-glob"
	[ "$WITH_INCLUDED_REGEX" = 1 ] && CONF_ARGS="$CONF_ARGS --with-included-regex"
	[ "$WITH_PCRE" = 1 ] && CONF_ARGS="$CONF_ARGS --with-pcre"
	[ "$WITHOUT_GETTEXT" = 1 ] && CONF_ARGS="$CONF_ARGS --without-gettext"
	[ "$WITHOUT_ICONV" = 1 ] && CONF_ARGS="$CONF_ARGS --without-iconv"
	[ "$WITHOUT_WCWIDTH" = 1 ] && CONF_ARGS="$CONF_ARGS --without-wcwidth"
	( echo ; cd $MPDM ; ./config.sh $CONF_ARGS ; echo )
fi

cat $MPDM/config.ldflags >> config.ldflags
echo "MPDM=$MPDM" >> makefile.opts

# mpsl
echo -n "Looking for mpsl... "

for MPSL in ./mpsl ../mpsl NOTFOUND ; do
	if [ -d $MPSL ] && [ -f $MPSL/mpsl.h ] ; then
		break
	fi
done

if [ "$MPSL" != "NOTFOUND" ] ; then
	echo "-I$MPSL" >> config.cflags
	echo "-L$MPSL -lmpsl" >> config.ldflags
	echo "OK ($MPSL)"
else
	echo "No"
	exit 1
fi

# If mpsl is not configured, do it
if [ ! -f $MPSL/Makefile ] ; then
	CONF_ARGS="--prefix=$PREFIX"
	( echo ; cd $MPSL ; ./config.sh $CONF_ARGS ; echo )
fi

cat $MPSL/config.ldflags >> config.ldflags
echo "MPSL=$MPSL" >> makefile.opts

# test for curses / ncurses library
echo -n "Testing for curses... "

if [ "$WITHOUT_CURSES" = "1" ] ; then
	echo "Disabled by user"
else
	echo "#include <curses.h>" > .tmp.c
	echo "int main(void) { initscr(); endwin(); return 0; }" >> .tmp.c

	TMP_CFLAGS="-I/usr/local/include"
	TMP_LDFLAGS="-L/usr/local/lib -lncursesw"

	$CC $TMP_CFLAGS .tmp.c $TMP_LDFLAGS -o .tmp.o 2>> .config.log
	if [ $? = 0 ] ; then
		echo "#define CONFOPT_CURSES 1" >> config.h
		echo $TMP_CFLAGS >> config.cflags
		echo $TMP_LDFLAGS >> config.ldflags
		echo "OK (ncursesw)"
		DRIVERS="curses $DRIVERS"
	else
		# try plain curses library
		TMP_LDFLAGS="-L/usr/local/lib -lcurses"
		$CC $TMP_CFLAGS .tmp.c $TMP_LDFLAGS -o .tmp.o 2>> .config.log
		if [ $? = 0 ] ; then
			echo "#define CONFOPT_CURSES 1" >> config.h
			echo $TMP_CFLAGS >> config.cflags
			echo $TMP_LDFLAGS >> config.ldflags
			echo "OK (plain curses)"
			DRIVERS="curses $DRIVERS"
		else
			echo "No"
			WITHOUT_CURSES=1
		fi
	fi
fi

if [ "$WITHOUT_CURSES" != "1" ] ; then
	# test for transparent colors in curses
	echo -n "Testing for transparency support in curses... "

	echo "#include <curses.h>" > .tmp.c
	echo "int main(void) { initscr(); use_default_colors(); endwin(); return 0; }" >> .tmp.c

	$CC $TMP_CFLAGS .tmp.c $TMP_LDFLAGS -o .tmp.o 2>> .config.log
	if [ $? = 0 ] ; then
		echo "#define CONFOPT_TRANSPARENCY 1" >> config.h
		echo "OK"
	else
		echo "No"
	fi
fi

# GTK
echo -n "Testing for GTK... "

if [ "$WITHOUT_GTK" = "1" ] ; then
	echo "Disabled by user"
else
	echo "#include <gtk/gtk.h>" > .tmp.c
	echo "#include <gdk/gdkkeysyms.h>" >> .tmp.c
	echo "int main(void) { gtk_main(); return 0; } " >> .tmp.c

	# Try first GTK 2.0
	TMP_CFLAGS=`pkg-config --cflags gtk+-2.0 2>/dev/null`
	TMP_LDFLAGS=`pkg-config --libs gtk+-2.0 2>/dev/null`

	$CC $TMP_CFLAGS .tmp.c $TMP_LDFLAGS -o .tmp.o 2>> .config.log
	if [ $? = 0 ] ; then
		echo "#define CONFOPT_GTK 2" >> config.h
		echo "$TMP_CFLAGS " >> config.cflags
		echo "$TMP_LDFLAGS " >> config.ldflags
		echo "OK (2.0)"
		DRIVERS="gtk $DRIVERS"
	else
		echo "No"
		WITHOUT_GTK=1
	fi
fi

# Win32
echo -n "Testing for win32... "
if [ "$WITHOUT_WIN32" = "1" ] ; then
	echo "Disabled by user"
else
	grep CONFOPT_WIN32 ${MPDM}/config.h >/dev/null

	if [ $? = 0 ] ; then
		echo "#define CONFOPT_WIN32 1" >> config.h
		echo "OK"
		DRIVERS="win32 $DRIVERS"
		WITHOUT_UNIX_GLOB=1
		APPNAME=wmp.exe
	else
		echo "No"
	fi
fi

echo >> config.h
echo "#if defined(CONFOPT_CURSES) || defined(CONFOPT_GTK)" >> config.h
echo "#define CONFOPT_UNIX_LIKE 1" >> config.h
echo "#endif" >> config.h

echo "VERSION=$VERSION" >> makefile.opts
echo "WINDRES=$WINDRES" >> makefile.opts
echo "PREFIX=\$(DESTDIR)$PREFIX" >> makefile.opts
echo "APPNAME=$APPNAME" >> makefile.opts
echo >> makefile.opts

cat makefile.opts makefile.in makefile.depend > Makefile

##############################################

if [ "$DRIVERS" = "" ] ; then

	echo
	echo "*ERROR* No usable drivers (interfaces) found"
	echo "See the README file for the available options."

	exit 1
fi

echo
echo "Configured drivers:" $DRIVERS
echo
echo "Type 'make' to build Minimum Profit."

# cleanup
rm -f .tmp.c .tmp.o

exit 0
