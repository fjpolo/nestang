
// NES classic gamepad based on https://github.com/michael-swan/NES-Controller-SIPO
// fjpolo, 11.2023

module NESGamepad(
		input i_clk,
        input i_rst_n,
		// Device connections
		output o_data_clock,
		output o_data_latch,
		input i_serial_data,
		// Data output
		output [7:0] o_button_state,
		output o_data_available
   );
	parameter NUMBER_OF_STATES = 10;    // Latch -> 2 * 60uS
										// Data -> 8 * 2 * 60uS
										// Write -> 2 * 60uS
    parameter LAST_STATE = NUMBER_OF_STATES-1;
	
	// Unit Parameters //
	parameter Hz  = 1;
	parameter KHz = 1000*Hz;
	parameter MHz = 1000*KHz;
	
	// Context-sensitive Parameters //
	parameter MASTER_CLOCK_FREQUENCY = 27*MHz; // USER VARIABLE
	parameter OUTPUT_UPDATE_FREQUENCY = 120*Hz; // USER VARIABLE
    parameter LATCH_CYCLES = (12 / 1000000) * (1 / MASTER_CLOCK_FREQUENCY);
	parameter LATCH_120uS_CYCLES = 324;
	
	// Clock divider register size
	// parameter DIVIDER_EXPONENT = log2( (MASTER_CLOCK_FREQUENCY / OUTPUT_UPDATE_FREQUENCY) / 10 ) - 2;
	parameter COUNTER_60Hz = 225000;	
	parameter COUNTER_120uS = 1620;	
	parameter COUNTER_120uS_HALF = 810;	
	parameter BUSY_CYCLES = 2 * NUMBER_OF_STATES * COUNTER_120uS;	

	// Keep track of the stage of the cycle
	reg [(LAST_STATE):0] cycle_stage;	// Latch 120uS -> Wait 60uS -> Data 8x120uS -> End
	reg [7:0] data;
	reg [20:0] clock_counter_60Hz;
	reg [20:0] clock_counter_120uS;
    reg [7:0] button_state;
	wire clock_60Hz;
	wire clock_120uS;

	// Generate control signals for the three states
	wire latch_state = cycle_stage[0] & (clock_counter_60Hz <= (2 * NUMBER_OF_STATES * COUNTER_120uS + NUMBER_OF_STATES));
    wire data_state = cycle_stage[1] 
                    | cycle_stage[2] 
                    | cycle_stage[3] 
                    | cycle_stage[4] 
                    | cycle_stage[5] 
                    | cycle_stage[6] 
                    | cycle_stage[7]
                    | cycle_stage[8];	
    wire write_state = cycle_stage[9];
    
	// Generate a clock for generating the data clock and sampling the controller's output
    initial cycle_stage = 1;
	initial data = 8'h00;
    initial button_state = 8'h00;
	initial clock_counter_60Hz = 0;
	initial clock_counter_120uS = 0;

    // Handle 60Hz clock counter
	always @(posedge i_clk) begin
        if(!i_rst_n) begin
			clock_counter_60Hz <= 0;
		end else begin
			if(clock_counter_60Hz < (2 * COUNTER_60Hz)) begin
				clock_counter_60Hz <= clock_counter_60Hz + 1;
			end else begin
				clock_counter_60Hz <= 0;
			end
		end
	end

    // Handle 60Hz clock
	assign clock_60Hz = (clock_counter_60Hz < COUNTER_60Hz);

	// Handle 120uS clock counter
	always @(posedge i_clk) begin
		if(!i_rst_n) begin
			clock_counter_120uS <= 0;
			cycle_stage <= 1;
            data <= 8'h00;  
            button_state <= 8'h00;
		end else begin
            // Counter
            if((clock_counter_60Hz > 0) && (clock_counter_60Hz <= (2 * NUMBER_OF_STATES * COUNTER_120uS + NUMBER_OF_STATES))) begin
				if(clock_counter_120uS < (2 * COUNTER_120uS)) begin
					clock_counter_120uS <= clock_counter_120uS + 1;
				end else begin
					clock_counter_120uS <= 0;
						if(cycle_stage < (1 << LAST_STATE) && (cycle_stage != 0))
							cycle_stage <= cycle_stage << 1;
						else
							cycle_stage <= 1;
				end
			end else begin
				clock_counter_120uS <= 0;
			end

            // Handle button output
            if(!clock_120uS) begin
                // data <= 8'h00;  
                // button_state <= 8'h00;
            end else begin
                if(latch_state) begin
                    data <= 8'h00;
                end else if(data_state) begin
                    // data <= {!i_serial_data, data[7:1]};
                    // data <= {data[6:0], !i_serial_data};
                    case(cycle_stage)
                        (1 << 1): data[0] <= !i_serial_data;    // A
                        (1 << 2): data[1] <= !i_serial_data;    // B
                        (1 << 3): data[2] <= !i_serial_data;    // Select
                        (1 << 4): data[3] <= !i_serial_data;    // Start
                        (1 << 5): data[4] <= !i_serial_data;    // Up
                        (1 << 6): data[5] <= !i_serial_data;    // Down
                        (1 << 7): data[6] <= !i_serial_data;    // Left
                        (1 << 8): data[7] <= !i_serial_data;    // Right
                    endcase
                end else if(write_state) begin
                    button_state <= data;
                end
            end
		end
	end

	// Handle 120uS clock
	assign clock_120uS = (clock_counter_120uS > 0) && (clock_counter_120uS <= COUNTER_120uS);

	// Assign outputs
	// assign o_data_latch = (clock_counter_60Hz <= (2 * COUNTER_120uS));
	assign o_data_latch = latch_state;
    assign o_data_clock = clock_60Hz & clock_120uS & !latch_state;
	assign o_data_available = write_state;
    assign o_button_state = button_state;

	//
	// Formal verification
	//
	`ifdef	FORMAL

		`ifdef NESGAMEPAD
			`define	ASSUME	assume
		`else
			`define	ASSUME	assert
		`endif

    // f_past_valid
	reg	f_past_valid;
	initial	f_past_valid = 1'b0;
	always @(posedge i_clk)
		f_past_valid <= 1'b1;

		// Clock 60Hz
		always @(*)
			if(f_past_valid)
				assert(clock_counter_60Hz <= (2 * COUNTER_60Hz));

		// Clock 120uS
		always @(*)
			if(f_past_valid)
				assert(clock_counter_120uS <= (2 * COUNTER_120uS));

		// Prove that reset works
		always @(posedge i_clk) begin
			if((f_past_valid)&&($past(f_past_valid)&&(!$past(i_rst_n))&&(i_rst_n))) begin
				assert(clock_counter_120uS == 0);
				assert(cycle_stage == 1);
				assert(data == 8'h00);
				assert(button_state == 8'h00);
			end
		end		

		// // Prove that clock_120uS is assigned correctly
		// always @(*)
		// 	if(f_past_valid)
		// 		assert(clock_120uS == (clock_counter_120uS > 0) && (clock_counter_120uS <= COUNTER_120uS)); // Don't, too many ticks

		// Prove that cycle_stage is always only one bit active
		always @(*)
			if(f_past_valid)
				assert((cycle_stage == 0)||(cycle_stage == (1 << 0))||(cycle_stage == (1 << 1))||(cycle_stage == (1 << 2))||(cycle_stage == (1 << 3))||(cycle_stage == (1 << 4))||(cycle_stage == (1 << 5))||(cycle_stage == (1 << 6))||(cycle_stage == (1 << 7))||(cycle_stage == (1 << 8))||(cycle_stage == (1 << 9)));

		always @(*)
			if(f_past_valid)
				assert(latch_state == (cycle_stage[0] & (clock_counter_60Hz <= (2 * NUMBER_OF_STATES * COUNTER_120uS + NUMBER_OF_STATES))));
    
		always @(*)
			if(f_past_valid)
				assert(data_state == (cycle_stage[1] 
									| cycle_stage[2] 
									| cycle_stage[3] 
									| cycle_stage[4] 
									| cycle_stage[5] 
									| cycle_stage[6] 
									| cycle_stage[7]
									| cycle_stage[8]));	
    	
		always @(*)
			if(f_past_valid)
				assert(write_state == cycle_stage[9]);

		//
		// Contract
		//
		initial assert(cycle_stage == 1);
		initial assert(data == 8'h00);
		initial assert(button_state == 8'h00);
		initial assert(clock_counter_60Hz == 0);
		initial assert(clock_counter_120uS == 0);
		always @(posedge i_clk) begin
			if((f_past_valid)&&($past(f_past_valid))&&(i_rst_n)&&($past(clock_120uS))) begin
				if(clock_120uS) begin	// They depend on clock_120uS
					if($past(latch_state)) begin
						assert(data == 8'h00);
					end else if($past(data_state)) begin
						case($past(cycle_stage))
							(1 << 1): assert(data[0] == !$past(i_serial_data));    // A
							(1 << 2): assert(data[1] == !$past(i_serial_data));    // B
							(1 << 3): assert(data[2] == !$past(i_serial_data));    // Select
							(1 << 4): assert(data[3] == !$past(i_serial_data));    // Start
							(1 << 5): assert(data[4] == !$past(i_serial_data));    // Up
							(1 << 6): assert(data[5] == !$past(i_serial_data));    // Down
							(1 << 7): assert(data[6] == !$past(i_serial_data));    // Left
							(1 << 8): assert(data[7] == !$past(i_serial_data));    // Right
						endcase
					end else if($past(write_state)) begin
						assert(button_state == $past(data));
					end
				end
			end
		end

	`endif


endmodule