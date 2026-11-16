module cache_top(
    input  wire        clk, reset,
    input  wire        req_valid, req_write,
    input  wire [31:0] req_addr, req_wdata,
    output wire        req_ready, resp_valid, resp_hit, resp_error,
    output wire [31:0] resp_rdata,
    output wire        mem_valid, mem_write,
    output wire [31:0] mem_addr, mem_wdata,
    input  wire        mem_ready,
    input  wire [31:0] mem_rdata
);
    wire [31:0] lookup_addr, data0, data1, line_data;
    wire [25:0] tag, tag0, tag1;
    wire [3:0] index;
    wire valid0, valid1, dirty0, dirty1, victim_way;
    wire line_write, line_way, line_dirty, touch;
    wire hit0 = valid0 && tag0 == tag;
    wire hit1 = valid1 && tag1 == tag;
    wire victim_dirty = victim_way ? valid1 && dirty1 : valid0 && dirty0;

    address_decode decoder(.address(lookup_addr), .tag(tag), .index(index), .offset());
    tag_array tags(
        .clk(clk), .reset(reset), .set_index(index), .write_en(line_write),
        .write_way(line_way), .write_dirty(line_dirty), .write_tag(tag),
        .tag0(tag0), .tag1(tag1), .valid0(valid0), .valid1(valid1),
        .dirty0(dirty0), .dirty1(dirty1)
    );
    data_array data(
        .clk(clk), .set_index(index), .write_en(line_write), .write_way(line_way),
        .write_data(line_data), .data0(data0), .data1(data1)
    );
    lru_unit lru(
        .clk(clk), .reset(reset), .set_index(index), .valid0(valid0), .valid1(valid1),
        .touch(touch), .touched_way(line_way), .victim_way(victim_way)
    );
    cache_controller ctrl(
        .clk(clk), .reset(reset), .req_valid(req_valid), .req_write(req_write),
        .req_addr(req_addr), .req_wdata(req_wdata), .req_ready(req_ready),
        .resp_valid(resp_valid), .resp_hit(resp_hit), .resp_error(resp_error),
        .resp_rdata(resp_rdata), .hit0(hit0), .hit1(hit1),
        .victim_way(victim_way), .victim_dirty(victim_dirty),
        .hit_data(hit1 ? data1 : data0), .victim_data(victim_way ? data1 : data0),
        .victim_tag(victim_way ? tag1 : tag0), .lookup_addr(lookup_addr),
        .line_write(line_write), .line_way(line_way), .line_dirty(line_dirty),
        .touch(touch), .line_data(line_data), .mem_valid(mem_valid),
        .mem_write(mem_write), .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        .mem_ready(mem_ready), .mem_rdata(mem_rdata)
    );
endmodule
