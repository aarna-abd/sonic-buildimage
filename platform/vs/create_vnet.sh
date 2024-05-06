#!/bin/bash -e

usage() {
	echo "Usage: $0 [-n <int>] swname" 1>&2
    exit 1
}

SERVERS=2

while getopts ":n:" opt; do
    case $opt in
        n)
            SERVERS=$((OPTARG))
            ;;
        *)
            usage
			;;
    esac
done

shift $((OPTIND-1))

SWNAME=$1

pid=$(docker inspect --format '{{.State.Pid}}' $SWNAME)

echo Seting up servers


eth_index=1

for srv in `seq 0 $((SERVERS-1))`; do

    SRV="$SWNAME-srv$srv"

    NSS="ip netns exec $SRV"

    ip netns add $SRV

    $NSS ip addr add 127.0.0.1/8 dev lo
    $NSS ip addr add ::1/128 dev lo
    $NSS ip link set dev lo up

    # add virtual link between neighbor and the virtual switch docker

    IF1="eth${eth_index}"
    eth_index=$((eth_index+1))
    IF2="eth${eth_index}"
    eth_index=$((eth_index+1))

    ip link add ${SRV}eth0 type veth peer name $SWNAME-$IF1
    ip link set ${SRV}eth0 netns $SRV
    ip link set $SWNAME-$IF1 netns ${pid}
    nsenter -t $pid -n ip link set dev $SWNAME-$IF1 name $IF1

    ip link add ${SRV}eth1 type veth peer name $SWNAME-$IF2
    ip link set ${SRV}eth1 netns $SRV
    ip link set $SWNAME-$IF2 netns ${pid}
    nsenter -t $pid -n ip link set dev $SWNAME-$IF2 name $IF2

    echo "Bring ${SRV}eth0 up"
    $NSS ip link set dev ${SRV}eth0 name eth0
    $NSS ip link set dev eth0 up


    echo "Bring ${SRV}eth1 up"
    $NSS ip link set dev ${SRV}eth1 name eth1
    $NSS ip link set dev eth1 up

    echo "Bring $IF up in the virtual switch docker"
    nsenter -t $pid -n ip link set dev $IF1 up
    nsenter -t $pid -n ip link set dev $IF2 up


done
