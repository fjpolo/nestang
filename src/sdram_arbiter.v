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
// `default_nettype none
import configPackage::*;

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
    input   wire                                i_wram_load_ongoing
);

//
// WRAM BSRAM
//
`ifdef FORMAL
reg [7:0] wram_bsram[0:(8*1024)];
`else
(* ram_style = "block" *)   reg [7:0] wram_bsram[0:(8*1024)];   /* synthesis syn_keep=1 */
`endif
wire [15:0] addrB                   = (i_rom_loading ? i_loader_addr_mem : i_memory_addr_cpu);
wire        weB                     = ((i_loader_write_mem)||(i_memory_write_cpu));
wire        dinB                    = (i_rom_loading ? i_loader_write_data_mem : i_memory_din_sdram_cpu_dout);
wire        oeB                     = ((~i_rom_loading)&(i_memory_read_cpu));
wire [7:0]  doutB                   = (o_memory_dout_sdram_cpu_din);
wire        cpu_address_is_wram     = ((addrB >= 'h6000)&&(addrB <= 'h8000));
wire        cpu_we_is_wram          = ((weB)&&(cpu_address_is_wram));
wire        cpu_re_is_wram          = ((oeB)&&(cpu_address_is_wram));
wire        cpu_req_is_wram         = ((cpu_we_is_wram)||(cpu_re_is_wram))&&(cpu_address_is_wram);
wire        rv_address_is_wram      = ((i_rv_addr >= 'h66000)&&(i_rv_addr <= 'h68000));
wire        rv_we                   = (i_rv_wstrb != 0);
wire [7:0]  rv_din                  = (i_rv_word ? i_rv_wdata[31:16] : i_rv_wdata[15:0]);
wire        rv_we_is_wram           = ((rv_we)&&(rv_address_is_wram));
wire        rv_re_is_wram           = ((!rv_we)&&(rv_address_is_wram));
wire        rv_req_is_wram          = ((rv_we_is_wram)||(rv_re_is_wram))&&(i_rv_req)&&(rv_address_is_wram);
wire        address_is_wram         = ((cpu_address_is_wram)|(rv_we_is_wram));
wire        we_is_wram              = ((cpu_we_is_wram)|(rv_we_is_wram));
wire        re_is_wram              = ((cpu_re_is_wram)|(rv_re_is_wram));
wire        req_is_wram             = ((cpu_req_is_wram)|(rv_req_is_wram));
reg  [7:0]  r_wram_din;
wire [7:0]  wram_din                = cpu_we_is_wram ? dinB : ((rv_req_is_wram)&&(rv_we_is_wram)) ? rv_din[7:0] : r_wram_din;
reg  [7:0]  r_wram_dout;
reg  [15:0] r_wram_address;
wire [15:0] wram_address            = (((cpu_we_is_wram)||(cpu_re_is_wram))&&(!i_wram_load_ongoing)) ? addrB : ((rv_req_is_wram)&&((rv_we_is_wram)||(rv_re_is_wram))) ? i_rv_addr[15:0]: r_wram_address;
wire [15:0] wram_bsram_index        = wram_address - 15'h6000;

// Write
always @(posedge i_clk) begin
    if((req_is_wram)&&(we_is_wram))
        wram_bsram[wram_bsram_index] <= wram_din;
end

// Read
always @(posedge i_clk) begin
    if((req_is_wram)&&(re_is_wram))
        r_wram_dout <= wram_bsram[wram_bsram_index];
end

always @(posedge i_clk)
    r_wram_din <= wram_din;

always @(posedge i_clk)
    r_wram_address <= wram_address;

//
// Output
//
assign o_memory_dout_sdram_cpu_din  = ((cpu_req_is_wram)&&(cpu_re_is_wram)) ? r_wram_dout : sdram_dout_cpu;
assign o_rv_dout                    = ((rv_req_is_wram)&&(rv_re_is_wram)) ? {8'h0, r_wram_dout} : sdram_dout_rv;
// assign o_memory_dout_sdram_cpu_din = sdram_dout_cpu;
// assign o_rv_dout = sdram_dout_rv;


// From sdram_nes.v or sdram_sim.v
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
    // .rv_dout(o_rv_dout),
    .rv_dout(sdram_dout_rv),
    .rv_req(i_rv_req),
    .rv_req_ack(o_rv_req_ack),
    .rv_we(i_rv_wstrb != 0)
);
endmodule