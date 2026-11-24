// Equal-capacity baseline: 32 sets x 1 way x 4 bytes, same controller timing.
module direct_mapped_cache(
    input wire clk, reset, req_valid, req_write,
    input wire [31:0] req_addr, req_wdata,
    output wire req_ready, resp_valid, resp_hit, resp_error,
    output wire [31:0] resp_rdata,
    output wire mem_valid, mem_write,
    output wire [31:0] mem_addr, mem_wdata,
    input wire mem_ready,
    input wire [31:0] mem_rdata
);
    reg [24:0] tags [0:31];
    reg [31:0] words [0:31];
    reg [31:0] valid, dirty;
    wire [31:0] lookup_addr, line_data;
    wire [4:0] index = lookup_addr[6:2];
    wire line_write, line_dirty;
    wire hit = valid[index] && tags[index] == lookup_addr[31:7];

    always @(posedge clk) begin
        if (reset) begin
            valid <= 0;
            dirty <= 0;
        end else if (line_write) begin
            tags[index] <= lookup_addr[31:7];
            words[index] <= line_data;
            valid[index] <= 1;
            dirty[index] <= line_dirty;
        end
    end

    cache_controller #(.INDEX_BITS(5)) ctrl(
        .clk(clk), .reset(reset), .req_valid(req_valid), .req_write(req_write),
        .req_addr(req_addr), .req_wdata(req_wdata), .req_ready(req_ready),
        .resp_valid(resp_valid), .resp_hit(resp_hit), .resp_error(resp_error),
        .resp_rdata(resp_rdata), .hit0(hit), .hit1(1'b0), .victim_way(1'b0),
        .victim_dirty(valid[index] && dirty[index]),
        .hit_data(words[index]), .victim_data(words[index]),
        .victim_tag(tags[index]), .lookup_addr(lookup_addr),
        .line_write(line_write), .line_way(), .line_dirty(line_dirty),
        .touch(), .line_data(line_data), .mem_valid(mem_valid),
        .mem_write(mem_write), .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        .mem_ready(mem_ready), .mem_rdata(mem_rdata)
    );
endmodule
