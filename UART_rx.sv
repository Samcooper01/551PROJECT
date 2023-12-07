module UART_rx (clk, rst_n, RX, clr_rdy, rx_data, rdy);

	// ports
	input logic clk;
	input logic rst_n;
	input logic RX;
	input logic clr_rdy;
	output logic [7:0] rx_data;
	output logic rdy;
	
	// internal nets
	logic start;
	logic shift;
	logic [3:0] bit_cnt;
	logic receiving;
	logic [11:0] baud_cnt;
	logic [8:0] rx_shft_reg;
	logic RX_df; // this is the signal ot use, not RX
	logic RX_sf;
	logic set_rdy;
	
	// for state machine
	typedef enum logic { IDLE, RECEIVING } state_t;
	state_t state, next_state;
	
	// flop for the state machine
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			state <= IDLE;
		else
			state <= next_state;
	end
	
	// double flop RX for meta stability
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n) begin
			RX_df <= 1'b1;
			RX_sf <= 1'b1;
		end else begin
			RX_df <=  RX_sf;
			RX_sf <= RX;
		end
	end
	
	// receive shift reg
	always_ff @(posedge clk) begin
		if (shift)
			rx_shft_reg <= {RX_df, rx_shft_reg[8:1]};
		else
			rx_shft_reg <= rx_shft_reg;
	end
	
	// bit counter
	always_ff @(posedge clk) begin
		if (start)
			bit_cnt <= 4'h0;
		else if (shift)
			bit_cnt <= bit_cnt + 1;
		else
			bit_cnt <= bit_cnt;
	end
	
	// baud counter -- load w 1302 or 2604 to sample in middle of baud count to be accurate
	always_ff @(posedge clk) begin
		if (start|shift)
			baud_cnt <= (start) ? 12'd1302 : 12'd2604;
		else if (receiving)
			baud_cnt <= baud_cnt - 1;
		else
			baud_cnt <= baud_cnt;
	end
	
	// load the receive register
	assign rx_data = rx_shft_reg[7:0];
	
	// shift signal needs to be high after the certain number of clock cycles
	assign shift = (baud_cnt == 0) ? 1'b1 : 1'b0;
	
	// output (rdy) flop
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			rdy <= 1'b0;
		else if (start || clr_rdy)
			rdy <= 1'b0;
		else if (set_rdy)
			rdy <= 1'b1;
		else
			rdy <= rdy; // shouldn't happen
	end
	
	// state machine
	always_comb begin
		// default outputs
		start = 0;
		receiving = 0;
		set_rdy = 0;
		next_state = state;
		
		// cases
		case (state)
			RECEIVING:
				if (bit_cnt == 10) begin
					set_rdy = 1;
					next_state = IDLE;
				end
				else begin
					receiving = 1;
				end
			// default case is IDLE
			default:
				if (~RX_df) begin
					start = 1;
					next_state = RECEIVING;
				end
		endcase
	end
	
endmodule
				
				
				