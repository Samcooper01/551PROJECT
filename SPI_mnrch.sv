module SPI_mnrch( 
	input clk,
	input rst_n,
	input wrt, 
	input MISO, 
	output logic SS_n, 
	output logic SCLK, 
	output logic MOSI, 
	input logic [15:0]wrt_data, 
	output logic done,
	output logic [15:0]rd_data
); 

//signal internal to SPI monarch 
logic 	shft,
		shft_imm,
		MISO_smpl,
		smpl, 
		ld_SCLK,
		set_done, 
		done15,
		init;		
logic [4:0] sclk_div; 
logic [3:0] bit_cntr;
logic [15:0] shft_reg;
logic 	enable_shft;

////////////////////////////////////////////
//register for SCLK counting 
////////////////////////////////////////////
always_ff @(posedge clk)
	if (ld_SCLK) 
		sclk_div = 5'b10111;
	else 
		sclk_div = sclk_div + 1; 

assign SCLK = {sclk_div[4]}; 
assign shft_imm = (&sclk_div) ? 1'b1 : 1'b0; 
assign smpl = (sclk_div == 5'b01111) ? 1'b1 : 1'b0; 

////////////////////////////////////////////
//register for shift counting 
////////////////////////////////////////////
always_ff @(posedge clk)
	//initialization condition with priority over shift
	if (init) 
		bit_cntr = 4'b0000;
	else if (shft) 
		bit_cntr = bit_cntr + 1;

assign done15 = (&bit_cntr) ? 1'b1 : 1'b0; 

////////////////////////////////////////////
//register for shifting
////////////////////////////////////////////
always_ff @(posedge clk) 
	if (smpl)  
		MISO_smpl = MISO;

always_ff @(posedge clk) 
	if (init) 
		shft_reg[15:0] = wrt_data[15:0];
	else if (shft) 
		shft_reg = {shft_reg[14:0], MISO_smpl}; 
		
assign MOSI = shft_reg[15]; 
assign rd_data = shft_reg; 

//always_ff to produce output SS_n
always_ff @(posedge clk, negedge rst_n) 
	if (!rst_n) 
		SS_n = 1'b1; 
	else if (set_done) 
		SS_n = 1'b1; 
	else if (init) 
		SS_n = 1'b0; 

//always_ff to produce output done	
always_ff @(posedge clk, negedge rst_n) 
	if (!rst_n) 
		done = 1'b0; 
	else if (init) 
		done = 1'b0; 
	else if (set_done) 
		done = 1'b1; 

////////////////////////////////////////////
//combinational block for state machine
////////////////////////////////////////////
typedef enum reg [1:0] {IDLE, TRANS_BEGIN, TRANS, TRANS_END} state_t; 
state_t state, nxt_state; 

//reset and state asssignment for SM
always_ff @(posedge clk, negedge rst_n) 
	if (!rst_n)
		state <= IDLE; 
	else 
		state <= nxt_state;

always_comb begin
	ld_SCLK = 1'b0; //default ld_sclk to be one. will turn into zero during transactions
	init = 1'b0; 
	set_done = 1'b0; 
	shft = 1'b0; 
	nxt_state = state;
	//enable_shft = 1'b1; 

	case (state) 
		IDLE : begin  
			ld_SCLK = 1'b1;
			if (wrt) begin 
				init = 1'b1;				
				nxt_state = TRANS_BEGIN;
			end
		end
		TRANS_BEGIN : begin 
			if (shft_imm) 
				nxt_state = TRANS;
			else 
				nxt_state = TRANS_BEGIN; 
		end 
		TRANS : begin 
			if (shft_imm) 
				shft = 1'b1; 
			else if (done15)
				nxt_state = TRANS_END;
		end 
		TRANS_END : begin 
			if (shft_imm) begin
				shft = 1'b1; 
				ld_SCLK = 1'b1; 
				set_done = 1'b1; 
				nxt_state = IDLE; 
			end
		end
	endcase
end
		
endmodule
