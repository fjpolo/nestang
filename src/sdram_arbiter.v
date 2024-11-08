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

    // 
    input   wire                                loading,
    input   wire    [21:0]                      loader_addr_mem,
    input   wire                                loader_write_mem,
    input   wire    [7:0]                       loader_write_data_mem,
    input   wire    [21:0]                      memory_addr_cpu,
    input   wire                                memory_write_cpu,
    input   wire                                memory_read_cpu,
    input   wire    [31:0]                      rv_wdata,
    input   wire    [7:0]                       memory_dout_cpu,
    output  wire    [7:0]                       memory_din_cpu,


    // WRAM
    input   wire                                i_wram_load_ongoing
);
// From sdram_nes.v or sdram_sim.v
sdram_nes sdram (
    .clk(fclk), .clkref(clkref), .resetn(sys_resetn), .busy(sdram_busy),

    .SDRAM_DQ(IO_sdram_dq), .SDRAM_A(O_sdram_addr), .SDRAM_BA(O_sdram_ba), 
    .SDRAM_nCS(O_sdram_cs_n), .SDRAM_nWE(O_sdram_wen_n), .SDRAM_nRAS(O_sdram_ras_n), 
    .SDRAM_nCAS(O_sdram_cas_n), .SDRAM_CKE(O_sdram_cke), .SDRAM_DQM(O_sdram_dqm), 

    // PPU
    .addrA(memory_addr_ppu), .weA(memory_write_ppu), .dinA(memory_dout_ppu),
    .oeA(memory_read_ppu), .doutA(memory_din_ppu),

    // CPU
    .addrB(loading ? loader_addr_mem : memory_addr_cpu), .weB(loader_write_mem || memory_write_cpu),
    .dinB(loading ? loader_write_data_mem : memory_dout_cpu),
    .oeB(~loading & memory_read_cpu), .doutB(memory_din_cpu),

    // IOSys risc-v softcore
    .rv_addr({rv_addr[20:2], rv_word}), .rv_din(rv_word ? rv_wdata[31:16] : rv_wdata[15:0]), 
    .rv_ds(rv_ds), .rv_dout(rv_dout), .rv_req(rv_req), .rv_req_ack(rv_req_ack), .rv_we(rv_wstrb != 0)
);

endmodule