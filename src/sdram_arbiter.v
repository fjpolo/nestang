/******************************************************************
/*  SDRAM arbiter
/*  @fjpolo, 2024.11
/*
/*  Problem: NES CPU and RV need to access a shared memory space: WRAM, 
/* with the current mapping:
/*      - NES CPU: 16'h6000-16'h8000
/*      - RV: 22'h66000-22'h68000 mapped to (22'h66000>1'b1)-(22'h58000>1'b1) 
/* in this module
/*  
/*  This is a quick and dirty solution where a 8kB of BSRAM are used as a 
/* shared memory space for any access to this address region.
/*
/* sdram_nes module is not modified nor verified here.
/*  
/*  These are the properties that need to be formally proved:
/*      - For any write operation, SDRAM is used for all regions
/*      - For read operations, SDRAM is used for all regions but WRAM
/*      - At any write to WRAM, CPU has priority over RV unless wram_load_ongoing 
/*       is true (reg_load_bsram @0x020001A0 is true)
/*      - CPU and RV cannot write BSRAM at the same time
/*      - A write to a region outside WRAM has no effect on WRAM BSRAM
/*
/*  Some assumptions:
/*      - rv_req_ack comes from sdram_nes module, we only replace wv_dout
*******************************************************************/
// `default_nettype none
`ifndef FORMAL
import configPackage::*;
`else
    parameter SDRAM_DATA_WIDTH = 32;     // 4 bytes per word
    parameter SDRAM_ROW_WIDTH = 11;      // 2K rows
    parameter SDRAM_COL_WIDTH = 8;       // 256 cols
    parameter SDRAM_BANK_WIDTH = 2;      // 4 banks
`endif

module sdram_arbiter(    
    input   wire                                i_clk,
    input   wire                                i_clkref,
    input   wire                                i_resetn,
    output  wire                                o_sdram_busy,

    inout   wire    [(SDRAM_DATA_WIDTH-1):0]    io_sdram_dq,
    output  wire    [(SDRAM_DATA_WIDTH-1):0]    o_sdram_addr,
    output  wire    [1:0]                       o_sdram_ba,
    output  wire                                o_sdram_cs_n,
    output  wire                                o_sdram_wen_n,
    output  wire                                o_sdram_ras_n,
    output  wire                                o_sdram_cas_n,
    output  wire                                o_sdram_cke,
    output  wire    [SDRAM_DATA_WIDTH/8-1:0]    o_sdram_dqm,

    // PPU
    input   wire    [21:0]                      i_memory_addr_ppu,
    input   wire                                i_memory_write_ppu,
    input   wire    [7:0]                       i_memory_sdram_din_ppu_dout,
    input   wire                                i_memory_read_ppu,
    output  wire    [7:0]                       o_memory_sdram_dout_ppu_din,

    // CPU
    input   wire                                i_rom_loading,
    input   wire    [21:0]                      i_loader_addr_mem,
    input   wire                                i_loader_write_mem,
    input   wire    [21:0]                      i_memory_addr_cpu,
    input   wire                                i_memory_write_cpu,
    input   wire    [7:0]                       i_loader_write_data_mem,
    input   wire    [7:0]                       i_memory_din_sdram_cpu_dout,
    input   wire                                i_memory_read_cpu,
    output  wire    [7:0]                       o_memory_dout_sdram_cpu_din,

    // IOSys risc-v softcore
    input   wire    [22:0]                      i_rv_addr, 
    input   wire                                i_rv_word,
    input   wire    [31:0]                      i_rv_wdata,
    input   wire    [1:0]                       i_rv_ds,
    output  wire    [15:0]                      o_rv_dout,
    input   wire                                i_rv_req, 
    output  wire                                o_rv_req_ack,
    input   wire    [3:0]                       i_rv_wstrb,

    // WRAM
    input   wire                                i_wram_load_ongoing,
    input   wire                                i_wram_save_ongoing
);
localparam NES_BSRAM_SIZE = 'h2000;
localparam NES_BSRAM_STARTING_ADDRESS_RV  = 23'h0070_6000;
localparam NES_BSRAM_LAST_ADDRESS_RV  = (NES_BSRAM_STARTING_ADDRESS_RV + NES_BSRAM_SIZE);
localparam NES_BSRAM_STARTING_ADDRESS_NES = 16'h0000_6000;
localparam NES_BSRAM_LAST_ADDRESS_NES = NES_BSRAM_STARTING_ADDRESS_NES + NES_BSRAM_SIZE;

//
// WRAM BSRAM
//
`ifdef FORMAL
reg [7:0] wram_bsram[0:(NES_BSRAM_SIZE-1)];
`else
(* ram_style = "block" *)   reg [7:0] wram_bsram[0:(NES_BSRAM_SIZE-1)];   /* synthesis syn_keep=1 */
`endif

// Logic for CPU SRAM controller
wire [15:0] addrB                   = (i_rom_loading ? i_loader_addr_mem : i_memory_addr_cpu);
wire        weB                     = ((i_loader_write_mem)||(i_memory_write_cpu));
wire        dinB                    = (i_rom_loading ? i_loader_write_data_mem : i_memory_din_sdram_cpu_dout);
wire        oeB                     = ((~i_rom_loading)&(i_memory_read_cpu));
wire [7:0]  doutB                   = (o_memory_dout_sdram_cpu_din);
// Logic for CPU SRAM arbiter
wire        cpu_address_is_wram     = ((addrB >= NES_BSRAM_STARTING_ADDRESS_NES)&&(addrB <= NES_BSRAM_LAST_ADDRESS_NES));
wire        cpu_we_is_wram          = ((weB)&&(cpu_address_is_wram));
wire        cpu_re_is_wram          = ((oeB)&&(cpu_address_is_wram));
wire        cpu_req_is_wram         = ((cpu_we_is_wram)||(cpu_re_is_wram));
// Logic for RV SRAM controller
reg  [15:0] r_wram_din;
// Logic for RV SRAM arbiter
wire        rv_address_is_wram      = ((i_rv_addr >= NES_BSRAM_STARTING_ADDRESS_RV)&&(i_rv_addr <= NES_BSRAM_STARTING_ADDRESS_RV));
wire        rv_we                   = (i_rv_wstrb != 0);
wire [15:0] rv_din                  = (i_rv_word ? i_rv_wdata[31:16] : i_rv_wdata[15:0]);
wire        rv_we_is_wram           = (i_rv_req)&&((rv_we)&&(rv_address_is_wram));
wire        rv_re_is_wram           = (i_rv_req)&&((!rv_we)&&(rv_address_is_wram));
wire        rv_req_is_wram          = ((rv_we_is_wram)||(rv_re_is_wram));
// Logic for SRAM arbiter
wire        address_is_wram         = ((cpu_address_is_wram)|(rv_address_is_wram));
wire        we_is_wram              = ((cpu_we_is_wram)|(rv_we_is_wram));
wire        re_is_wram              = ((cpu_re_is_wram)|(rv_re_is_wram));
wire        req_is_wram             = ((cpu_req_is_wram)|(rv_req_is_wram));
wire [7:0]  wram_din                = ((rv_req_is_wram)&&(rv_we_is_wram)&&(!cpu_we_is_wram)) ? rv_din[7:0] : dinB;
reg  [7:0]  r_wram_dout;
reg  [15:0] r_wram_address;
wire [15:0] wram_address            = !cpu_address_is_wram ? 
                                            'h0 :                   // We don't care if !cpu_address_is_wram
                                            i_wram_load_ongoing ?   // Meaning RV is writing to WRAM
                                                                   ((rv_req_is_wram)&&((rv_we_is_wram)||(rv_re_is_wram))) ? (i_rv_addr[15:0] - NES_BSRAM_STARTING_ADDRESS_RV) : addrB
                                                                    : addrB; // CPU writes to WRAM       
wire [15:0] wram_bsram_index_cpu        = ((addrB >= NES_BSRAM_STARTING_ADDRESS_NES)&&(addrB <= NES_BSRAM_LAST_ADDRESS_NES)) ? (addrB - NES_BSRAM_STARTING_ADDRESS_NES) : 'h0;
wire [15:0] wram_bsram_index_rv         = ((i_rv_addr >= NES_BSRAM_STARTING_ADDRESS_RV)&&(i_rv_addr <= NES_BSRAM_LAST_ADDRESS_RV)) ? (i_rv_addr - NES_BSRAM_STARTING_ADDRESS_RV) : 'h0;
wire [15:0] wram_bsram_index            = ((address_is_wram)&&(rv_address_is_wram)) ? wram_bsram_index_rv : wram_bsram_index_cpu;

// Write
always @(posedge i_clk) begin
    if((req_is_wram)&&(we_is_wram)&&(address_is_wram))
        wram_bsram[wram_bsram_index] <= wram_din[7:0];
end

// Read
always @(posedge i_clk) begin
    if((req_is_wram)&&(re_is_wram))
        r_wram_dout <= wram_bsram[wram_bsram_index];
end

always @(posedge i_clk)
    if((req_is_wram)&&(we_is_wram))
        r_wram_din <= {8'h00, wram_din};

always @(posedge i_clk)
    r_wram_address <= wram_address;

//
// Output
//
assign o_memory_dout_sdram_cpu_din = ((cpu_address_is_wram)&&(cpu_req_is_wram)&&(cpu_re_is_wram)) ? r_wram_dout : sdram_dout_cpu;
assign o_rv_dout = ((rv_address_is_wram)&&(rv_req_is_wram)&&(rv_re_is_wram)) ? r_wram_dout : sdram_dout_rv;

// From sdram_nes.v or sdram_sim.v
`ifndef FORMAL
wire [7:0] sdram_dout_cpu;
wire [15:0] sdram_dout_rv;
sdram_nes sdram (
    .clk(i_clk),
    .clkref(i_clkref),
    .resetn(i_resetn),
    .busy(o_sdram_busy),
    // SDRAM
    .SDRAM_DQ(io_sdram_dq),
    .SDRAM_A(o_sdram_addr),
    .SDRAM_BA(o_sdram_ba), 
    .SDRAM_nCS(o_sdram_cs_n),
    .SDRAM_nWE(o_sdram_wen_n),
    .SDRAM_nRAS(o_sdram_ras_n), 
    .SDRAM_nCAS(o_sdram_cas_n),
    .SDRAM_CKE(o_sdram_cke),
    .SDRAM_DQM(o_sdram_dqm), 

    // PPU
    .addrA(i_memory_addr_ppu),
    .weA(i_memory_write_ppu),
    .dinA(i_memory_sdram_din_ppu_dout),
    .oeA(i_memory_read_ppu),
    .doutA(o_memory_sdram_dout_ppu_din),

    // CPU
    .addrB(i_rom_loading ? i_loader_addr_mem : i_memory_addr_cpu),
    .weB((i_loader_write_mem)||(i_memory_write_cpu)),
    .dinB(i_rom_loading ? i_loader_write_data_mem : i_memory_din_sdram_cpu_dout),
    .oeB((~i_rom_loading)&(i_memory_read_cpu)),
    // .doutB(o_memory_dout_sdram_cpu_din),
    .doutB(sdram_dout_cpu),

    // IOSys risc-v softcore
    .rv_addr({i_rv_addr[20:2], i_rv_word}),
    .rv_din(i_rv_word ? i_rv_wdata[31:16] : i_rv_wdata[15:0]),
    .rv_ds(i_rv_ds),
    .rv_dout(sdram_dout_rv),
    .rv_req(i_rv_req),
    .rv_req_ack(o_rv_req_ack),
    .rv_we(i_rv_wstrb != 0)
);
`endif 

//
// Formal methods
//
`ifdef FORMAL
    // f_past_valid
	reg	f_past_valid;
	initial	f_past_valid = 1'b0;
	initial assert(!f_past_valid);
	always @(posedge i_clk)
		f_past_valid = 1'b1;

    // BMC Assumptions
    always @(posedge i_clk)
        if(!f_past_valid)
            assume($past(!i_resetn));

    always @(posedge i_clk)
        if($past(!i_resetn))
            assume(!f_past_valid);



    // BMC Assertions

    // 1. If there's a valid address_is_wram, then there's a valid address from CPU or RV
    always @(posedge i_clk)
        if((f_past_valid)&&($past(i_resetn))&&(i_resetn))
            if(address_is_wram)
                assert((cpu_address_is_wram)||(rv_address_is_wram));

    // 2.1 CPU address is always between $6000 and $8000 for cpu_address_is_wram to be valid
    always @(*)
        if(cpu_address_is_wram)
            assert((addrB >= 'h6000)&&(addrB <= 'h8000));

    // 2.2 RV address is always between $706000 and $708000 for rv_address_is_wram to be valid
    always @(*)
        if(rv_address_is_wram)
            assert((i_rv_addr >= 'h706000)&&(i_rv_addr <= 'h708000));

    // 3. wram_bsram_index is always between 0 and 'h2000
    always @(*)
        if(address_is_wram)
            assert(wram_bsram_index <= 'h2000);

    // 3.1 wram_bsram_index_cpu is always between 0 and 'h2000
    always @(*)
        if(cpu_address_is_wram)
            assert(wram_bsram_index_cpu <= 'h2000);

    // 3.2 wram_bsram_index_rv is always between 0 and 'h2000
    always @(*)
        if(rv_address_is_wram)
            assert(wram_bsram_index_rv <= 'h2000);

    // 4. wram_address is always between $6000 and $8000 or 0
    always @(*)
        if(address_is_wram)
            assert((wram_address >= 'h6000)&&(wram_address <= 'h8000)||(wram_address == 0));

    // 5. req_is_wram is valid if address is valid
    always @(*)
        if(req_is_wram)
            assert(address_is_wram);

    // 5.1 req_is_wram is valid if CPU or RV address is valid
    always @(*)
        if(req_is_wram)
            assert((cpu_address_is_wram)||(rv_address_is_wram));
    
    // 5.2 req_is_wram is valid if CPU or RV request is valid
    always @(*)
        if(req_is_wram)
            assert((cpu_req_is_wram)||(rv_req_is_wram));

    // 6. wram_din is rv_din only if RV request is valid and CPU is not requesting
    always @(*)
        if((rv_req_is_wram)&&(rv_address_is_wram)&&(rv_we_is_wram)&&(!cpu_we_is_wram))
            assert(wram_din == rv_din[7:0]);
        else
            assert(wram_din == dinB);

    // 7. r_wram_din changes on clock edges and only if write request is valid
    always @(posedge i_clk)
        if((f_past_valid)&&($past(i_resetn))&&(i_resetn))
            if(($past(req_is_wram))&&($past(we_is_wram)))
                assert(r_wram_din == $past(wram_din));
            else
                assert(r_wram_din == $past(r_wram_din));

    // // 8. BSRAM
    // (* anyconst *)  reg [(SDRAM_DATA_WIDTH-1):0]    f_const_addr;
    //                 reg [7:0]                       f_const_value;
    // always @(*)
    //     assume(f_const_addr <= 'h8000);
        
    // always @(posedge i_clk) begin
    //     if(!f_past_valid)
    //         f_const_value <= wram_bsram[f_const_addr];
    //     else
    //         assert(f_const_value == wram_bsram[f_const_addr]);
    // end

    // 9. CPU output
    always @(*)
        assert(doutB == o_memory_dout_sdram_cpu_din);
    always @(posedge i_clk) begin
        if((f_past_valid)&&($past(i_resetn))&&(i_resetn))
            if((cpu_address_is_wram)&&(cpu_req_is_wram)&&(cpu_re_is_wram))
                assert(o_memory_dout_sdram_cpu_din == r_wram_dout);
            else
                assert(o_memory_dout_sdram_cpu_din == sdram_dout_cpu);
    end

    // 10. RV output
    always @(posedge i_clk) begin
        if((f_past_valid)&&($past(i_resetn))&&(i_resetn))
            if((rv_address_is_wram)&&(rv_req_is_wram)&&(rv_re_is_wram))
                assert(o_rv_dout == r_wram_dout);
            else
                assert(o_rv_dout == sdram_dout_rv);
    end

    // Cover

    // Contract
    
    // Induction assumptions

    // Induction assertions

`endif // FORMAL

endmodule