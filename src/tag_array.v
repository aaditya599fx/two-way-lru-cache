// FILE PURPOSE: stores the labels of each cache line: its tag, valid bit and dirty bit.
// Start of the module.
module tag_array(
    // Clock and reset inputs.
    input  wire        clk, reset,
    // Which of the 16 sets we are using.
    input  wire [3:0]  set_index,
    // write_en = "write now", write_way = which way, write_dirty = new dirty value.
    input  wire        write_en, write_way, write_dirty,
    // The new tag to be saved.
    input  wire [25:0] write_tag,
    // Output: the stored tags of way 0 and way 1.
    output wire [25:0] tag0, tag1,
    // Output: valid (has real data) and dirty (data was changed) for both ways.
    output wire        valid0, valid1, dirty0, dirty1
// End of the list of inputs and outputs.
);
    // 32 tag boxes (one per cache line), 26 bits each.
    reg [25:0] tags [0:31];
    // 32 valid bits and 32 dirty bits, one of each per cache line.
    reg [31:0] valid, dirty;
    // Number (0 to 31) of the line being written: set number joined with way number.
    wire [4:0] entry = {set_index, write_way};

    // Read the tag of way 0 in this set.
    assign tag0   = tags[{set_index, 1'b0}];
    // Read the tag of way 1 in this set.
    assign tag1   = tags[{set_index, 1'b1}];
    // Read the valid bit of way 0.
    assign valid0 = valid[{set_index, 1'b0}];
    // Read the valid bit of way 1.
    assign valid1 = valid[{set_index, 1'b1}];
    // Read the dirty bit of way 0.
    assign dirty0 = dirty[{set_index, 1'b0}];
    // Read the dirty bit of way 1.
    assign dirty1 = dirty[{set_index, 1'b1}];

    // Do the following at every rising clock edge.
    always @(posedge clk) begin
        // If reset is on...
        if (reset) begin
            // ...mark every line as empty.
            valid <= 0;
            // ...mark every line as not changed. Old dirty data is thrown away, not saved to memory.
            dirty <= 0;
        // Otherwise, if we are told to write...
        end else if (write_en) begin
            // ...save the new tag.
            tags[entry]  <= write_tag;
            // ...mark this line as holding real data.
            valid[entry] <= 1'b1;
            // ...set it as dirty (changed) or clean.
            dirty[entry] <= write_dirty;
        // End of the write part.
        end
    // End of the clocked block.
    end
// End of the module.
endmodule
