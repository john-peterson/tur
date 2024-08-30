TERMUX_PKG_HOMEPAGE=https://github.com/rkd77/elinks
TERMUX_PKG_DESCRIPTION=" 
terminal JavaScript browser that  WORKS if you can help the web master or patch the page. usually fails from lack of testing by the web master

sometimes a fake user agent magically load the content you need
~/.config/elinks/elinks.conf
set protocol.http.user_agent = Gecko

my test branch https://github.com/john-peterson/elinks/tree/test print more output from
elinks -test url
"
TERMUX_PKG_LICENSE="GPL-2.0"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION=$(date +"%y%m%d")
TERMUX_PKG_REVISION=1
TERMUX_PKG_SRCURL=git+https://github.com/john-peterson/elinks
TERMUX_PKG_GIT_BRANCH=make
TERMUX_PKG_DEPENDS="libandroid-execinfo, libexpat, libiconv, libidn, openssl, libbz2, zlib,quickjs"
#  build netsurf for libdom libcss
TERMUX_PKG_BUILD_DEPENDS="netsurf"
TERMUX_PKG_AUTO_UPDATE=true
TERMUX_PKG_BUILD_IN_SRC=true
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
--enable-256-colors
--enable-true-color
--mandir=$TERMUX_PREFIX/share/man
--with-openssl
--with-quickjs
--without-brotli
--without-zstd
"
#--enable-debug
TERMUX_PKG_EXTRA_MAKE_ARGS="V=1"
if $TERMUX_ON_DEVICE_BUILD; then TERMUX_PKG_MAKE_PROCESSES=1;fi

termux_step_post_get_source() {

}

# use latest version this is a real bug fest
build_qjs(){
if !$TERMUX_ON_DEVICE_BUILD; then
return
fi
git clone --depth 1 https://github.com/bellard/quickjs
#cp -r $HOME/quickjs .
make -C quickjs
}

termux_step_pre_configure() {
	build_qjs
	./autogen.sh
	#export LIBRARY_PATH+=$TERMUX_TOPDIR/netsurf/src/inst-gtk3/lib
	export LIBRARY_PATH+="$(pwd):$PREFIX/lib"
	export PKG_CONFIG_PATH+="$TERMUX_TOPDIR/netsurf/src/inst-gtk3/lib/pkgconfig"
	export CPATH=$(pwd)
	export C_INCLUDE_PATH=$(pwd)
	export LDFLAGS+=" -landroid-execinfo"
	export CFLAGS+=" -w -Wno-error"
}

termux_step_post_configure(){
	export CFLAGS+=" -w -Wno-error -Wfatal-errors"
}

termux_step_make_install(){
	install -Dm755 -t "${TERMUX_PREFIX}"/src/elinks elinksjs
}
