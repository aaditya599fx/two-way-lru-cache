// FILE PURPOSE: the basic testbench. It gives 15 hand-picked requests and checks each answer.
// `timescale: time is counted in 1ns steps, with 1ps accuracy.
`timescale 1ns/1ps
// A testbench has no inputs or outputs. It is the test setup itself.
module tb_cache;
    // Make the clock signal, starting at 0.
    reg clk = 0;
    // Flip the clock every 5ns, so one full clock cycle is 10ns.
    always #5 clk = ~clk;
    // CPU control signals that the test drives. We start with reset turned on.
    reg reset = 1, req_valid = 0, req_write = 0;
    // Address and write data that the test drives.
    reg [31:0] req_addr = 0, req_wdata = 0;
    // Reply signals coming from the cache.
    wire req_ready, resp_valid, resp_hit, resp_error;
    // Answer data coming from the cache.
    wire [31:0] resp_rdata;
    // Signals between the cache and the memory.
    wire mem_valid, mem_write, mem_ready;
    // Memory address, write data and read data wires.
    wire [31:0] mem_addr, mem_wdata, mem_rdata;
    // Counters: memory reads, memory writes, and tests passed.
    integer reads = 0, writes = 0, checks = 0;
    // Notes about the most recent memory read and write, used for checking.
    reg [31:0] last_read_addr, last_write_addr, last_write_data;
    // Test addresses A to E. All fall in the same set (set 5), so they compete with each other. 'h means hex.
    localparam [31:0] A = 'h014, B = 'h054, C = 'h094, D = 'h0D4, E = 'h114;
    // An address that falls in a different set (set 6).
    localparam [31:0] OTHER = 'h018;
    // New data values that we will write.
    localparam [31:0] NEW_A = 'h12345678, NEW_E = 'hA1B2C3D4;

    // Create the cache being tested (dut = design under test). ".*" connects signals with the same name.
    cache_top dut(.*);
    // Create the pretend memory.
    main_memory memory(
        // Connect clock, reset and the command signals.
        .clk(clk), .reset(reset), .valid(mem_valid), .write_en(mem_write),
        // Connect the memory address, data and ready signals.
        .address(mem_addr), .write_data(mem_wdata), .ready(mem_ready), .read_data(mem_rdata)
    // End of the memory connections.
    );

    // This block watches memory traffic at every clock edge.
    always @(posedge clk) begin
        // When a memory command completes...
        if (mem_valid && mem_ready) begin
            // ...if it was a write...
            if (mem_write) begin
                // ...count one more write.
                writes <= writes + 1;
                // Remember where it wrote.
                last_write_addr <= mem_addr;
                // Remember what it wrote.
                last_write_data <= mem_wdata;
            // Otherwise it was a read...
            end else begin
                // ...count one more read.
                reads <= reads + 1;
                // Remember which address was read.
                last_read_addr <= mem_addr;
            // End of the read part.
            end
        // End of the "command completed" part.
        end
    // End of the watcher block.
    end

    // A "task" is a reusable function: send one request and check the result.
    task automatic access_word(
        // label = name of the test, printed when it passes.
        input string label,
        // write_en = 1 for a store, 0 for a load.
        input logic write_en,
        // The address to access, and the data to write.
        input logic [31:0] address, wdata,
        // What we expect: hit or not, and error or not.
        input logic expected_hit, expected_error,
        // The answer data we expect.
        input logic [31:0] expected_data,
        // How many memory reads and writes we expect.
        input integer expected_reads, expected_writes
    // End of the task's inputs.
    );
        // Variables to save the counter values before the request.
        integer old_reads, old_writes;
        // Start of the task steps.
        begin
            // Wait for the falling clock edge, so signals change safely between rising edges.
            @(negedge clk);
            // Keep waiting until the cache is free.
            while (!req_ready) @(negedge clk);
            // Save the current read count.
            old_reads = reads;
            // Save the current write count.
            old_writes = writes;
            // Put the address on the cache input.
            req_addr = address;
            // Put the write data on the input.
            req_wdata = wdata;
            // Set read or write.
            req_write = write_en;
            // Say "I have a request".
            req_valid = 1;
            // Wait one clock, so the cache picks it up.
            @(negedge clk);
            // Remove the request signal.
            req_valid = 0;
            // Wait until the cache says the answer is ready.
            while (!resp_valid) @(negedge clk);
            // Now compare. Fail if the hit or error flag is wrong...
            if (resp_hit !== expected_hit || resp_error !== expected_error ||
                // ...or the data is wrong, or the number of memory reads is wrong...
                resp_rdata !== expected_data || reads - old_reads != expected_reads ||
                // ...or the number of memory writes is wrong...
                writes - old_writes != expected_writes ||
                // ...or memory was read from the wrong address.
                (expected_reads != 0 && last_read_addr !== address))
                // Stop the simulation and print what went wrong.
                $fatal(1, "%s: hit=%b error=%b data=%h reads=%0d writes=%0d read_addr=%h",
                       // Values to fill into the error message.
                       label, resp_hit, resp_error, resp_rdata, reads-old_reads,
                       // The remaining values for the error message.
                       writes-old_writes, last_read_addr);
            // If nothing failed, count one more passed test.
            checks = checks + 1;
            // Print PASS with the test number and name.
            $display("PASS %02d %s", checks, label);
        // End of the task steps.
        end
    // End of the task.
    endtask

    // The main test sequence starts here and runs once.
    initial begin
        // Create a waveform file, so signals can be viewed as graphs.
        $dumpfile("build/cache.vcd");
        // Record all signals of this testbench.
        $dumpvars(0, tb_cache);
        // Wait 2 clock cycles while reset is on.
        repeat (2) @(negedge clk);
        // Turn reset off. Testing begins.
        reset = 0;
        // Read A. The cache is empty, so it is a miss and goes into way 0.
        access_word("cold miss fills way 0", 0, A, 0, 0, 0, 'hCAFE0005, 1, 0);
        // Read A again. Now it should hit.
        access_word("repeat access hits", 0, A, 0, 1, 0, 'hCAFE0005, 0, 0);
        // Read B. Same set, so it goes into the empty way 1.
        access_word("second tag fills invalid way 1", 0, B, 0, 0, 0, 'hCAFE0015, 1, 0);
        // Write new data to A. It hits, A becomes dirty and most recently used.
        access_word("write hit makes A dirty and most recent", 1, A, NEW_A, 1, 0, NEW_A, 0, 0);
        // Check that memory still has A's OLD value (this is what write-back means)...
        if (memory.words[A >> 2] !== 32'hCAFE0005)
            // ...and fail if memory was changed too early.
            $fatal(1, "Write hit changed backing memory before eviction");
        // Read C. The set is full, so the older line B is removed. B is clean, so no write is needed.
        access_word("C evicts clean B", 0, C, 0, 0, 0, 'hCAFE0025, 1, 0);
        // Read A. It must still be there, with the new data.
        access_word("A survives and retains updated data", 0, A, 0, 1, 0, NEW_A, 0, 0);
        // Access a different set. It should not disturb set 5.
        access_word("separate set fills independently", 0, OTHER, 0, 0, 0, 'hCAFE0006, 1, 0);
        // Read B again. It misses, and now C is removed.
        access_word("B misses again and evicts C", 0, B, 0, 0, 0, 'hCAFE0015, 1, 0);
        // Read D. A is now the oldest and is dirty, so it must be written to memory first.
        access_word("D evicts dirty A and writes it back", 0, D, 0, 0, 0, 'hCAFE0035, 1, 1);
        // Check that the write-back used the right address and data...
        if (last_write_addr !== A || last_write_data !== NEW_A ||
            // ...and that memory now holds the new value.
            memory.words[A >> 2] !== NEW_A)
            // If not, fail the test.
            $fatal(1, "Dirty victim address/data mismatch");
        // Read A again. It misses, and memory gives the updated value.
        access_word("A refills from updated backing memory", 0, A, 0, 0, 0, NEW_A, 1, 0);
        // Write E while it is not cached. The cache loads the line, then stores the data (write-allocate).
        access_word("write miss allocates dirty E", 1, E, NEW_E, 0, 0, NEW_E, 1, 0);
        // Read E. It should hit.
        access_word("read hits allocated E", 0, E, 0, 1, 0, NEW_E, 0, 0);
        // Check that memory still has E's old value, because we use write-back...
        if (memory.words[E >> 2] !== 32'hCAFE0045)
            // ...and fail if it changed too early.
            $fatal(1, "Write allocate changed backing memory before eviction");
        // Use address A+1, which is not a multiple of 4. We expect an error and no memory use.
        access_word("unaligned request returns error", 0, A+1, 0, 0, 1, 0, 0, 0);
        // The line in the other set should still be there.
        access_word("other set retains data", 0, OTHER, 0, 1, 0, 'hCAFE0006, 0, 0);
        // Wait for a falling clock edge.
        @(negedge clk);
        // Turn reset on.
        reset = 1;
        // Hold it for one clock cycle.
        @(negedge clk);
        // Turn reset off.
        reset = 0;
        // Read A again. Reset emptied the cache, so it misses, but memory still has the data.
        access_word("reset invalidates cache but retains memory", 0, A, 0, 0, 0, NEW_A, 1, 0);
        // Print the final summary.
        $display("PASS all %0d checks (%0d refills, %0d writebacks)", checks, reads, writes);
        // End the simulation successfully.
        $finish;
    // End of the main test sequence.
    end

    // A safety timer, running alongside the test.
    initial begin
        // Wait for 5000ns.
        #5000;
        // If the test is still running, something is stuck, so fail.
        $fatal(1, "Testbench timeout");
    // End of the safety timer.
    end
// End of the testbench.
endmodule
