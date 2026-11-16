`timescale 1ns/1ps
module tb_cache;
    reg clk = 0;
    always #5 clk = ~clk;
    reg reset = 1, req_valid = 0, req_write = 0;
    reg [31:0] req_addr = 0, req_wdata = 0;
    wire req_ready, resp_valid, resp_hit, resp_error;
    wire [31:0] resp_rdata;
    wire mem_valid, mem_write, mem_ready;
    wire [31:0] mem_addr, mem_wdata, mem_rdata;
    integer reads = 0, writes = 0, checks = 0;
    reg [31:0] last_read_addr, last_write_addr, last_write_data;
    localparam [31:0] A = 'h014, B = 'h054, C = 'h094, D = 'h0D4, E = 'h114;
    localparam [31:0] OTHER = 'h018;
    localparam [31:0] NEW_A = 'h12345678, NEW_E = 'hA1B2C3D4;

    cache_top dut(.*);
    main_memory memory(
        .clk(clk), .reset(reset), .valid(mem_valid), .write_en(mem_write),
        .address(mem_addr), .write_data(mem_wdata), .ready(mem_ready), .read_data(mem_rdata)
    );

    always @(posedge clk) begin
        if (mem_valid && mem_ready) begin
            if (mem_write) begin
                writes <= writes + 1;
                last_write_addr <= mem_addr;
                last_write_data <= mem_wdata;
            end else begin
                reads <= reads + 1;
                last_read_addr <= mem_addr;
            end
        end
    end

    task automatic access_word(
        input string label,
        input logic write_en,
        input logic [31:0] address, wdata,
        input logic expected_hit, expected_error,
        input logic [31:0] expected_data,
        input integer expected_reads, expected_writes
    );
        integer old_reads, old_writes;
        begin
            @(negedge clk);
            while (!req_ready) @(negedge clk);
            old_reads = reads;
            old_writes = writes;
            req_addr = address;
            req_wdata = wdata;
            req_write = write_en;
            req_valid = 1;
            @(negedge clk);
            req_valid = 0;
            while (!resp_valid) @(negedge clk);
            if (resp_hit !== expected_hit || resp_error !== expected_error ||
                resp_rdata !== expected_data || reads - old_reads != expected_reads ||
                writes - old_writes != expected_writes ||
                (expected_reads != 0 && last_read_addr !== address))
                $fatal(1, "%s: hit=%b error=%b data=%h reads=%0d writes=%0d read_addr=%h",
                       label, resp_hit, resp_error, resp_rdata, reads-old_reads,
                       writes-old_writes, last_read_addr);
            checks = checks + 1;
            $display("PASS %02d %s", checks, label);
        end
    endtask

    initial begin
        $dumpfile("build/cache.vcd");
        $dumpvars(0, tb_cache);
        repeat (2) @(negedge clk);
        reset = 0;
        access_word("cold miss fills way 0", 0, A, 0, 0, 0, 'hCAFE0005, 1, 0);
        access_word("repeat access hits", 0, A, 0, 1, 0, 'hCAFE0005, 0, 0);
        access_word("second tag fills invalid way 1", 0, B, 0, 0, 0, 'hCAFE0015, 1, 0);
        access_word("write hit makes A dirty and most recent", 1, A, NEW_A, 1, 0, NEW_A, 0, 0);
        if (memory.words[A >> 2] !== 32'hCAFE0005)
            $fatal(1, "Write hit changed backing memory before eviction");
        access_word("C evicts clean B", 0, C, 0, 0, 0, 'hCAFE0025, 1, 0);
        access_word("A survives and retains updated data", 0, A, 0, 1, 0, NEW_A, 0, 0);
        access_word("separate set fills independently", 0, OTHER, 0, 0, 0, 'hCAFE0006, 1, 0);
        access_word("B misses again and evicts C", 0, B, 0, 0, 0, 'hCAFE0015, 1, 0);
        access_word("D evicts dirty A and writes it back", 0, D, 0, 0, 0, 'hCAFE0035, 1, 1);
        if (last_write_addr !== A || last_write_data !== NEW_A ||
            memory.words[A >> 2] !== NEW_A)
            $fatal(1, "Dirty victim address/data mismatch");
        access_word("A refills from updated backing memory", 0, A, 0, 0, 0, NEW_A, 1, 0);
        access_word("write miss allocates dirty E", 1, E, NEW_E, 0, 0, NEW_E, 1, 0);
        access_word("read hits allocated E", 0, E, 0, 1, 0, NEW_E, 0, 0);
        if (memory.words[E >> 2] !== 32'hCAFE0045)
            $fatal(1, "Write allocate changed backing memory before eviction");
        access_word("unaligned request returns error", 0, A+1, 0, 0, 1, 0, 0, 0);
        access_word("other set retains data", 0, OTHER, 0, 1, 0, 'hCAFE0006, 0, 0);
        @(negedge clk);
        reset = 1;
        @(negedge clk);
        reset = 0;
        access_word("reset invalidates cache but retains memory", 0, A, 0, 0, 0, NEW_A, 1, 0);
        $display("PASS all %0d checks (%0d refills, %0d writebacks)", checks, reads, writes);
        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "Testbench timeout");
    end
endmodule
