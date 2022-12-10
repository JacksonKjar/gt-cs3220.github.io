#!/bin/bash

cd $SLURM_SUBMIT_DIR
#module load anaconda3
#Pynq 2.7 moves the notebook execution underneath a venv execution environment
#sudo XILINX_XRT=/usr /usr/local/share/pynq-venv/bin/jupyter notebook --no-browser --allow-root --ip=${HOSTNAME} --port=52242
(sudo XILINX_XRT=/usr /usr/local/share/pynq-venv/bin/jupyter notebook --no-browser --allow-root --ip=${HOSTNAME} --port=52242 &> /dev/null ) &
sleep 3600

