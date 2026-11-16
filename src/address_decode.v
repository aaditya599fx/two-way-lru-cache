module address_decode(
    input  wire [31:0] address,
    output wire [25:0] tag,
    output wire [3:0]  index,
    output wire [1:0]  offset
);
    assign {tag, index, offset} = address;
endmodule
