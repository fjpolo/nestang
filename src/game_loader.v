// Module reads bytes and writes to proper address in ram.
// Done is asserted when the whole game is loaded.
// This parses iNES headers too.

module GameLoader(
                  input clk,
                  input reset,
                  input [7:0] indata,
                  input indata_clk,
                  output [21:0] o_mem_addr,
                  output [7:0] mem_data,
                  output mem_write,
                  output o_mem_refresh,
                  output [31:0] mapper_flags,
                  output o_done,
                  output error,
                  output [2:0] loader_state,
                  output [21:0] loader_bytes_left,
                  // Rewind
                  input i_rewind_time_to_save,
                  input i_rewind_enable 
                );

  reg [2:0] state = 0;
  reg [7:0] prgsize;
  reg [3:0] ctr;
  reg [7:0] ines[0:15]; // 16 bytes of iNES header
  reg [21:0] bytes_left;
  
  assign error = (state == 5);
  assign loader_state = state;
  assign loader_bytes_left = bytes_left;
  wire [7:0] prgrom = ines[4];
  wire [7:0] chrrom = ines[5];
  assign mem_data = indata;
  assign mem_write = !done && (bytes_left != 0) && indata_clk;

  wire [2:0] prg_size = prgrom <= 1  ? 0 :
                        prgrom <= 2  ? 1 : 
                        prgrom <= 4  ? 2 : 
                        prgrom <= 8  ? 3 : 
                        prgrom <= 16 ? 4 : 
                        prgrom <= 32 ? 5 : 
                        prgrom <= 64 ? 6 : 7;
                        
  wire [2:0] chr_size = chrrom <= 1  ? 0 : 
                        chrrom <= 2  ? 1 : 
                        chrrom <= 4  ? 2 : 
                        chrrom <= 8  ? 3 : 
                        chrrom <= 16 ? 4 : 
                        chrrom <= 32 ? 5 : 
                        chrrom <= 64 ? 6 : 7;
  
  wire [7:0] mapper = {ines[7][7:4], ines[6][7:4]};
  wire has_chr_ram = (chrrom == 0);

  reg [21:0] mem_addr;
  reg mem_refresh;
  reg done;

  assign o_mem_addr = mem_addr;
  assign o_mem_refresh = mem_refresh;
  assign o_done = done;

  assign mapper_flags = {16'b0, has_chr_ram, ines[6][0], chr_size, prg_size, mapper};

  // RAM buffers
  parameter NES_CARTRIDGE_RAM_SIZE = 8 * 1024;
  parameter NES_INTERNAL_RAM_SIZE = 2 * 1024;
  parameter NES_TOTAL_RAM_SIZE = NES_CARTRIDGE_RAM_SIZE + NES_INTERNAL_RAM_SIZE;
  reg [13:0] rewind_RAM_buffer[7:0];

  // Rewind: Save state
  reg [2:0] state_rewind = 0;
  reg [7:0] prgsize_rewind;
  reg [3:0] ctr_rewind;
  reg [7:0] ines_rewind[0:15];
  reg [21:0] bytes_left_rewind;
  reg [21:0] mem_addr_rewind;
  reg mem_refresh_rewind;
  reg done_rewind;

  always @(posedge i_rewind_time_to_save) begin
    if(!i_rewind_enable) begin
      state_rewind <= state;
      prgsize_rewind <= prgsize;
      ctr_rewind <= ctr;
      ines_rewind[0:15] <= ines;
      bytes_left_rewind <= bytes_left;
      mem_addr_rewind <= mem_addr;
      done_rewind <= done;
      mem_refresh_rewind <= mem_refresh;
    end
  end
  
  always @(posedge clk) begin
    if (reset) begin
      state <= 0;
      done <= 0;
      ctr <= 0;
      mem_addr <= 0;  // Address for PRG
    end else begin
      if(i_rewind_enable) begin
        state <= state_rewind;
        prgsize <= prgsize_rewind;
        ctr <= ctr_rewind;
        ines[0:15] <= ines_rewind[0:15];
        bytes_left <= bytes_left_rewind;
        mem_addr <= mem_addr_rewind;
        done <= done_rewind;
      end else begin
        case(state)
          // Read 16 bytes of ines header
          0: 
            if (indata_clk) begin
              ctr <= ctr + 1;
              ines[ctr] <= indata;
              bytes_left <= {prgrom, 14'b0};           // Each prgrom is 16KB
              if (ctr == 4'b1111)
                state <= (ines[0] == 8'h4E) && (ines[1] == 8'h45) && (ines[2] == 8'h53) && (ines[3] == 8'h1A) && !ines[6][2] && !ines[6][3] ? 1 : 5;
            end
          // Read the next | bytes_left | bytes into | mem_addr |
          1, 2: begin 
              if (bytes_left != 0) begin
                if (indata_clk) begin
                  if( ( (mem_addr >= 'h6000) && (mem_addr <= 'h7FFF) ) ||( (mem_addr >= 'h0000) && (mem_addr <= 'h07FF) ) ) begin
                    // Save into RAM buffer
                    if(mem_addr >= 'h6000) begin
                      rewind_RAM_buffer[mem_addr - 'h0800] = mem_data;
                    end else begin
                      rewind_RAM_buffer[mem_addr] = mem_data;
                    end
                  end
                  bytes_left <= bytes_left - 1;
                  mem_addr <= mem_addr + 1;
                end
              end else if (state == 1) begin
                state <= 2;
                mem_addr <= 22'b10_0000_0000_0000_0000_0000;
                bytes_left <= {1'b0, chrrom, 13'b0};      // Each chrrom is 8KB
              end else if (state == 2) begin
                done <= 1;
              end
            end
        endcase
      end
    end
  end

  // refresh logic
  // do 6 refresh after each write, (RAM needs one per 15us)
  // lowest baudrate=115200, 86.8us per byte
  // highest baudrate=921600, 10.85us per byte
  reg [7:0] cycles_since_write;
  always @(posedge clk) begin
    if(i_rewind_enable) begin
      mem_refresh <= mem_refresh_rewind;
    end else begin
      mem_refresh <= 1'b0;
      if (!done) begin
          cycles_since_write <= cycles_since_write == 8'd48 ? 8'd48 : cycles_since_write + 1;
          if (mem_write) begin
              cycles_since_write <= 0;
          end else if (cycles_since_write[2:0] == 3'b111) begin
              // do refresh on these cycles after a write: 7, 15, 23, 31, 39, 47
              mem_refresh <= 1'b1;
          end  
      end
    end
    if (reset) cycles_since_write <= 8'd48;
  end
  
endmodule

