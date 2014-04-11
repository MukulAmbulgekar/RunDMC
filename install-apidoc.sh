#!/usr/bin/env bash
#
# Install RunDMC apidoc component.
#
######################################################################

# look for GNU readlink first (OS X, BSD, Solaris)
READLINK=`type -P greadlink`
if [ -z "$READLINK" ]; then
    # if readlink is not GNU-style, setting BASE will fail
    READLINK=`type -P readlink`
fi
BASE=`$READLINK -f $0`
BASE=`dirname $BASE`
if [ -z "$BASE" ]; then
    echo Error initializing environment from $READLINK
    $READLINK --help
    exit 1
fi

set -e
cd $BASE

echo To get started we need your MarkLogic admin login.
read -p "Hostname: [localhost] " HOSTNAME
if [ -z "$HOSTNAME" ]; then
    HOSTNAME=localhost
fi
read -p "Admin user: [admin] " ADMIN_USER
if [ -z "$ADMIN_USER" ]; then
    ADMIN_USER=admin
fi
read -s -p "Admin password: [admin] " ADMIN_PASSWORD
if [ -z "$ADMIN_PASSWORD" ]; then
    ADMIN_PASSWORD=admin
fi
echo
echo

# local customization
if [ -z "$TMPDIR" ]; then
    TMPDIR=/tmp
fi
PACKAGE=apidoc-`date +%s`
ZIP=${TMPDIR}/${PACKAGE}.zip
echo building $ZIP
mkdir -p "${TMPDIR}/${PACKAGE}"
PACKAGE_LOG=${TMPDIR}/$PACKAGE.log
echo logging to $PACKAGE_LOG
cd "${TMPDIR}/${PACKAGE}"
cp -r "${BASE}/apidoc/package/"* .
SERVERS=`echo servers/Default/*.xml`
echo processing $SERVERS
sed -e '1,$s:RUNDMC_ROOT:'"${BASE}"':g' -i'.bak' $SERVERS
zip -qr "$ZIP" * --exclude "*.bak"
echo

# use digest not anyauth
CREDENTIAL="--digest -u "${ADMIN_USER}":"${ADMIN_PASSWORD}
URL="http://"${HOSTNAME}":8002/manage/v2"
echo creating package $PACKAGE at $URL
curl --progress-bar \
    -X POST $CREDENTIAL \
    -H "Content-type: application/zip" \
    --data-binary @"$ZIP" \
    "${URL}/packages?pkgname=${PACKAGE}" \
    | tee -a "$PACKAGE_LOG"
# error detection
grep -q error $PACKAGE_LOG && exit 1 || true
echo

echo installing package $PACKAGE
# Post /dev/null to avoid empty response.
curl --progress-bar \
    -X POST $CREDENTIAL \
    --data-binary @/dev/null \
    -H "Content-type: application/zip" \
    "${URL}/packages/${PACKAGE}/install" \
    | tee -a "$PACKAGE_LOG"
# error detection
grep -q error $PACKAGE_LOG && exit 1 || true
echo

echo cleaning up
rm "$ZIP"
cd "${TMPDIR}" && rm -rf "${PACKAGE}"

echo fixing permissions
find "$BASE" -type f | xargs chmod a+r
find "$BASE" -type d | xargs chmod a+rx

# download raw docs for processing
cd ${TMPDIR}
PUBS=MarkLogic_7_pubs
ZIP="${PUBS}.zip"
echo $ZIP
[ -r "${ZIP}" ] && unzip -qt "${ZIP}" \
    || rm -f "${ZIP}"
if [ -r "${ZIP}" ]; then
    echo "using existing ${ZIP}"
else
    echo "fetching ${ZIP} from marklogic.com"
    curl --remote-name "http://docs.marklogic.com/${ZIP}" \
    | tee -a "$PACKAGE_LOG"
fi
echo unzipping in `pwd`
unzip -qu "${ZIP}"
echo fixing permissions
find "$PUBS" -type f | xargs chmod a+r
find "$PUBS" -type d | xargs chmod a+rx
echo

# process raw docs
VERSION=7.0
PUBS_DIR=`pwd`"/$PUBS"
XSD="${BASE}/apidoc/schema"
URL="http://"${HOSTNAME}":9898/apidoc/setup/build.xqy"
DATA="version=${VERSION}&srcdir=${PUBS_DIR}&help-xsd-dir=${XSD}&clean=yes"
echo Processing... this may take some time.
echo You can watch the ErrorLog.txt for progress.
time curl -D - --max-time 900 -X POST --data "$DATA" $CREDENTIAL "${URL}" \
    | tee -a "$PACKAGE_LOG"
# error detection
grep -q '500 Internal Server Error' $PACKAGE_LOG && exit 1 || true

echo cleaning up
rm -rf "$PUBS"

echo apidoc install ok
echo

# Try to open the new page in a browser
URL="http://"${HOSTNAME}":8011"
# The user may have set BROWSER for us.
# If not, this takes care of most linux desktops, plus OSX.
if [ -z "$BROWSER" ]; then
    BROWSER=$(which xdg-open || which gnome-open || which open)
fi
if [ -n "$BROWSER" ]; then
    exec "$BROWSER" "$URL"
else
    echo "Now open $URL in your favorite browser"
fi

# install-apidoc.sh
