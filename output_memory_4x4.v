module output_memory_4x4 (
    input  wire        clk,

    // write one row (4 cols) in one cycle
    input  wire        wr_en,
    input  wire [1:0]  wr_row,
    input  wire [7:0]  wr_d0,
    input  wire [7:0]  wr_d1,
    input  wire [7:0]  wr_d2,
    input  wire [7:0]  wr_d3,

    // read one row (4 cols) in one cycle (registered read)
    input  wire        rd_en,
    input  wire [1:0]  rd_row,
    output reg  [7:0]  rd_c0,
    output reg  [7:0]  rd_c1,
    output reg  [7:0]  rd_c2,
    output reg  [7:0]  rd_c3
);
    reg [7:0] mem0 [0:3];
    reg [7:0] mem1 [0:3];
    reg [7:0] mem2 [0:3];
    reg [7:0] mem3 [0:3];

    always @(posedge clk) begin
        if (wr_en) begin
            mem0[wr_row] <= wr_d0;
            mem1[wr_row] <= wr_d1;
            mem2[wr_row] <= wr_d2;
            mem3[wr_row] <= wr_d3;
        end

        if (rd_en) begin
            rd_c0 <= mem0[rd_row];
            rd_c1 <= mem1[rd_row];
            rd_c2 <= mem2[rd_row];
            rd_c3 <= mem3[rd_row];
        end
    end
endmodule