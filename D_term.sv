module D_term (hdng_vld, rst_n, clk, err_sat, D_term);
	
	// ports
	input logic signed [9:0] err_sat;
	output logic signed [12:0] D_term;
	input logic hdng_vld;
	input logic rst_n;
	input logic clk;
	
	// internal signals and constants
	localparam  D_COEFF = 5'h0E;
	localparam LARGEST_NEG_NUM = 8'h80;
	localparam LARGEST_POS_NUM = 8'h7F;
	logic signed [9:0] ff1, ff2;
	logic signed [10:0] D_diff;
	logic signed [7:0] D_diff_sat;
	
	
	// flop 1
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			ff1 <= 10'b000;
		else if (hdng_vld)
			ff1 <= err_sat;
	end

	// flop 2
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			ff2 <= 10'b000;
		else if (hdng_vld)
			ff2 <= ff1;
	end
	
	// subtractor
	assign D_diff = err_sat - ff2;

	assign D_diff_sat = (D_diff[10] && |(~(D_diff[9:7]))) ? LARGEST_NEG_NUM
					 :  (~(D_diff[10]) && |(D_diff[9:7])) ? LARGEST_POS_NUM
					 :  D_diff[7:0];

	// the signed multiply
	assign D_term = D_diff_sat * $signed(D_COEFF);
	
endmodule