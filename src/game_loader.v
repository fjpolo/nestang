// Module reads bytes and writes to proper address in ram.
// Done is asserted when the whole game is loaded.
// This parses iNES Header headers too.
//
// Reference:
//              
//              https://www.nesdev.org/wiki/INES
//              https://www.nesdev.org/wiki/Mapper
//              https://www.nesdev.org/wiki/NES_2.0
//              


module GameLoader(
                    // In
                    input clk,                              // System clock
                    input reset,                            // System reset
                    input [7:0] indata,                     // Input data - (in nes_tang20k coming from SD Card)
                    input indata_clk,                       // Input data clock - (in nes_tang_20k clocks as HI when SD d_out is valid) 
                    // Out
                    output reg [21:0] mem_addr,             // Output address - ($00 0000 - $3F FFFF) 
                    output [7:0] mem_data,                  // Output data
                    output mem_write,                       // Write enable output    
                    output reg mem_refresh,                 // Memory refresh output
                    output [31:0] mapper_flags,             // Mapper flags - (used by nes_tang20k to call NES() with used mapper)
                    output reg done, 
                    output error,
                    output [2:0] loader_state, 
                    output [21:0] loader_bytes_left
                );

  reg [2:0] state = 0;                       // State handle - 5 means error
  reg [3:0] current_byte_index;
  reg [7:0] ines_header[0:15];               // 16 bytes of iNES Header
  reg [21:0] bytes_left;                     // iNES bytes left to read from input
  
  assign error = (state == 5);              // Error handle - High ONLY if state == 5
  assign loader_state = state;              // Loading state handle
  assign loader_bytes_left = bytes_left;
  wire [7:0] prgrom = ines_header[4];       // Size of PRG ROM in 16 KB units
  wire [7:0] chrrom = ines_header[5];       // Size of CHR ROM in  8 KB units (value 0 means the board uses CHR RAM)
  assign mem_data = indata;                 // Output data is input data - Will depend on mem_write
  // Enable output only when !done, there's bytes left and input data clock is high - done is high when GameLoader states is in state 2
  assign mem_write = !done && (bytes_left != 0) && indata_clk;  

  // Get PRG size from iNES
  wire [2:0] prg_size = prgrom <= 1  ? 0 :
                        prgrom <= 2  ? 1 : 
                        prgrom <= 4  ? 2 : 
                        prgrom <= 8  ? 3 : 
                        prgrom <= 16 ? 4 : 
                        prgrom <= 32 ? 5 : 
                        prgrom <= 64 ? 6 : 7;

  // Get CHR size from iNES         
  wire [2:0] chr_size = chrrom <= 1  ? 0 : 
                        chrrom <= 2  ? 1 : 
                        chrrom <= 4  ? 2 : 
                        chrrom <= 8  ? 3 : 
                        chrrom <= 16 ? 4 : 
                        chrrom <= 32 ? 5 : 
                        chrrom <= 64 ? 6 : 7;
  
  // Take mapper info from iNES header taken from ROM
  wire [7:0] mapper = {
                        ines_header[7][7:4],    // iNes Byte 7, high nibble - Mapper Number high nibble
                        ines_header[6][7:4]     // iNes Byte 6, high nibble - Mapper Number low nibble
                      };           

  // chrrom value 0 means the board uses CHR RAM                    
  wire has_chr_ram = (chrrom == 0);

  // Mapper flags
  // byte 7 bits [7:4] are Mapper number's high nibble
  // byte 6 bits [7:4] are Mapper number's low nibble
  assign mapper_flags = {
                            16'b0, 
                            has_chr_ram,        // 0 for ROM, 1 for RAM
                            ines_header[6][0],  // iNES Byte 6, bit 0
                            chr_size,           // CHR ROM/RAM size [2:0]
                            prg_size,           // PRG size [2:0]
                            mapper              // Mapper number [7:0]
                        };

  // Parse ROM
  always @(posedge clk) begin
    // Initialize after reset
    if (reset) begin
      state <= 0;
      done <= 0;
      current_byte_index <= 0;
      mem_addr <= 0;
    // GameLoader state machine
    end else begin
      case(state)
      // Read 16 bytes of iNES header
      0: if (indata_clk) begin
           // Next byte - Increment
           current_byte_index <= current_byte_index + 1;
           // Save current byte to iNES header, take from input data
           ines_header[current_byte_index] <= indata;
           // Each prgrom is 16KB
           bytes_left <= {prgrom, 14'b0};               // bytes_left[21:0] = {prgrom[7:0], 14'b0} -> prgrom[7:0] = 64, 32, 16...0
           // Parse only 16 bytes
           if (current_byte_index == 4'h15)
             state <= (    (ines_header[0] == 8'h4E)    // 'N'
                        && (ines_header[1] == 8'h45)    // 'E'
                        && (ines_header[2] == 8'h53)    // 'S'
                        && (ines_header[3] == 8'h1A)    // MS-DOS end of file <EOF>
                        && !ines_header[6][2]           // Cartridge contains battery-backed PRG RAM ($6000-7FFF) or other persistent memory
                        && !ines_header[6][3]           // 512-byte trainer at $7000-$71FF (stored before PRG data)
                      )
                        ? 1 : 5;                        // 5 is an error:
                                                        //                  - Any char from "NES\<EOF>" missing
                                                        //                  - Battery-backed PRG RAM currently unsupported
                                                        //                  - Trainer currently unsupported    
         end
      // Read the next |bytes_left| bytes into |mem_addr|
      // Dumps data from input data to output data
      1, 2: begin
          // Dump PRG ROM (Trainer area skipped, not supported)
          if (bytes_left != 0) begin
            if (indata_clk) begin
              // Need to decrement bytes left each clock
              bytes_left <= bytes_left - 1;
              // Need to increment memory address each clock
              mem_addr <= mem_addr + 1;
            end
          // Dump CHR ROM
          end else if (state == 1) begin
            state <= 2;
            mem_addr <= 22'b10_0000_0000_0000_0000_0000;
            // Each chrrom is 8KB
            bytes_left <= {1'b0, chrrom, 13'b0};
          // Dump done
          end else if (state == 2) begin
            // DONE!
            done <= 1;
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

