
// Simple autofire mechanism. When 'btn' is high, 'out' will toggle betwen 1 and 0 at a rate of FIRERATE

module Autofire #(
    parameter FREQ = 37_800_000,
    parameter FIRERATE = 10
) (
    input clk,
    input resetn,
    input btn,
    output reg out
);

`ifdef FORMAL
localparam DELAY = 20;
`else
localparam DELAY = FREQ / FIRERATE / 2;
`endif
reg [$clog2(DELAY)-1:0] timer;
initial timer = 0;

always @(posedge clk) begin
    if (~resetn) begin
        timer <= 0;
        out <= 0;
    end else begin
        if (btn) begin
            timer <= timer + 1;
            if (timer == 0) out <= ~out;
            if (timer == DELAY-1) timer <= 0;
        end else begin
            timer <= 0;
            out <= 0;
        end
    end
end

//
// Formal verification
//
`ifdef	FORMAL

    `ifdef AUTOFIRE
        `define	ASSUME	assume
    `else
        `define	ASSUME	assert
    `endif

    // f_past_valid
    reg	f_past_valid;
    initial	f_past_valid = 1'b0;
    always @(posedge clk)
        f_past_valid <= 1'b1;

    always @(*)
        if((f_past_valid)&&(resetn))
            assert(timer <= (DELAY-1));

    always @(posedge clk)
        if((f_past_valid)&&(!$past(resetn))) begin
            assert(timer == 0);
            assert(out == 0);
        end

    // 
    // Contract
    // 
    always @(posedge clk) begin
        if((f_past_valid)&&(resetn)&&(btn || $past(btn))&&($past(timer) == 0))
            assert(out <= ~$past(out));
    end

`endif // FORMAL

endmodule