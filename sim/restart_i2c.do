vcom ../src/i2c_refined.vhd
vcom ../src/i2c_slave.vhd
vcom ../src/clock_delay.vhd
vcom tb_i2c_master.vhd

restart
#vsim -t ns -voptargs="+acc" work.tb_i2c_master

#add wave -hex -r *

run -all