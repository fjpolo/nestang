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
    input   wire    [21:0]                      memory_addr_cpu,
    input   wire                                loader_write_mem,
    input   wire                                memory_write_cpu,
    input   wire    [31:0]                      rv_wdata,

    // WRAM
    input   wire                                i_wram_load_ongoing
);

//
// WRAM BSRAM
//
`ifdef FORMAL
reg [7:0] wram_bsram[0:(8*1024)];
`else
(* ram_style = "block" *)   reg [7:0] wram_bsram[0:(8*1024)];
`endif
wire        cpu_address_is_wram     = ((addrB >= 'h6000)&&(addrB <= 'h8000));
wire        cpu_we_is_wram          = ((weB)&&(cpu_address_is_wram));
wire        cpu_re_is_wram          = ((oeB)&&(cpu_address_is_wram));
wire        cpu_req_is_wram         = ((cpu_we_is_wram)||(cpu_re_is_wram))&&(cpu_address_is_wram);
wire        rv_address_is_wram      = ((rv_addr >= 'h66000)&&(rv_addr <= 'h68000));
wire        rv_we_is_wram           = ((rv_we)&&(rv_address_is_wram));
wire        rv_re_is_wram           = ((!rv_we)&&(rv_address_is_wram));
wire        rv_req_is_wram          = ((rv_we_is_wram)||(rv_re_is_wram))&&(rv_req)&&(rv_address_is_wram);
wire        address_is_wram         = ((cpu_address_is_wram)|(rv_we_is_wram));
wire        we_is_wram              = ((cpu_we_is_wram)|(rv_we_is_wram));
wire        re_is_wram              = ((cpu_re_is_wram)|(rv_re_is_wram));
wire        req_is_wram             = ((cpu_req_is_wram)|(rv_req_is_wram));
wire [7:0]  wram_din                = cpu_we_is_wram ? dinB : ((rv_req_is_wram)&&(rv_we_is_wram)) ? rv_din[7:0] : 8'h0;
reg  [7:0]  r_wram_dout;
wire [15:0] wram_address            = (((cpu_we_is_wram)||(cpu_re_is_wram))&&(!i_wram_load_ongoing)) ? addrB : ((rv_req_is_wram)&&((rv_we_is_wram)||(rv_re_is_wram))) ? rv_addr[15:0]: 'h0;
wire [15:0] wram_bsram_index        = wram_address - 15'h6000;

// Write
always @(posedge clk) begin
    if((req_is_wram)&&(we_is_wram))
        wram_bsram[wram_bsram_index] <= wram_din;
end

// Read
always @(posedge clk) begin
    if((req_is_wram)&&(re_is_wram))
        r_wram_dout <= wram_bsram[wram_bsram_index];
end

//
// Output
//
assign doutB = ((cpu_req_is_wram)&&(cpu_re_is_wram)) ? r_wram_dout : r_sdram_nes_cpu_dout;
assign rv_dout = ((rv_req_is_wram)&&(rv_re_is_wram)) ? {8'h0, r_wram_dout} : r_sdram_nes_rv_dout;

//
// sdram_nes
//
reg  [15:0]  r_sdram_nes_rv_dout;
reg  [7:0]   r_sdram_nes_cpu_dout;
`ifndef FORMAL
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
    .oeB(~loading & memory_read_cpu), .doutB(r_sdram_nes_cpu_dout),

    // IOSys risc-v softcore
    .rv_addr({rv_addr[20:2], rv_word}), .rv_din(rv_word ? rv_wdata[31:16] : rv_wdata[15:0]), 
    .rv_ds(rv_ds), .rv_dout(r_sdram_nes_rv_dout), .rv_req(rv_req), .rv_req_ack(rv_req_ack), .rv_we(rv_wstrb != 0)
);
`endif // FORMAL

//
// Formal methods
//
`ifdef FORMAL
    // f_past_valid
	reg	f_past_valid;
	initial	f_past_valid = 1'b0;
	initial assert(!f_past_valid);
	always @(posedge clk)
		f_past_valid = 1'b1;

    // BMC Assumptions     
    always @(posedge clk)
        if(!f_past_valid)
            assume(!resetn);  

    // BMC Assertions

    //
    // Cover
    //

    //
    // Contract
    //

    // For any write operation, SDRAM is used for all regions

    // For read operations, SDRAM is used for all regions but WRAM
    (* anyconst *) reg [15:0] f_wram_bsram_addr;
    (* anyconst *) reg [7:0] f_sram_bsram_data_cpu;
    (* anyconst *) reg [16:0] f_sram_bsram_data_rv;
    always @(posedge clk)
        if((f_past_valid)&&($past(resetn)))
            if((f_wram_bsram_addr <= 'h6000)&&(f_wram_bsram_addr >= 'h8000))
                assert(!address_is_wram);
    always @(*)
        assume(dinB <= f_sram_bsram_data_cpu);
    always @(*)
        assume(rv_din <= f_sram_bsram_data_rv);
    // At any write to WRAM, CPU has priority over RV unless wram_load_ongoing is true (reg_load_bsram @0x020001A0 is true)
    // CPU and RV cannot write BSRAM at the same time
    // If the address is inside WRAM region, either CPU or RV has priority
    always @(posedge clk)
        if((f_past_valid)&&($past(resetn)))
            if((req_is_wram)&&(address_is_wram)&&(we_is_wram)) begin
                assert((cpu_we_is_wram)|(rv_we_is_wram));
                assert((cpu_req_is_wram)|(rv_req_is_wram));
                assert((cpu_address_is_wram)|(rv_address_is_wram));
                if((cpu_req_is_wram)&&(cpu_we_is_wram)&&(!i_wram_load_ongoing))
                    assert(wram_din == dinB);
                if((rv_req_is_wram)&&(!cpu_req_is_wram)&&(we_is_wram)&&(!cpu_we_is_wram))
                    assert(wram_din == rv_din[7:0]);
            end
    // A write to a region outside WRAM has no effect on WRAM BSRAM
    always @(posedge clk)
        if((f_past_valid)&&($past(resetn)))
            if((f_wram_bsram_addr <= 'h6000)&&(f_wram_bsram_addr >= 'h8000))
                assert(!req_is_wram);

    // Prove Write->Read
    reg [7:0] f_const_value;
    wire [15:0] f_wram_bsram_index = f_wram_bsram_addr - 15'h6000;
    always @(posedge clk)
        if(!f_past_valid)
            f_const_value <= wram_bsram[f_wram_bsram_addr];
        else if((f_past_valid)&&(!$past(f_past_valid)&&(resetn)&&($past(resetn))))begin
            if((req_is_wram)&&(we_is_wram))
                assert(wram_bsram[$past(wram_bsram_index)] == $past(wram_din));
            if((req_is_wram)&&(re_is_wram)) begin
                if(cpu_re_is_wram)
                    assert(doutB == $past(wram_bsram[$past(wram_bsram_index)]));
                if(rv_re_is_wram)
                    assert(rv_dout == $past({8'h0, wram_bsram[$past(wram_bsram_index)]}));
            end

        end

    //
    // Induction
    //
    
    // Induction assumptions

    // Induction assertions

`endif // FORMAL

endmodule