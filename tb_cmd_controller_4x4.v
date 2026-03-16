`timescale 1ns/1ps
module tb_cmd_controller_4x4;
    reg clk;
    reg rst_n;
    reg [7:0] rx_byte;
    reg rx_valid;

    wire act_wr_pulse;
    wire [1:0] act_wr_row, act_wr_col;
    wire [7:0] act_wr_data;
    wire wgt_wr_pulse;
    wire [1:0] wgt_wr_row, wgt_wr_col;
    wire [7:0] wgt_wr_data;
    wire bias_wr_pulse;
    wire [1:0] bias_col;
    wire [23:0] bias_data;
    wire start_compute_pulse;
    wire start_output_pulse;

    integer errors;

    cmd_controller_4x4 dut(
        .clk(clk), .rst_n(rst_n),
        .rx_byte(rx_byte), .rx_valid(rx_valid),
        .act_wr_pulse(act_wr_pulse), .act_wr_row(act_wr_row), .act_wr_col(act_wr_col), .act_wr_data(act_wr_data),
        .wgt_wr_pulse(wgt_wr_pulse), .wgt_wr_row(wgt_wr_row), .wgt_wr_col(wgt_wr_col), .wgt_wr_data(wgt_wr_data),
        .bias_wr_pulse(bias_wr_pulse), .bias_col(bias_col), .bias_data(bias_data),
        .start_compute_pulse(start_compute_pulse), .start_output_pulse(start_output_pulse)
    );

    initial clk = 0;
    always #50 clk = ~clk;

    task send_byte;
        input [7:0] b;
        begin
            @(negedge clk);
            rx_byte = b;
            rx_valid = 1'b1;
            @(negedge clk);
            rx_valid = 1'b0;
        end
    endtask

    initial begin
        errors = 0;
        rst_n = 0;
        rx_byte = 0;
        rx_valid = 0;
        repeat (2) @(posedge clk);
        rst_n = 1;

        send_byte(8'hA0); send_byte(8'd2); send_byte(8'd1); send_byte(8'h55);
        @(posedge clk);
        if (!(act_wr_pulse && act_wr_row==2'd2 && act_wr_col==2'd1 && act_wr_data==8'h55)) errors = errors + 1;

        send_byte(8'hB0); send_byte(8'd3); send_byte(8'd0); send_byte(8'hAA);
        @(posedge clk);
        if (!(wgt_wr_pulse && wgt_wr_row==2'd3 && wgt_wr_col==2'd0 && wgt_wr_data==8'hAA)) errors = errors + 1;

        send_byte(8'hC0); send_byte(8'd1); send_byte(8'h11); send_byte(8'h22); send_byte(8'h33);
        @(posedge clk);
        if (!(bias_wr_pulse && bias_col==2'd1 && bias_data==24'h112233)) errors = errors + 1;

        send_byte(8'hD0);
        @(posedge clk);
        if (!start_compute_pulse) errors = errors + 1;

        send_byte(8'hE0);
        @(posedge clk);
        if (!start_output_pulse) errors = errors + 1;

        if (errors == 0) $display("tb_cmd_controller_4x4 PASS");
        else             $display("tb_cmd_controller_4x4 FAIL, errors=%0d", errors);
        $finish;
    end
endmodule

