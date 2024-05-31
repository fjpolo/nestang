`default_nettype none

module wishbone_slave #(
                            `include "wishbone_slaves.vh"
                        )
                        (
                            input wire i_clk,
                            input wire i_reset_n,
                            output wire o_led,
                            // Wishbone slave
                            input wire i_wb_cyc,
                            input wire i_wb_stb,
                            input wire i_wb_we,
                            input wire i_wb_err,
                            input wire [1:0] i_wb_addr,
                            input wire [31:0] i_wb_idata,
                            output wire o_wb_ack,
                            output wire o_wb_stall,
                            output wire o_wb_err,
                            output wire [31:0]  o_wb_odata
                     );
reg led;
reg wb_ack;
reg wb_stall;
reg wb_err;
reg [31:0] wb_odata;

always @(posedge i_clk) begin
    if((~i_reset_n)||(~i_wb_err)) begin
        wb_err <= 1'b0;
        led <= 1'b0;
        wb_stall <= 1'b0;
    end else begin
        if((i_wb_stb)&&(i_wb_cyc)&&(i_wb_we)&&(~i_wb_err)&&(i_wb_addr == 1))
            led <= i_wb_idata[0];
            wb_odata <= i_wb_idata;
    end
end

assign o_wb_ack = i_wb_stb;
assign o_led = led;
assign o_wb_stall = wb_stall;
assign o_wb_err = wb_err;
assign o_wb_odata = wb_odata;

endmodule