`timescale 1ns/1ps
module tb_workload;
    parameter DIRECT = 0;
    reg clk = 0;
    always #5 clk = ~clk;
    reg reset = 1, req_valid = 0, req_write = 0;
    reg [31:0] req_addr = 0, req_wdata = 0;
    wire req_ready, resp_valid, resp_hit, resp_error;
    wire [31:0] resp_rdata;
    wire mem_valid, mem_write, mem_ready;
    wire [31:0] mem_addr, mem_wdata, mem_rdata;

    generate
        if (DIRECT) begin : baseline
            direct_mapped_cache dut(.*);
        end else begin : associative
            cache_top dut(.*);
        end
    endgenerate
    main_memory memory(
        .clk(clk), .reset(reset), .valid(mem_valid), .write_en(mem_write),
        .address(mem_addr), .write_data(mem_wdata), .ready(mem_ready),
        .read_data(mem_rdata)
    );

    integer fd, status, count = 0, hits = 0, cycles = 0;
    integer reads = 0, writes = 0, latency, before_reads, before_writes;
    integer expected_hit, expected_writeback, store;
    reg [31:0] address, data, expected_data, victim_address, victim_data;
    reg [31:0] observed_address, observed_data, observed_read;
    string trace_path;

    always @(posedge clk) begin
        if (mem_valid && mem_ready) begin
            if (mem_write) begin
                writes = writes + 1;
                observed_address = mem_addr;
                observed_data = mem_wdata;
            end else begin
                reads = reads + 1;
                observed_read = mem_addr;
            end
        end
    end

    initial begin
        if (!$value$plusargs("TRACE=%s", trace_path))
            $fatal(1, "Supply +TRACE=path");
        fd = $fopen(trace_path, "r");
        if (fd == 0) $fatal(1, "Cannot open trace");
        repeat (2) @(negedge clk);
        reset = 0;
        status = $fscanf(fd, "%d %h %h %d %h %d %h %h\n", store,
                         address, data, expected_hit, expected_data,
                         expected_writeback, victim_address, victim_data);
        while (status == 8) begin
            @(negedge clk);
            while (!req_ready) @(negedge clk);
            req_valid = 1;
            req_write = store;
            req_addr = address;
            req_wdata = data;
            before_reads = reads;
            before_writes = writes;
            @(negedge clk);
            req_valid = 0;
            latency = 0;
            while (!resp_valid) begin
                @(negedge clk);
                latency = latency + 1;
                if (latency > 30) $fatal(1, "Transaction timeout");
            end
            if (resp_error !== 0 || resp_hit !== (expected_hit != 0) ||
                resp_rdata !== expected_data)
                $fatal(1, "Response mismatch transaction %0d addr=%h hit=%b data=%h expected=%h",
                       count, address, resp_hit, resp_rdata, expected_data);
            if (reads-before_reads != 1-expected_hit ||
                writes-before_writes != expected_writeback)
                $fatal(1, "Traffic mismatch transaction %0d", count);
            if (!expected_hit && observed_read !== address)
                $fatal(1, "Refill address mismatch");
            if (expected_writeback &&
                (observed_address !== victim_address || observed_data !== victim_data))
                $fatal(1, "Victim write-back mismatch");
            if (latency != 1 + 3*(1-expected_hit) + 3*expected_writeback)
                $fatal(1, "Latency mismatch %0d", latency);
            count = count + 1;
            hits = hits + expected_hit;
            cycles = cycles + latency;
            status = $fscanf(fd, "%d %h %h %d %h %d %h %h\n", store,
                             address, data, expected_hit, expected_data,
                             expected_writeback, victim_address, victim_data);
        end
        if (status != -1 || count == 0) $fatal(1, "Invalid or empty trace");
        $display("RESULT %0d %0d %0d %0d %0d", count, hits, reads, writes, cycles);
        $fclose(fd);
        $finish;
    end
endmodule
