# test_apu.py

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
from cocotb.triggers import RisingEdge


@cocotb.test()
async def apu_simple_test(dut):
    """Try accessing the design."""

    # Set initial values
    dut.phi1 = 0
    dut.aclk1
    dut.aclk1_d
    dut.reset = 0
    dut.cold_reset = 0
    dut.allow_us = 0
    dut.write
    dut.LenCtr_Clock
    dut.LinCtr_Clock
    dut.Enabled
    dut.Addr      # 2bit
    dut.DIN       # 8bit
    dut.lc_load   # 8bit
    # outputs
    # [3:0] dut.Sample
    # dut.IsNonZero

    # Create a 10us period clock on port clk
    clock = Clock(dut.clk, 10, units="us")
    # Start the clock. Start it low to avoid issues on the first RisingEdge
    cocotb.start_soon(clock.start(start_high=False))