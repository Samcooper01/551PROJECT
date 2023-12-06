module PID (clk, rst_n, moving, dsrd_hdng, actl_hdng, hdng_vld, frwrd_spd, at_hdng, lft_spd, rght_spd);
	
	// ports
	input logic clk, rst_n, moving, hdng_vld;
	input logic signed [11:0] dsrd_hdng, actl_hdng;
	input logic [10:0] frwrd_spd;
	output logic signed [11:0] lft_spd, rght_spd;
	output logic at_hdng;

	// internal logic
	logic signed [13:0] P_term_ext;
	logic signed [11:0] I_term_ext;
	logic signed [12:0] D_term_ext;
	logic signed [14:0] PID_term;
	logic signed [11:0] PID_term_shifted;
	logic signed [11:0] frwrd_spd_ext;
	logic signed [11:0] total_left_spd;
	logic signed [11:0] total_right_spd;
	logic signed [11:0] abs_err_sat;
	logic signed [11:0] error;
	logic signed [9:0] err_sat;
	logic signed [13:0] P_term;
	logic signed [11:0] I_term;
	logic signed [12:0] D_term;
	
	// intantiate the modules needed
	P_term p(.error(error), .P_term(P_term), .err_sat(err_sat));
	I_term i(.clk(clk), .rst_n(rst_n), .hdng_vld(hdng_vld), .moving(moving), .err_sat(err_sat), .I_term(I_term));
	D_term d(.hdng_vld(hdng_vld), .rst_n(rst_n), .clk(clk), .err_sat(err_sat), .D_term(D_term));
	
	// get error from act_hdng and dsrd_hdng
	assign error = actl_hdng - dsrd_hdng;
	
	// sign-extend P, I, D terms
	assign P_term_ext = {{P_term[13]}, P_term};
	assign I_term_ext = {{3{I_term[11]}}, I_term};
	assign D_term_ext = {{2{D_term[12]}}, D_term};
	
	// sum the PID terms together
	assign PID_term = P_term_ext + I_term_ext + D_term_ext;
	
	// divide the PID term by 8
	assign PID_term_shifted = PID_term[14:3];
	
	// extend frwrd_spd
	assign frwrd_spd_ext = {1'b0, frwrd_spd};
	
	// sum PID term and frwrd spd to get final speeds
	assign total_left_spd = PID_term_shifted + frwrd_spd_ext;
	assign total_right_spd = frwrd_spd_ext - PID_term_shifted;
	
	// muxes for output
	assign lft_spd = (moving) ? total_left_spd : 12'h000;
	assign rght_spd = (moving) ? total_right_spd : 12'h000;
	
	// handle at_hdng with absolute value of saturated error
	always_comb begin 
		if (err_sat < 0)
			abs_err_sat = -err_sat;
		else
			abs_err_sat = err_sat;
	end
	assign at_hdng = (abs_err_sat< 10'd30) ? 1'b1 : 1'b0;

endmodule

	




















