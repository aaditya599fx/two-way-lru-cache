// FILE PURPOSE: stores the actual data of the cache (32 lines of 4 bytes = 128 bytes).
// Start of the module.
module data_array(
    // Clock input. Writing happens only when the clock ticks.
    input  wire        clk,
    // Which of the 16 sets we are using.
    input  wire [3:0]  set_index,
    // write_en = "write now". write_way = which way (0 or 1) to write.
    input  wire        write_en, write_way,
    // The 32-bit word to be written.
    input  wire [31:0] write_data,
    // The stored words of way 0 and way 1 of the chosen set.
    output wire [31:0] data0, data1
// End of the list of inputs and outputs.
);
    // The storage itself: 32 boxes (16 sets x 2 ways), each 32 bits wide.
    reg [31:0] lines [0:31];

    // Read way 0. Box number = set number followed by 0 (same as set x 2).
    assign data0 = lines[{set_index, 1'b0}];
    // Read way 1. Box number = set number followed by 1 (same as set x 2 + 1).
    assign data1 = lines[{set_index, 1'b1}];

    // Do the following every time the clock goes from 0 to 1.
    always @(posedge clk) begin
        // Only if we are told to write...
        if (write_en)
            // ...save the new word in the box for this set and way. "<=" means update at the clock edge.
            lines[{set_index, write_way}] <= write_data;
    // End of the clocked block.
    end
// End of the module.
endmodule
