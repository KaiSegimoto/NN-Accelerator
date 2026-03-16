module piso_8 #(
    parameter MSB_FIRST = 1
)(
    input  wire       clk,
    input  wire       rst_n,

    input  wire       ser_cs,     // CS active HIGH
    input  wire       load,       // 1-cycle pulse to load byte_in and start sending
    input  wire [7:0] byte_in,

    output reg        ser_dout,   // MISO
    output reg        busy,       // 1 while shifting bits
    output reg        done        // 1-cycle pulse when one byte finished
);
    reg [7:0] sh;
    reg [2:0] cnt;

    always @(posedge clk) begin
        if (!rst_n) begin
            sh <= 8'd0;
            cnt <= 3'd0;
            ser_dout <= 1'b0;
            busy <= 1'b0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;

            if (!ser_cs) begin
                // abort if CS drops
                busy <= 1'b0;
                cnt  <= 3'd0;
            end else begin
                if (load && !busy) begin
                    sh   <= byte_in;
                    cnt  <= 3'd0;
                    busy <= 1'b1;

                    // output first bit immediately (same cycle visible after clk edge)
                    ser_dout <= MSB_FIRST ? byte_in[7] : byte_in[0];
                end else if (busy) begin
                    cnt <= cnt + 3'd1;

                    if (cnt == 3'd7) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                    end else begin
                        if (MSB_FIRST) begin
                            sh <= {sh[6:0], 1'b0};
                            ser_dout <= sh[6]; // next MSB
                        end else begin
                            sh <= {1'b0, sh[7:1]};
                            ser_dout <= sh[1]; // next LSB
                        end
                    end
                end
            end
        end
    end
endmodule