`timescale 1ns/1ps
module tb_piso_8;
    reg clk;
    reg rst_n;
    reg ser_cs;
    reg load;
    reg [7:0] byte_in;
    wire ser_dout;
    wire busy;
    wire done;
    integer errors;

    piso_8 dut(
        .clk(clk), .rst_n(rst_n),
        .ser_cs(ser_cs), .load(load), .byte_in(byte_in),
        .ser_dout(ser_dout), .busy(busy), .done(done)
    );

    initial clk = 0;
    always #50 clk = ~clk;

    initial begin
        errors = 0;
        rst_n = 0;
        ser_cs = 1;
        load = 0;
        byte_in = 8'hA5;
        repeat (2) @(posedge clk);
        rst_n = 1;

        @(negedge clk);
        load = 1;
        @(negedge clk);
        load = 0;

        repeat (12) @(posedge clk);

        if (busy !== 1'b0) errors = errors + 1;
        if (done !== 1'b0) begin
            // done is pulse, only sanity check no stuck-high
            errors = errors + 1;
        end

        if (errors == 0) $display("tb_piso_8 PASS");
        else             $display("tb_piso_8 FAIL, errors=%0d", errors);
        $finish;
    end
endmodule

