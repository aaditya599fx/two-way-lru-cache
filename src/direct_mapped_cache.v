// Equal-capacity baseline: 32 sets x 1 way x 4 bytes, same controller timing.
// FILE PURPOSE: the simpler cache we compare against. Each address has only ONE possible place.
// Start of the module.
module direct_mapped_cache(
    // CPU side inputs: clock, reset, "I have a request", and read/write.
    input wire clk, reset, req_valid, req_write,
    // CPU address and CPU write data.
    input wire [31:0] req_addr, req_wdata,
    // Replies to CPU: ready, answer valid, hit and error.
    output wire req_ready, resp_valid, resp_hit, resp_error,
    // Answer data to the CPU.
    output wire [31:0] resp_rdata,
    // To memory: "I have a command", and whether it is a write.
    output wire mem_valid, mem_write,
    // To memory: address and write data.
    output wire [31:0] mem_addr, mem_wdata,
    // From memory: "done".
    input wire mem_ready,
    // From memory: the data that was read.
    input wire [31:0] mem_rdata
// End of the list of inputs and outputs.
);
    // 32 tag boxes. Tags are 25 bits because the set number now takes 5 bits.
    reg [24:0] tags [0:31];
    // 32 data boxes of 32 bits each (128 bytes, same size as the two-way cache).
    reg [31:0] words [0:31];
    // One valid bit and one dirty bit for each box.
    reg [31:0] valid, dirty;
    // The saved CPU address, and the data to be stored.
    wire [31:0] lookup_addr, line_data;
    // Address bits 6 to 2 pick one of the 32 boxes.
    wire [4:0] index = lookup_addr[6:2];
    // Control signals: write a line now, and mark it dirty or not.
    wire line_write, line_dirty;
    // Hit if this box holds real data and its tag matches the address tag.
    wire hit = valid[index] && tags[index] == lookup_addr[31:7];

    // Do the following at every rising clock edge.
    always @(posedge clk) begin
        // If reset is on...
        if (reset) begin
            // ...mark every box as empty.
            valid <= 0;
            // ...mark every box as clean.
            dirty <= 0;
        // Otherwise, if the controller says write...
        end else if (line_write) begin
            // ...save the tag.
            tags[index] <= lookup_addr[31:7];
            // ...save the data.
            words[index] <= line_data;
            // ...mark the box as filled.
            valid[index] <= 1;
            // ...set it as dirty or clean.
            dirty[index] <= line_dirty;
        // End of the write part.
        end
    // End of the clocked block.
    end

    // Reuse the same controller, now with 5 index bits, so the comparison is fair.
    cache_controller #(.INDEX_BITS(5)) ctrl(
        // Connect clock, reset and the CPU request signals.
        .clk(clk), .reset(reset), .req_valid(req_valid), .req_write(req_write),
        // Connect the CPU address, write data and ready.
        .req_addr(req_addr), .req_wdata(req_wdata), .req_ready(req_ready),
        // Connect the reply signals.
        .resp_valid(resp_valid), .resp_hit(resp_hit), .resp_error(resp_error),
        // There is only one way, so hit1 and victim_way are fixed at 0.
        .resp_rdata(resp_rdata), .hit0(hit), .hit1(1'b0), .victim_way(1'b0),
        // The old line needs saving if it is filled and changed.
        .victim_dirty(valid[index] && dirty[index]),
        // The same single box gives both the hit data and the removed data.
        .hit_data(words[index]), .victim_data(words[index]),
        // Connect the old tag, and the saved address.
        .victim_tag(tags[index]), .lookup_addr(lookup_addr),
        // line_way is left unconnected () because there is no second way.
        .line_write(line_write), .line_way(), .line_dirty(line_dirty),
        // touch is unconnected because with one way no LRU is needed.
        .touch(), .line_data(line_data), .mem_valid(mem_valid),
        // Connect the memory command signals.
        .mem_write(mem_write), .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        // Connect the memory's reply signals.
        .mem_ready(mem_ready), .mem_rdata(mem_rdata)
    // End of the controller connections.
    );
// End of the module.
endmodule
