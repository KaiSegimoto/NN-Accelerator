`timescale 1ns/1ps
module tb_activation_unit_relu_q8;
    reg  signed [23:0] in_val;
    wire        [7:0]  out_q8;
    integer errors;

    activation_unit_relu_q8 dut(
        .in_val(in_val),
        .out_q8(out_q8)
    );

    task check;
        input signed [23:0] vin;
        input [7:0] expected;
        begin
            in_val = vin;
            #1;
            if (out_q8 !== expected) begin
                $display("[FAIL] in=%0d out=%0d expected=%0d", vin, out_q8, expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        errors = 0;
        check(-24'sd1,   8'd0);
        check( 24'sd0,   8'd0);
        check( 24'sd37,  8'd37);
        check( 24'sd127, 8'd127);
        check( 24'sd128, 8'd127);

        if (errors == 0) $display("tb_activation_unit_relu_q8 PASS");
        else             $display("tb_activation_unit_relu_q8 FAIL, errors=%0d", errors);
        $finish;
    end
endmodule

