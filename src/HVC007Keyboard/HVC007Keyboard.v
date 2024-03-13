// HVC007KEyboard module to convert USB keyboard to HVC-007 standard
// @fjpolo March, 2024
//
// References:
// - https://www.nesdev.org/wiki/Family_BASIC_Keyboard
// - http://cmpslv2.starfree.jp/Famic/Fambas.htm
// - https://www.nesdev.org/wiki/Expansion_port
// - https://forums.nesdev.org/viewtopic.php?t=23656
// - https://github.com/nand2mario/usb_hid_host
// - https://www.win.tue.nl/~aeb/linux/kbd/scancodes-1.html
// - https://en.wikipedia.org/wiki/Scancode
// - http://www.quadibloc.com/comp/scan.htm#:~:text=Scan%20Code%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20Key%20%20%20%20%20%20%20Scan%20Code%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20Key%20%20%20%20%20%20%20%20%20Scan%20Code%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20Key

module HVC007Keyboard(
    input i_clk,                                // System clock
    input i_ce,                             // Chip Enable
    input i_reset,                          // System reset
    // USB keyboard
    input [7:0] i_usb_key_modifiers,        // Shift, Ctrl,...
    input [7:0] i_usb_key1,                 // Scancase #1
    input [7:0] i_usb_key2,                 // Scancase #2
    input [7:0] i_usb_key3,                 // Scancase #3
    input [7:0] i_usb_key4,                 // Scancase #4
    // HVC-007 Keyboard
    input [7:0] i_register_4016,
    output [7:0] o_register_4017
);

reg [1:0] hvc_column;
reg [4:0] hvc_row;
reg [3:0] hvc_current_state_col_0;
reg [3:0] hvc_current_state_col_1;
wire read_data_from_column_0;
wire read_data_from_column_1;

initial hvc_current_state_col_0 = 4'b1111;
initial hvc_current_state_col_1 = 4'b1111;
initial hvc_column = 0;
initial hvc_row = 0;

assign read_data_from_column_0 = i_register_4016 == 8'h04;
assign read_data_from_column_1 = i_register_4016 == 8'h06;

always @(posedge i_clk) begin
    if(!i_ce)begin
        if(i_reset) begin
            hvc_current_state_col_0 <= 4'b1111;
            hvc_current_state_col_1 <= 4'b1111;
            hvc_column <= 0;
            hvc_row <= 0;
        end else begin
            // Reset - Column0, Row0
            if (i_register_4016 == 8'h05) begin
                hvc_column <= 0;
                hvc_row <= 0;
                hvc_current_state_col_0 <= 4'b1111;
                hvc_current_state_col_1 <= 4'b1111;
            // Select column 0, next row if not just reset
            end else if (i_register_4016 == 8'h04) begin
                // Default state 
                hvc_current_state_col_0 <= 4'b1111;
                // Check SHIFT modifier
                if(i_usb_key_modifiers == 8'hE1 || i_usb_key_modifiers == 8'hE5) begin
                    // Check rows
                    case (hvc_row)
                        0: begin
                            // Check USB keys:
                            // b4   b3  b2      b1
                            // ]	[	RETURN	F8

                            // F8  
                            if( i_usb_key1 == 8'h41 || i_usb_key2 == 8'h41 || i_usb_key3 == 8'h41 || i_usb_key4 == 8'h41) begin
                                hvc_current_state_col_0[0] <= 0;
                            // RETURN
                            end else if( i_usb_key1 == 8'h2A || i_usb_key2 == 8'h2A || i_usb_key3 == 8'h2A || i_usb_key4 == 8'h2A) begin
                                hvc_current_state_col_0[1] <= 0;
                            // [
                            end else if( i_usb_key1 == 8'h5B || i_usb_key2 == 8'h5B || i_usb_key3 == 8'h5B || i_usb_key4 == 8'h5B) begin
                                hvc_current_state_col_0[2] <= 0;
                            // ]
                            end else if( i_usb_key1 == 8'h54 || i_usb_key2 == 8'h54 || i_usb_key3 == 8'h54 || i_usb_key4 == 8'h54) begin
                                hvc_current_state_col_0[3] <= 0;
                            end
                        end
                        1: begin
                            // Check USB keys:
                            // b4  b3  b2   b1
                            // ;   :   @	F7

                            // F7
                            if( i_usb_key1 == 8'h40 || i_usb_key2 == 8'h40 || i_usb_key3 == 8'h40 || i_usb_key4 == 8'h40) begin
                                hvc_current_state_col_0[0] <= 0;
                            // @
                            end else if( i_usb_key1 == 8'h1F || i_usb_key2 == 8'h1F || i_usb_key3 == 8'h1F || i_usb_key4 == 8'h1F) begin
                                hvc_current_state_col_0[1] <= 0;
                            // :
                            end else if( i_usb_key1 == 8'h33 || i_usb_key2 == 8'h33 || i_usb_key3 == 8'h33 || i_usb_key4 == 8'h33) begin
                                hvc_current_state_col_0[2] <= 0;
                            // ;
                            end else if( i_usb_key1 == 8'h32 || i_usb_key2 == 8'h32 || i_usb_key3 == 8'h32 || i_usb_key4 == 8'h32) begin
                                hvc_current_state_col_0[3] <= 0;
                            end
                        end
                        2: begin
                            // Check USB keys:
                            // b4  b3  b2   b1
                            // K	L	O	F6

                            // F6 
                            if( i_usb_key1 == 8'h3F || i_usb_key2 == 8'h3F || i_usb_key3 == 8'h3F || i_usb_key4 == 8'h3F) begin
                                hvc_current_state_col_0[0] <= 0;
                            // O
                            end else if( i_usb_key1 == 8'h12 || i_usb_key2 == 8'h12 || i_usb_key3 == 8'h12 || i_usb_key4 == 8'h12) begin
                                hvc_current_state_col_0[1] <= 0;
                            // L
                            end else if( i_usb_key1 == 8'h0F || i_usb_key2 == 8'h0F || i_usb_key3 == 8'h0F || i_usb_key4 == 8'h0F) begin
                                hvc_current_state_col_0[2] <= 0;
                            // K
                            end else if( i_usb_key1 == 8'h0E || i_usb_key2 == 8'h0E || i_usb_key3 == 8'h0E || i_usb_key4 == 8'h0E) begin
                                hvc_current_state_col_0[3] <= 0;
                            end
                        end
                        3: begin
                            // Check USB keys:
                            // b4  b3  b2   b1
                            // J	U	I	F5

                            // F5 
                            if( i_usb_key1 == 8'h3E || i_usb_key2 == 8'h3E || i_usb_key3 == 8'h3E || i_usb_key4 == 8'h3E) begin
                                hvc_current_state_col_0[0] <= 0;
                            // I
                            end else if( i_usb_key1 == 8'h0C || i_usb_key2 == 8'h0C || i_usb_key3 == 8'h0C || i_usb_key4 == 8'h0C) begin
                                hvc_current_state_col_0[1] <= 0;
                            // U
                            end else if( i_usb_key1 == 8'h18 || i_usb_key2 == 8'h18 || i_usb_key3 == 8'h18 || i_usb_key4 == 8'h18) begin
                                hvc_current_state_col_0[2] <= 0;
                            // J
                            end else if( i_usb_key1 == 8'h0D || i_usb_key2 == 8'h0D || i_usb_key3 == 8'h0D || i_usb_key4 == 8'h0D) begin
                                hvc_current_state_col_0[3] <= 0;
                            end
                        end
                        4: begin
                            // Check USB keys:
                            // b4  b3  b2   b1
                            // H	G	Y	F4

                            // F4 
                            if( i_usb_key1 == 8'h3C || i_usb_key2 == 8'h3C || i_usb_key3 == 8'h3C || i_usb_key4 == 8'h3C) begin
                                hvc_current_state_col_0[0] <= 0;
                            // Y
                            end else if( i_usb_key1 == 8'h1C || i_usb_key2 == 8'h1C || i_usb_key3 == 8'h1C || i_usb_key4 == 8'h1C) begin
                                hvc_current_state_col_0[1] <= 0;
                            // G
                            end else if( i_usb_key1 == 8'h0A || i_usb_key2 == 8'h0A || i_usb_key3 == 8'h0A || i_usb_key4 == 8'h0A) begin
                                hvc_current_state_col_0[2] <= 0;
                            // H
                            end else if( i_usb_key1 == 8'h0B || i_usb_key2 == 8'h0B || i_usb_key3 == 8'h0B || i_usb_key4 == 8'h0B) begin
                                hvc_current_state_col_0[3] <= 0;
                            end
                        end
                        5: begin
                            // Check USB keys:
                            // b4  b3  b2   b1
                            // 	D	R	T	F3

                            // F3
                            if( i_usb_key1 == 8'h3C || i_usb_key2 == 8'h3C || i_usb_key3 == 8'h3C || i_usb_key4 == 8'h3C) begin
                                hvc_current_state_col_0[0] <= 0;
                            // T
                            end else if( i_usb_key1 == 8'h17 || i_usb_key2 == 8'h17 || i_usb_key3 == 8'h17 || i_usb_key4 == 8'h17) begin
                                hvc_current_state_col_0[1] <= 0;
                            // R
                            end else if( i_usb_key1 == 8'h15 || i_usb_key2 == 8'h15 || i_usb_key3 == 8'h15 || i_usb_key4 == 8'h15) begin
                                hvc_current_state_col_0[2] <= 0;
                            // D
                            end else if( i_usb_key1 == 8'h07 || i_usb_key2 == 8'h07 || i_usb_key3 == 8'h07 || i_usb_key4 == 8'h07) begin
                                hvc_current_state_col_0[3] <= 0;
                            end
                        end
                        6: begin
                            // Check USB keys:
                            // b4  b3  b2   b1
                            // 	A	S	W	F2

                            // F2
                            if( i_usb_key1 == 8'h3B || i_usb_key2 == 8'h3B || i_usb_key3 == 8'h3B || i_usb_key4 == 8'h3B) begin
                                hvc_current_state_col_0[0] <= 0;
                            // W
                            end else if( i_usb_key1 == 8'h1A || i_usb_key2 == 8'h1A || i_usb_key3 == 8'h1A || i_usb_key4 == 8'h1A) begin
                                hvc_current_state_col_0[1] <= 0;
                            // S
                            end else if( i_usb_key1 == 8'h16 || i_usb_key2 == 8'h16 || i_usb_key3 == 8'h16 || i_usb_key4 == 8'h16) begin
                                hvc_current_state_col_0[2] <= 0;
                            // A
                            end else if( i_usb_key1 == 8'h04 || i_usb_key2 == 8'h04 || i_usb_key3 == 8'h04 || i_usb_key4 == 8'h04) begin
                                hvc_current_state_col_0[3] <= 0;
                            end
                        end
                        7: begin
                            // Check USB keys:
                            // b4   b3  b2   b1
                            // CTR	Q	ESC	 F1

                            // F1
                            if( i_usb_key1 == 8'h3A || i_usb_key2 == 8'h3A || i_usb_key3 == 8'h3A || i_usb_key4 == 8'h3A) begin
                                hvc_current_state_col_0[0] <= 0;
                            // ESC
                            end else if( i_usb_key1 == 8'h1E || i_usb_key2 == 8'h1E || i_usb_key3 == 8'h1E || i_usb_key4 == 8'h1E) begin
                                hvc_current_state_col_0[1] <= 0;
                            // Q
                            end else if( i_usb_key1 == 8'h14 || i_usb_key2 == 8'h14 || i_usb_key3 == 8'h14 || i_usb_key4 == 8'h14) begin
                                hvc_current_state_col_0[2] <= 0;
                            // CTR
                            end else if( i_usb_key1 == (8'hE0 || 8'hE4) || i_usb_key2 == (8'hE0 || 8'hE4) || i_usb_key3 == (8'hE0 || 8'hE4) || i_usb_key4 == (8'hE0 || 8'hE4)) begin
                                hvc_current_state_col_0[3] <= 0;
                            end
                        end
                        8: begin
                            // Check USB keys:
                            // b4   b3      b2  b1
                            // LEFT	RIGHT	UP	CLR HOME

                            // RIGHT
                            if( i_usb_key1 == 8'(8'h4F || 8'H5E) || i_usb_key2 == 8'(8'H4F || 8'H5E) || i_usb_key3 == 8'(8'H4F || 8'H5E) || i_usb_key4 == 8'(8'H4F || 8'H5E)) begin
                                hvc_current_state_col_0[0] <= 0;
                            // LEFT
                            end else if( i_usb_key1 == 8'(8'H50 || 8'H97) || i_usb_key2 == 8'(8'H50 || 8'H97) || i_usb_key3 == 8'(8'H50 || 8'H97) || i_usb_key4 == 8'(8'H50 || 8'H97)) begin
                                hvc_current_state_col_0[1] <= 0;
                            // UP
                            end else if( i_usb_key1 == (8'h52 || 8'h60) || i_usb_key2 == (8'h52 || 8'h60) || i_usb_key3 == (8'h52 || 8'h60) || i_usb_key4 == (8'h52 || 8'h60)) begin
                                hvc_current_state_col_0[2] <= 0;
                            // CLR HOME
                            end else if( i_usb_key1 == (8'h4a || 8'h5f) || i_usb_key2 == (8'h4a || 8'h5f) || i_usb_key3 == (8'h4a || 8'h5f) || i_usb_key4 == (8'h4a || 8'h5f)) begin
                                hvc_current_state_col_0[3] <= 0;
                            end
                        end
                    endcase
                end            
            // Select column 1
            end else if (i_register_4016 == 8'h06) begin
                                // Default state 
                hvc_current_state_col_1 <= 4'b1111;
                // Check SHIFT modifier
                if(i_usb_key_modifiers == 8'hE1 || i_usb_key_modifiers == 8'hE5) begin
                    // Check rows
                    case (hvc_row)
                        0: begin
                            // Check USB keys:
                            // b4   b3      b2      b1
                            // STOP	¥ € $	RSHIFT	KANA

                            // // STOP 
                            // if( i_usb_key1 == 8'41 || i_usb_key2 == 8'41 || i_usb_key3 == 8'41 || i_usb_key4 == 8'41) begin
                            //     hvc_current_state_col_1[0] <= 0;
                            // // ¥ € $
                            if( i_usb_key1 == 8'h21 || i_usb_key2 == 8'h21 || i_usb_key3 == 8'h21 || i_usb_key4 == 8'h21) begin
                                hvc_current_state_col_1[1] <= 0;
                            // RSHIFT
                            end else if( i_usb_key1 == 8'hE5 || i_usb_key2 == 8'hE5 || i_usb_key3 == 8'hE5 || i_usb_key4 == 8'hE5) begin
                                hvc_current_state_col_1[2] <= 0;
                            // // KANA
                            // end else if( i_usb_key1 == 8'h54 || i_usb_key2 == 8'h54 || i_usb_key3 == 8'h54 || i_usb_key4 == 8'h54) begin
                            //     hvc_current_state_col_1[3] <= 0;
                            // end
                            end
                        end
                        1: begin
                            // Check USB keys:
                            // b4  b3  b2   b1
                            // ^	-	/	_

                            // ^
                            if( i_usb_key1 == 8'h32 || i_usb_key2 == 8'h32 || i_usb_key3 == 8'h32 || i_usb_key4 == 8'h32) begin
                                hvc_current_state_col_1[0] <= 0;
                            // -
                            end else if( i_usb_key1 == 8'h2D || i_usb_key2 == 8'h2D || i_usb_key3 == 8'h2D || i_usb_key4 == 8'h2D) begin
                                hvc_current_state_col_1[1] <= 0;
                            // /
                            end else if( i_usb_key1 == (8'H32 || 8'H54) || i_usb_key2 == (8'H32 || 8'H54) || i_usb_key3 == (8'H32 || 8'H54) || i_usb_key4 == (8'H32 || 8'H54)) begin
                                hvc_current_state_col_1[2] <= 0;
                            // // _
                            // end else if( i_usb_key1 == 8'h32 || i_usb_key2 == 8'h32 || i_usb_key3 == 8'h32 || i_usb_key4 == 8'h32) begin
                            //     hvc_current_state_col_1[3] <= 0;
                            // end
                            end
                        end
                        2: begin
                            // Check USB keys:
                            // b4  b3  b2   b1
                            // 0	P	,	.

                            // 0 
                            if( i_usb_key1 == 8'h27 || i_usb_key2 == 8'h27 || i_usb_key3 == 8'h27 || i_usb_key4 == 8'h27) begin
                                hvc_current_state_col_1[0] <= 0;
                            // P
                            end else if( i_usb_key1 == 8'h13 || i_usb_key2 == 8'h13 || i_usb_key3 == 8'h13 || i_usb_key4 == 8'h13) begin
                                hvc_current_state_col_1[1] <= 0;
                            // ,
                            end else if( i_usb_key1 == 8'h36 || i_usb_key2 == 8'h36 || i_usb_key3 == 8'h36 || i_usb_key4 == 8'h36) begin
                                hvc_current_state_col_1[2] <= 0;
                            // .
                            end else if( i_usb_key1 == 8'h37 || i_usb_key2 == 8'h37 || i_usb_key3 == 8'h37 || i_usb_key4 == 8'h37) begin
                                hvc_current_state_col_1[3] <= 0;
                            end
                        end
                        3: begin
                            // Check USB keys:
                            // b4   b3  b2   b1
                            // 8    9	N	 M

                            // 8 
                            if( i_usb_key1 == 8'h25 || i_usb_key2 == 8'h25 || i_usb_key3 == 8'h25 || i_usb_key4 == 8'h25) begin
                                hvc_current_state_col_1[0] <= 0;
                            // 9
                            end else if( i_usb_key1 == 8'h26 || i_usb_key2 == 8'h26 || i_usb_key3 == 8'h26 || i_usb_key4 == 8'h26) begin
                                hvc_current_state_col_1[1] <= 0;
                            // N
                            end else if( i_usb_key1 == 8'h11 || i_usb_key2 == 8'h11 || i_usb_key3 == 8'h11 || i_usb_key4 == 8'h11) begin
                                hvc_current_state_col_1[2] <= 0;
                            // M
                            end else if( i_usb_key1 == 8'h10 || i_usb_key2 == 8'h10 || i_usb_key3 == 8'h10 || i_usb_key4 == 8'h10) begin
                                hvc_current_state_col_1[3] <= 0;
                            end
                        end
                        4: begin
                            // Check USB keys:
                            // b4  b3  b2   b1
                            // 6	7	V	B

                            // 6
                            if( i_usb_key1 == 8'h23 || i_usb_key2 == 8'h23 || i_usb_key3 == 8'h23 || i_usb_key4 == 8'h23) begin
                                hvc_current_state_col_1[0] <= 0;
                            // 7
                            end else if( i_usb_key1 == 8'h24 || i_usb_key2 == 8'h24 || i_usb_key3 == 8'h24 || i_usb_key4 == 8'h24) begin
                                hvc_current_state_col_1[1] <= 0;
                            // V
                            end else if( i_usb_key1 == 8'h19 || i_usb_key2 == 8'h19 || i_usb_key3 == 8'h19 || i_usb_key4 == 8'h19) begin
                                hvc_current_state_col_1[2] <= 0;
                            // B
                            end else if( i_usb_key1 == 8'h05 || i_usb_key2 == 8'h05 || i_usb_key3 == 8'h05 || i_usb_key4 == 8'h05) begin
                                hvc_current_state_col_1[3] <= 0;
                            end
                        end
                        5: begin
                            // Check USB keys:
                            // b4  b3  b2   b1
                            // 4	5	C	F

                            // 4
                            if( i_usb_key1 == 8'h21 || i_usb_key2 == 8'h21 || i_usb_key3 == 8'h21 || i_usb_key4 == 8'h21) begin
                                hvc_current_state_col_1[0] <= 0;
                            // 5
                            end else if( i_usb_key1 == 8'h22 || i_usb_key2 == 8'h22 || i_usb_key3 == 8'h22 || i_usb_key4 == 8'h22) begin
                                hvc_current_state_col_1[1] <= 0;
                            // C
                            end else if( i_usb_key1 == 8'h06 || i_usb_key2 == 8'h06 || i_usb_key3 == 8'h06 || i_usb_key4 == 8'h06) begin
                                hvc_current_state_col_1[2] <= 0;
                            // F
                            end else if( i_usb_key1 == 8'h09 || i_usb_key2 == 8'h09 || i_usb_key3 == 8'h09 || i_usb_key4 == 8'h09) begin
                                hvc_current_state_col_1[3] <= 0;
                            end
                        end
                        6: begin
                            // Check USB keys:
                            // b4   b3  b2   b1
                            // 3	E	Z	X

                            // 3
                            if( i_usb_key1 == 8'h20 || i_usb_key2 == 8'h20 || i_usb_key3 == 8'h20 || i_usb_key4 == 8'h20) begin
                                hvc_current_state_col_1[0] <= 0;
                            // E
                            end else if( i_usb_key1 == 8'h08 || i_usb_key2 == 8'h08 || i_usb_key3 == 8'h08 || i_usb_key4 == 8'h08) begin
                                hvc_current_state_col_1[1] <= 0;
                            // Z
                            end else if( i_usb_key1 == 8'h1D || i_usb_key2 == 8'h1D || i_usb_key3 == 8'h1D || i_usb_key4 == 8'h1D) begin
                                hvc_current_state_col_1[2] <= 0;
                            // X
                            end else if( i_usb_key1 == 8'h1B || i_usb_key2 == 8'h1B || i_usb_key3 == 8'h1B || i_usb_key4 == 8'h1B) begin
                                hvc_current_state_col_1[3] <= 0;
                            end
                        end
                        7: begin
                            // Check USB keys:
                            // b4   b3  b2   b1
                            // 2	1	GRPH	LSHIFT

                            // 2
                            if( i_usb_key1 == 8'h1F || i_usb_key2 == 8'h1F || i_usb_key3 == 8'h1F || i_usb_key4 == 8'h1F ) begin
                                hvc_current_state_col_1[0] <= 0;
                            // 1
                            end else if( i_usb_key1 == 8'h1E || i_usb_key2 == 8'h1E || i_usb_key3 == 8'h1E || i_usb_key4 == 8'h1E ) begin
                                hvc_current_state_col_1[1] <= 0;
                            // GRPH
                            end else if( i_usb_key1 == 8'h46 || i_usb_key2 == 8'h46 || i_usb_key3 == 8'h46 || i_usb_key4 == 8'h46 ) begin
                                hvc_current_state_col_1[2] <= 0;
                            // LSHIFT
                            end else if( i_usb_key1 == 8'hE1 || i_usb_key2 == 8'hE1 || i_usb_key3 == 8'hE1 || i_usb_key4 == 8'hE1 ) begin
                                hvc_current_state_col_1[3] <= 0;
                            end
                        end
                        8: begin
                            // Check USB keys:
                            // b4   b3      b2  b1
                            // INS	DEL	SPACE	DOWN

                            // INS
                            if( i_usb_key1 == (8'H49|| 8'H62) || i_usb_key2 == (8'H49|| 8'H62) || i_usb_key3 == (8'H49|| 8'H62) || i_usb_key4 == (8'H49|| 8'H62)) begin
                                hvc_current_state_col_1[0] <= 0;
                            // DEL (BACKSPACE)
                            end else if( i_usb_key1 == (8'H2A || 8'H63 || 8'H4C) || i_usb_key2 == 8'(8'H2A || 8'H63 || 8'H4C) || i_usb_key3 == 8'(8'H2A || 8'H63 || 8'H4C) || i_usb_key4 == 8'(8'H2A || 8'H63 || 8'H4C)) begin
                                hvc_current_state_col_1[1] <= 0;
                            // SPACE
                            end else if( i_usb_key1 == 8'h2c || i_usb_key2 == 8'h2c || i_usb_key3 == 8'h2c || i_usb_key4 == 8'h2c) begin
                                hvc_current_state_col_1[2] <= 0;
                            // DOWN
                            end else if( i_usb_key1 == (8'h51 || 8'h5a) || i_usb_key2 == (8'h51 || 8'h5a) || i_usb_key3 == (8'h51 || 8'h5a) || i_usb_key4 == (8'h51 || 8'h5a)) begin
                                hvc_current_state_col_1[3] <= 0;
                            end
                        end
                    endcase
                end else begin
                hvc_row <= hvc_row + 1;
                if(hvc_row == 9)
                    hvc_row <= 9;
                end
            end
        end
    end
end

assign o_register_4017[4:1] = read_data_from_column_0 ? hvc_current_state_col_0 : (read_data_from_column_1 ? hvc_current_state_col_1 : 4'b1111);

endmodule