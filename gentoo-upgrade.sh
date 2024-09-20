#!/bin/bash



#/var/db/pkg/sys-libs/glibc-2.39-r7/PF:glibc-2.39-r7

#/var/db/pkg/games-emulation/pcsx2-1.7.5835/RDEPEND:app-arch/lz4:0/r132= app-arch/zstd:0/1= dev-qt/qtbase:6[concurrent,gui,widgets] dev-qt/qtsvg:6 media-libs/freetype media-libs/libglvnd[X] media-libs/libjpeg-turbo:0/0.2= media-libs/libpng:0/16= media-libs/libsdl2[haptic,joystick] media-libs/libwebp:0/7= media-video/ffmpeg:0/58.60.60= net-libs/libpcap net-misc/curl sys-apps/dbus sys-libs/zlib:0/1= virtual/libudev:0/1= x11-libs/libXrandr media-libs/alsa-lib media-libs/shaderc media-libs/vulkan-loader >=games-emulation/pcsx2_patches-0_p20230917 >=sys-libs/glibc-2.39-r7

# Get rid of -r# level upgrades:
# emerge -pv world > /ramdisk/plan
# grep -v 'ebuild[^]]\+\<U\>[^=]\+[a-z]-\([-._0-9]\+\)-r[0-9][^[]\+\[\1-r[0-9]:'
#
# :%!grep 'U.*-r[0-9]'
# :%s@ \([0-9,.]\+.[MK]iB\|[A-Z_][A-Z_0-9]\+=\).*@@
# :%s@[:][^[:space:]]\+@@g
# :%s@/[0-9][^[:space:]]\+@@g
# :%s@^.ebuild[^]]\+] @@
# :%s@^\(\(\([^-]\+\|-[^0-9]\)\+\).*\)\[\(.*\)$@\2-\4 \1@
# :%!grep '^\(\([^ -]\+\|-[^r]\|-r[^0-9]\)\+\)\(-r[0-9]\+\)\?.* \1-r[0-9]'
# :w
# :!while read -u3 -r p1 p2; do ~drkshadow/code/gentoo-upgrade.sh "$p1" "$p2"; done 3< /ramdisk/plan.txt
#
# xargs --no-run-if-empty -n2 -- ~drkshadow/code/gentoo-upgrade.sh < /ramdisk/plan.txt
# :%s@^@\~drkshadow/code/gentoo-upgrade.sh @

# 1. rename dir
# 2. update /PF
# 3. update RDEPEND for all things


re_esc() {
	sed 's/[/.*]/\\&/g;' <<< "$1"
}

version_upg() {

	if [ -z "$1" ] || [ -z "$2" ]; then
		echo "Use like: $0 sys-libs/glibc-2.39-r9 sys-libs/glibc-2.39-r9"
		exit 1
	fi 1>&2

	if ! [ -d "/var/db/pkg/$1" ] || ! [ -f "/var/db/pkg/$1/PF" ]; then
		echo "\$1 should be a fully versioned package name: sys-libs/glibc-2.39-r7."
		echo "/var/db/pkg/$1 not found."
		exit 1
	fi 1>&2

	pkg_name="${2%%-[0-9]*}"
	oldpkg_name="${1%%-[0-9]*}"
	if [ "$pkg_name" != "$oldpkg_name" ]; then
		echo "New package name ($pkg_name) does not match old package name ($oldpkg_name)."
		echo "I don't support this type of upgrade."
		exit 1
	fi 1>&2

	if [ ! -f "/usr/portage/$pkg_name/${2#*/}.ebuild" ]; then
		echo "The given new version of the package, $2, is not available."
		echo "I expect this to be at /usr/portage/$pkg_name / ${2#*/}.ebuild. ($2)"
		exit 1
	fi 1>&2

	# Might not still exist..
	diff -u "/var/db/pkg/$1/${1#*/}.ebuild" "/usr/portage/$pkg_name/${2#*/}.ebuild"
	echo "Continue? (y/N)"
	read yn
	[ "$yn" = "y" ] || exit 1

	if [ "$1" = "$2" ]; then
		echo "Versions are not changed; done."
		exit
	fi

	find /var/db/pkg/ -name RDEPEND -exec grep --files-with-match "\\<$(sed 's/\./\\./g' <<< "$1")\\>" {} + |
	xargs -d\\n --no-run-if-empty -- sed 's/\<'"$(re_esc "$1")"'\>/'"$(re_esc "$2")"'/' |
		grep '= ' && {
			echo "ERROR: $1 $2 -- got an '= ' where I don't expect it."
			sleep 10
			exit 2
		} 1>&2

	echo "${2#*/}" > "/var/db/pkg/$1/PF"
	mv "/var/db/pkg/$1" "/var/db/pkg/$2"


	# Only updates the version refs, not any attributes, and not any unversioned package references.
	find /var/db/pkg/ \( -name RDEPEND -o -name DEPEND \) -exec grep --files-with-match "\\<$(sed 's/\./\\./g' <<< "$1")\\>" {} + |
	xargs -d\\n --no-run-if-empty -- sed -i 's/\<'"$(re_esc "$1")"'\>/'"$(re_esc "$2")"'/'

}

# Dependency upgrade -- for when things depend on "=pkg-ver" stupidly.
dep_upg() {
	# =dev-lang/perl-5.40* required by (virtual/perl-libnet-3.150.0-r1:0/0::gentoo, ebuild scheduled for merge)
	# =dev-lang/perl-5.40* required by (virtual/perl-Test-Simple-1.302.199:0/0::gentoo, ebuild scheduled for merge)
	# =dev-lang/perl:0/5.38 required by (dev-perl/IO-HTML-1.4.0:0/0::gentoo, installed)
	# =dev-lang/perl:0/5.38 required by (virtual/perl-File-Path-2.180.0-r3:0/0::gentoo, installed)
	#
	# >=media-libs/libvpx-1.10.0:0/8= required by (media-libs/tg_owt-0_pre20230921:0/20230921::gentoo, installed)
	# x11-libs/wxGTK:3.2-gtk3/3.2.4=[X,opengl] required by (media-gfx/hugin-2023.0.0-r1:0/0::gentoo, installed)
	# x11-libs/wxGTK:3.2-gtk3/3.2.4=[X,opengl] required by (media-gfx/hugin-2023.0.0-r1:0/0::gentoo, installed)
	#
	#
	# use this like: 
	# emerge --deep -upv world 2>&1 > /dev/null | ~drkshadow/code/gentoo-upgrade.sh -dep
	#
	
	# Don't remove it from RDEPEND, I think that breaks the dependency tree.
	# Expected: $1 -- package, without version; $2 -- thing depending on package.
	# Remove the *version* from the package dependency, and make it just-the-package.
	# Copy-paste the dependency lines and we'll do that.
	
	# Only installed packages need to be modified; to-be-merged will handle the newer versions.
	grep ', installed)' |
	sed 's/^[[:space:]]\+//; s/, installed.*//;
		s/\(\(-[0-9][-.pr0-9_]*\)\?:0[^[[:space:]]*[=*]\?\|\/[0-9][^[[:space:]]*[=*]\?\|-[0-9][-.pr0-9]*\*\).*required by/ required by/g;
		s/^=//;
		s/\(required by[^:]*\):[^[:space:]]*/\1/;
		s/\(.*\) required by (\(.*\)/\2 \1/;' |
	while read -r pkg dep; do
		dep_name="${dep%%-[0-9]*}"
		dep_name="${dep_name#[^a-z]}"
		dep_name="${dep_name#[^a-z]}"

		# Trim the version
		dep_name="${dep_name%%-[0-9]*}"

		if ! [ -d "/var/db/pkg/$pkg" ]; then
			echo "/var/db/pkg/$pkg -- package not found."
			continue
		fi 1>&2

		echo "Un-version: $dep_name in pkg: $pkg"
		#pkg_name_re="$(re_esc <<< "$pkg_name")
		echo sed 's/[<>=]*\<\('"$(re_esc "$dep_name")"'\)\(-[0-9][-pr0-9._]*\|\/[0-9][-0-9._/=*]\+\|:[0-9][-/.0-9rp]*\)=\?/\1/' "/var/db/pkg/$pkg/"{,[RB]}DEPEND
		cat "/var/db/pkg/$pkg/"{,[RB]}DEPEND
		sed -i 's/[<>=~]*\<\('"$(re_esc "$dep_name")"'\)\(-[0-9][-pr0-9._]*\(:[0-9]\+\(\/[0-9][-0-9._rp]*\)\?\)\?\|\/[0-9][-0-9._/=*]\+\|:[0-9][-/.0-9rp]*\)=\?/\1/' "/var/db/pkg/$pkg/"{,[RB]}DEPEND
	done
	

}

if [ "${1:0:1}" != '-' ]; then
	version_upg "$@"
elif [ "$1" = "-dep" ]; then
	dep_upg "${@:1}"
fi

