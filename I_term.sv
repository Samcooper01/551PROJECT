module I_term (clk, rst_n, hdng_vld, moving, err_sat, I_term);

	// ports
	input logic clk;
	input logic rst_n;
	input logic hdng_vld;
	input logic moving;
	input logic signed [9:0] err_sat;
	output logic [11:0] I_term;
	
	// internal logic
	logic integrator_valid;
	logic overflow;
	logic valid;
	logic signed [15:0] err_sat_ext;
	logic signed [15:0] integrator;
	logic signed [15:0] sum_integrator_err_sat;
	logic signed [15:0] passthrough;
	logic signed [15:0] nxt_integrator;
	
	// overflow logic...
	assign overflow = ((integrator[15] && err_sat_ext[15] && ~sum_integrator_err_sat[15])
					|| (~integrator[15] && ~err_sat_ext[15] && sum_integrator_err_sat[15]))
					? 1'b1 : 1'b0;
	and and1(valid, ~overflow, hdng_vld);
	
	// sign extend err_sat
	assign err_sat_ext = {{6{err_sat[9]}}, err_sat};
	
	// for the adder
	assign sum_integrator_err_sat = integrator + err_sat_ext;
	
	// here's the first mux that operates on overflow
	assign passthrough = (valid) ? sum_integrator_err_sat : integrator;
	
	// here's the second mux
	assign nxt_integrator = (moving) ? passthrough : 16'h0000;
	
	// here's the for integrator
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			integrator <= 16'h0000;
		else
			integrator <= nxt_integrator;
	end
	
	// assign to the output
	assign I_term = integrator[15:4];

endmodule