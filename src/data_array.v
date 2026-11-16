module data_array(
    input  wire        clk,
    input  wire [3:0]  set_index,
    input  wire        write_en, write_way,
    input  wire [31:0] write_data,
    output wire [31:0] data0, data1
);
    reg [31:0] lines [0:31];

    assign data0 = lines[{set_index, 1'b0}];
    assign data1 = lines[{set_index, 1'b1}];

    always @(posedge clk) begin
        if (write_en)
            lines[{set_index, write_way}] <= write_data;
    end
endmodule
