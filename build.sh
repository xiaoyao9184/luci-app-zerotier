#!/bin/bash 

current_script_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
parent_folder_path="$(dirname $current_script_path)"
parent_folder_name="$(basename $current_script_path)"
git_short_hash="$(git rev-parse --short HEAD)"
git_remote_url="$(git config --get remote.origin.url)"

IPK_PACKAGE=${IPK_PACKAGE:=$parent_folder_name}
IPK_VERSION=${IPK_VERSION:=$git_short_hash}
IPK_DEPENDS=${IPK_DEPENDS:=}
IPK_MAINTAINER=${IPK_MAINTAINER:=}
IPK_DESCRIPTION=${IPK_DESCRIPTION:=}
IPK_SOURCE=${IPK_SOURCE:=$git_remote_url}

OPENWRT_BRANCH=${OPENWRT_BRANCH:=openwrt-18.06}
BUILD_PATH_IPKG=/tmp/$IPK_PACKAGE
BUILD_PATH_DATA=$BUILD_PATH_IPKG/$IPK_VERSION
BUILD_PATH_CONTROL=$BUILD_PATH_DATA/CONTROL
BUILD_PATH_I18N=$BUILD_PATH_DATA/usr/lib/lua/luci/i18n
LUCI_I18N_WORKSPACE=$BUILD_PATH_IPKG/po2lmo
IPKG_WORKSPACE=$BUILD_PATH_IPKG/ipkg

echo "clear build path"
rm -rdf $BUILD_PATH_IPKG

echo "copy file to data path"
mkdir -p $BUILD_PATH_DATA/usr/lib/lua/luci
[ -d $current_script_path/luasrc ] && cp -R $current_script_path/luasrc/* $BUILD_PATH_DATA/usr/lib/lua/luci/
[ -d $current_script_path/root ] && cp -R $current_script_path/root/* $BUILD_PATH_DATA/
chmod +x $BUILD_PATH_DATA/etc/init.d/* >/dev/null 2>&1
chmod +x $BUILD_PATH_DATA/etc/uci-defaults/* >/dev/null 2>&1

echo "create control file"
mkdir -p $BUILD_PATH_CONTROL
if [ -f $current_script_path/control ]; then
    cp $current_script_path/control $BUILD_PATH_CONTROL/control
else
    cat >$BUILD_PATH_CONTROL/control <<EOF
Package: ${IPK_PACKAGE}
Version: ${IPK_VERSION}
Depends: ${IPK_DEPENDS}
Architecture: all
Maintainer: ${IPK_MAINTAINER}
Section: luci
Priority: optional
Description: ${IPK_DESCRIPTION}
Source: ${IPK_SOURCE}
EOF
fi

if [ -d $current_script_path/po ]; then
    echo "build i18n file"
    mkdir -p $LUCI_I18N_WORKSPACE
    sudo -E apt-get -y install gcc make wget && \
    wget -O $LUCI_I18N_WORKSPACE/Makefile https://raw.githubusercontent.com/openwrt/luci/$OPENWRT_BRANCH/modules/luci-base/src/Makefile && \
    wget -O $LUCI_I18N_WORKSPACE/po2lmo.c https://raw.githubusercontent.com/openwrt/luci/$OPENWRT_BRANCH/modules/luci-base/src/po2lmo.c && \
    wget -O $LUCI_I18N_WORKSPACE/template_lmo.h https://raw.githubusercontent.com/openwrt/luci/$OPENWRT_BRANCH/modules/luci-base/src/template_lmo.h && \
    wget -O $LUCI_I18N_WORKSPACE/template_lmo.c https://raw.githubusercontent.com/openwrt/luci/$OPENWRT_BRANCH/modules/luci-base/src/template_lmo.c && \
    cd $LUCI_I18N_WORKSPACE && \
    make po2lmo

    mkdir -p $BUILD_PATH_I18N
    PO_DIRS="$current_script_path/po/*/"
    for i18n_path in $PO_DIRS; do
        i18n_lang="$(basename $i18n_path)"
        for i18n_file in $i18n_path/*.po; do
            i18n_file="$(realpath $i18n_file)"
            i18n_name="$(basename $i18n_file)"
            i18n_name="${i18n_name%.*}"
            echo "build i18n $i18n_name.$i18n_lang.lmo"
            ./po2lmo $i18n_file $BUILD_PATH_I18N/$i18n_name.$i18n_lang.lmo
        done
    done
fi


echo "build ipk"
mkdir -p $IPKG_WORKSPACE
wget -O $IPKG_WORKSPACE/ipkg-build https://raw.githubusercontent.com/openwrt/openwrt/$OPENWRT_BRANCH/scripts/ipkg-build && \
    chmod +x $IPKG_WORKSPACE/ipkg-build && \
    $IPKG_WORKSPACE/ipkg-build -o root -g root $BUILD_PATH_DATA $BUILD_PATH_IPKG