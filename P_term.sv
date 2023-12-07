module P_term (error, P_term, err_sat);

	// ports
	input logic signed [11:0] error;
	output logic [13:0] P_term;
	output logic signed [9:0] err_sat;

	// a couple constants
	localparam P_COEFF = 4'h3;
	localparam signed LARGEST_NEG_NUM = 10'h200;
	localparam signed LARGEST_POS_NUM = 10'h1FF;

	// saturator
	assign err_sat = (error[11] && |(~error[10:9])) ? LARGEST_NEG_NUM
				  :  (~error[11] && (|error[10:9])) ? LARGEST_POS_NUM
				  :  error[9:0];
	
	// assign to P_term
	assign P_term = err_sat * $signed(P_COEFF);

endmodule