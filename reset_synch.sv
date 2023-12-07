module reset_synch (clk, RST_n, rst_n);

	// ports
	input logic clk;
	input logic RST_n;
	output logic rst_n;
	// for double flop
	logic rst_ff1;
	
	// reset unit
	always_ff @(negedge clk, negedge RST_n) begin
		if (!RST_n) begin
			rst_ff1 <= 1'b0;
			rst_n <= 1'b0;
		end
		else begin
			rst_n <= rst_ff1;
			rst_ff1 <= 1'b1;
		end	
	end
	
endmodule