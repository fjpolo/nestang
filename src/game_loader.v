// Module reads bytes and writes to proper address in ram.
// Done is asserted when the whole game is loaded.
// This parses iNES headers too.

module GameLoader(input clk, input reset,
                  input downloading,
                  input   [7:0] filetype,
                  input [7:0] indata, input indata_clk,
                  output reg [21:0] mem_addr, output [7:0] mem_data, output mem_write, output reg mem_refresh,
                  output [31:0] mapper_flags,
                  output reg done, output error,
                  output [2:0] loader_state, output [21:0] loader_bytes_left
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
  assign mem_write = (bytes_left != 0) && (state == 1 || state == 2) || (downloading && (state == 0 || state == 4)) && indata_clk;

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
  assign mapper_flags = {16'b0, has_chr_ram, ines[6][0], chr_size, prg_size, mapper};
  always @(posedge clk) begin
    if (reset) begin
      state <= 0;
      done <= 0;
      ctr <= 0;
      mem_addr <= filetype == 8'h0B ? 22'b00_0100_0000_0000_0001_0000 : 22'b00_0000_0000_0000_0000_0000;  // Address for FDS : BIOS/PRG
    end else begin
      case(state)
      // Read 16 bytes of ines header
      0: if (indata_clk) begin
           ctr <= ctr + 1;
           mem_addr <= mem_addr + 1'd1;
           ines[ctr] <= indata;
           bytes_left <= {prgrom, 14'b0};           // Each prgrom is 16KB
           if (ctr == 4'b1111) begin
              // Check the 'NES' header. Also, we don't support trainers.
              if ((ines[0] == 8'h4E) && (ines[1] == 8'h45) && (ines[2] == 8'h53) && (ines[3] == 8'h1A) && !ines[6][2]) begin
                mem_addr <= 0;  // Address for PRG
                state <= 1;
              //FDS
              end else if ((ines[0] == 8'h46) && (ines[1] == 8'h44) && (ines[2] == 8'h53) && (ines[3] == 8'h1A)) begin
                mem_addr <= 22'b00_0100_0000_0000_0001_0000;  // Address for FDS skip Header
                state <= 4;
                bytes_left <= 21'b1;
              end else if (filetype[7:0]==8'h0A) begin // Bios
                state <= 4;
                mem_addr <= 22'b00_0000_0000_0000_0001_0000;  // Address for BIOS skip Header
                bytes_left <= 21'b1;
              end else if (filetype[7:0]==8'h0B) begin // FDS
                state <= 4;
                mem_addr <= 22'b00_0100_0000_0000_0010_0000;  // Address for FDS no Header
                bytes_left <= 21'b1;
              end else begin
                state <= 3;
              end
            end
         end
      1, 2: begin // Read the next |bytes_left| bytes into |mem_addr|
          if (bytes_left != 0) begin
            if (indata_clk) begin
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
        4: begin // Read the next |bytes_left| bytes into |mem_addr|
          if (downloading) begin
            if (indata_clk) begin
              mem_addr <= mem_addr + 1'd1;
            end
          end else begin
            done <= 1;
            bytes_left <= 21'b0;
            ines[6] <= 8'h40;
            ines[7] <= 8'h10;
            ines[8] <= 8'h00;
            ines[9] <= 8'h00;
            ines[10] <= 8'h00;
            ines[11] <= 8'h00;
            ines[12] <= 8'h00;
            ines[13] <= 8'h00;
            ines[14] <= 8'h00;
            ines[15] <= 8'h00;
          end
        end
      endcase
    end
  end

  // refresh logic
  // do 6 refresh after each write, (RAM needs one per 15us)
  // lowest baudrate=115200, 86.8us per byte
  // highest baudrate=921600, 10.85us per byte
  reg [7:0] cycles_since_write;
  always @(posedge clk) begin
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
    if (reset) cycles_since_write <= 8'd48;
  end
  
endmodule

