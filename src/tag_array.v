module tag_array(
    input  wire        clk, reset,
    input  wire [3:0]  set_index,
    input  wire        write_en, write_way, write_dirty,
    input  wire [25:0] write_tag,
    output wire [25:0] tag0, tag1,
    output wire        valid0, valid1, dirty0, dirty1
);
    reg [25:0] tags [0:31];
    reg [31:0] valid, dirty;
    wire [4:0] entry = {set_index, write_way};

    assign tag0   = tags[{set_index, 1'b0}];
    assign tag1   = tags[{set_index, 1'b1}];
    assign valid0 = valid[{set_index, 1'b0}];
    assign valid1 = valid[{set_index, 1'b1}];
    assign dirty0 = dirty[{set_index, 1'b0}];
    assign dirty1 = dirty[{set_index, 1'b1}];

    always @(posedge clk) begin
        if (reset) begin
            valid <= 0;
            dirty <= 0;
        end else if (write_en) begin
            tags[entry]  <= write_tag;
            valid[entry] <= 1'b1;
            dirty[entry] <= write_dirty;
        end
    end
endmodule
