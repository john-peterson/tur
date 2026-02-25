TERMUX_PKG_HOMEPAGE=https://www.mesa3d.org
TERMUX_PKG_DESCRIPTION=" mesa tools for on device build  "
TERMUX_PKG_LICENSE="MIT"
TERMUX_PKG_LICENSE_FILE="docs/license.rst"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="25.3.5"
TERMUX_PKG_SRCURL=https://archive.mesa3d.org/mesa-${TERMUX_PKG_VERSION}.tar.xz
TERMUX_PKG_SHA256=be472413475082df945e0f9be34f5af008baa03eb357e067ce5a611a2d44c44b
TERMUX_PKG_DEPENDS="libandroid-shmem, libc++, libdrm, libllvm (<< $TERMUX_LLVM_NEXT_MAJOR_VERSION),  libx11, libxext, libxfixes, libxshmfence, libxxf86vm, ncurses, vulkan-loader, zlib, zstd"
TERMUX_PKG_SUGGESTS="mesa-dev"
TERMUX_PKG_BUILD_DEPENDS="libclc, libxrandr, llvm, llvm-tools, mlir, spirv-tools, xorgproto"
TERMUX_PKG_BREAKS="osmesa, osmesa-demos"
TERMUX_PKG_CONFLICTS="libmesa, ndk-sysroot (<= 25b), osmesa"
TERMUX_PKG_REPLACES="libmesa, osmesa"

TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
--cmake-prefix-path $TERMUX_PREFIX
-Dxmlconfig=disabled

-D mesa-clc=enabled
-D install-mesa-clc=true
-D tools=panfrost,drm-shim

-D platforms=
-D video-codecs=
-D gallium-drivers=
-D vulkan-drivers=
-D build-tests=false
"

# the symbols are too big on device 
# -D buildtype=debug

# -Dllvm=enabled
# -Dshared-llvm=enabled

# -Dgallium-rusticl=false
# -Dglvnd=disabled
# -Dgbm=enabled
# -Dopengl=false
# -Degl=disabled
# -Dgles1=disabled
# -Dgles2=disabled
# -Dglx=disabled


termux_step_post_get_source() {
	# Do not use meson wrap projects
	rm -rf subprojects
}

termux_step_pre_configure() {
	if [ "$TERMUX_PKG_API_LEVEL" -lt 29 ]; then
		# ELF TLS is supported starting with API level 29.
		patch --silent -p1 < "$TERMUX_PKG_BUILDER_DIR/0011-lld-undefined-version.diff"
	fi

	return

	termux_setup_cmake
	if [[ "${TERMUX_ON_DEVICE_BUILD}" == "false" ]]; then
		export BINDGEN_EXTRA_CLANG_ARGS="--sysroot ${TERMUX_STANDALONE_TOOLCHAIN}/sysroot"
		case "${TERMUX_ARCH}" in
		arm) BINDGEN_EXTRA_CLANG_ARGS+=" --target=arm-linux-androideabi${TERMUX_PKG_API_LEVEL}" ;;
		*) BINDGEN_EXTRA_CLANG_ARGS+=" --target=${TERMUX_ARCH}-linux-android${TERMUX_PKG_API_LEVEL}" ;;
		esac
	fi

	CPPFLAGS+=" -D__USE_GNU"
	LDFLAGS+=" -landroid-shmem"

	_WRAPPER_BIN=$TERMUX_PKG_BUILDDIR/_wrapper/bin
	mkdir -p $_WRAPPER_BIN
	if [ "$TERMUX_ON_DEVICE_BUILD" = "false" ]; then
		sed 's|@CMAKE@|'"$(command -v cmake)"'|g' \
			$TERMUX_PKG_BUILDER_DIR/cmake-wrapper.in \
			> $_WRAPPER_BIN/cmake
		chmod 0700 $_WRAPPER_BIN/cmake
		termux_setup_wayland_cross_pkg_config_wrapper
	fi
	export LLVM_CONFIG="${TERMUX_PREFIX}/bin/llvm-config"
	export PATH="${_WRAPPER_BIN}:${CARGO_HOME}/bin:${PATH}"
}

termux_step_post_configure() {
	rm -f $_WRAPPER_BIN/cmake
}

termux_step_post_make_install() {
	unset BINDGEN_EXTRA_CLANG_ARGS LLVM_CONFIG
}

termux_step_post_massage(){
	for f in $(find $TERMUX_PKG_BUILDDIR -type -f -executable); do
		cp -v $f bin/
	done
}
