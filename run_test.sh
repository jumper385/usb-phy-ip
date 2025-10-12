#!/bin/bash
# sample
# <path_to_sh>.sh <path_to_manifest> <tb_top> <optional_time_with_units>
# ./run_test.sh usb_phy.tb_manifest usb_phy_tb 100us

# gets the file manifest
MANIFEST_FILE=$1

if [ ! -f $MANIFEST_FILE ]; then
    echo "Manifest file $MANIFEST_FILE does not exist"
    exit 1
fi

# gets the top level entity name 
TOP_ENTITY_NAME=$2

if [ -z "$TOP_ENTITY_NAME" ]; then
    echo "Top entity name not provided"
    exit 1
fi

# optional sim time
SIM_TIME=${3:-10us}

# remove .cf and .vcd and .ghw files if they exist
rm -f *.cf
rm -f *.vcd
rm -f *.ghw

# ghdl -a
ghdl -a --std=08 -fsynopsys -frelaxed-rules --work=work $(cat $MANIFEST_FILE)
if [ $? -ne 0 ]; then
    echo "Error during analysis"
    exit 1
fi

# ghdl -e
ghdl -e --std=08 -fsynopsys -frelaxed-rules --work=work $TOP_ENTITY_NAME
if [ $? -ne 0 ]; then
    echo "Error during elaboration"
    exit 1
fi

# ghdl -r --waves
ghdl -r --std=08 -fsynopsys -frelaxed-rules --work=work $TOP_ENTITY_NAME --wave=$TOP_ENTITY_NAME.ghw --stop-time=$SIM_TIME
if [ $? -ne 0 ]; then
    echo "Error during simulation"
    exit 1
fi