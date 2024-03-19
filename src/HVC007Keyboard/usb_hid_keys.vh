/**
 * USB HID Keyboard scan codes as per USB spec 1.11
 * plus some additional codes
 * 
 * Created by MightyPork, 2016
 * Public domain
 * 
 * Adapted from:
 * https://source.android.com/devices/input/keyboard-devices.html
 */


/**
 * Modifier masks - used for the first byte in the HID report.
 * NOTE: The second byte in the report is reserved, 8'h00
 */
parameter  [7:0] KEY_MOD_LCTRL  = 8'h01;
parameter  [7:0] KEY_MOD_LSHIFT = 8'h02;
parameter  [7:0] KEY_MOD_LALT   = 8'h04;
parameter  [7:0] KEY_MOD_LMETA  = 8'h08;
parameter  [7:0] KEY_MOD_RCTRL  = 8'h10;
parameter  [7:0] KEY_MOD_RSHIFT = 8'h20;
parameter  [7:0] KEY_MOD_RALT   = 8'h40;
parameter  [7:0] KEY_MOD_RMETA  = 8'h80;

/**
 * Scan codes - last N slots in the HID report (usually 6).
 * 8'h00 if no key pressed.
 * 
 * If more than N keys are pressed, the HID reports 
 * KEY_ERR_OVF in all slots to indicate this condition.
 */

parameter  [7:0] KEY_NONE       = 8'h00; // No key pressed
parameter  [7:0] KEY_ERR_OVF    = 8'h01; //  Keyboard Error Roll Over - used for all slots if too many keys are pressed ("Phantom key")
// 8'h02 //  Keyboard POST Fail
// 8'h03 //  Keyboard Error Undefined
parameter  [7:0] KEY_A = 8'h04; // Keyboard a and A
parameter  [7:0] KEY_B = 8'h05; // Keyboard b and B
parameter  [7:0] KEY_C = 8'h06; // Keyboard c and C
parameter  [7:0] KEY_D = 8'h07; // Keyboard d and D
parameter  [7:0] KEY_E = 8'h08; // Keyboard e and E
parameter  [7:0] KEY_F = 8'h09; // Keyboard f and F
parameter  [7:0] KEY_G = 8'h0a; // Keyboard g and G
parameter  [7:0] KEY_H = 8'h0b; // Keyboard h and H
parameter  [7:0] KEY_I = 8'h0c; // Keyboard i and I
parameter  [7:0] KEY_J = 8'h0d; // Keyboard j and J
parameter  [7:0] KEY_K = 8'h0e; // Keyboard k and K
parameter  [7:0] KEY_L = 8'h0f; // Keyboard l and L
parameter  [7:0] KEY_M = 8'h10; // Keyboard m and M
parameter  [7:0] KEY_N = 8'h11; // Keyboard n and N
parameter  [7:0] KEY_O = 8'h12; // Keyboard o and O
parameter  [7:0] KEY_P = 8'h13; // Keyboard p and P
parameter  [7:0] KEY_Q = 8'h14; // Keyboard q and Q
parameter  [7:0] KEY_R = 8'h15; // Keyboard r and R
parameter  [7:0] KEY_S = 8'h16; // Keyboard s and S
parameter  [7:0] KEY_T = 8'h17; // Keyboard t and T
parameter  [7:0] KEY_U = 8'h18; // Keyboard u and U
parameter  [7:0] KEY_V = 8'h19; // Keyboard v and V
parameter  [7:0] KEY_W = 8'h1a; // Keyboard w and W
parameter  [7:0] KEY_X = 8'h1b; // Keyboard x and X
parameter  [7:0] KEY_Y = 8'h1c; // Keyboard y and Y
parameter  [7:0] KEY_Z = 8'h1d; // Keyboard z and Z

parameter  [7:0] KEY_1 = 8'h1e; // Keyboard 1 and !
parameter  [7:0] KEY_2 = 8'h1f; // Keyboard 2 and @
parameter  [7:0] KEY_3 = 8'h20; // Keyboard 3 and #
parameter  [7:0] KEY_4 = 8'h21; // Keyboard 4 and $
parameter  [7:0] KEY_5 = 8'h22; // Keyboard 5 and %
parameter  [7:0] KEY_6 = 8'h23; // Keyboard 6 and ^
parameter  [7:0] KEY_7 = 8'h24; // Keyboard 7 and &
parameter  [7:0] KEY_8 = 8'h25; // Keyboard 8 and *
parameter  [7:0] KEY_9 = 8'h26; // Keyboard 9 and (
parameter  [7:0] KEY_0 = 8'h27; // Keyboard 0 and )

parameter  [7:0] KEY_ENTER        = 8'h28; // Keyboard Return (ENTER)
parameter  [7:0] KEY_ESC          = 8'h29; // Keyboard ESCAPE
parameter  [7:0] KEY_BACKSPACE    = 8'h2a; // Keyboard DELETE (Backspace)
parameter  [7:0] KEY_TAB          = 8'h2b; // Keyboard Tab
parameter  [7:0] KEY_SPACE        = 8'h2c; // Keyboard Spacebar
parameter  [7:0] KEY_MINUS        = 8'h2d; // Keyboard - and _
parameter  [7:0] KEY_EQUAL        = 8'h2e; // Keyboard = and +
parameter  [7:0] KEY_LEFTBRACE    = 8'h2f; // Keyboard [ and {
parameter  [7:0] KEY_RIGHTBRACE   = 8'h30; // Keyboard ] and }
parameter  [7:0] KEY_BACKSLASH    = 8'h31; // Keyboard \ and |
parameter  [7:0] KEY_HASHTILDE    = 8'h32; // Keyboard Non-US # and ~
parameter  [7:0] KEY_SEMICOLON    = 8'h33; // Keyboard ; and :
parameter  [7:0] KEY_APOSTROPHE   = 8'h34; // Keyboard ' and "
parameter  [7:0] KEY_GRAVE        = 8'h35; // Keyboard ` and ~
parameter  [7:0] KEY_COMMA        = 8'h36; // Keyboard , and <
parameter  [7:0] KEY_DOT          = 8'h37; // Keyboard . and >
parameter  [7:0] KEY_SLASH        = 8'h38; // Keyboard / and ?
parameter  [7:0] KEY_CAPSLOCK     = 8'h39; // Keyboard Caps Lock

parameter  [7:0] KEY_F1   = 8'h3a; // Keyboard F1
parameter  [7:0] KEY_F2   = 8'h3b; // Keyboard F2
parameter  [7:0] KEY_F3   = 8'h3c; // Keyboard F3
parameter  [7:0] KEY_F4   = 8'h3d; // Keyboard F4
parameter  [7:0] KEY_F5   = 8'h3e; // Keyboard F5
parameter  [7:0] KEY_F6   = 8'h3f; // Keyboard F6
parameter  [7:0] KEY_F7   = 8'h40; // Keyboard F7
parameter  [7:0] KEY_F8   = 8'h41; // Keyboard F8
parameter  [7:0] KEY_F9   = 8'h42; // Keyboard F9
parameter  [7:0] KEY_F10  = 8'h43; // Keyboard F10
parameter  [7:0] KEY_F11  = 8'h44; // Keyboard F11
parameter  [7:0] KEY_F12  = 8'h45; // Keyboard F12

parameter  [7:0] KEY_SYSRQ        = 8'h46; // Keyboard Print Screen
parameter  [7:0] KEY_SCROLLLOCK   = 8'h47; // Keyboard Scroll Lock
parameter  [7:0] KEY_PAUSE        = 8'h48; // Keyboard Pause
parameter  [7:0] KEY_INSERT       = 8'h49; // Keyboard Insert
parameter  [7:0] KEY_HOME         = 8'h4a; // Keyboard Home
parameter  [7:0] KEY_PAGEUP       = 8'h4b; // Keyboard Page Up
parameter  [7:0] KEY_DELETE       = 8'h4c; // Keyboard Delete Forward
parameter  [7:0] KEY_END          = 8'h4d; // Keyboard End
parameter  [7:0] KEY_PAGEDOWN     = 8'h4e; // Keyboard Page Down
parameter  [7:0] KEY_RIGHT        = 8'h4f; // Keyboard Right Arrow
parameter  [7:0] KEY_LEFT         = 8'h50; // Keyboard Left Arrow
parameter  [7:0] KEY_DOWN         = 8'h51; // Keyboard Down Arrow
parameter  [7:0] KEY_UP           = 8'h52; // Keyboard Up Arrow

parameter  [7:0] KEY_NUMLOCK      = 8'h53; // Keyboard Num Lock and Clear
parameter  [7:0] KEY_KPSLASH      = 8'h54; // Keypad /
parameter  [7:0] KEY_KPASTERISK   = 8'h55; // Keypad *
parameter  [7:0] KEY_KPMINUS      = 8'h56; // Keypad -
parameter  [7:0] KEY_KPPLUS       = 8'h57; // Keypad +
parameter  [7:0] KEY_KPENTER      = 8'h58; // Keypad ENTER
parameter  [7:0] KEY_KP1          = 8'h59; // Keypad 1 and End
parameter  [7:0] KEY_KP2          = 8'h5a; // Keypad 2 and Down Arrow
parameter  [7:0] KEY_KP3          = 8'h5b; // Keypad 3 and PageDn
parameter  [7:0] KEY_KP4          = 8'h5c; // Keypad 4 and Left Arrow
parameter  [7:0] KEY_KP5          = 8'h5d; // Keypad 5
parameter  [7:0] KEY_KP6          = 8'h5e; // Keypad 6 and Right Arrow
parameter  [7:0] KEY_KP7          = 8'h5f; // Keypad 7 and Home
parameter  [7:0] KEY_KP8          = 8'h60; // Keypad 8 and Up Arrow
parameter  [7:0] KEY_KP9          = 8'h61; // Keypad 9 and Page Up
parameter  [7:0] KEY_KP0          = 8'h62; // Keypad 0 and Insert
parameter  [7:0] KEY_KPDOT        = 8'h63; // Keypad . and Delete

parameter  [7:0] KEY_102ND        = 8'h64; // Keyboard Non-US \ and |
parameter  [7:0] KEY_COMPOSE      = 8'h65; // Keyboard Application
parameter  [7:0] KEY_POWER        = 8'h66; // Keyboard Power
parameter  [7:0] KEY_KPEQUAL      = 8'h67; // Keypad =

parameter  [7:0] KEY_F13 = 8'h68; // Keyboard F13
parameter  [7:0] KEY_F14 = 8'h69; // Keyboard F14
parameter  [7:0] KEY_F15 = 8'h6a; // Keyboard F15
parameter  [7:0] KEY_F16 = 8'h6b; // Keyboard F16
parameter  [7:0] KEY_F17 = 8'h6c; // Keyboard F17
parameter  [7:0] KEY_F18 = 8'h6d; // Keyboard F18
parameter  [7:0] KEY_F19 = 8'h6e; // Keyboard F19
parameter  [7:0] KEY_F20 = 8'h6f; // Keyboard F20
parameter  [7:0] KEY_F21 = 8'h70; // Keyboard F21
parameter  [7:0] KEY_F22 = 8'h71; // Keyboard F22
parameter  [7:0] KEY_F23 = 8'h72; // Keyboard F23
parameter  [7:0] KEY_F24 = 8'h73; // Keyboard F24

parameter  [7:0] KEY_OPEN         = 8'h74; // Keyboard Execute
parameter  [7:0] KEY_HELP         = 8'h75; // Keyboard Help
parameter  [7:0] KEY_PROPS        = 8'h76; // Keyboard Menu
parameter  [7:0] KEY_FRONT        = 8'h77; // Keyboard Select
parameter  [7:0] KEY_STOP         = 8'h78; // Keyboard Stop
parameter  [7:0] KEY_AGAIN        = 8'h79; // Keyboard Again
parameter  [7:0] KEY_UNDO         = 8'h7a; // Keyboard Undo
parameter  [7:0] KEY_CUT          = 8'h7b; // Keyboard Cut
parameter  [7:0] KEY_COPY         = 8'h7c; // Keyboard Copy
parameter  [7:0] KEY_PASTE        = 8'h7d; // Keyboard Paste
parameter  [7:0] KEY_FIND         = 8'h7e; // Keyboard Find
parameter  [7:0] KEY_MUTE         = 8'h7f; // Keyboard Mute
parameter  [7:0] KEY_VOLUMEUP     = 8'h80; // Keyboard Volume Up
parameter  [7:0] KEY_VOLUMEDOWN   = 8'h81; // Keyboard Volume Down
// 8'h82  Keyboard Locking Caps Lock
// 8'h83  Keyboard Locking Num Lock
// 8'h84  Keyboard Locking Scroll Lock
parameter  [7:0] KEY_KPCOMMA = 8'h85; // Keypad Comma
// 8'h86  Keypad Equal Sign
parameter  [7:0] KEY_RO               = 8'h87; // Keyboard International1
parameter  [7:0] KEY_KATAKANAHIRAGANA = 8'h88; // Keyboard International2
parameter  [7:0] KEY_YEN              = 8'h89; // Keyboard International3
parameter  [7:0] KEY_HENKAN           = 8'h8a; // Keyboard International4
parameter  [7:0] KEY_MUHENKAN         = 8'h8b; // Keyboard International5
parameter  [7:0] KEY_KPJPCOMMA        = 8'h8c; // Keyboard International6
// 8'h8d  Keyboard International7
// 8'h8e  Keyboard International8
// 8'h8f  Keyboard International9
parameter  [7:0] KEY_HANGEUL          = 8'h90; // Keyboard LANG1
parameter  [7:0] KEY_HANJA            = 8'h91; // Keyboard LANG2
parameter  [7:0] KEY_KATAKANA         = 8'h92; // Keyboard LANG3
parameter  [7:0] KEY_HIRAGANA         = 8'h93; // Keyboard LANG4
parameter  [7:0] KEY_ZENKAKUHANKAKU   = 8'h94; // Keyboard LANG5
// 8'h95  Keyboard LANG6
// 8'h96  Keyboard LANG7
// 8'h97  Keyboard LANG8
// 8'h98  Keyboard LANG9
// 8'h99  Keyboard Alternate Erase
// 8'h9a  Keyboard SysReq/Attention
// 8'h9b  Keyboard Cancel
// 8'h9c  Keyboard Clear
// 8'h9d  Keyboard Prior
// 8'h9e  Keyboard Return
// 8'h9f  Keyboard Separator
// 8'ha0  Keyboard Out
// 8'ha1  Keyboard Oper
// 8'ha2  Keyboard Clear/Again
// 8'ha3  Keyboard CrSel/Props
// 8'ha4  Keyboard ExSel

// 8'hb0  Keypad 00
// 8'hb1  Keypad 000
// 8'hb2  Thousands Separator
// 8'hb3  Decimal Separator
// 8'hb4  Currency Unit
// 8'hb5  Currency Sub-unit
parameter  [7:0] KEY_KPLEFTPAREN  = 8'hb60; // Keypad (
parameter  [7:0] KEY_KPRIGHTPAREN = 8'hb70; // Keypad )
// 8'hb8  Keypad {
// 8'hb9  Keypad }
// 8'hba  Keypad Tab
// 8'hbb  Keypad Backspace
// 8'hbc  Keypad A
// 8'hbd  Keypad B
// 8'hbe  Keypad C
// 8'hbf  Keypad D
// 8'hc0  Keypad E
// 8'hc1  Keypad F
// 8'hc2  Keypad XOR
// 8'hc3  Keypad ^
// 8'hc4  Keypad %
// 8'hc5  Keypad <
// 8'hc6  Keypad >
// 8'hc7  Keypad &
// 8'hc8  Keypad &&
// 8'hc9  Keypad |
// 8'hca  Keypad ||
// 8'hcb  Keypad :
// 8'hcc  Keypad #
// 8'hcd  Keypad Space
// 8'hce  Keypad @
// 8'hcf  Keypad !
// 8'hd0  Keypad Memory Store
// 8'hd1  Keypad Memory Recall
// 8'hd2  Keypad Memory Clear
// 8'hd3  Keypad Memory Add
// 8'hd4  Keypad Memory Subtract
// 8'hd5  Keypad Memory Multiply
// 8'hd6  Keypad Memory Divide
// 8'hd7  Keypad +/-
// 8'hd8  Keypad Clear
// 8'hd9  Keypad Clear Entry
// 8'hda  Keypad Binary
// 8'hdb  Keypad Octal
// 8'hdc  Keypad Decimal
// 8'hdd  Keypad Hexadecimal

parameter  [7:0] KEY_LEFTCTRL     = 8'he0; // Keyboard Left Control
parameter  [7:0] KEY_LEFTSHIFT    = 8'he1; // Keyboard Left Shift
parameter  [7:0] KEY_LEFTALT      = 8'he2; // Keyboard Left Alt
parameter  [7:0] KEY_LEFTMETA     = 8'he3; // Keyboard Left GUI
parameter  [7:0] KEY_RIGHTCTRL    = 8'he4; // Keyboard Right Control
parameter  [7:0] KEY_RIGHTSHIFT   = 8'he5; // Keyboard Right Shift
parameter  [7:0] KEY_RIGHTALT     = 8'he6; // Keyboard Right Alt
parameter  [7:0] KEY_RIGHTMETA    = 8'he7; // Keyboard Right GUI

parameter  [7:0] KEY_MEDIA_PLAYPAUSE      = 8'he8;
parameter  [7:0] KEY_MEDIA_STOPCD         = 8'he9;
parameter  [7:0] KEY_MEDIA_PREVIOUSSONG   = 8'hea;
parameter  [7:0] KEY_MEDIA_NEXTSONG       = 8'heb;
parameter  [7:0] KEY_MEDIA_EJECTCD        = 8'hec;
parameter  [7:0] KEY_MEDIA_VOLUMEUP       = 8'hed;
parameter  [7:0] KEY_MEDIA_VOLUMEDOWN     = 8'hee;
parameter  [7:0] KEY_MEDIA_MUTE           = 8'hef;
parameter  [7:0] KEY_MEDIA_WWW            = 8'hf0;
parameter  [7:0] KEY_MEDIA_BACK           = 8'hf1;
parameter  [7:0] KEY_MEDIA_FORWARD        = 8'hf2;
parameter  [7:0] KEY_MEDIA_STOP           = 8'hf3;
parameter  [7:0] KEY_MEDIA_FIND           = 8'hf4;
parameter  [7:0] KEY_MEDIA_SCROLLUP       = 8'hf5;
parameter  [7:0] KEY_MEDIA_SCROLLDOWN     = 8'hf6;
parameter  [7:0] KEY_MEDIA_EDIT           = 8'hf7;
parameter  [7:0] KEY_MEDIA_SLEEP          = 8'hf8;
parameter  [7:0] KEY_MEDIA_COFFEE         = 8'hf9;
parameter  [7:0] KEY_MEDIA_REFRESH        = 8'hfa;
parameter  [7:0] KEY_MEDIA_CALC           = 8'hfb;