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

initial led = 0;
initial wb_ack = 0;
initial wb_stall = 0;
initial wb_err = 0;
initial wb_odata = 0;

always @(posedge i_clk) begin
    if((~i_reset_n)||(~i_wb_err)) begin
        wb_err <= 1'b0;
        led <= 1'b0;
        wb_stall <= 1'b0;
    end else begin
        if(i_reset_n)
            if((i_wb_stb)&&(i_wb_cyc)&&(i_wb_we)&&(~i_wb_err)&&(i_wb_addr == 1)&&(~wb_stall)) begin
                led <= !i_wb_idata[0];
                wb_odata <= i_wb_idata;
            end
    end
end

assign o_wb_ack = i_wb_stb;
assign o_led = led;
assign o_wb_stall = wb_stall;
assign o_wb_err = wb_err;
assign o_wb_odata = wb_odata;

`ifdef FORMAL
    // f_past_valid
	reg	f_past_valid;
	initial	f_past_valid = 1'b0;
	initial assert(!f_past_valid);
	always @(posedge i_clk)
		f_past_valid = 1'b1;

    // BMC Assumptions
    always @(posedge i_clk)
        if((f_past_valid)&&((~$past(i_reset_n))||(~$past(i_wb_err)))) begin
            assume(i_wb_addr == 2'b1);
            assume($stable(i_wb_addr));
            assume($stable(i_wb_idata));
        end

    always @(posedge i_clk)
        if((f_past_valid)&&(~$past(f_past_valid))) begin
            assume(i_wb_stb);
            assume(i_wb_we);
            assume(~i_wb_err);
            assume(~i_wb_cyc);
        end else begin
            assume(~i_wb_stb);
            assume(~i_wb_we);
            assume(~i_wb_err);
            assume(i_wb_cyc);
        end




    // BMC Assertions
    always @(posedge i_clk)
        if((f_past_valid)&&($past(f_past_valid))&&((~$past(i_reset_n))||(~$past(i_wb_err)))) begin
            assert(wb_err == 1'b0);
            assert(led == 1'b0);
            assert(wb_stall == 1'b0);
        end

    // Cover

    // Contract
    always @(posedge i_clk)
        if((f_past_valid)&&($past(i_reset_n))&&(i_reset_n)&&(($past(i_wb_stb))&&($past(i_wb_cyc))&&($past(i_wb_we))&&(~$past(i_wb_err))&&($past(i_wb_addr) == 1))) begin
            assert(led == !i_wb_idata[0]);
            assert(wb_odata == i_wb_idata);
        end

    always @(posedge i_clk)
        if((f_past_valid)&&($past(f_past_valid))&&((~$past(i_reset_n))||(~$past(i_wb_err))))
            if(i_wb_stb)
                assert(o_wb_ack);
    
    // Induction assumptions

    // Induction assertions
    

`endif // FORMAL

endmodule