/******************************************************************
/*  SDRAM arbiter
/*  @fjpolo, 2024.11
/*
/*  Problem: NES CPU and RV need to access a shared memory space: WRAM, with the current mapping:
/*      - NES CPU: 16'h6000-16'h8000
/*      - RV: 22'h66000-22'h68000 mapped to (22'h66000>1'b1)-(22'h58000>1'b1) in this module
/*  
/*  This is a quick and dirty solution where a 8kB of BSRAM are used as a shared memory space for any access to this address region.
/* sdram_nes module is not modified nor verified here.
/*  
/*  These are the properties that need to be formally proved:
/*      - For any write operation, SDRAM is used for all regions
/*      - For read operations, SDRAM is used for all regions but WRAM
/*      - At any write to WRAM, CPU has priority over RV unless wram_load_ongoing is true (reg_load_bsram @0x020001A0 is true)
/*      - CPU and RV cannot write BSRAM at the same time
/*      - If the address is inside WRAM region, either CPU or RV has priority
/*      - A write to a region outside WRAM has no effect on WRAM BSRAM
/*
/*  Some assumptions:
/*      - rv_req_ack comes from sdram_nes module, we only replace wv_dout
*******************************************************************/
//`default_nettype none

module sdram_arbiter #(
    // Clock frequency, max 66.7Mhz with current set of T_xx/CAS parameters.
    parameter         FREQ = 64_800_000,

    parameter [4:0]   CAS  = 4'd2,     // 2/3 cycles, set in mode register
    parameter [4:0]   T_WR = 4'd2,     // 2 cycles, write recovery
    parameter [4:0]   T_MRD= 4'd2,     // 2 cycles, mode register set
    parameter [4:0]   T_RP = 4'd2,     // 15ns, precharge to active
    parameter [4:0]   T_RCD= 4'd2,     // 15ns, active to r/w
    parameter [4:0]   T_RC = 4'd6      // 63ns, ref/active to ref/active
) 
(    
	inout   reg     [SDRAM_DATA_WIDTH-1:0]      SDRAM_DQ,   // 16 bit bidirectional data bus
	output  wire    [SDRAM_ROW_WIDTH-1:0]       SDRAM_A,    // 13 bit multiplexed address bus
	output  reg     [SDRAM_DATA_WIDTH/8-1:0]    SDRAM_DQM,  // two byte masks
	output  reg     [1:0]                       SDRAM_BA,   // two banks
	output  wire                                SDRAM_nCS,  // a single chip select
	output  wire                                SDRAM_nWE,  // write enable
	output  wire                                SDRAM_nRAS, // row address select
	output  wire                                SDRAM_nCAS, // columns address select
    output  wire                                SDRAM_CKE,

	// cpu/chipset interface
	input   wire                                clk,        // sdram clock
	input   wire                                resetn,
    input   wire                                clkref,
    output  reg                                 busy,

	input   wire    [21:0]                      addrA,      // 4MB, bank 0/1
	input   wire                                weA,        // ppu requests write
	input   wire    [7:0]                       dinA,       // data input from cpu
	input   wire                                oeA,        // ppu requests data
	output  reg     [7:0]                       doutA,      // data output to cpu

	input   wire    [21:0]                      addrB,      // 4MB, bank 0/1
	input   wire                                weB,        // cpu requests write
	input   wire    [7:0]                       dinB,       // data input from ppu
	input   wire                                oeB,        // cpu requests data
	output  reg     [7:0]                       doutB,      // data output to ppu

    // RISC-V softcore
    input   wire    [22:0]      	            rv_addr,      // 2MB RV memory space, bank 2
    input   wire                                rv_word,
    input   wire    [15:0]      	            rv_din,       // 16-bit accesses
    input   wire    [1:0]       	            rv_ds,
    output  reg     [15:0]      	            rv_dout,
    input   wire                                rv_req,
    output  reg                                 rv_req_ack,   // ready for new requests. read data available on NEXT mclk
    input   wire                                rv_we,

    // WRAM
    input   wire                                i_wram_load_ongoing
);
// From sdram_nes.v or sdram_sim.v
reg [7:0] r_dout_cpu;
reg [16:0] r_dout_rv;
sdram_nes sdram (
    .clk(clk), .clkref(clkref), .resetn(resetn), .busy(busy),

    .SDRAM_DQ(SDRAM_DQ), .SDRAM_A(SDRAM_A), .SDRAM_BA(SDRAM_BA), 
    .SDRAM_nCS(SDRAM_nCS), .SDRAM_nWE(SDRAM_nWE), .SDRAM_nRAS(SDRAM_nRAS), 
    .SDRAM_nCAS(SDRAM_nCAS), .SDRAM_CKE(SDRAM_CKE), .SDRAM_DQM(SDRAM_DQM), 

    // PPU
    .addrA(addrA), .weA(weA), .dinA(dinA),
    .oeA(oeA), .doutA(doutA),

    // CPU
    .addrB(addrB), .weB(weB),
    .dinB(dinB),
    .oeB(oeB),

    // IOSys risc-v softcore
    .rv_addr({rv_addr[20:2], rv_word}), .rv_din(rv_din), 
    .rv_ds(rv_ds), .rv_dout(rv_dout), .rv_req(rv_req), .rv_req_ack(rv_req_ack), .rv_we(rv_we)
);

endmodule