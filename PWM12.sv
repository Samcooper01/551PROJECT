module PWM12(clk, rst_n, duty, PWM1, PWM2);

input logic clk, rst_n;
input logic [11:0] duty;
output logic PWM1, PWM2;

localparam NONOVERLAP = 12'h02c;

logic [11:0] cnt;

always_ff@(posedge clk, negedge rst_n) begin
	if(!rst_n)
		cnt <= 12'h000;
	else
		cnt <= cnt + 1;
end
always_ff@(posedge clk, negedge rst_n) begin
	if(!rst_n)
		PWM2 <= 1'b0;
	else if(&cnt)
		PWM2 <= 1'b0;
	else if(cnt>=(duty+NONOVERLAP))
		PWM2 <= 1'b1;
end
always_ff@(posedge clk, negedge rst_n) begin
	if(!rst_n)
		PWM1 <= 1'b0;
	else if(cnt>=duty)
		PWM1 <= 1'b0;
	else if(cnt>=NONOVERLAP)
		PWM1 <= 1'b1;
end




endmodule
