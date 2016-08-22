#!/bin/sh

OS=`uname`
CURRENT_OS=`echo "$OS" | tr '[A-Z]' '[a-z]'` # Convert to lowercase
echo $CURRENT_OS | grep "darwin" >/dev/null && CURRENT_OS="macosx" # Convert darwin --> macosx

CURRENT_ARCH=`uname -m`
echo $CURRENT_ARCH | grep "i.86" >/dev/null && CURRENT_ARCH="x86" # Convert iX86 --> x86
echo $CURRENT_ARCH | grep "86pc" >/dev/null && CURRENT_ARCH="x86" # Convert 86pc --> x86
echo $CURRENT_ARCH | grep "amd64" >/dev/null && CURRENT_ARCH="x86_64" # Convert amd64 --> x86_64
echo $CURRENT_ARCH | grep "Power" >/dev/null && CURRENT_ARCH="ppc" # Convert Power Macintosh --> ppc

checksys()
{
    if [ ! -d "./bin/$CURRENT_OS/" -a "$CURRENT_OS" != "linux" ]; then
        echo "Warning: No binaries for \"$CURRENT_OS\" found, trying to default to Linux..."
        CURRENT_OS="linux"
    fi

    if [ ! -d "./bin/$CURRENT_OS/$CURRENT_ARCH/" -a "$CURRENT_ARCH" != "x86" ]; then
        echo "Warning: No binaries for \"$CURRENT_ARCH\" found, trying to default to x86..."
        CURRENT_ARCH="x86"
    fi
}

configure()
{
    echo "Collecting info for this system..."
    
    checksys
    
    echo "Operating system: $CURRENT_OS"   
    echo "CPU Arch: $CURRENT_ARCH"
}

launchfrontend()
{
    DIR="$1"

    MOJOBIN="${DIR}/mojosetup"
    if [ -f ${MOJOBIN} ]; then
        echo trying mojosetup in ${DIR}
        chmod +x $MOJOBIN
        export MOJOSETUP_BASE=$MAKESELF_SHAR
        export MOJOSETUP_GUIPATH=$DIR
        export MOJOSETUP_MARKER=`pwd`/frontendstarted
        `pwd`/$MOJOBIN $ARGS
        RET=$?
        if [ ! -f frontendstarted ]; then
            exit $RET
        fi
    fi
}

ARGS="$*"
configure

touch frontendstarted

launchfrontend bin/$CURRENT_OS/$CURRENT_ARCH;

echo "Error: Couldn't run mojosetup"
exit 1
