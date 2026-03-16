module sram_4x4x8_4read (
    input  wire        clk,
    input  wire        write_enable,
    input  wire        read_enable,

    input  wire [1:0]  row_select,    // 0~3
    input  wire [1:0]  col_select,    // 0~3 (write target column)

    input  wire [7:0]  write_data_in,

    output reg  [7:0]  read_col0_out,
    output reg  [7:0]  read_col1_out,
    output reg  [7:0]  read_col2_out,
    output reg  [7:0]  read_col3_out
);

    // 4 banks, each bank is 4 rows x 8-bit
    reg [7:0] mem_col0 [0:3];
    reg [7:0] mem_col1 [0:3];
    reg [7:0] mem_col2 [0:3];
    reg [7:0] mem_col3 [0:3];

    always @(posedge clk) begin
        // -------------------------
        // Write: only one column bank is written
        // -------------------------
        if (write_enable) begin
            case (col_select)
                2'd0: mem_col0[row_select] <= write_data_in;
                2'd1: mem_col1[row_select] <= write_data_in;
                2'd2: mem_col2[row_select] <= write_data_in;
                2'd3: mem_col3[row_select] <= write_data_in;
                default: ;
            endcase
        end

        // -------------------------
        // Read: in ONE cycle, read out 4 columns of the same row
        // -------------------------
        if (read_enable) begin
            // write-first for the written column (same cycle)
            // other columns just read memory
            read_col0_out <= (write_enable && col_select==2'd0) ? write_data_in : mem_col0[row_select];
            read_col1_out <= (write_enable && col_select==2'd1) ? write_data_in : mem_col1[row_select];
            read_col2_out <= (write_enable && col_select==2'd2) ? write_data_in : mem_col2[row_select];
            read_col3_out <= (write_enable && col_select==2'd3) ? write_data_in : mem_col3[row_select];
        end
    end

endmodule

