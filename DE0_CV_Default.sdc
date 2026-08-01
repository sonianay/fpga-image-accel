# Primary DE0-CV oscillator.
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]

# The UART receive pin is asynchronous. The first synchronizer stage may go
# metastable; timing starts at the second stage.
set_false_path -from [get_ports {GPIO_0[0]}] -to [get_registers {*serial_meta}]

# RESET_N is an asynchronous board-level reset.
set_false_path -from [get_ports {RESET_N}]

derive_clock_uncertainty
