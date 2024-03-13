// HVC007KEyboard module to convert USB keyboard to HVC-007 standard
// @fjpolo March, 2024
//
// References:
// - https://www.nesdev.org/wiki/Family_BASIC_Keyboard
// - http://cmpslv2.starfree.jp/Famic/Fambas.htm
// - https://www.nesdev.org/wiki/Expansion_port
// - https://forums.nesdev.org/viewtopic.php?t=23656

module HVC007Keyboard(
input i_clk,                                // System clock
    input i_ce,                             // Chip Enable
    input i_reset,                          // System reset
    // USB keyboard
    input [7:0] i_usb_keyboard_data,        // Data coming from USB keyboard
    // HVC-007 Keyboard
    input i_reset_first_row,                // $4016 b0
    input i_Select_column_row_increment,    // $4016 b1
    input i_keyboard_matrix_enable,         // $4016 b2
    output [3:0] o_hvc007_keyboard_data,    // $4017 [b3:b1]
);

endmodule