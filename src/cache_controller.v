// FILE PURPOSE: the brain of the cache. It is a state machine that handles one request at a time.
// INDEX_BITS = number of set-number bits: 4 for two-way (16 sets), 5 for direct-mapped (32 sets).
module cache_controller #(parameter INDEX_BITS = 4)(
    // Clock and reset inputs.
    input  wire        clk, reset,
    // From CPU: "I have a request", and whether it is a write.
    input  wire        req_valid, req_write,
    // From CPU: the address, and the data to write.
    input  wire [31:0] req_addr, req_wdata,
    // To CPU: "I am free to take a new request".
    output wire        req_ready,
    // To CPU: "my answer is ready now".
    output wire        resp_valid,
    // To CPU: was it a hit, and was there an error. "reg" means the value is held until changed.
    output reg         resp_hit, resp_error,
    // To CPU: the 32-bit answer data.
    output reg  [31:0] resp_rdata,
    // From the arrays: hit in way 0, hit in way 1, way to remove, and whether it is dirty.
    input  wire        hit0, hit1, victim_way, victim_dirty,
    // Data of the way that hit, and data of the line being removed.
    input  wire [31:0] hit_data, victim_data,
    // Tag of the line being removed. Its width depends on INDEX_BITS.
    input  wire [29-INDEX_BITS:0] victim_tag,
    // The saved copy of the CPU address, which the cache uses while working.
    output reg  [31:0] lookup_addr,
    // To the arrays: write a line, which way, dirty or clean, and "this way was used".
    output wire        line_write, line_way, line_dirty, touch,
    // The data that should be written into the cache line.
    output wire [31:0] line_data,
    // To memory: "I have a command", and whether it is a write.
    output wire        mem_valid, mem_write,
    // To memory: the address, and the data to write.
    output wire [31:0] mem_addr, mem_wdata,
    // From memory: "your command is done".
    input  wire        mem_ready,
    // From memory: the data that was read.
    input  wire [31:0] mem_rdata
// End of the list of inputs and outputs.
);
    // Give names to the 5 states (steps). IDLE = waiting, TAG_COMPARE = checking hit or miss,
    // WRITEBACK = saving changed old data to memory.
    localparam [2:0] IDLE = 0, TAG_COMPARE = 1, WRITEBACK = 2,
                     // REFILL = bringing the new data from memory, DONE = sending the answer.
                     REFILL = 3, DONE = 4;
    // Remembers which step we are in right now.
    reg [2:0] state;
    // Remembers if this request is a write, and which way we will fill after a miss.
    reg write_request, refill_way;
    // Remembers the CPU's write data.
    reg [31:0] request_data;
    // It is a hit if either way 0 or way 1 matched.
    wire hit = hit0 || hit1;
    // A good word address ends in 00 (it is a multiple of 4).
    wire aligned = lookup_addr[1:0] == 2'b00;
    // True when we are checking a good address and it hits.
    wire hit_access = state == TAG_COMPARE && aligned && hit;
    // True at the moment memory delivers the data during REFILL.
    wire fill = state == REFILL && mem_ready;

    // We can accept a new request only when not in reset and waiting in IDLE.
    assign req_ready  = !reset && state == IDLE;
    // The answer is valid only in the DONE state.
    assign resp_valid = !reset && state == DONE;
    // Write into the cache when new data arrives (fill), or when a store request hits.
    assign line_write = !reset && (fill || (hit_access && write_request));
    // Update LRU whenever a line is used: on a fill or on a hit.
    assign touch      = !reset && (fill || hit_access);
    // Which way to write: during REFILL the remembered way, otherwise the way that hit.
    assign line_way   = state == REFILL ? refill_way : hit1;
    // A store makes the line dirty. A read refill keeps it clean.
    assign line_dirty = write_request;
    // Data to put in the cache: CPU data for a store, memory data for a read.
    assign line_data  = write_request ? request_data : mem_rdata;
    // Send a memory command only during WRITEBACK or REFILL.
    assign mem_valid  = !reset && (state == WRITEBACK || state == REFILL);
    // It is a memory write only during WRITEBACK. Otherwise it is a read.
    assign mem_write  = state == WRITEBACK;
    // Memory address. For write-back, rebuild the old address: old tag + set number + 00.
    assign mem_addr   = mem_write ? {victim_tag, lookup_addr[INDEX_BITS+1:2], 2'b00} :
                                     // For refill, use the requested address with its last 2 bits set to 00.
                                     {lookup_addr[31:2], 2'b00};
    // The only thing we ever write to memory is the data of the removed line.
    assign mem_wdata  = victim_data;

    // Do the following at every rising clock edge.
    always @(posedge clk) begin
        // If reset is on, put everything back to the starting values.
        if (reset) begin
            // Go to the waiting state.
            state         <= IDLE;
            // Clear the saved address.
            lookup_addr   <= 0;
            // Clear the saved write data.
            request_data  <= 0;
            // Forget the read/write type.
            write_request <= 0;
            // Clear the saved way.
            refill_way    <= 0;
            // Clear the hit flag.
            resp_hit      <= 0;
            // Clear the error flag.
            resp_error    <= 0;
            // Clear the answer data.
            resp_rdata    <= 0;
        // If reset is off, run the state machine.
        end else begin
            // Check which state we are in.
            case (state)
                // IDLE: wait here until the CPU sends a request.
                IDLE: if (req_valid) begin
                    // Save the address.
                    lookup_addr   <= req_addr;
                    // Save the write data.
                    request_data  <= req_wdata;
                    // Save whether it is a read or a write.
                    write_request <= req_write;
                    // Clear the old hit flag.
                    resp_hit      <= 0;
                    // Clear the old error flag.
                    resp_error    <= 0;
                    // Clear the old answer data.
                    resp_rdata    <= 0;
                    // Next step: check the tags.
                    state         <= TAG_COMPARE;
                // End of the IDLE actions.
                end
                // TAG_COMPARE: decide between error, hit and miss.
                TAG_COMPARE: begin
                    // If the address is not a multiple of 4...
                    if (!aligned) begin
                        // ...report an error.
                        resp_error <= 1;
                        // Go straight to DONE. Memory is not used.
                        state <= DONE;
                    // Else if the data is in the cache (hit)...
                    end else if (hit) begin
                        // ...tell the CPU it was a hit.
                        resp_hit   <= 1;
                        // Answer: for a write, repeat the written data. For a read, give the cached data.
                        resp_rdata <= write_request ? request_data : hit_data;
                        // Go to DONE.
                        state      <= DONE;
                    // Else it is a miss.
                    end else begin
                        // Remember which way we will replace.
                        refill_way <= victim_way;
                        // If the old line is dirty, save it to memory first. Otherwise fetch the new data directly.
                        state      <= victim_dirty ? WRITEBACK : REFILL;
                    // End of the miss part.
                    end
                // End of the TAG_COMPARE actions.
                end
                // WRITEBACK: wait until memory says the old data is saved...
                WRITEBACK: if (mem_ready)
                    // ...then go and fetch the new data.
                    state <= REFILL;
                // REFILL: wait until memory delivers the new data.
                REFILL: if (mem_ready) begin
                    // Keep the answer: memory data for a read, CPU data for a write.
                    resp_rdata <= line_data;
                    // Go to DONE.
                    state      <= DONE;
                // End of the REFILL actions.
                end
                // DONE: the answer is shown for one cycle, then we return to waiting.
                DONE: state <= IDLE;
                // Safety: if the state is ever an unknown value, return to IDLE.
                default: state <= IDLE;
            // End of the state list.
            endcase
        // End of the "reset is off" part.
        end
    // End of the clocked block.
    end
// End of the module.
endmodule
