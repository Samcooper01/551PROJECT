module IR_math(clk, rst_n, lft_opn, rght_opn, lft_IR, rght_IR, IR_Dtrm, en_fusion, dsrd_hdng, dsrd_hdng_adj); 

	parameter NOM_IR = 12'h970; //nominal IR reading if bot is centered

	input clk, rst_n; 
	input lft_opn, rght_opn; 
	input [11:0] lft_IR, rght_IR; 
	input signed [8:0]IR_Dtrm;
	input en_fusion; 
	input reg signed [11:0]dsrd_hdng; 
	output reg signed [11:0]dsrd_hdng_adj;  

	//define internal logic
	wire signed [11:0] lft_IR_diff,
	 	rght_IR_diff, 
		div2, 
		sum2, 
		m0, m1, m2;

	wire signed [12:0] div32, 
		IR_diff,
		ir_ext,
		sum1, 
		IR_Dtrm_ext;

	wire l_and_r;

	//sign extend for two unsigned numbers so the shift right (div by 2) works well
	assign IR_diff = {1'b0,lft_IR} - {1'b0,rght_IR}; 
	assign lft_IR_diff = lft_IR - NOM_IR; 
	assign rght_IR_diff = NOM_IR - rght_IR; 

	assign m0 = (rght_opn ? lft_IR_diff : IR_diff[12:1]); 
	assign m1 = (lft_opn ? rght_IR_diff : m0);  

	and IAND(l_and_r, lft_opn, rght_opn); 
	assign m2 = (l_and_r ? 12'h000 : m1); 

	//sign extend to 13 bits for sum with IR derivative term
	assign div32 = {{6{m2[11]}},m2[11:5]};

	//sign extend to 13 bits for sum with div32 result
	assign ir_ext = {{2{IR_Dtrm[8]}},IR_Dtrm[8:0],2'b00}; 

	assign sum1 = div32[12:0] + ir_ext[12:0]; 

	assign div2 = {sum1[12:1]}; //take upper bits for divide by 2 operation

	assign sum2 = div2[11:0] + dsrd_hdng[11:0]; 

	//output to feed into pipelined flop
	logic signed [11:0] dsrd_hdng_piped_in;


	//assign dsrd_hdng_adj = en_fusion ? sum2[11:0] : dsrd_hdng[11:0]; 
	
	///////////////////////////////////////////////////////////////
	// TIMING SOLUTION: Pipeline block 1						// 
	// 	Slow down input path to PID 						   //
	// 		-> goto PID module for the other side of this fix //
	///////////////////////////////////////////////////////////
	assign dsrd_hdng_piped_in = en_fusion ? sum2[11:0] : dsrd_hdng[11:0]; 
	//assign dsrd_hdng_adj = dsrd_hdng_piped_in;
	
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n) 
			dsrd_hdng_adj <= 12'b0;
		else 
			dsrd_hdng_adj <= dsrd_hdng_piped_in;
endmodule
	
