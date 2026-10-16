module dotprod_step4 (
    input  wire signed [7:0]  a_scalar,

    input  wire signed [7:0]  w0,
    input  wire signed [7:0]  w1,
    input  wire signed [7:0]  w2,
    input  wire signed [7:0]  w3,

    input  wire signed [23:0] acc0_in,
    input  wire signed [23:0] acc1_in,
    input  wire signed [23:0] acc2_in,
    input  wire signed [23:0] acc3_in,

    output wire signed [23:0] acc0_out,
    output wire signed [23:0] acc1_out,
    output wire signed [23:0] acc2_out,
    output wire signed [23:0] acc3_out
);
    wire signed [15:0] p0 = a_scalar * w0;
    wire signed [15:0] p1 = a_scalar * w1;
    wire signed [15:0] p2 = a_scalar * w2;
    wire signed [15:0] p3 = a_scalar * w3;

    // sign-extend 16->24 then add
    assign acc0_out = acc0_in + {{8{p0[15]}}, p0};
    assign acc1_out = acc1_in + {{8{p1[15]}}, p1};
    assign acc2_out = acc2_in + {{8{p2[15]}}, p2};
    assign acc3_out = acc3_in + {{8{p3[15]}}, p3};
endmodule