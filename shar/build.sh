#!/bin/sh

archs="x86 x86_64"
has_mojo=1
dir=`dirname $0`

for arch in $archs; do
    mkdir -p mojosetup/bin/linux/$arch/guis/
    if [ ! -e mojosetup/bin/linux/$arch/mojosetup ]; then
        has_mojo=0
        echo "***"
        echo "You do not have the compiled mojo files for architecture $arch on linux setup"
        echo "You first need to copy the mojosetup bin and guis into the $dir/mojosetup directory"
        echo "The mojosetup binary dir: $dir/mojosetup/bin/linux/$arch/"
        echo "The mojo gui \".so\" dir: $dir/mojosetup/bin/linux/$arch/guis/"
        echo "***"
    fi
done

if [ $has_mojo -eq 0 ]; then
    exit 1
fi

cp startmojo.sh $dir/mojosetup
name="Mojo Setup"

./makeself.sh --nox11 \
    --header $dir/mojo-header.sh \
    $dir/mojosetup \
    mojosetup.sh \
    "$name" \
    ./startmojo.sh

