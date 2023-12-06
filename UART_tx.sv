module UART_tx (clk, rst_n, TX, trmt, tx_data, tx_done);

	// ports
	input logic clk, rst_n;
	input logic trmt;
	input logic [7:0] tx_data;
	output logic tx_done;
	output logic TX;
	
	// internal signals
	logic shift;
	logic [8:0] tx_shft_reg;
	logic [11:0] baud_cnt;
	logic [3:0] bit_cnt;
	logic transmitting;
	logic init;
	logic set_done;
	
	// for the state machine
	typedef enum logic { IDLE, TRANS } state_t;
	state_t state, next_state;
	
	// flop for the state machine
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			state <= IDLE;
		else
			state <= next_state;
	end;
	
	// shifter flop
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			tx_shft_reg <= 9'h1FF;
		else if (init)
			tx_shft_reg <= {tx_data, 1'b0};
		else if (shift)
			tx_shft_reg <= {1'b1, tx_shft_reg[8:1]};
		else
			tx_shft_reg <= tx_shft_reg;
	end
	
	// TX need to be that last bit of TX
	assign TX = tx_shft_reg[0];
	
	// baud ounter flop
	always_ff @(posedge clk) begin
		if (init|shift)
			baud_cnt <= 12'h000;
		else if (transmitting)
			baud_cnt <= baud_cnt + 1;
	end
	
	// tell shifter when it's time
	assign shift = (baud_cnt == 2604) ? 1'b1 : 1'b0;
	
	// bit counter for shifter flop
	always_ff @(posedge clk) begin
		if (init)
			bit_cnt <= 4'h0;
		else if (shift)
			bit_cnt <= bit_cnt + 1;
	end
	
	// done flop
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			tx_done <= 1'b0;
		else if (set_done)
			tx_done <= 1'b1;
		else if (init)
			tx_done <= 1'b0;
	end
	
	// state machine
	always_comb begin
		// default outputs
		init = 0;
		transmitting = 0;
		set_done = 0;
		next_state = state;
		
		// cases
		case (state)
			TRANS:
				if (bit_cnt == 10) begin
					set_done = 1;
					next_state = IDLE;
				end
				else begin
					transmitting = 1;
				end
			// default state is IDLE
			default:
				if (trmt) begin
					init = 1;
					next_state = TRANS;
				end
		endcase
	end
	
endmodule