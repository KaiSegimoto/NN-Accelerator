module nn_control_fsm (
    input  wire clk,
    input  wire rst_n,
    input  wire load_req,
    input  wire execute_req,
    input  wire output_req,
    input  wire load_done,
    input  wire exec_done,
    input  wire output_done,
    output reg  in_load_mode,
    output reg  exec_mode,
    output reg  output_mode,
    output reg  busy
);
    localparam S_IDLE    = 2'd0;
    localparam S_LOAD    = 2'd1;
    localparam S_EXECUTE = 2'd2;
    localparam S_OUTPUT  = 2'd3;

    reg [1:0] state, next_state;

    always @(posedge clk) begin
        if (!rst_n)
            state <= S_IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        next_state   = state;
        in_load_mode = 1'b0;
        exec_mode    = 1'b0;
        output_mode  = 1'b0;
        busy         = 1'b1;

        case (state)
            S_IDLE: begin
                busy = 1'b0;
                if (load_req)
                    next_state = S_LOAD;
                else if (execute_req)
                    next_state = S_EXECUTE;
                else if (output_req)
                    next_state = S_OUTPUT;
            end
            S_LOAD: begin
                in_load_mode = 1'b1;
                if (load_done)
                    next_state = S_IDLE;
            end
            S_EXECUTE: begin
                exec_mode = 1'b1;
                if (exec_done)
                    next_state = S_IDLE;
            end
            S_OUTPUT: begin
                output_mode = 1'b1;
                if (output_done)
                    next_state = S_IDLE;
            end
            default: begin
                next_state = S_IDLE;
            end
        endcase
    end
endmodule
