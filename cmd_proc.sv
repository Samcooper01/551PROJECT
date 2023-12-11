module cmd_proc(clk, rst_n, cmd, cmd_rdy, clr_cmd_rdy, send_resp, strt_cal, cal_done, in_cal, sol_cmplt,
				strt_hdng, strt_mv, stp_lft, stp_rght, dsrd_hdng, mv_cmplt, cmd_md);
	///////////////////////////////////////////////////////////////////
	// cmd_proc I/O seperated by the other blocks it interacts with //
	/////////////////////////////////////////////////////////////////

	// to/from UART_Wrapper
	input logic [15:0] cmd;
	input logic cmd_rdy;
	output logic clr_cmd_rdy;
	output logic send_resp;
	
	// to/from inert_intf
	input logic cal_done;
	output logic strt_cal;
	output logic in_cal;			// asserted when in calibration 
	
	// to navigate unit
	input logic mv_cmplt;
	output logic strt_hdng;
	output logic strt_mv;
	output logic stp_lft;
	output logic stp_rght;
	output logic [11:0] dsrd_hdng;
	
	input logic sol_cmplt;			// asserted when magnet found
	output logic cmd_md;			// for navigate muxing
	input logic clk, rst_n;		
	
	//flop for stp_lft, stp_rght
	always @(posedge clk, negedge rst_n) begin 
		if (!rst_n) begin 
			stp_lft <= 1'b0;
			stp_rght <= 1'b0;
		end
		else begin
			stp_lft <= cmd[1];
			stp_rght <= cmd[0]; 
		end 
	end 

	//heading register
	logic [11:0] nxt_hdng; 
	always @(posedge clk, negedge rst_n) begin 
		if (!rst_n)
			dsrd_hdng <= 12'h000;
		else 
			dsrd_hdng <= nxt_hdng; 
	end

	// define SM enum type 
	typedef enum logic [2:0] {IDLE, MOVE, HEADING, CALIBRATE, SOLVE} state_t;
	state_t state, next_state;
	
	// next state flop
	always @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			state <= IDLE;
		else
			state <= next_state;
	end

	
	//////////////////////////////////////////
	// cmd[15:13] indicates the cmd opcode 	//
	// 3'b000		calibrate				//
	// 3'b001 		heading					//
	// 3'b010 		move 					//
	// 3'b011		solve					//
	// 3'b1xx		reserved 				//
	//////////////////////////////////////////
	always_comb begin
		//default outputs of SM
		clr_cmd_rdy = 0;
		strt_mv = 0;
		stp_lft = 0;
		stp_rght = 0;
		strt_hdng = 0;
		strt_cal = 0;
		send_resp = 0;
		cmd_md = 1;
		in_cal = 0;
		next_state = state;
		
		case (state) 
			IDLE: begin
				if (cmd_rdy) begin
					if (cmd[15:13] == 3'b000) begin
						strt_cal = 1;
						next_state = CALIBRATE;
					end

					else if (cmd[15:13] == 3'b001) begin
						strt_hdng = 1;
						nxt_hdng = cmd[11:0]; 					//capture dsrd_hdng from cmd word
						next_state = HEADING;
					end

					else if (cmd[15:13] == 3'b010) begin
						strt_mv = 1;
						next_state = MOVE;
					end

					else if (cmd[15:13] == 3'b011) begin
						cmd_md = 0;
						next_state = SOLVE;
					end
					clr_cmd_rdy = 1;
				end
			end

			CALIBRATE: begin
				in_cal = 1;
				if (cal_done) begin
					send_resp = 1;
					next_state = IDLE;
				end
			end

			HEADING: begin
				if (mv_cmplt) begin
					send_resp = 1;
					next_state = IDLE;
				end
			end

			MOVE: begin
				//UPDATE: stp_left st_rght assignments moved from IDLE state
				//if (cmd[1] == 1'b1) stp_lft = 1'b1;
				//if (cmd[0] == 1'b1) stp_rght = 1'b1;

				if (mv_cmplt) begin
					send_resp = 1;
					next_state = IDLE;
				end
			end

			SOLVE: begin
				cmd_md = 0; 
				if (sol_cmplt) begin
					send_resp = 1;		
					next_state = IDLE;
				end
			end

			default: begin
				next_state = IDLE;
			end
		endcase
	end

endmodule
	