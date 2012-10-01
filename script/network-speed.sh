#!/bin/bash

#target="ftp://ftp-test.telkomadsl.co.za/500K-test.file"
#size=512000
target="ftp://ftp-test.telkomadsl.co.za/2Meg-test.file"
size=2048000

TIMEFORMAT='%6R'

# Get the file repeatedly
t1=$( { time curl -s "$target" -o download_test.t1 > /dev/null; } 2>&1 )
t2=$( { time curl -s "$target" -o download_test.t2 > /dev/null; } 2>&1 )
t3=$( { time curl -s "$target" -o download_test.t3 > /dev/null; } 2>&1 )
t4=$( { time curl -s "$target" -o download_test.t4 > /dev/null; } 2>&1 )

# Confirm file sizes
s1=$(stat -c%s "download_test.t1")
s2=$(stat -c%s "download_test.t2")
s3=$(stat -c%s "download_test.t3")
s4=$(stat -c%s "download_test.t4")

# Make sure we got down a file
if [ "$s1" -ne "$size" ] ; then
	error="Sizes differ"
fi
if [ "$s2" -ne "$size" ] ; then
	error="Sizes differ"
fi
if [ "$s3" -ne "$size" ] ; then
	error="Sizes differ"
fi
if [ "$s4" -ne "$size" ] ; then
	error="Sizes differ"
fi

# log the result
if [ -z "$error" ] ; then
	echo "bandwidth_throughput $size $t1 $t2 $t3 $t4" | nc ec2-50-19-129-102.compute-1.amazonaws.com 54545 -w1 -u
fi
