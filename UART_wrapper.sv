module UART_wrapper (
	input clk, 
	input rst_n, 
	input RX,
	input trmt, 
	input [7:0] resp, 
	input clr_cmd_rdy,
	output reg cmd_rdy, 
	output logic [15:0] cmd,  
	output reg tx_done, 
	output reg TX 
); 
	logic 	rx_rdy, 
			clr_rx_rdy, 
			set_cmd_rdy,
			hold_reg;
			
	logic [7:0] rx_data; 
	
	// the UART
	UART iUART(.clk(clk), .rst_n(rst_n), .RX(RX), .TX(TX), .rx_rdy(rx_rdy), .clr_rx_rdy(clr_rx_rdy), 
				.rx_data(rx_data), .trmt(trmt), .tx_data(resp), .tx_done(tx_done));  

	//SM
	typedef enum logic {HIGH, LOW} state_t; 
	state_t state, nxt_state;
	always_ff @(posedge clk, negedge rst_n) 
		if (!rst_n) 
			state <= HIGH;
		else 
			state <= nxt_state;
			
	// hold the command between transmissions
	always_ff @(posedge clk) 
		if (hold_reg) 
			cmd[15:8] <= rx_data[7:0]; 
		else 
			cmd[7:0] <= rx_data[7:0]; 
	
	// cmd_rdy set reset
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n) 
			cmd_rdy <= 1'b0; 
		else if (clr_cmd_rdy || hold_reg) 
			cmd_rdy <= 1'b0; 
		else if (set_cmd_rdy)
			cmd_rdy <= 1'b1;  
	
	// actual SM
	always_comb begin : SM
		// default outputs
		clr_rx_rdy = 1'b0; 
		hold_reg = 1'b0;
		set_cmd_rdy = 1'b0; 
		nxt_state = state; 
		
		case (state) 
			HIGH : begin 
				if (rx_rdy) begin 
					clr_rx_rdy = 1'b1; 
					hold_reg = 1'b1;
					nxt_state = LOW;
				end
				
			end
			LOW : begin 
				if (rx_rdy) begin 
					set_cmd_rdy = 1'b1; 
					clr_rx_rdy = 1'b1; 
					nxt_state = HIGH; 
				end
			end
			
		endcase
	end : SM
	
	
	
endmodule
