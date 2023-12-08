module RemoteComm(clk, rst_n, RX, TX, cmd, send_cmd, cmd_sent, resp_rdy, resp);

input clk, rst_n;		// clock and active low reset
input RX;				// serial data input
input send_cmd;			// indicates to tranmit 24-bit command (cmd)
input [15:0] cmd;		// 16-bit command

output TX;				// serial data output
output logic cmd_sent;		// indicates transmission of command complete
output resp_rdy;		// indicates 8-bit response has been received
output [7:0] resp;		// 8-bit response from DUT


//<<<  Your declaration stuff here >>>
logic 	trmt, 
		sel, 
		set_cmd_snt, 
		tx_done;
logic [7:0] cmd_low, 
			tx_data; 
	
///////////////////////////////////////////////
// Instantiate basic 8-bit UART transceiver //
/////////////////////////////////////////////
UART iUART(.clk(clk), .rst_n(rst_n), .RX(RX), .TX(TX), .tx_data(tx_data), .trmt(trmt),
           .tx_done(tx_done), .rx_data(resp), .rx_rdy(resp_rdy), .clr_rx_rdy(resp_rdy));

	//declare and instatiate sm 
	typedef enum logic [1:0] {IDLE, HIGH, LOW} state_t; 
	state_t state, nxt_state;
	
	//reset sm and assign nxt_state
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n) 
			state <= IDLE;
		else 
			state <= nxt_state; 
		
	//define internal siganls to sm
	
	always_comb begin 
		//default internal SM values 
		trmt = 1'b0; 
		sel = 1'b0; 
		set_cmd_snt = 1'b0; 
		nxt_state = state; 
		
		case (state) 
			IDLE: begin 
				if (send_cmd) begin 
					trmt = 1'b1; 
					sel = 1'b1;
					nxt_state = HIGH;
				end
			end 
			
			HIGH : begin 
				if (tx_done) begin 
					trmt = 1'b1; 
					sel = 1'b0; 
					nxt_state = LOW; 
				end 	
			end 
			
			LOW : begin 
				if (tx_done) begin 
					set_cmd_snt = 1'b1;
					nxt_state = IDLE;
				end
			end
			default : 
				nxt_state = IDLE;
		endcase
	end
	
	always_ff @(posedge clk) 
		if (send_cmd) 
			cmd_low <= cmd[7:0];
	
	//assign tx_data to the respective 8 bit signal based in high signal
	assign tx_data[7:0] = sel ? cmd[15:8] : cmd_low[7:0]; 

	//combinational logic for cmd_snt signal
	always_ff @(posedge clk, negedge rst_n) 
		if (!rst_n) 
			cmd_sent = 1'b0; 
		else if (send_cmd) 
			cmd_sent = 1'b0; 
		else if (set_cmd_snt) 
			cmd_sent = 1'b1; 
			
endmodule	
