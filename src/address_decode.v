// FILE PURPOSE: cut a 32-bit address into three pieces: tag, index and offset.
// A "module" is one hardware block. This line starts the block named address_decode.
module address_decode(
    // Input: the full 32-bit address that we want to break apart.
    input  wire [31:0] address,
    // Output: tag (top 26 bits). It is like a name label that tells which memory block this is.
    output wire [25:0] tag,
    // Output: index (4 bits). It picks one of the 16 sets (groups) in the cache.
    output wire [3:0]  index,
    // Output: offset (2 bits). It picks one byte inside the 4-byte line.
    output wire [1:0]  offset
// End of the list of inputs and outputs.
);
    // Split the address: top 26 bits go to tag, next 4 to index, last 2 to offset.
    assign {tag, index, offset} = address;
// End of this hardware block.
endmodule
