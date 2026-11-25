// FILE PURPOSE: the main wrapper of the two-way cache. It connects all the smaller blocks.
// Start of the module named cache_top.
module cache_top(
    // clk is the clock (the heartbeat of the circuit). reset clears the cache.
    input  wire        clk, reset,
    // req_valid = CPU says "I have a request". req_write = 1 means store (write), 0 means load (read).
    input  wire        req_valid, req_write,
    // req_addr = address the CPU wants. req_wdata = data the CPU wants to write.
    input  wire [31:0] req_addr, req_wdata,
    // Replies to CPU: ready for a request, reply is valid, it was a hit, there was an error.
    output wire        req_ready, resp_valid, resp_hit, resp_error,
    // The 32-bit data that we send back to the CPU.
    output wire [31:0] resp_rdata,
    // To memory: mem_valid = "I have a command". mem_write = 1 for write, 0 for read.
    output wire        mem_valid, mem_write,
    // To memory: which address to use, and what data to write there.
    output wire [31:0] mem_addr, mem_wdata,
    // From memory: mem_ready = "I have finished your command".
    input  wire        mem_ready,
    // From memory: the data that memory read for us.
    input  wire [31:0] mem_rdata
// End of the list of inputs and outputs.
);
    // Internal wires: the saved CPU address, the data from way 0 and way 1, and the data to store.
    wire [31:0] lookup_addr, data0, data1, line_data;
    // Wires for tags: the requested tag, and the tags stored in way 0 and way 1.
    wire [25:0] tag, tag0, tag1;
    // Wire for the set number (0 to 15).
    wire [3:0] index;
    // Status wires: is each way filled (valid), is it changed (dirty), and which way to remove.
    wire valid0, valid1, dirty0, dirty1, victim_way;
    // Control wires: write a line now, which way, mark it dirty or not, and update LRU.
    wire line_write, line_way, line_dirty, touch;
    // Way 0 is a hit if it holds real data AND its stored tag equals the requested tag.
    wire hit0 = valid0 && tag0 == tag;
    // Same hit check for way 1. Both ways are checked at the same time.
    wire hit1 = valid1 && tag1 == tag;
    // Is the line we are going to remove dirty? Pick way 1 or way 0, and check it is valid and dirty.
    wire victim_dirty = victim_way ? valid1 && dirty1 : valid0 && dirty0;

    // Add the address splitter. It gives us tag and index. The offset is not needed, so () is empty.
    address_decode decoder(.address(lookup_addr), .tag(tag), .index(index), .offset());
    // Add the tag storage block (labels, valid bits and dirty bits).
    tag_array tags(
        // Connect clock, reset, the chosen set, and the "write now" signal.
        .clk(clk), .reset(reset), .set_index(index), .write_en(line_write),
        // Connect which way to write, the new dirty value, and the new tag.
        .write_way(line_way), .write_dirty(line_dirty), .write_tag(tag),
        // Take out both stored tags and both valid bits.
        .tag0(tag0), .tag1(tag1), .valid0(valid0), .valid1(valid1),
        // Take out both dirty bits.
        .dirty0(dirty0), .dirty1(dirty1)
    // End of the tag block connections.
    );
    // Add the data storage block (the actual cached words).
    data_array data(
        // Connect clock, set number, write signal, and which way to write.
        .clk(clk), .set_index(index), .write_en(line_write), .write_way(line_way),
        // Connect the new data going in, and the data of both ways coming out.
        .write_data(line_data), .data0(data0), .data1(data1)
    // End of the data block connections.
    );
    // Add the LRU block, which remembers the least recently used way of each set.
    lru_unit lru(
        // Connect clock, reset, set number, and both valid bits.
        .clk(clk), .reset(reset), .set_index(index), .valid0(valid0), .valid1(valid1),
        // touch = "a way was just used". It also tells which way, and gets back the way to remove.
        .touch(touch), .touched_way(line_way), .victim_way(victim_way)
    // End of the LRU block connections.
    );
    // Add the controller, which is the brain that decides every step.
    cache_controller ctrl(
        // Connect clock, reset, and the CPU request signals.
        .clk(clk), .reset(reset), .req_valid(req_valid), .req_write(req_write),
        // Connect the CPU address and write data, and the "ready" reply.
        .req_addr(req_addr), .req_wdata(req_wdata), .req_ready(req_ready),
        // Connect the reply signals: valid, hit and error.
        .resp_valid(resp_valid), .resp_hit(resp_hit), .resp_error(resp_error),
        // Connect the reply data and the two hit results.
        .resp_rdata(resp_rdata), .hit0(hit0), .hit1(hit1),
        // Tell the controller which way to remove and whether that line is dirty.
        .victim_way(victim_way), .victim_dirty(victim_dirty),
        // hit_data: data from the way that hit. victim_data: data from the line being removed.
        .hit_data(hit1 ? data1 : data0), .victim_data(victim_way ? data1 : data0),
        // victim_tag: tag of the removed line. lookup_addr: the address the controller saved.
        .victim_tag(victim_way ? tag1 : tag0), .lookup_addr(lookup_addr),
        // The controller decides when, where and how (clean or dirty) to write a line.
        .line_write(line_write), .line_way(line_way), .line_dirty(line_dirty),
        // Connect the LRU update signal, the data to store, and the "memory command" signal.
        .touch(touch), .line_data(line_data), .mem_valid(mem_valid),
        // Connect the memory command type, address and write data.
        .mem_write(mem_write), .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        // Connect the memory's "done" signal and the data it returns.
        .mem_ready(mem_ready), .mem_rdata(mem_rdata)
    // End of the controller connections.
    );
// End of the cache_top module.
endmodule
