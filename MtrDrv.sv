module MtrDrv(lft_spd, vbatt, rght_spd, clk, rst_n, lftPWM1, lftPWM2, rghtPWM1, rghtPWM2);

input logic signed [11:0] lft_spd, rght_spd;
input logic [11:0] vbatt;
input logic clk, rst_n;

output logic lftPWM1, lftPWM2, rghtPWM1, rghtPWM2;

logic signed [12:0] scale_factor;
logic signed [23:0] lft_prod, rght_prod, lft_div, rght_div;

logic signed [11:0] lft_scaled, rght_scaled, lft_sum, rght_sum;

localparam signed DIV = 2048;
localparam signed SUM = 12'h800;

DutyScaleROM DUT(.clk(clk),.batt_level(vbatt[9:4]),.scale(scale_factor));
PWM12 PWM1(.clk(clk), .rst_n(rst_n), .duty(lft_sum), .PWM1(lftPWM1), .PWM2(lftPWM2));
PWM12 PWM2(.clk(clk), .rst_n(rst_n), .duty(rght_sum), .PWM1(rghtPWM1), .PWM2(rghtPWM2));

assign lft_prod = lft_spd*scale_factor;
assign rght_prod = rght_spd*scale_factor;

assign lft_div = lft_prod/DIV;
assign rght_div = rght_prod/DIV;


	assign lft_scaled = (lft_div[23] && |(~lft_div[22:11])) ? 11'h400
				  :  (~lft_div[23] && (|lft_div[22:11])) ? 10'h3FF
				  :  lft_div[11:0];
	assign rght_scaled = (rght_div[23] && |(~rght_div[22:11])) ? 11'h400
				  :  (~rght_div[23] && (|rght_div[22:11])) ? 10'h3FF
				  :  rght_div[11:0];			

assign lft_sum = lft_scaled + SUM;
assign rght_sum = SUM - rght_scaled;

endmodule
