#!/bin/sh

source common.sh
setupDirStructure
cd "$BUILDDIR"

if [ "x$PIDGIN_SOURCE" = "x" ] ; then
	echo 'Error: you need to set PIDGIN_SOURCE to be the location of' \
	'your pidgin source tree.'
	exit 1
fi

echo "Using Pidgin source from: $PIDGIN_SOURCE"

# Read in our parameters
USER_REGENERATE=FALSE
ARCHES=(ppc i386)
while [ $# -gt 0 ] ; do
	case $1 in
		--regenerate)
			USER_REGENERATE=TRUE
			shift 1 
			;;
		--ppc)
			ARCHES=(ppc)
			shift 1
			;;
		--i386)
			ARCHES=(i386)
			shift 1
			;;
		*)
			echo "Invalid argument: $1"
			shift 1
			;;
	esac
done
echo purple_make.sh: Compiling ${ARCHES[@]}

DEBUG_SYMBOLS=TRUE
PROTOCOLS="bonjour facebook gg irc jabber msn myspace novell oscar qq sametime simple yahoo zephyr"

###
# Patches bringing in forward changes from libpurple:
#
###
# Patches for our own hackery
#
# libpurple_jabber_avoid_sasl_option_hack.diff is needed to avoid using PLAIN via SASL on Mac OS X 10.4, 
# 		where it doesn't work properly
# libpurple_makefile_linkage_hacks.diff fixes some linkage problems
# libpurple_jabber_parser_error_handler.diff maintains the error handler
# 		which Foundation apparently manages to reset repeated, 
# 		which may fix crashes in __xmlRaiseError() --> _structuredErrorFunc().
# libpurple_xmlnode_parser_error_handler does the same for other xml parsing.
# libpurple_disable_last_seen_tracking.diff disables the last-seen tracking, 
# 		avoiding unnecessary blist.xml writes, since we don't ever use the information (we keep track of it ourselves).
# libpurple_jabber_fallback_to_auth_old_after_gssapi_only_fails.diff fixes iChat 
# 		10.5 Server compatibility by falling back on iq:jabber:auth if GSSAPI
# 		fails and is the only available mechanism. It should be applied after
# 		libpurple_jabber_avoid_sasl_option_hack.diff
# libpurple_jabber_use_builtin_digestmd5.diff uses our built-in digest-MD5
# 		implementation for Jabber auth to prevent problems with some servers'
# 		poor interaction with cyrus-sasl. Note that this means we can connect
# 		to some servers iChat can't ;)
# libpurple_jabber_roster_debug.diff is temporary debugging for #8834
#
# libpurple_oscar_sendfile_debug.diff adds debug logging for #10587
###
LIBPURPLE_PATCHES=("$PATCHDIR/libpurple_makefile_linkage_hacks.diff" \
					"$PATCHDIR/libpurple_disable_last_seen_tracking.diff" \
					"$PATCHDIR/libpurple-restrict-potfiles-to-libpurple.diff" \
					"$PATCHDIR/libpurple_jabber_parser_error_handler.diff" \
					"$PATCHDIR/libpurple_jabber_avoid_sasl_option_hack.diff" \
					"$PATCHDIR/libpurple_xmlnode_parser_error_handler.diff" \
					"$PATCHDIR/libpurple_zephyr_fix_krb4_flags.diff" \
					"$PATCHDIR/libpurple_jabber_use_builtin_digestmd5.diff" \
					"$PATCHDIR/libpurple_jabber_fallback_to_auth_old_after_gssapi_only_fails.diff" \
					"$PATCHDIR/libpurple_jabber_roster_debug.diff" \
					"$PATCHDIR/libpurple_oscar_sendfile_debug.diff")

pushd $PIDGIN_SOURCE > /dev/null 2>&1
	for patch in ${LIBPURPLE_PATCHES[@]} ; do
		echo "Applying $patch"
		# telekinetic-patch will let us maintain timestamps,
		# for incremental building
		python $PATCHDIR/telekinetic-patch.py --forward -p0 < $patch || true
	done

popd > /dev/null 2>&1

###
# These files are overwritten during each build, which prevents us from
# performing incremental builds.
#
# This list was generated by a DTrace script that watched files being written
# to during a build of each architecture. I then narrowed the list to only the
# files that were written during BOTH builds.
#
# It should be confirmed that these files all need to be copied.
#
# -- Ryan Govostes, July 15 '08
##
AUTOGEN_GREMLINS=("autom4te.cache" \
				"config.guess" \
				"config.sub" \
				"configure" \
				"intltool-extract.in" \
				"intltool-merge.in" \
				"intltool-update.in" \
				"ltmain.sh" \
				"mkinstalldirs" \
				"po/Makefile.in.in" \
				)

for ARCH in ${ARCHES[@]} ; do
	case $ARCH in
		ppc)
			export HOST=powerpc-apple-darwin9
			export PATH="$PATH_PPC"
			export ACLOCAL_FLAGS="-I $TARGET_DIR_PPC/share/aclocal"
			export PKG_CONFIG_PATH="$TARGET_DIR_PPC/lib/pkgconfig"
			TARGET_DIR=$TARGET_DIR_PPC
			;;
		i386)
			export HOST=i686-apple-darwin9
			export PATH="$PATH_I386"
			export ACLOCAL_FLAGS="-I $TARGET_DIR_I386/share/aclocal"
			export PKG_CONFIG_PATH="$TARGET_DIR_I386/lib/pkgconfig"
			TARGET_DIR=$TARGET_DIR_I386
			;;
	esac
	
	#Get access to the sasl headers
	mkdir -p $TARGET_DIR/include/sasl || true
	cp $SOURCEDIR/cyrus-sasl-2.1.18/include/*.h $TARGET_DIR/include/sasl
	
	#Note that whether we use openssl or cdsa the same underlying workarounds (as seen in jabber.c, only usage at present 12/07) are needed
	export CFLAGS="$BASE_CFLAGS -arch $ARCH -I$TARGET_DIR/include -I$SDK_ROOT/usr/include/kerberosIV -DHAVE_SSL -DHAVE_OPENSSL -fno-common "
	
	if [ "$DEBUG_SYMBOLS" = "TRUE" ] ; then
		export CFLAGS="$CFLAGS -gdwarf-2 -g3" 
	fi
	
	export LDFLAGS="$BASE_LDFLAGS -L$TARGET_DIR/lib -arch $ARCH -lsasl2"
	export PKG_CONFIG="$TARGET_DIR_BASE-$ARCH/bin/pkg-config"
	export MSGFMT="`which msgfmt`"
	
	mkdir libpurple-$ARCH > /dev/null || true
	pushd libpurple-$ARCH > /dev/null 2>&1
		export ARCH
		echo Compiling for $ARCH
		echo LDFLAGS is $LDFLAGS
		echo PKG_CONFIG is $PKG_CONFIG
		
		# we don't need pkg-config for this
		export LIBXML_CFLAGS='-I/usr/include/libxml2' 
		export LIBXML_LIBS='-lxml2'
		export GADU_CFLAGS="-I$TARGET_DIR/include"
		export GADU_LIBS="-lgadu"
		export MEANWHILE_CFLAGS="-I$TARGET_DIR/include/meanwhile -I$TARGET_DIR/include/glib-2.0 -I$TARGET_DIR/lib/glib-2.0/include"
		export MEANWHILE_LIBS="-lmeanwhile -lglib-2.0 -liconv"
		
		# If we're trying to use files we generated previously, make sure they're there
		FORCE_REGENERATE="$USER_REGENERATE"
		if [ x"$FORCE_REGENERATE" = x"FALSE" ] ; then
			if [ ! -e ./Makefile ] ; then
				echo "Makefile not found; forcing regenerate"
				FORCE_REGENERATE=TRUE
			fi
			if [ ! -e ./config.status ] ; then
				echo "config.status not found; forcing regenerate"
				FORCE_REGENERATE=TRUE
			fi
			if [ ! -d ./autogen_cache ] ; then
				echo "autogen_cache not found; forcing regenerate"
				FORCE_REGENERATE=TRUE
			else
				pushd autogen_cache > /dev/null 2>&1
					for file in ${AUTOGEN_GREMLINS[@]} ; do
						if [ ! -e $file ] ; then
							echo "autogen_cache/$file not found; forcing regenerate"
							FORCE_REGENERATE=TRUE
							break
						fi
					done
				popd > /dev/null 2>&1
			fi
		fi
		
		# We only need to autogen if building from scratch or it's requested
		if [ x"$FORCE_REGENERATE" = x"TRUE" ] ; then
			pushd $PIDGIN_SOURCE > /dev/null 2>&1
				./autogen.sh --help
			popd > /dev/null 2>&1
			
			$PIDGIN_SOURCE/configure \
				--disable-gtkui --disable-consoleui \
				--disable-perl \
				--enable-debug \
				--disable-static --enable-shared \
				--with-krb4 \
				--enable-cyrus-sasl \
				--prefix=$TARGET_DIR \
				--with-static-prpls="$PROTOCOLS" --disable-plugins \
				--host=$HOST \
				--disable-gstreamer \
				--disable-avahi \
				--disable-dbus \
				--enable-gnutls=no --enable-nss=no --enable-openssl=no $@
		else
			echo "Restoring files from previous build"
			for file in ${AUTOGEN_GREMLINS[@]} ; do
				cp -pRv autogen_cache/$file $PIDGIN_SOURCE/`dirname $file`
			done
		fi
		
		pushd libpurple > /dev/null 2>&1
			make -j $NUMBER_OF_CORES && make install
		popd > /dev/null 2>&1
		
		# Now save the files for later
		echo "Rescuing files for subsequent builds"
		rm -Rf ./autogen_cache || true
		mkdir autogen_cache
		pushd autogen_cache > /dev/null 2>&1
			for file in ${AUTOGEN_GREMLINS[@]} ; do
				if [ x`dirname $file` != x"." ] ; then
					mkdir `dirname $file` || true
				fi
				cp -pRv $PIDGIN_SOURCE/$file `dirname $file` || true
			done
		popd > /dev/null 2>&1
		
	popd > /dev/null 2>&1
	
	# HACK ALERT! We use the following internal-only headers:
	cp	$PIDGIN_SOURCE/libpurple/protocols/oscar/oscar.h \
		$PIDGIN_SOURCE/libpurple/protocols/oscar/snactypes.h \
		$PIDGIN_SOURCE/libpurple/protocols/oscar/peer.h \
		$PIDGIN_SOURCE/libpurple/cmds.h \
		$PIDGIN_SOURCE/libpurple/internal.h \
		$PIDGIN_SOURCE/libpurple/protocols/msn/*.h \
		$PIDGIN_SOURCE/libpurple/protocols/yahoo/*.h \
		$PIDGIN_SOURCE/libpurple/protocols/gg/buddylist.h \
		$PIDGIN_SOURCE/libpurple/protocols/gg/gg.h \
		$PIDGIN_SOURCE/libpurple/protocols/gg/search.h \
		$PIDGIN_SOURCE/libpurple/protocols/jabber/buddy.h \
		$PIDGIN_SOURCE/libpurple/protocols/jabber/caps.h \
		$PIDGIN_SOURCE/libpurple/protocols/jabber/jutil.h \
		$PIDGIN_SOURCE/libpurple/protocols/jabber/presence.h \
		$PIDGIN_SOURCE/libpurple/protocols/jabber/si.h \
		$PIDGIN_SOURCE/libpurple/protocols/jabber/jabber.h \
		$TARGET_DIR/include/libpurple
done

pushd $PIDGIN_SOURCE > /dev/null 2>&1
	for patch in ${LIBPURPLE_PATCHES[@]} ; do
		echo "Reverting $patch"
		# telekinetic-patch will let us maintain timestamps,
		# for incremental building
		$PATCHDIR/telekinetic-patch.py -R -p0 < $patch || true
	done
popd > /dev/null 2>&1

echo "Done - now run ./universalize.sh"