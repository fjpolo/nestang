//
// NESTang top level
// nand2mario
//

// `timescale 1ns / 100ps

import configPackage::*;

module nestang_top (
    input sys_clk,

    // Button S1 and pin 48 are both resets
    input s1,
    input reset2,

    // UART
    input UART_RXD,
    output UART_TXD,

    // LEDs
    output [2:0] led,

    // SDRAM
    // For Primer 25K: https://github.com/MiSTer-devel/Hardware_MiSTer/blob/master/releases/sdram_xsds_3.0.pdf
    // For Nano 20K: 8MB 32-bit SDRAM
    output O_sdram_clk,
    output O_sdram_cke,
    output O_sdram_cs_n,            // chip select
    output O_sdram_cas_n,           // columns address select
    output O_sdram_ras_n,           // row address select
    output O_sdram_wen_n,           // write enable
    inout [SDRAM_DATA_WIDTH-1:0]    IO_sdram_dq,      // bidirectional data bus
    output [SDRAM_ROW_WIDTH-1:0] O_sdram_addr,     // multiplexed address bus
    output [1:0] O_sdram_ba,        // two banks
    output [SDRAM_DATA_WIDTH/8-1:0]   O_sdram_dqm,    

    // MicroSD
    output sd_clk,
    inout sd_cmd,       // MOSI
    input  sd_dat0,     // MISO
    output sd_dat1,     // 1
    output sd_dat2,     // 1
    output sd_dat3,     // 1

    // NES gamepad
`ifdef N20K
    output NES_gamepad_data_clock,
    output NES_gampepad_data_latch,
    input NES_gampead_serial_data,
    output NES_gamepad_data_clock2,
    output NES_gampepad_data_latch2,
    input NES_gampead_serial_data2,
    output NES_gamepad_data_clock3,
    output NES_gampepad_data_latch3,
    input NES_gampead_serial_data3,
    output NES_gamepad_data_clock4,
    output NES_gampepad_data_latch4,
    input NES_gampead_serial_data4,
    `endif

    // HDMI TX
    output       tmds_clk_n,
    output       tmds_clk_p,
    output [2:0] tmds_d_n,
    output [2:0] tmds_d_p
);


reg sys_resetn = 0;
reg [7:0] reset_cnt = 255;      // reset for 255 cycles before start everything
always @(posedge clk) begin
    reset_cnt <= reset_cnt == 0 ? 0 : reset_cnt - 1;
    if (reset_cnt == 0)
        sys_resetn <= ~s1 & ~reset2 & ~(nes_btn[5] && nes_btn[2]);    // 8BitDo Home button = Select + Down
end

`ifndef VERILATOR

// clk is 27Mhz
`ifdef P25K
  wire clk, clk_sdram;
  gowin_pll_27 pll27 (.clkin(sys_clk), .clkout0(clk), .clkout1(clk_sdram));      // Primer25K: PLL to generate 27Mhz from 50Mhz
`else
  wire clk = sys_clk;       // Nano20K: native 27Mhz system clock
  wire clk_sdram = ~clk;  
`endif
  wire clk_usb;

  // USB clock 12Mhz
  gowin_pll_usb pll_usb(
      .clkin(clk),
      .clkout(clk_usb)       // 12Mhz usb clock
  );

  // HDMI domain clocks
  wire clk_p;     // 720p pixel clock: 74.25 Mhz
  wire clk_p5;    // 5x pixel clock: 371.25 Mhz
  wire pll_lock;

  gowin_pll_hdmi pll_hdmi (
    .clkin(clk),
    .clkout(clk_p5),
    .lock(pll_lock)
  );

  gowin_clkdiv clk_div (
    .clkout(clk_p),
    .hclkin(clk_p5),
    .resetn(sys_resetn & pll_lock)
  );
`else   // VERILATOR
  // dummy clocks for verilator
  wire clk = sys_clk;
  wire clk_sdram = sys_clk;
`endif

  wire [5:0] color;
  wire [15:0] sample;
  wire [8:0] scanline;
  wire [8:0] cycle;

  // internal wiring and state
  wire joypad_strobe;
  wire [1:0] joypad_clock;
  wire [21:0] memory_addr;      // 4MB address space
  wire memory_read_cpu, memory_read_ppu;
  wire memory_write;
  wire [7:0] memory_din_cpu, memory_din_ppu;
  wire [7:0] memory_dout;
  reg [7:0] joypad_bits, joypad_bits2;
  reg [23:0] joypad_bits_multitap, joypad_bits_multitap2;
  reg [1:0] last_joypad_clock;
  wire [31:0] dbgadr;
  wire [1:0] dbgctr;
  reg [3:0] nes_ce = 0;
  wire [15:0] SW = 16'b1111_1111_1111_1111;   // every switch is on

  wire [7:0] sd_dout;
  wire sd_dout_valid;

  // UART
  wire [7:0] uart_data;
  wire [7:0] uart_addr;
  wire       uart_write;
  wire       uart_error;
`ifndef VERILATOR
UartDemux #(.FREQ(FREQ), .BAUDRATE(BAUDRATE)) uart_demux(
    clk, 1'b0, UART_RXD, uart_data, uart_addr, uart_write, uart_error
);
`endif

  // ROM loader
  reg  [7:0] loader_conf;     // bit 0 is reset

`ifdef EMBED_GAME
  // Static compiled-in game data 
  wire [7:0] loader_input;
  wire loader_clk;
  wire loader_reset = ~sys_resetn;
  GameData game_data(
        .clk(clk), .reset(~sys_resetn), .start(1'b1), 
        .odata(loader_input), .odata_clk(loader_clk));
`else
  // Dynamic game loading from UART
  wire [7:0] loader_input = sd_dout_valid ? sd_dout : uart_data;
  wire       loader_clk   = (uart_addr == 8'h37) && uart_write || sd_dout_valid;
  wire loader_reset = ~sys_resetn | loader_conf[0];
`endif

  reg  [7:0] loader_btn, loader_btn_2;
  always @(posedge clk) begin
    if (uart_addr == 8'h35 && uart_write)
      loader_conf <= uart_data;
    if (uart_addr == 8'h40 && uart_write)
      loader_btn <= uart_data;
    if (uart_addr == 8'h41 && uart_write)
      loader_btn_2 <= uart_data;
  end

  /* NES buttons */
  wire [7:0] nes_btn  = NES_gamepad_button_state;
  wire [7:0] nes_btn2 = NES_gamepad_button_state2;
  wire [7:0] nes_btn3  = NES_gamepad_button_state3;
  wire [7:0] nes_btn4  = NES_gamepad_button_state4;

  /* Multitap support */
  reg NES_gamepad_is_multitap;
  initial NES_gamepad_is_multitap = 0;
  wire NES_gamepad_is_multitap_button;
  assign NES_gamepad_is_multitap_button = (!nes_btn[6] & !nes_btn[4]);

  always @(posedge NES_gamepad_is_multitap_button) begin
    NES_gamepad_is_multitap <= ~NES_gamepad_is_multitap;
  end

  // NES gamepad
  wire [7:0]NES_gamepad_button_state;
  wire NES_gamepad_data_available;
  wire [7:0]NES_gamepad_button_state2;
  wire NES_gamepad_data_available2;
  wire [7:0]NES_gamepad_button_state3;
  wire NES_gamepad_data_available3;
  wire [7:0]NES_gamepad_button_state4;
  wire NES_gamepad_data_available4;

`ifdef N20K
  NESGamepad nes_gamepad(
		.i_clk(clk),
        .i_rst(sys_resetn),
		.o_data_clock(NES_gamepad_data_clock),
		.o_data_latch(NES_gampepad_data_latch),
		.i_serial_data(NES_gampead_serial_data),
		.o_button_state(NES_gamepad_button_state),
        .o_data_available(NES_gamepad_data_available)
                        );

  NESGamepad nes_gamepad2(
		.i_clk(clk),
        .i_rst(sys_resetn),
		.o_data_clock(NES_gamepad_data_clock2),
		.o_data_latch(NES_gampepad_data_latch2),
		.i_serial_data(NES_gampead_serial_data2),
		.o_button_state(NES_gamepad_button_state2),
        .o_data_available(NES_gamepad_data_available2)
                        );
`endif

  NESGamepad nes_gamepad3(
		.i_clk(clk),
        .i_rst(sys_resetn),
		.o_data_clock(NES_gamepad_data_clock3),
		.o_data_latch(NES_gampepad_data_latch3),
		.i_serial_data(NES_gampead_serial_data3),
		.o_button_state(NES_gamepad_button_state3),
        .o_data_available(NES_gamepad_data_available3)
                        );

  NESGamepad nes_gamepad4(
		.i_clk(clk),
        .i_rst(sys_resetn),
		.o_data_clock(NES_gamepad_data_cloc4k),
		.o_data_latch(NES_gampepad_data_latch4),
		.i_serial_data(NES_gampead_serial_data4),
		.o_button_state(NES_gamepad_button_state4),
        .o_data_available(NES_gamepad_data_available4)
                        );  

  // Joypad handling
  always @(posedge clk) begin
    if (!NES_gamepad_is_multitap) begin
        /* Normal 2 gamepads mode */
        if (joypad_strobe) begin
          joypad_bits <= nes_btn;
          joypad_bits2 <= nes_btn2;
        end
        if (!joypad_clock[0] && last_joypad_clock[0])
          joypad_bits <= {1'b0, joypad_bits[7:1]};
        if (!joypad_clock[1] && last_joypad_clock[1])
          joypad_bits2 <= {1'b0, joypad_bits2[7:1]};
        last_joypad_clock <= joypad_clock;
    end else begin
        /* Multitap: Four Score mode */
        if (joypad_strobe) begin
          joypad_bits_multitap <= {8'b0010_000, nes_btn2, nes_btn};
          joypad_bits_multitap2 <= {8'b0010_000, nes_btn4, nes_btn3};
        end
        if (!joypad_clock[0] && last_joypad_clock[0])
          joypad_bits_multitap <= {1'b0, joypad_bits_multitap[23:1]};
        if (!joypad_clock[1] && last_joypad_clock[1])
          joypad_bits_multitap2 <= {1'b0, joypad_bits_multitap2[23:1]};
        last_joypad_clock <= joypad_clock;
    end
  end

  wire [21:0] loader_addr;
  wire [7:0] loader_write_data;
  wire loader_write;
  wire [31:0] mapper_flags;
  wire loader_done, loader_fail, loader_refresh;

  // Parses ROM data and store them for MemoryController to access
  GameLoader loader(
        .clk(clk), .reset(loader_reset), .indata(loader_input), .indata_clk(loader_clk),
        .mem_addr(loader_addr), .mem_data(loader_write_data), .mem_write(loader_write),
        .mem_refresh(loader_refresh), .mapper_flags(mapper_flags), 
        .done(loader_done), .error(loader_fail), .loader_state(), .loader_bytes_left());

  // The NES machine
  // nes_ce  / 0 \___/ 1 \___/ 2 \___/ 3 \___/ 4 \___/ 0 \___
  // MemCtrl |mem_cmd|ACTIVE | RD/WR |       |  Dout |run_mem|
  // NES                                     |run_nes|
  //                 `-------- read delay = 4 -------'
  wire reset_nes = !loader_done;
  wire run_mem = (nes_ce == 0) && !reset_nes;       // memory runs at clock cycle #0
  wire run_nes = (nes_ce == 4) && !reset_nes;       // nes runs at clock cycle #4

  // For debug
  reg [21:0] last_addr;
  reg [7:0] last_din;
  reg [7:0] last_dout;
  reg last_write;   // if 0, then we did a read
  reg last_idle;

  reg tick_seen;

  // NES is clocked at every 5th cycle.
  always @(posedge clk) begin
`ifdef VERILATOR
    nes_ce <= nes_ce == 4'd4 ? 0 : nes_ce + 1;
`else
  `ifndef STEP_TRACING
    nes_ce <= nes_ce == 4'd4 ? 0 : nes_ce + 1;    
  `else
    // single stepping every 0.01 second
    // - when waiting for a tick, nes_ce loops between 7 and 13 and 
    //   issues memory refresh on #7
    // - when a tick is seen, nes_ce goes back to 0
    nes_ce <= nes_ce == 4'd13 ? 4'd7 : nes_ce + 1;
    if (tick) tick_seen <= 1'b1;
    if (nes_ce == 4'd13 && tick_seen) begin
        nes_ce <= 0;
        tick_seen <= 1'b0;
    end
  `endif
`endif
    // log memory access result for debug
    if (nes_ce == 4'd4 && !reset_nes) begin
        if (memory_write || memory_read_cpu || memory_read_ppu) begin
            last_addr <= memory_addr;
            last_dout <= memory_read_cpu ? memory_din_cpu : memory_din_ppu;
            last_din <= memory_dout;
            last_write <= memory_write;
            last_idle <= 1'b0;
        end else begin
            // memory is idle this cycle
            last_idle <= 1'b1;
        end
    end else if (loader_write) begin
        last_write <= 1'b1;
        last_addr <= loader_addr;
        last_din <= loader_write_data;
    end
  end

  // VRC6
  wire NES_int_audio;
  wire NES_ext_audio;
  assign NES_int_audio = 1;
  assign NES_ext_audio = (mapper_flags[7:0] == 19) | (mapper_flags[7:0] == 24) | (mapper_flags[7:0] == 26);

  // Main NES machine
  NES nes(
          clk, reset_nes, run_nes,
          mapper_flags,
          sample, color,
          joypad_strobe, joypad_clock, (NES_gamepad_is_multitap ? {joypad_bits_multitap2[0], joypad_bits_multitap[0]}: {joypad_bits2[0], joypad_bits[0]}),
          SW[4:0],
          memory_addr,
          memory_read_cpu, memory_din_cpu,
          memory_read_ppu, memory_din_ppu,
          memory_write, memory_dout,
          cycle, scanline,
          // VRC6
          NES_int_audio,
          NES_ext_audio
        );

/*verilator tracing_off*/
  // Combine RAM and ROM data to a single address space for NES to access
  wire ram_busy, ram_fail;
  wire [19:0] ram_total_written;
  MemoryController memory(.clk(clk), .clk_sdram(clk_sdram), .resetn(sys_resetn),
        .read_a(memory_read_cpu && run_mem), 
        .read_b(memory_read_ppu && run_mem),
        .write(memory_write && run_mem || loader_write),
        .refresh((~memory_read_cpu && ~memory_read_ppu && ~memory_write && ~loader_write) && run_mem || nes_ce == 4'd7 || (loader_refresh && ~loader_write)),
        .addr(loader_write ? loader_addr : memory_addr),
        .din(loader_write ? loader_write_data : memory_dout),
        .dout_a(memory_din_cpu), .dout_b(memory_din_ppu),
        .busy(ram_busy), .fail(ram_fail), .total_written(ram_total_written),

        .SDRAM_DQ(IO_sdram_dq), .SDRAM_A(O_sdram_addr), .SDRAM_BA(O_sdram_ba), .SDRAM_nCS(O_sdram_cs_n),
        .SDRAM_nWE(O_sdram_wen_n), .SDRAM_nRAS(O_sdram_ras_n), .SDRAM_nCAS(O_sdram_cas_n), 
        .SDRAM_CLK(O_sdram_clk), .SDRAM_CKE(O_sdram_cke), .SDRAM_DQM(O_sdram_dqm)
);
/*verilator tracing_on*/

`ifndef VERILATOR

wire menu_overlay;
wire [5:0] menu_color;
wire [7:0] menu_scanline, menu_cycle;

// HDMI output
nes2hdmi u_hdmi (
    .clk(clk), .resetn(sys_resetn),
    .color(menu_overlay ? menu_color : color), .cycle(menu_overlay ? menu_cycle : cycle), 
    .scanline(menu_overlay ? menu_scanline : scanline), .sample(sample >> 1),
    .clk_pixel(clk_p), .clk_5x_pixel(clk_p5), .locked(pll_lock),
    .tmds_clk_n(tmds_clk_n), .tmds_clk_p(tmds_clk_p),
    .tmds_d_n(tmds_d_n), .tmds_d_p(tmds_d_p)
);

reg [7:0] sd_debug_reg;
wire [7:0] sd_debug_out;

SDLoader #(.FREQ(FREQ)) sd_loader (
    .clk(clk), .resetn(sys_resetn),
    .overlay(menu_overlay), .color(menu_color), .scanline(menu_scanline),
    .cycle(menu_cycle),
    .nes_btn(loader_btn | nes_btn | loader_btn_2 | nes_btn2), 
    .dout(sd_dout), .dout_valid(sd_dout_valid),
    .sd_clk(sd_clk), .sd_cmd(sd_cmd), .sd_dat0(sd_dat0), .sd_dat1(sd_dat1),
    .sd_dat2(sd_dat2), .sd_dat3(sd_dat3),

    .debug_reg(sd_debug_reg), .debug_out(sd_debug_out)
);

//
// Print control
//
`include "print.v"
defparam tx.uart_freq=BAUDRATE;
defparam tx.clk_freq=FREQ;
assign print_clk = clk;
assign UART_TXD = uart_txp;

reg[3:0] state_0;
reg[3:0] state_1;
reg[3:0] state_old = 3'd7;
wire[3:0] state_new = state_1;

reg [7:0] print_counters = 0, print_counters_p;

reg tick;       // pulse every 0.01 second
reg print_stat; // pulse every 2 seconds

reg [15:0] recv_packets = 0;
reg [15:0] indata_clk_count = 0;

reg [3:0] sd_state0 = 0;

reg [19:0] timer;           // 37 times per second
always @(posedge clk) timer <= timer + 1;
reg [7:0] debug_cnt = 0;

// `define SD_REPORT
// `define DS2_REPORT

always@(posedge clk)begin
    state_0<={2'b0, loader_done};
    state_1<=state_0;

    // status for SD file browsing
`ifdef SD_REPORT
    if (debug_cnt < 100) begin
        case (timer)
        20'h00000: begin
          debug_cnt <= debug_cnt + 1;
          `print("sd: file_total=", STR);
          sd_debug_reg = 2;
        end
        20'h10000: begin 
          `print(sd_debug_out, 1);
          sd_debug_reg = 1;
        end
        20'h20000: `print(sd_debug_out, 1);
        20'h30000: begin
          `print(", file_start=", STR);
          sd_debug_reg = 3;      
        end
        20'h40000: `print(sd_debug_out, 1);
        20'h50000: begin
          `print(", active=", STR);
          sd_debug_reg = 4;      
        end
        20'h60000: `print(sd_debug_out, 1);
        20'h70000: begin
          `print(", total=", STR);
          sd_debug_reg = 5;      
        end
        20'h80000: `print(sd_debug_out, 1);
        20'h80000: begin
          `print(", state=", STR);
          sd_debug_reg = 6;      
        end
        20'ha0000: `print(sd_debug_out, 1);
        20'hb0000: `print(", buttons=", STR);
        20'hc0000: `print({nes_btn, nes_btn2}, 2);
        20'hf0000: `print("\n", STR);
        endcase
    end
`endif

`ifdef DS2_REPORT
//  joy_rx[0:1] dualshock buttons: 0:(L D R U St R3 L3 Se)  1:(□ X O △ R1 L1 R2 L2)

    case (timer)
    20'h00000: `print("controller1=", STR);
    20'h10000: `print({joy_rx[0], joy_rx[1]}, 2);
    20'h20000: `print(", controller2=", STR);
    20'h30000: `print({joy_rx2[0], joy_rx2[1]}, 2);
    20'h40000: `print(", usb_btn=", STR);
    20'h50000: `print(usb_btn, 1);
    20'hf0000: `print("\n", STR);
    endcase

`endif

    if (uart_demux.write)
        recv_packets <= recv_packets + 1;        

    if(state_0==state_1) begin //stable value
        state_old<=state_new;

        if(state_old!=state_new)begin//state changes
            if(state_new==3'd0) `print("NES_Tang starting...\n", STR);
            if(state_new==3'd1) `print("Game loading done.\n", STR);
        end
    end

`ifdef HID_REPORT
    if (timer == 20'h00000)
      `print("hid=", STR);
    if (timer == 20'h10000)
      `print(dbg_hid_report, 8);
    if (timer == 20'h20000)
      `print(", vidpid=", STR);
    if (timer == 20'h30000)
      `print({dbg_vid, dbg_pid}, 4);
    if (timer == 20'h40000)
      `print(", dev=", STR);
    if (timer == 20'h50000)
      `print({4'b0, dbg_dev}, 1);
    if (timer == 20'h60000)
      `print(", ds2[2]=", STR);
    if (timer == 20'h70000)
      `print({joy_rx[0], joy_rx[1], joy_rx2[0], joy_rx2[1]}, 4);
    if (timer == 20'h80000)
      `print(", usb_btn[2]=", STR);
    if (timer == 20'h90000)
      `print({usb_btn, usb_btn2}, 2);

    if (timer == 20'hf0000)
      `print("\n", STR);
`endif

`ifdef PRINT_SD
    if (sd_state != sd_state0) begin
        if (sd_state == SD_READ_META) begin
            `print("Reading SDcard\n", STR);
        end
        if (sd_state == SD_START_SECTOR) begin
            if (sd_rsector[15:0] == 16'b0) begin
                `print(sd_romlen, 3);
            end else 
                `print(sd_rsector[15:0], 2);
        end
        sd_state0 <= sd_state;
    end
`endif

`ifdef COLOR_TRACING
    // print some color values
    if (loader_done && tick)
        print_counters <= 8'd1;
    print_counters_p <= print_counters;
    if (print_state == PRINT_IDLE_STATE && print_counters == print_counters_p && print_counters != 0) begin
        case (print_counters)
        8'd1: `print({7'b0, scanline}, 2);
        8'd2: `print("  ", STR);
        8'd3: `print({7'b0, cycle}, 2);
        8'd4: `print("  ", STR);
        8'd5: `print({2'b0, color}, 1);
        8'd6: `print("  ", STR);
        8'd255: `print("\n", STR);
        endcase
        print_counters <= print_counters == 8'd255 ? 0 : print_counters + 1;
    end
`endif

    // print stats every 2 seconds normally, or every 0.01 second before game data is ready
`ifdef STEP_TRACING
    if (tick)
        print_counters <= 8'd1;
    print_counters_p <= print_counters;
    if (print_state == PRINT_IDLE_STATE && print_counters == print_counters_p && print_counters != 0) begin
        case (print_counters)
        8'd1: `print("loader_done=", STR);
        8'd2: `print({7'b0, loader_done}, 1);
        8'd3: if (~last_idle) `print(", last memory operation: <write=", STR);
        8'd6: if (~last_idle) `print({7'b0, last_write}, 1);
        8'd7: if (~last_idle) `print(", addr=", STR);
        8'd8: if (~last_idle) `print({2'b0, last_addr}, 3);
        8'd9: if (~last_idle) `print(", din=", STR);
        8'd10: if (~last_idle) `print(last_din, 1);
        8'd11: if (~last_idle) `print(", dout=", STR);
        8'd12: if (~last_idle) `print(last_dout, 1);
        8'd13: if (~last_idle) `print(">", STR);
        8'd14: `print(", total_written=", STR);
        8'd15: `print({4'b0, ram_total_written}, 3);
        8'd16: `print(", ram_busy=", STR);
        8'd17: `print({7'b0, ram_busy}, 1);
        8'd18: `print(", ram_fail=", STR);
        8'd19: `print({7'b0, ram_fail}, 1);

        8'd255: `print("\n\n", STR);
        endcase
        print_counters <= print_counters == 8'd255 ? 0 : print_counters + 1;
    end
`endif

    if(~sys_resetn) begin
       `print("System Reset\nWelcome to NESTang\n",STR);
        debug_cnt <= 0;
    end
end

reg [19:0] tick_counter;
reg [9:0] stat_counter;
always @(posedge clk) begin
    tick <= tick_counter == 0;
    tick_counter <= tick_counter == 0 ? FREQ/100 : tick_counter - 1;

    print_stat <= 0;
    if (tick) begin
        print_stat <= stat_counter == 0;
        stat_counter <= stat_counter == 0 ? 200 : stat_counter - 1;
    end
end

`endif

//assign led = ~{~UART_RXD, loader_done};
//assign led = ~{~UART_RXD, usb_conerr, loader_done};
// assign led = ~usb_btn;

reg [23:0] led_cnt;
always @(posedge clk) led_cnt <= led_cnt + 1;
assign led[1:0] = {led_cnt[23], led_cnt[22]};
assign led[2] = NES_gamepad_is_multitap;

endmodule