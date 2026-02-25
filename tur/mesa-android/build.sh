TERMUX_PKG_HOMEPAGE=https://www.mesa3d.org
TERMUX_PKG_DESCRIPTION="mesa android platform"
TERMUX_PKG_LICENSE="MIT"
TERMUX_PKG_LICENSE_FILE="docs/license.rst"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="25.3.5"
# TERMUX_PKG_SRCURL=https://archive.mesa3d.org/mesa-${TERMUX_PKG_VERSION}.tar.xz
# TERMUX_PKG_SHA256=be472413475082df945e0f9be34f5af008baa03eb357e067ce5a611a2d44c44b
# TERMUX_PKG_SRCURL=git+https://gitlab.freedesktop.org/mesa/mesa
# TERMUX_PKG_GIT_BRANCH=main
TERMUX_PKG_SRCURL=git+https://github.com/john-peterson/mesa
TERMUX_PKG_GIT_BRANCH=build/android
TERMUX_PKG_BREAKS="osmesa, osmesa-demos"
TERMUX_PKG_CONFLICTS="libmesa, ndk-sysroot (<= 25b), osmesa, libglvnd"
TERMUX_PKG_REPLACES="libmesa, osmesa"
TERMUX_PKG_SUGGESTS="mesa-dev"

TERMUX_PKG_DEPENDS="libandroid-shmem, libc++, libdrm,  libllvm (<< $TERMUX_LLVM_NEXT_MAJOR_VERSION),  libx11, libxext, libxfixes, libxshmfence, libxxf86vm, ncurses, vulkan-loader, zlib, zstd"
TERMUX_PKG_BUILD_DEPENDS=" libxrandr, llvm, llvm-tools, mlir, spirv-tools, xorgproto"

# libclc is only required for panfrost
# TERMUX_PKG_DEPENDS+=", libclc"

# they claim  stub build still work on device without any libs for build 
# TERMUX_PKG_DEPENDS+=", aosp-libs"

TERMUX_PKG_API_LEVEL=33
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
--cmake-prefix-path $TERMUX_PREFIX
-Dxmlconfig=disabled
-Dglvnd=disabled
-Dllvm=enabled
-Dshared-llvm=enabled

-D mesa-clc=system
-Dprecomp-compiler=system
-D build-tests=true

-Dgallium-drivers=softpipe,zink
-D vulkan-drivers=
-Dgles2=enabled
-Degl=enabled
-D glx=disabled

-Degl-native-platform=android
-Dplatforms=android,x11,xcb,surfaceless,device

-Dplatform-sdk-version=$TERMUX_PKG_API_LEVEL
-D android-stub=true
"

# -D android-libbacktrace=disabled
# -D android-strict=false
# -Dgallium-drivers=llvmpipe,panfrost,softpipe,virgl,zink
# -D vulkan-drivers=panfrost,broadcom,freedreno,gfxstream,virtio,swrast
# -Dxmlconfig=disabled
# -Dglx=dri
# -Dgbm=enabled
# -Dopengl=true
# -Dgles1=disabled

# build host compilers first 
termux_step_host_build() {
test $TERMUX_ON_DEVICE_BUILD && return
mkdir -vp ~/bin
test -f ~/bin/mesa_clc && return

shopt -s expand_aliases
alias i="sudo apt -qy install"
alias p="pip install --break-system-packages"

i clang-21 libclang-21-dev libclang-cpp-21-dev libclc-21-dev libdrm-dev   llvm-21-dev libllvmspirvlib-21-dev libzstd-dev libpolly-21-dev
# libglvnd-dev should not be necessary 
i glslang-tools bison flex
p packaging mako

cd
git clone --depth=10 https://gitlab.freedesktop.org/mesa/mesa || true
cd ~/mesa
args=(
-D mesa-clc=enabled
-D install-mesa-clc=true
-D precomp-compiler=enabled
-D install-precomp-compiler=true
-D tools=panfrost
-D buildtype=debug

-D build-tests=false
-D enable-glcpp-tests=false
-D gallium-rusticl=false
-Dglvnd=disabled
-D gallium-drivers=
-D platforms=
-D video-codecs=
-D vulkan-drivers=
)
meson setup out --reconfigure ${args[*]}
meson compile -C out
cp ./out/src/compiler/clc/mesa_clc ~/bin/
cp ./out/src/compiler/spirv/vtn_bindgen2 ~/bin/
cp ./out/src/panfrost/clc/panfrost_compile ~/bin/
}

termux_step_post_get_source() {
	# Do not use meson wrap projects
	rm -rf subprojects
}

termux_step_pre_configure() {
	if [ "$TERMUX_PKG_API_LEVEL" -lt 29 ]; then
		# ELF TLS is supported starting with API level 29.
		patch  -p1 < "$TERMUX_PKG_BUILDER_DIR/0011-lld-undefined-version.diff"
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

	# CPPFLAGS+=" -D__USE_GNU"
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
	# Avoid hard links
	local f1
	for f1 in $TERMUX_PREFIX/lib/dri/*; do
		if [ ! -f "${f1}" ]; then
			continue
		fi
		local f2
		for f2 in $TERMUX_PREFIX/lib/dri/*; do
			if [ -f "${f2}" ] && [ "${f1}" != "${f2}" ]; then
				local s1=$(stat -c "%i" "${f1}")
				local s2=$(stat -c "%i" "${f2}")
				if [ "${s1}" = "${s2}" ]; then
					ln -sfr "${f1}" "${f2}"
				fi
			fi
		done
	done

	# Create symlinks
	# ln -sf libEGL_mesa.so ${TERMUX_PREFIX}/lib/libEGL_mesa.so.0
	# ln -sf libGLX_mesa.so ${TERMUX_PREFIX}/lib/libGLX_mesa.so.0

	unset BINDGEN_EXTRA_CLANG_ARGS LLVM_CONFIG
}

termux_step_post_massage(){
	ln -s libEGL.so /lib/libEGL.so.0 || true

}
