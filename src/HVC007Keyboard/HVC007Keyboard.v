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

`include "usb_hid_keys.vh"

module HVC007Keyboard(
    input i_clk,                            // System clock
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
    output [7:0] o_register_4017,
    output [7:0] o_keyboard_buttons
);

reg [1:0] hvc_column;
reg [4:0] hvc_row;
reg [3:0] hvc_current_state_col_0;
reg [3:0] hvc_current_state_col_1;
wire read_data_from_column_0;
wire read_data_from_column_1;
reg [7:0]keyboard_buttons;

initial hvc_current_state_col_0 = 4'b1111;
initial hvc_current_state_col_1 = 4'b1111;
initial hvc_column = 0;
initial hvc_row = 0;

assign read_data_from_column_0 = i_register_4016 == KEY_A;
assign read_data_from_column_1 = i_register_4016 == KEY_C;

always @(posedge i_clk) begin
    if(!i_ce)begin
        if(i_reset) begin
            hvc_current_state_col_0 <= 4'b1111;
            hvc_current_state_col_1 <= 4'b1111;
            hvc_column <= 0;
            hvc_row <= 0;
            keyboard_buttons <= 8'b1111_1111;
        end else begin
            // Reset - Column0, Row0
            if (i_register_4016 == KEY_B) begin
                hvc_column <= 0;
                hvc_row <= 0;
                hvc_current_state_col_0 <= 4'b1111;
                hvc_current_state_col_1 <= 4'b1111;
                keyboard_buttons <= 8'b1111_1111;
            // Select column 0, next row if not just reset
            end else if (i_register_4016 == KEY_A) begin
                // Default state 
                hvc_current_state_col_0 <= 4'b1111;
                
                // Check rows
                case (hvc_row)
                    0: begin
                        // Check USB keys:
                        // b4   b3  b2      b1
                        // ]	[	RETURN	F8

                        // F8  
                        if( i_usb_key1 == KEY_F8 || i_usb_key2 == KEY_F8 || i_usb_key3 == KEY_F8 || i_usb_key4 == KEY_F8) begin
                            hvc_current_state_col_0[0] <= 0;
                        // RETURN
                        end else if( i_usb_key1 == KEY_ENTER || i_usb_key2 == KEY_ENTER || i_usb_key3 == KEY_ENTER || i_usb_key4 == KEY_ENTER) begin
                            hvc_current_state_col_0[1] <= 0;
                            keyboard_buttons[4] <= 0;
                        // [
                        end else if( i_usb_key1 == KEY_LEFTBRACE || i_usb_key2 == KEY_LEFTBRACE || i_usb_key3 == KEY_LEFTBRACE || i_usb_key4 == KEY_LEFTBRACE) begin
                            hvc_current_state_col_0[2] <= 0;
                        // ]
                        end else if( i_usb_key1 == KEY_RIGHTBRACE || i_usb_key2 == KEY_RIGHTBRACE || i_usb_key3 == KEY_RIGHTBRACE || i_usb_key4 == KEY_RIGHTBRACE) begin
                            hvc_current_state_col_0[3] <= 0;
                        end
                    end
                    1: begin
                        // Check USB keys:
                        // b4  b3  b2   b1
                        // ;   :   @	F7

                        // F7
                        if( i_usb_key1 == KEY_F7 || i_usb_key2 == KEY_F7 || i_usb_key3 == KEY_F7 || i_usb_key4 == KEY_F7) begin
                            hvc_current_state_col_0[0] <= 0;
                        // @
                        end else if( i_usb_key1 == KEY_2 || i_usb_key2 == KEY_2 || i_usb_key3 == KEY_2 || i_usb_key4 == KEY_2) begin
                            hvc_current_state_col_0[1] <= 0;
                        // // :
                        // end else if( i_usb_key1 == 8'h33 || i_usb_key2 == 8'h33 || i_usb_key3 == 8'h33 || i_usb_key4 == 8'h33) begin
                        //     hvc_current_state_col_0[2] <= 0;
                        // ;
                        end else if( i_usb_key1 == KEY_SEMICOLON || i_usb_key2 == KEY_SEMICOLON || i_usb_key3 == KEY_SEMICOLON || i_usb_key4 == KEY_SEMICOLON) begin
                            hvc_current_state_col_0[3] <= 0;
                        end
                    end
                    2: begin
                        // Check USB keys:
                        // b4  b3  b2   b1
                        // K	L	O	F6

                        // F6 
                        if( i_usb_key1 == KEY_F6 || i_usb_key2 == KEY_F6 || i_usb_key3 == KEY_F6 || i_usb_key4 == KEY_F6) begin
                            hvc_current_state_col_0[0] <= 0;
                        // O
                        end else if( i_usb_key1 == KEY_O || i_usb_key2 == KEY_O || i_usb_key3 == KEY_O || i_usb_key4 == KEY_O) begin
                            hvc_current_state_col_0[1] <= 0;
                        // L
                        end else if( i_usb_key1 == KEY_L || i_usb_key2 == KEY_L || i_usb_key3 == KEY_L || i_usb_key4 == KEY_L) begin
                            hvc_current_state_col_0[2] <= 0;
                        // K
                        end else if( i_usb_key1 == KEY_K || i_usb_key2 == KEY_K || i_usb_key3 == KEY_K || i_usb_key4 == KEY_K) begin
                            hvc_current_state_col_0[3] <= 0;
                        end
                    end
                    3: begin
                        // Check USB keys:
                        // b4  b3  b2   b1
                        // J	U	I	F5

                        // F5 
                        if( i_usb_key1 == KEY_F5 || i_usb_key2 == KEY_F5 || i_usb_key3 == KEY_F5 || i_usb_key4 == KEY_F5) begin
                            hvc_current_state_col_0[0] <= 0;
                        // I
                        end else if( i_usb_key1 == KEY_I || i_usb_key2 == KEY_I || i_usb_key3 == KEY_I || i_usb_key4 == KEY_I) begin
                            hvc_current_state_col_0[1] <= 0;
                        // U
                        end else if( i_usb_key1 == KEY_U || i_usb_key2 == KEY_U || i_usb_key3 == KEY_U || i_usb_key4 == KEY_U) begin
                            hvc_current_state_col_0[2] <= 0;
                        // J
                        end else if( i_usb_key1 == KEY_J || i_usb_key2 == KEY_J || i_usb_key3 == KEY_J || i_usb_key4 == KEY_J) begin
                            hvc_current_state_col_0[3] <= 0;
                        end
                    end
                    4: begin
                        // Check USB keys:
                        // b4  b3  b2   b1
                        // H	G	Y	F4

                        // F4 
                        if( i_usb_key1 == KEY_F4 || i_usb_key2 == KEY_F4 || i_usb_key3 == KEY_F4 || i_usb_key4 == KEY_F4) begin
                            hvc_current_state_col_0[0] <= 0;
                        // Y
                        end else if( i_usb_key1 == KEY_Y || i_usb_key2 == KEY_Y || i_usb_key3 == KEY_Y || i_usb_key4 == KEY_Y) begin
                            hvc_current_state_col_0[1] <= 0;
                        // G
                        end else if( i_usb_key1 == KEY_G || i_usb_key2 == KEY_G || i_usb_key3 == KEY_G || i_usb_key4 == KEY_G) begin
                            hvc_current_state_col_0[2] <= 0;
                        // H
                        end else if( i_usb_key1 == KEY_H || i_usb_key2 == KEY_H || i_usb_key3 == KEY_H || i_usb_key4 == KEY_H) begin
                            hvc_current_state_col_0[3] <= 0;
                        end
                    end
                    5: begin
                        // Check USB keys:
                        // b4  b3  b2   b1
                        // 	D	R	T	F3

                        // F3
                        if( i_usb_key1 == KEY_F3 || i_usb_key2 == KEY_F3 || i_usb_key3 == KEY_F3 || i_usb_key4 == KEY_F3) begin
                            hvc_current_state_col_0[0] <= 0;
                        // T
                        end else if( i_usb_key1 == KEY_T || i_usb_key2 == KEY_T || i_usb_key3 == KEY_T || i_usb_key4 == KEY_T) begin
                            hvc_current_state_col_0[1] <= 0;
                        // R
                        end else if( i_usb_key1 == KEY_R || i_usb_key2 == KEY_R || i_usb_key3 == KEY_R || i_usb_key4 == KEY_R) begin
                            hvc_current_state_col_0[2] <= 0;
                        // D
                        end else if( i_usb_key1 == KEY_D || i_usb_key2 == KEY_D || i_usb_key3 == KEY_D || i_usb_key4 == KEY_D) begin
                            hvc_current_state_col_0[3] <= 0;
                        end
                    end
                    6: begin
                        // Check USB keys:
                        // b4  b3  b2   b1
                        // 	A	S	W	F2

                        // F2
                        if( i_usb_key1 == KEY_F2 || i_usb_key2 == KEY_F2 || i_usb_key3 == KEY_F2 || i_usb_key4 == KEY_F2) begin
                            hvc_current_state_col_0[0] <= 0;
                        // W
                        end else if( i_usb_key1 == KEY_W || i_usb_key2 == KEY_W || i_usb_key3 == KEY_W || i_usb_key4 == KEY_W) begin
                            hvc_current_state_col_0[1] <= 0;
                        // S
                        end else if( i_usb_key1 == KEY_S || i_usb_key2 == KEY_S || i_usb_key3 == KEY_S || i_usb_key4 == KEY_S) begin
                            hvc_current_state_col_0[2] <= 0;
                            keyboard_buttons[6] <= 0;
                        // A
                        end else if( i_usb_key1 == KEY_A || i_usb_key2 == KEY_A || i_usb_key3 == KEY_A || i_usb_key4 == KEY_A) begin
                            hvc_current_state_col_0[3] <= 0;
                            keyboard_buttons[7] <= 0;
                        end
                    end
                    7: begin
                        // Check USB keys:
                        // b4   b3  b2   b1
                        // CTR	Q	ESC	 F1

                        // F1
                        if( i_usb_key1 == KEY_F1 || i_usb_key2 == KEY_F1 || i_usb_key3 == KEY_F1 || i_usb_key4 == KEY_F1) begin
                            hvc_current_state_col_0[0] <= 0;
                        // ESC
                        end else if( i_usb_key1 == KEY_ESC || i_usb_key2 == KEY_ESC || i_usb_key3 == KEY_ESC || i_usb_key4 == KEY_ESC) begin
                            hvc_current_state_col_0[1] <= 0;
                        // Q
                        end else if( i_usb_key1 == KEY_Q || i_usb_key2 == KEY_Q || i_usb_key3 == KEY_Q || i_usb_key4 == KEY_Q) begin
                            hvc_current_state_col_0[2] <= 0;
                        // CTR
                        end else if( i_usb_key1 == (KEY_LEFTCTRL || KEY_RIGHTCTRL) || i_usb_key2 == (KEY_LEFTCTRL || KEY_RIGHTCTRL) || i_usb_key3 == (KEY_LEFTCTRL || KEY_RIGHTCTRL) || i_usb_key4 == (KEY_LEFTCTRL || KEY_RIGHTCTRL)) begin
                            hvc_current_state_col_0[3] <= 0;
                        end
                    end
                    8: begin
                        // Check USB keys:
                        // b4   b3      b2  b1
                        // LEFT	RIGHT	UP	CLR HOME

                        // RIGHT
                        if( i_usb_key1 == KEY_RIGHT || i_usb_key2 == KEY_RIGHT || i_usb_key3 == KEY_RIGHT || i_usb_key4 == KEY_RIGHT) begin
                            hvc_current_state_col_0[0] <= 0;
                            keyboard_buttons[0] <= 0;
                        // LEFT
                        end else if( i_usb_key1 == KEY_LEFT || i_usb_key2 == KEY_LEFT || i_usb_key3 == KEY_LEFT || i_usb_key4 == KEY_LEFT) begin
                            hvc_current_state_col_0[1] <= 0;
                            keyboard_buttons[1] <= 0;
                        // UP
                        end else if( i_usb_key1 == KEY_UP || i_usb_key2 == KEY_UP || i_usb_key3 == KEY_UP || i_usb_key4 == KEY_UP) begin
                            hvc_current_state_col_0[2] <= 0;
                            keyboard_buttons[3] <= 0;
                        // // CLR HOME
                        // end else if( i_usb_key1 == (8'h4a || 8'h5f) || i_usb_key2 == (8'h4a || 8'h5f) || i_usb_key3 == (8'h4a || 8'h5f) || i_usb_key4 == (8'h4a || 8'h5f)) begin
                        //     hvc_current_state_col_0[3] <= 0;
                        end
                    end
                endcase
                     
            // Select column 1
            end else if (i_register_4016 == KEY_C) begin
                                // Default state 
                hvc_current_state_col_1 <= 4'b1111;

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
                        // if( i_usb_key1 == KEY_4 || i_usb_key2 == KEY_4 || i_usb_key3 == KEY_4 || i_usb_key4 == KEY_4) begin
                        //     hvc_current_state_col_1[1] <= 0;
                        // RSHIFT
                        if( i_usb_key1 == KEY_RIGHTSHIFT || i_usb_key2 == KEY_RIGHTSHIFT || i_usb_key3 == KEY_RIGHTSHIFT || i_usb_key4 == KEY_RIGHTSHIFT) begin
                            hvc_current_state_col_1[2] <= 0;
                        // // KANA
                        // end else if( i_usb_key1 == KEY_RIGHTBRACE || i_usb_key2 == KEY_RIGHTBRACE || i_usb_key3 == KEY_RIGHTBRACE || i_usb_key4 == KEY_RIGHTBRACE) begin
                        //     hvc_current_state_col_1[3] <= 0;
                        // end
                        end
                    end
                    1: begin
                        // Check USB keys:
                        // b4  b3  b2   b1
                        // ^	-	/	_

                        // ^
                        // if( i_usb_key1 == KEY_SEMICOLON || i_usb_key2 == KEY_SEMICOLON || i_usb_key3 == KEY_SEMICOLON || i_usb_key4 == KEY_SEMICOLON) begin
                        //     hvc_current_state_col_1[0] <= 0;
                        // -
                        if( i_usb_key1 == KEY_MINUS || i_usb_key2 == KEY_MINUS || i_usb_key3 == KEY_MINUS || i_usb_key4 == KEY_MINUS) begin
                            hvc_current_state_col_1[1] <= 0;
                        // /
                        end else if( i_usb_key1 == KEY_SLASH || i_usb_key2 == KEY_SLASH || i_usb_key3 == KEY_SLASH || i_usb_key4 == KEY_SLASH) begin
                            hvc_current_state_col_1[2] <= 0;
                        // _
                        // end else if( i_usb_key1 == KEY_SEMICOLON || i_usb_key2 == KEY_SEMICOLON || i_usb_key3 == KEY_SEMICOLON || i_usb_key4 == KEY_SEMICOLON) begin
                        //     hvc_current_state_col_1[3] <= 0;
                        end
                    end
                    2: begin
                        // Check USB keys:
                        // b4  b3  b2   b1
                        // 0	P	,	.

                        // 0 
                        if( i_usb_key1 == KEY_0 || i_usb_key2 == KEY_0 || i_usb_key3 == KEY_0 || i_usb_key4 == KEY_0) begin
                            hvc_current_state_col_1[0] <= 0;
                        // P
                        end else if( i_usb_key1 == KEY_P || i_usb_key2 == KEY_P || i_usb_key3 == KEY_P || i_usb_key4 == KEY_P) begin
                            hvc_current_state_col_1[1] <= 0;
                        // ,
                        end else if( i_usb_key1 == KEY_COMMA || i_usb_key2 == KEY_COMMA || i_usb_key3 == KEY_COMMA || i_usb_key4 == KEY_COMMA) begin
                            hvc_current_state_col_1[2] <= 0;
                        // .
                        end else if( i_usb_key1 == KEY_KPDOT || i_usb_key2 == KEY_KPDOT || i_usb_key3 == KEY_KPDOT || i_usb_key4 == KEY_KPDOT) begin
                            hvc_current_state_col_1[3] <= 0;
                        end
                    end
                    3: begin
                        // Check USB keys:
                        // b4   b3  b2   b1
                        // 8    9	N	 M

                        // 8 
                        if( i_usb_key1 == KEY_8 || i_usb_key2 == KEY_8 || i_usb_key3 == KEY_8 || i_usb_key4 == KEY_8) begin
                            hvc_current_state_col_1[0] <= 0;
                        // 9
                        end else if( i_usb_key1 == KEY_9 || i_usb_key2 == KEY_9 || i_usb_key3 == KEY_9 || i_usb_key4 == KEY_9) begin
                            hvc_current_state_col_1[1] <= 0;
                        // N
                        end else if( i_usb_key1 == KEY_N || i_usb_key2 == KEY_N || i_usb_key3 == KEY_N || i_usb_key4 == KEY_N) begin
                            hvc_current_state_col_1[2] <= 0;
                        // M
                        end else if( i_usb_key1 == KEY_M || i_usb_key2 == KEY_M || i_usb_key3 == KEY_M || i_usb_key4 == KEY_M) begin
                            hvc_current_state_col_1[3] <= 0;
                        end
                    end
                    4: begin
                        // Check USB keys:
                        // b4  b3  b2   b1
                        // 6	7	V	B

                        // 6
                        if( i_usb_key1 == KEY_6 || i_usb_key2 == KEY_6 || i_usb_key3 == KEY_6 || i_usb_key4 == KEY_6) begin
                            hvc_current_state_col_1[0] <= 0;
                        // 7
                        end else if( i_usb_key1 == KEY_7 || i_usb_key2 == KEY_7 || i_usb_key3 == KEY_7 || i_usb_key4 == KEY_7) begin
                            hvc_current_state_col_1[1] <= 0;
                        // V
                        end else if( i_usb_key1 == KEY_V || i_usb_key2 == KEY_V || i_usb_key3 == KEY_V || i_usb_key4 == KEY_V) begin
                            hvc_current_state_col_1[2] <= 0;
                        // B
                        end else if( i_usb_key1 == KEY_B || i_usb_key2 == KEY_B || i_usb_key3 == KEY_B || i_usb_key4 == KEY_B) begin
                            hvc_current_state_col_1[3] <= 0;
                        end
                    end
                    5: begin
                        // Check USB keys:
                        // b4  b3  b2   b1
                        // 4	5	C	F

                        // 4
                        if( i_usb_key1 == KEY_4 || i_usb_key2 == KEY_4 || i_usb_key3 == KEY_4 || i_usb_key4 == KEY_4) begin
                            hvc_current_state_col_1[0] <= 0;
                        // 5
                        end else if( i_usb_key1 == KEY_5 || i_usb_key2 == KEY_5 || i_usb_key3 == KEY_5 || i_usb_key4 == KEY_5) begin
                            hvc_current_state_col_1[1] <= 0;
                        // C
                        end else if( i_usb_key1 == KEY_C || i_usb_key2 == KEY_C || i_usb_key3 == KEY_C || i_usb_key4 == KEY_C) begin
                            hvc_current_state_col_1[2] <= 0;
                        // F
                        end else if( i_usb_key1 == KEY_F || i_usb_key2 == KEY_F || i_usb_key3 == KEY_F || i_usb_key4 == KEY_F) begin
                            hvc_current_state_col_1[3] <= 0;
                        end
                    end
                    6: begin
                        // Check USB keys:
                        // b4   b3  b2   b1
                        // 3	E	Z	X

                        // 3
                        if( i_usb_key1 == KEY_3 || i_usb_key2 == KEY_3 || i_usb_key3 == KEY_3 || i_usb_key4 == KEY_3) begin
                            hvc_current_state_col_1[0] <= 0;
                        // E
                        end else if( i_usb_key1 == KEY_E || i_usb_key2 == KEY_E || i_usb_key3 == KEY_E || i_usb_key4 == KEY_E) begin
                            hvc_current_state_col_1[1] <= 0;
                        // Z
                        end else if( i_usb_key1 == KEY_Z || i_usb_key2 == KEY_Z || i_usb_key3 == KEY_Z || i_usb_key4 == KEY_Z) begin
                            hvc_current_state_col_1[2] <= 0;
                        // X
                        end else if( i_usb_key1 == KEY_X || i_usb_key2 == KEY_X || i_usb_key3 == KEY_X || i_usb_key4 == KEY_X) begin
                            hvc_current_state_col_1[3] <= 0;
                        end
                    end
                    7: begin
                        // Check USB keys:
                        // b4   b3  b2   b1
                        // 2	1	GRPH	LSHIFT

                        // 2
                        if( i_usb_key1 == KEY_2 || i_usb_key2 == KEY_2 || i_usb_key3 == KEY_2 || i_usb_key4 == KEY_2 ) begin
                            hvc_current_state_col_1[0] <= 0;
                        // 1
                        end else if( i_usb_key1 == KEY_1 || i_usb_key2 == KEY_1 || i_usb_key3 == KEY_1 || i_usb_key4 == KEY_1 ) begin
                            hvc_current_state_col_1[1] <= 0;
                        // GRPH
                        end else if( i_usb_key1 == KEY_SYSRQ || i_usb_key2 == KEY_SYSRQ || i_usb_key3 == KEY_SYSRQ || i_usb_key4 == KEY_SYSRQ ) begin
                            hvc_current_state_col_1[2] <= 0;
                        // LSHIFT
                        end else if( i_usb_key1 == KEY_LEFTSHIFT || i_usb_key2 == KEY_LEFTSHIFT || i_usb_key3 == KEY_LEFTSHIFT || i_usb_key4 == KEY_LEFTSHIFT ) begin
                            hvc_current_state_col_1[3] <= 0;
                        end
                    end
                    8: begin
                        // Check USB keys:
                        // b4   b3      b2  b1
                        // INS	DEL	SPACE	DOWN

                        // INS
                        if( i_usb_key1 == KEY_INSERT || i_usb_key2 == KEY_INSERT || i_usb_key3 == KEY_INSERT || i_usb_key4 == KEY_INSERT) begin
                            hvc_current_state_col_1[0] <= 0;
                        // DEL (BACKSPACE)
                        end else if( i_usb_key1 == KEY_BACKSPACE || i_usb_key2 == KEY_BACKSPACE || i_usb_key3 == KEY_BACKSPACE || i_usb_key4 == KEY_BACKSPACE) begin
                            hvc_current_state_col_1[1] <= 0;
                        // SPACE
                        end else if( i_usb_key1 == KEY_SPACE || i_usb_key2 == KEY_SPACE || i_usb_key3 == KEY_SPACE || i_usb_key4 == KEY_SPACE) begin
                            hvc_current_state_col_1[2] <= 0;
                            keyboard_buttons[5] <= 0;
                        // DOWN
                        end else if( i_usb_key1 == KEY_DOWN || i_usb_key2 == KEY_DOWN || i_usb_key3 == KEY_DOWN || i_usb_key4 == KEY_DOWN) begin
                            hvc_current_state_col_1[3] <= 0;
                            keyboard_buttons[2] <= 0;
                        end
                    end
                endcase

                hvc_row <= hvc_row + 1;
                if(hvc_row == 9)
                    hvc_row <= 9;


            end
        end
    end
end

assign o_register_4017[4:1] = read_data_from_column_0 ? hvc_current_state_col_0 : (read_data_from_column_1 ? hvc_current_state_col_1 : 4'b1111);
assign o_keyboard_buttons = keyboard_buttons;

endmodule