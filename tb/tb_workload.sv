// FILE PURPOSE: the benchmark testbench. It replays a long list of requests (a "trace")
// and checks every single one against the answers worked out by Python.
// `timescale: time is counted in 1ns steps, with 1ps accuracy.
`timescale 1ns/1ps
// Start of the testbench.
module tb_workload;
    // Setting: 0 = test the two-way cache, 1 = test the direct-mapped cache.
    parameter DIRECT = 0;
    // Make the clock signal.
    reg clk = 0;
    // Flip it every 5ns (one cycle = 10ns).
    always #5 clk = ~clk;
    // CPU control signals. Reset starts on.
    reg reset = 1, req_valid = 0, req_write = 0;
    // CPU address and write data.
    reg [31:0] req_addr = 0, req_wdata = 0;
    // Reply signals from the cache.
    wire req_ready, resp_valid, resp_hit, resp_error;
    // Answer data from the cache.
    wire [31:0] resp_rdata;
    // Signals between the cache and memory.
    wire mem_valid, mem_write, mem_ready;
    // Memory address and data wires.
    wire [31:0] mem_addr, mem_wdata, mem_rdata;

    // "generate" chooses which hardware to build before the simulation runs.
    generate
        // If DIRECT is 1...
        if (DIRECT) begin : baseline
            // ...build the direct-mapped cache.
            direct_mapped_cache dut(.*);
        // Otherwise...
        end else begin : associative
            // ...build the two-way cache.
            cache_top dut(.*);
        // End of the choice.
        end
    // End of generate.
    endgenerate
    // Create the pretend memory.
    main_memory memory(
        // Connect clock, reset and command signals.
        .clk(clk), .reset(reset), .valid(mem_valid), .write_en(mem_write),
        // Connect address, write data and ready.
        .address(mem_addr), .write_data(mem_wdata), .ready(mem_ready),
        // Connect the read data.
        .read_data(mem_rdata)
    // End of the memory connections.
    );

    // fd = opened file, status = number of values read. Also totals: requests, hits and cycles.
    integer fd, status, count = 0, hits = 0, cycles = 0;
    // Memory read and write counts, time taken, and counts saved before each request.
    integer reads = 0, writes = 0, latency, before_reads, before_writes;
    // Values read from the trace: expected hit, expected write-back, and read/write type.
    integer expected_hit, expected_writeback, store;
    // The request's address and data, the expected answer, and the expected removed line.
    reg [31:0] address, data, expected_data, victim_address, victim_data;
    // What was actually seen on the memory side.
    reg [31:0] observed_address, observed_data, observed_read;
    // The name of the trace file.
    string trace_path;

    // Watch memory traffic at every clock edge.
    always @(posedge clk) begin
        // When a memory command completes...
        if (mem_valid && mem_ready) begin
            // ...if it is a write...
            if (mem_write) begin
                // ...count it.
                writes = writes + 1;
                // Save the write address.
                observed_address = mem_addr;
                // Save the written data.
                observed_data = mem_wdata;
            // Otherwise it is a read...
            end else begin
                // ...count it.
                reads = reads + 1;
                // Save the read address.
                observed_read = mem_addr;
            // End of the read part.
            end
        // End of the "command completed" part.
        end
    // End of the watcher block.
    end

    // The main test starts here.
    initial begin
        // Get the trace file name from the command line (+TRACE=...).
        if (!$value$plusargs("TRACE=%s", trace_path))
            // Stop if no name was given.
            $fatal(1, "Supply +TRACE=path");
        // Open the file for reading.
        fd = $fopen(trace_path, "r");
        // Stop if the file cannot be opened.
        if (fd == 0) $fatal(1, "Cannot open trace");
        // Keep reset on for 2 clock cycles.
        repeat (2) @(negedge clk);
        // Turn reset off.
        reset = 0;
        // Read the first line of the trace: 8 values.
        status = $fscanf(fd, "%d %h %h %d %h %d %h %h\n", store,
                         // Read/write type, address, data, expected hit, expected answer...
                         address, data, expected_hit, expected_data,
                         // ...expected write-back, and the address and data of the removed line.
                         expected_writeback, victim_address, victim_data);
        // Repeat as long as a full line of 8 values was read.
        while (status == 8) begin
            // Wait for a falling clock edge.
            @(negedge clk);
            // Wait until the cache is free.
            while (!req_ready) @(negedge clk);
            // Send a request.
            req_valid = 1;
            // Set read or write.
            req_write = store;
            // Set the address.
            req_addr = address;
            // Set the write data.
            req_wdata = data;
            // Save the read count before this request.
            before_reads = reads;
            // Save the write count before this request.
            before_writes = writes;
            // Wait one clock, so the cache accepts it.
            @(negedge clk);
            // Remove the request signal.
            req_valid = 0;
            // Start counting the time taken.
            latency = 0;
            // While the answer is not ready...
            while (!resp_valid) begin
                // ...wait one clock...
                @(negedge clk);
                // ...and add 1 to the time.
                latency = latency + 1;
                // If it takes more than 30 cycles, the cache is stuck, so fail.
                if (latency > 30) $fatal(1, "Transaction timeout");
            // End of the waiting loop.
            end
            // Check 1: no error, and hit or miss is as expected...
            if (resp_error !== 0 || resp_hit !== (expected_hit != 0) ||
                // ...and the answer data is correct.
                resp_rdata !== expected_data)
                // If not, stop with an error message.
                $fatal(1, "Response mismatch transaction %0d addr=%h hit=%b data=%h expected=%h",
                       // Values for the error message.
                       count, address, resp_hit, resp_rdata, expected_data);
            // Check 2: a miss must cause exactly 1 memory read, and a hit none...
            if (reads-before_reads != 1-expected_hit ||
                // ...and the number of write-backs must be as expected.
                writes-before_writes != expected_writeback)
                // If not, fail.
                $fatal(1, "Traffic mismatch transaction %0d", count);
            // Check 3: on a miss, memory must be read from the requested address.
            if (!expected_hit && observed_read !== address)
                // If not, fail.
                $fatal(1, "Refill address mismatch");
            // Check 4: if a write-back was expected...
            if (expected_writeback &&
                // ...it must have the correct old address and old data.
                (observed_address !== victim_address || observed_data !== victim_data))
                // If not, fail.
                $fatal(1, "Victim write-back mismatch");
            // Check 5: time must be 1 cycle, plus 3 for a miss, plus 3 for a write-back.
            if (latency != 1 + 3*(1-expected_hit) + 3*expected_writeback)
                // If not, fail.
                $fatal(1, "Latency mismatch %0d", latency);
            // Count this request.
            count = count + 1;
            // Add to the number of hits.
            hits = hits + expected_hit;
            // Add to the total cycles.
            cycles = cycles + latency;
            // Read the next line of the trace.
            status = $fscanf(fd, "%d %h %h %d %h %d %h %h\n", store,
                             // The same 8 values as before...
                             address, data, expected_hit, expected_data,
                             // ...for the next request.
                             expected_writeback, victim_address, victim_data);
        // End of the loop.
        end
        // At the end, status must be -1 (end of file) and at least one request must have run.
        if (status != -1 || count == 0) $fatal(1, "Invalid or empty trace");
        // Print the totals. The Python script reads this RESULT line.
        $display("RESULT %0d %0d %0d %0d %0d", count, hits, reads, writes, cycles);
        // Close the file.
        $fclose(fd);
        // End the simulation.
        $finish;
    // End of the main test.
    end
// End of the testbench.
endmodule
