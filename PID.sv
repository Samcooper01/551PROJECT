module PID(clk, rst_n, moving, hdng_vld, dsrd_hdng, actl_hdng, frwrd_spd, at_hdng, lft_spd, rght_spd);

	input logic clk;
	input logic rst_n; 
	input logic moving;
	input logic hdng_vld;
	input logic signed [11:0] dsrd_hdng;
	input logic signed [11:0] actl_hdng; 
	input logic [10:0] frwrd_spd;
	output logic at_hdng; 
	output logic signed [11:0] lft_spd;
	output logic signed [11:0] rght_spd;

	///////////////////////////////
	//	Set up input to P term	//											 
	/////////////////////////////
	logic signed [11:0] error;
	assign error = actl_hdng - dsrd_hdng; 

	//////////
	// PIPELINE SOLUTION 
	// 	-> slow down the subtractor feeding into PID
	///////////
	logic signed [11:0] error_piped;
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			error_piped <= 12'h000;
		else 
			error_piped <= error;

	//////////////////////////////
	//	paste in P term module //
	////////////////////////////
	logic signed [13:0]P_term_int; 
	logic signed [14:0]P_term;
	logic signed[9:0]err_sat;

	localparam P_COEFF = 4'h3; 

	//test if pos (check msb == 0)
	//checking on bits (10:9) set 
		//if not all are 
	assign err_sat = (error_piped[11] && !(&error_piped[10:9])) ? 10'h200 : //neg case not all bits[10:9] are set -> sat to most neg value 
			(!error_piped[11] && |error_piped[10:9]) ? 10'h1FF : //any bits set[10:9] -> sat to most pos value
			error_piped[9:0]; 

	/*
	///////////////////////////////////////////////////
	// PIPELINE SOLUTION 							//
	// 	-> slow down err_sat going into P I and D  //
	////////////////////////////////////////////////
	logic [9:0] err_sat_piped; 
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			err_sat_piped <= 10'h000;
		else 
			err_sat_piped <= P_term_int;

	assign P_term_int[13:0] =  $signed(P_COEFF) * err_sat_piped;
	*/ 
	assign P_term_int[13:0] =  $signed(P_COEFF) * err_sat;

	///////////////////////////////////////////////
	// PIPELINE SOLUTION 						//
	//	-> pipe before each SE on PID blocks   //
	////////////////////////////////////////////
	logic signed [13:0] P_term_int_piped;
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			P_term_int_piped <= 13'h0000;
		else 
			P_term_int_piped <= P_term_int;

	assign P_term = P_term_int_piped[13] ? {1'b1,P_term_int_piped[13:0]} : {1'b0,P_term_int_piped[13:0]}; 
	
	//assign P_term = P_term_int[13] ? {1'b1,P_term_int[13:0]} : {1'b0,P_term_int[13:0]}; 	

	//////////////////////////////
	//	paste in I term module //
	////////////////////////////
	logic signed [11:0]I_term_int; 
	logic signed [14:0] I_term; 
	logic ov_and, overflow; 
	logic [15:0]	adder_output,
					sign_ext,
					nxt_integrator, 
					integrator,
					mux_intermediate; 

	//sign extend err_sat for following I_term calculations
	assign sign_ext = {{6{err_sat[9]}},err_sat};

	assign adder_output = sign_ext + integrator; 

	assign overflow = 	((integrator[15] && sign_ext[15] && ~adder_output[15]) || 
						(~integrator[15] && ~sign_ext[15] && adder_output[15]));

	and iAND1(ov_and, hdng_vld, ~overflow);  

	assign mux_intermediate = ov_and ? adder_output : integrator; 

	assign nxt_integrator = moving ? mux_intermediate : 16'h0000; 

	always_ff@(posedge clk, negedge rst_n) begin
		if(!rst_n)
 	   		integrator <= 16'h0000;
	 	else 
	   		integrator <= nxt_integrator; 
	end

	assign I_term_int = integrator[15:4];

	///////////////////////////////////////////////
	// PIPELINE SOLUTION 						//
	//	-> pipe before each SE on PID blocks   //
	////////////////////////////////////////////
	logic signed [11:0] I_term_int_piped;
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			I_term_int_piped <= 12'h000;
		else 
			I_term_int_piped <= I_term_int;

	assign I_term = I_term_int_piped[11] ? {3'b111,I_term_int_piped[11:0]} : {3'b000,I_term_int_piped[11:0]};

	//assign I_term = I_term_int[11] ? {3'b111,I_term_int[11:0]} : {3'b000,I_term_int[11:0]};

	//////////////////////////////
	//	paste in D term module //
	////////////////////////////
	localparam D_COEFF = 5'h0E;
	logic signed[9:0] flop0, flop1;
	logic signed[10:0]D_diff; 			//11 bits wide for overflow
	logic signed[7:0]D_sat; 
	logic signed [12:0]D_term_int; 
	logic signed [14:0]D_term; 
	
	//first flop on err_sat
	always_ff@(posedge clk, negedge rst_n) begin
	  if(!rst_n) begin
	   	flop0 <= 10'h000;
	    flop1 <= 10'h000;
	  end 
	  else if (hdng_vld) begin
	   	flop0 <= err_sat;  
		flop1 <= flop0; 
	  end
	end					//infers latch if hdng signal is not high (will use old value)

	assign D_diff = err_sat - flop1; 

	assign D_sat = 	(D_diff[10] && !(&D_diff[9:7])) ? 8'h80 : 			//neg case not all bits[8:7] are set -> sat to most neg value 
					(!D_diff[10] && |D_diff[9:7]) ? 8'h7F : 			//any bits set[8:7] -> sat to most pos value
					D_diff[7:0]; 

	/*
	//////////////
	// PIPELINE SOLUTION 
	//		-> slow down after D sat 
	///////////
	logic [7:0] D_sat_piped;
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			D_sat_piped <= 8'h00;
		else 
			D_sat_piped <= D_sat;

	assign D_term_int = $signed(D_COEFF) * D_sat_piped;
	*/

	assign D_term_int = $signed(D_COEFF) * D_sat;

	
	///////////////////////////////////////////////
	// PIPELINE SOLUTION 						//
	//	-> pipe before each SE on PID blocks   //
	////////////////////////////////////////////
	logic signed [14:0] D_term_int_piped;
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			D_term_int_piped <= 14'h0000;
		else 
			D_term_int_piped <= D_term_int;

	//sign extension of D term
	assign D_term = D_term_int_piped[12] ? {2'b11,D_term_int_piped[12:0]} : {2'b00,D_term_int_piped[12:0]}; 
	
	//sign extension of D term
	//assign D_term = D_term_int[12] ? {2'b11,D_term_int[12:0]} : {2'b00,D_term_int[12:0]}; 

	////////////////////////////////////////////////////////////
	//	logic completed after PID terms have been calculated //
	//////////////////////////////////////////////////////////
	logic signed [14:0] PID; 
	logic signed [11:0] PID_div8; 
	logic signed [11:0]	lft_spd_fct, 
						rght_spd_fct;

	////////////////////////////////
	// TIMING SOLUTION 
	//		-> slow down addition of 
	//			P+I+D
	////////////////////////////////

	assign PID = P_term + I_term + D_term;  
	assign PID_div8 = PID[14:3];

	assign lft_spd_fct = PID_div8 + {1'b0, frwrd_spd}; 
	assign rght_spd_fct = {1'b0, frwrd_spd} - PID_div8; 

	//assign at_hdng = |err_sat| < 10'd30 
	assign at_hdng = (err_sat < $signed(10'd30) && err_sat > $signed(-10'd30)) ? 1'b1 : 1'b0; 
	
	assign lft_spd = moving ? lft_spd_fct : 12'h000; 
	assign rght_spd = moving ? rght_spd_fct : 12'h000; 
	
endmodule