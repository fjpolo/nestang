////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	NESrewind.cpp
//
// Project:	NESTang Tang Nano 20k
//
// Purpose:	Main Verilator simulation script for the NESrewind design
//
//	In this script we simulate some reads to a classic NES Gamepad
//
// Creator:	F. J. Polo @GitHub /fjpolo
//
//
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include "VNESrewind.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <math.h>
// random
#include <random>

void tick(int tick_count, VNESrewind *tb, VerilatedVcdC* tfp){
    // The following eval () looks
    // redundant ... many of hours
    // of debugging reveal its not
    tb->eval();
    // dump 2nS before the tick
    if(tfp)
        tfp->dump(tick_count * 10 - 2);
    tb->i_clk = 1;
    tb->eval();
    // tick every 10nS
    if(tfp)
        tfp->dump(tick_count * 10);
    tb->i_clk= 0;
    tb->eval();
    // trailing edge dump
    if(tfp){
        tfp->dump(tick_count * 10 + 5);
        tfp->flush();
    }
}

int main(int argc, char **argv) {
    int last_led;
    unsigned tick_count = 0;

    // Call commandArgs
    Verilated::commandArgs(argc, argv);

    // Instantiate design
    VNESrewind *tb = new VNESrewind;

    // Generate a trace
    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    tb->trace(tfp, 99);
    tfp ->open("NESrewindtrace.vcd ");

 

    tb->i_clk = 0x00;
    tb->i_rst = 0x01;
    for(int k=0; k<(1<<23); k++){
        // Tick()
        tick(++tick_count, tb, tfp);
        // Do something
    }
}
