module maze_solve(
    input clk, 
    input rst_n, 
    input cmd_md, 
    input cmd0, 
    input lft_opn, 
    input rght_opn, 
    input mv_cmplt, 
    input sol_cmplt, 
    output logic strt_hdng, 
    output logic signed [11:0] dsrd_hdng, 
    output logic strt_mv, 
    output logic stp_lft, 
    output logic stp_rght
);
    ///////////////////////
    // Heading register // 
    /////////////////////
    logic signed [11:0] nxt_hdng; 
    logic assign_nxt_hdng; 
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            dsrd_hdng <= 12'h000;
        else if (assign_nxt_hdng)
            dsrd_hdng  <= nxt_hdng; 

    /////////////////////////////////////////////
    // stp_lft/stp_rght pass through register //
    ///////////////////////////////////////////
    always_ff @(posedge clk, negedge rst_n) 
        if (!rst_n) begin 
            stp_lft <= 1'b0; 
            stp_rght <= 1'b0;
        end 
        else if (cmd0) begin
            stp_lft <= 1'b1; 
            stp_rght <= 1'b0;
        end 
        else begin 
            stp_lft <= 1'b0;
            stp_rght <= 1'b1;
        end

    ///////////////////////////
    // define and set up SM //
    /////////////////////////
    typedef enum logic [2:0] {IDLE, MV_FORWARD, WAIT_FRWRD_SETUP_HDNG, 
                        START_HEADING, WAIT_MV_CMPLT} state_t;
    state_t state, nxt_state;

    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            state <= IDLE;
        else
            state <= nxt_state;

    always_comb begin : SM
        strt_mv = 0; 
        strt_hdng = 0;
        nxt_hdng = 12'h000; 
        assign_nxt_hdng = 0; 
        nxt_state = state;

        case (state) 
            ///////////////////////////////////////////
            // SHARED STATES REGARDLESS OF AFFINITY //
            /////////////////////////////////////////
            IDLE: begin 
                if (!cmd_md) begin 
                    nxt_hdng = 12'h000;         //heading should default to north immediately after calibration
                    nxt_state = MV_FORWARD;
                end 
            end 

            MV_FORWARD : begin 
                strt_mv = 1; 
                nxt_state = WAIT_FRWRD_SETUP_HDNG; 
            end 

            WAIT_FRWRD_SETUP_HDNG : begin 
                if (sol_cmplt)
                    nxt_state = IDLE; 
                else if (mv_cmplt) begin 
                    //TURNING LEFT 
                    if ((cmd0 & lft_opn) || (!cmd0 & !rght_opn & lft_opn)) begin 
                        case (dsrd_hdng)
                            12'h000 : 
                                nxt_hdng = 12'h3FF; 
                            12'h3FF : 
                                nxt_hdng = 12'h7FF; 
                            12'h7FF : 
                                nxt_hdng = 12'hC00; 
                            12'hC00 : 
                                nxt_hdng = 12'h000; 
                        endcase 
                        assign_nxt_hdng = 1;
                    end

                    //TURNING RIGHT
                    else if ((!cmd0 & rght_opn) || (cmd0 & !lft_opn & rght_opn)) begin 
                        case (dsrd_hdng)
                            12'h000 : 
                                nxt_hdng = 12'hC00; 
                            12'hC00 : 
                                nxt_hdng = 12'h7FF; 
                            12'h7FF : 
                                nxt_hdng = 12'h3FF; 
                            12'h3FF : 
                                nxt_hdng = 12'h000; 
                        endcase 
                        assign_nxt_hdng = 1;
                    end 

                    //TURNING 180
                    else if ((!lft_opn & !rght_opn)) begin 
                        case (dsrd_hdng)
                            12'h000 : 
                                nxt_hdng = 12'h7FF; 
                            12'hC00 : 
                                nxt_hdng = 12'h3FF; 
                            12'h7FF : 
                                nxt_hdng = 12'h000; 
                            12'h3FF : 
                                nxt_hdng = 12'hC00; 
                        endcase 
                        assign_nxt_hdng = 1;
                    end 
                    
                    nxt_state = START_HEADING;
                end 
                    
            end 

            START_HEADING : begin 
                strt_hdng = 1'b1; 
                nxt_state = WAIT_MV_CMPLT; 
            end 

            WAIT_MV_CMPLT : begin 
                if (mv_cmplt) 
                    nxt_state = MV_FORWARD; 
            end 
            
            default : 
                nxt_state = IDLE;
            
        endcase
    end : SM
endmodule