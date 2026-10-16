`timescale 1ns/1ps
module tb_dotprod_step4;
    reg  signed [7:0]  a_scalar;
    reg  signed [7:0]  w0, w1, w2, w3;
    reg  signed [23:0] acc0_in, acc1_in, acc2_in, acc3_in;
    wire signed [23:0] acc0_out, acc1_out, acc2_out, acc3_out;
    integer errors;

    dotprod_step4 dut(
        .a_scalar(a_scalar),
        .w0(w0), .w1(w1), .w2(w2), .w3(w3),
        .acc0_in(acc0_in), .acc1_in(acc1_in), .acc2_in(acc2_in), .acc3_in(acc3_in),
        .acc0_out(acc0_out), .acc1_out(acc1_out), .acc2_out(acc2_out), .acc3_out(acc3_out)
    );

    task check_case;
        input signed [7:0] a;
        input signed [7:0] iw0, iw1, iw2, iw3;
        input signed [23:0] ia0, ia1, ia2, ia3;
        begin
            a_scalar = a;
            w0 = iw0; w1 = iw1; w2 = iw2; w3 = iw3;
            acc0_in = ia0; acc1_in = ia1; acc2_in = ia2; acc3_in = ia3;
            #1;
            if (acc0_out !== ia0 + a*iw0) errors = errors + 1;
            if (acc1_out !== ia1 + a*iw1) errors = errors + 1;
            if (acc2_out !== ia2 + a*iw2) errors = errors + 1;
            if (acc3_out !== ia3 + a*iw3) errors = errors + 1;
        end
    endtask

    initial begin
        errors = 0;
        check_case(8'sd3,  8'sd2,  8'sd4,  8'sd1, -8'sd2, 24'sd0, 24'sd0, 24'sd0, 24'sd0);
        check_case(-8'sd5, 8'sd7, -8'sd3, 8'sd2,  8'sd1, 24'sd9, -24'sd1, 24'sd10, -24'sd6);

        if (errors == 0) $display("tb_dotprod_step4 PASS");
        else             $display("tb_dotprod_step4 FAIL, errors=%0d", errors);
        $finish;
    end
endmodule

