module spi_output_fsm_4x4 (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        start,   // 1-cycle pulse
    output reg         done,    // 1-cycle pulse when all bytes sent

    // SPI window
    input  wire        ser_cs,

    // read output memory (registered read)
    output reg         out_rd_en,
    output reg  [1:0]  out_rd_row,
    input  wire [7:0]  out_c0,
    input  wire [7:0]  out_c1,
    input  wire [7:0]  out_c2,
    input  wire [7:0]  out_c3,

    // drive PISO
    output reg         tx_load,
    output reg  [7:0]  tx_byte,
    input  wire        tx_busy,
    input  wire        tx_done
);

    localparam ST_IDLE      = 4'd0;
    localparam ST_RD_ROW    = 4'd1;
    localparam ST_WAIT_ROW  = 4'd2;
    localparam ST_LATCH_ROW = 4'd3;
    localparam ST_SEND0     = 4'd4;
    localparam ST_SEND1     = 4'd5;
    localparam ST_SEND2     = 4'd6;
    localparam ST_SEND3     = 4'd7;

    reg [3:0] st;
    reg [1:0] row;
    reg       load_issued;

    // latch one row (4 bytes) after outmem read
    reg [7:0] r0, r1, r2, r3;

    always @(posedge clk) begin
        if (!rst_n) begin
            st <= ST_IDLE;
            row <= 2'd0;

            done <= 1'b0;
            out_rd_en <= 1'b0;
            out_rd_row <= 2'd0;

            tx_load <= 1'b0;
            tx_byte <= 8'd0;
            load_issued <= 1'b0;

            r0 <= 0; r1 <= 0; r2 <= 0; r3 <= 0;
        end else begin
            done <= 1'b0;
            tx_load <= 1'b0;
            out_rd_en <= 1'b0;

            // if CS drops mid-stream, go back idle
            if (!ser_cs && st != ST_IDLE) begin
                st <= ST_IDLE;
                row <= 2'd0;
                load_issued <= 1'b0;
            end else begin
                case (st)
                    ST_IDLE: begin
                        load_issued <= 1'b0;
                        if (start) begin
                            row <= 2'd0;
                            st  <= ST_RD_ROW;
                        end
                    end

                    ST_RD_ROW: begin
                        out_rd_row <= row;
                        out_rd_en  <= 1'b1;
                        st <= ST_WAIT_ROW;
                    end

                    ST_WAIT_ROW: begin
                        st <= ST_LATCH_ROW;
                    end

                    ST_LATCH_ROW: begin
                        // latch registered outputs (valid this cycle)
                        r0 <= out_c0;
                        r1 <= out_c1;
                        r2 <= out_c2;
                        r3 <= out_c3;
                        load_issued <= 1'b0;
                        st <= ST_SEND0;
                    end

                    ST_SEND0: begin
                        if (tx_done) begin
                            load_issued <= 1'b0;
                            st <= ST_SEND1;
                        end else if (!load_issued) begin
                            tx_byte <= r0;
                            tx_load <= 1'b1;
                            load_issued <= 1'b1;
                        end
                    end

                    ST_SEND1: begin
                        if (tx_done) begin
                            load_issued <= 1'b0;
                            st <= ST_SEND2;
                        end else if (!load_issued) begin
                            tx_byte <= r1;
                            tx_load <= 1'b1;
                            load_issued <= 1'b1;
                        end
                    end

                    ST_SEND2: begin
                        if (tx_done) begin
                            load_issued <= 1'b0;
                            st <= ST_SEND3;
                        end else if (!load_issued) begin
                            tx_byte <= r2;
                            tx_load <= 1'b1;
                            load_issued <= 1'b1;
                        end
                    end

                    ST_SEND3: begin
                        if (tx_done) begin
                            load_issued <= 1'b0;
                            if (row == 2'd3) begin
                                done <= 1'b1;
                                st <= ST_IDLE;
                            end else begin
                                row <= row + 2'd1;
                                st <= ST_RD_ROW;
                            end
                        end else if (!load_issued) begin
                            tx_byte <= r3;
                            tx_load <= 1'b1;
                            load_issued <= 1'b1;
                        end
                    end

                    default: st <= ST_IDLE;
                endcase
            end
        end
    end

endmodule
