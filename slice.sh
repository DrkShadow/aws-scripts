#!/bin/sh


# Hints: 69 1634
#
# trying to carve up a mis-rebuilt RAID and replace the blocks in a different order,
# using snapshots underneath, and linear combination of sliced pieces

strt=$1
end=$2
shift 2

if [ "$strt" != "${strt##*[^0-9]}" ] || [ "$end" != "${end##*[^0-9]}" ]; then
	echo "Start and end have to be numbers." 1>&2
	exit 1
fi

for dev in "$@"; do

	i=0
	while [ -e /dev/mapper/slice$i ]; do i=$(( $i + 1 )); done

	dsize="$(blockdev --getsz "$dev")"

	echo "0 $(( $dsize - $strt - $end )) linear $dev $strt" |
		dmsetup create slice$i
done
