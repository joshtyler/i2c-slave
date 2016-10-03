# I2C Slave

An implementation of an I2C slave core in VHDL.

This core sends and receives data between a set of 8 bit registers, and an external master.

A read/write region of registers is included for run-time configuration of a hardware design, and a read only region of registers is included intended to report the status.

##Key Implementation Notes
A sample clock is used, this is to debounce SDA and SCL due to their long rise time, and the typically poor hysteresis of FPGA inputs. In addition the sample clock allows robust start/stop condition detection. The deboucning is performed using an external dore [provided here](https://github.com/joshtyler/debounce).

##Testing and Issues
The VHDL core has verified in simulation, and a flexible testbench for I2C testing is provided. Validation testing will be be provided shortly using an example FPGA implementation.

##Documentation
Documentation will be added shortly.

##License
This project is released under the MIT license, see LICENSE.txt.

You may do whatever you please with this code, so long as attribution is given to me.