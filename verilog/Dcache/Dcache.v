// cachemem32x64

`timescale 1ns/100ps

// read basically reads and tells if cache is miss or not
// write basically edit data to cache
// controller is incharge of dealing with the sequence
// module Dcache(
//         input logic                             clock, reset,
//         input logic                             wr1_en, wr2_en,
//         input logic [$clog2(`NUM_IDX)-1:0]      wr1_idx, wr2_idx, rd1_idx, rd2_idx,
//         input logic [$clog2(`NUM_BLOCK)-1:0]    wr1_BO, wr2_BO, rd1_BO, rd2_BO,
//         input logic [`NUM_D_TAG_BITS-1:0]       wr1_tag, wr2_tag, rd1_tag, rd1_tag,
//         input logic [63:0]                      wr1_data, wr2_data,
        
//         output logic [63:0]                     rd1_data_out, rd2_data_out,
//         output logic                            rd1_hit_out, rd2_hit_out
//       );
module Dcache(
  input logic                             clock, reset,
  input logic                             wr1_en,
  input logic [$clog2(`NUM_IDX)-1:0]      wr1_idx, rd1_idx, rd2_idx,
  input logic [$clog2(`NUM_BLOCK)-1:0]    wr1_BO, rd1_BO, rd2_BO,
  input logic [`NUM_D_TAG_BITS-1:0]       wr1_tag, rd1_tag, rd2_tag,
  input logic [63:0]                      wr1_data,
  
  output logic [63:0]                     rd1_data_out, rd2_data_out,
  output logic                            rd1_hit_out, rd2_hit_out
);
  logic [`NUM_WAY-1:0] wr1_hit, rd1_hit, rd2_hit, wr1_en_bus;
  // logic [`NUM_WAY-1:0] wr1_hit, wr2_hit, rd1_hit, rd2_hit, wr1_en_bus, wr2_en_bus;
  logic [`NUM_WAY-1:0] LRU_bank_sel;
  logic [(64*(`NUM_WAY))-1:0] rd1_data, rd2_data;
  logic [$clog2(`NUM_WAY)-1:0] rd1_hit_idx, rd2_hit_idx, wr1_hit_idx;
  // logic [$clog2(`NUM_WAY)-1:0] rd1_hit_idx, rd2_hit_idx, wr1_hit_idx, wr2_hit_idx;
  logic [$clog2(`NUM_WAY)-1:0] RU_idx, next_RU_idx;
  
  logic [`NUM_IDX-1:0][($clog2(`NUM_WAY)*(`NUM_WAY - 1))-1:0] reset_bank_idx,bank_idx;
  logic [`NUM_IDX-1:0][($clog2(`NUM_WAY)*(`NUM_WAY - 2))-1:0] prev_bank_idx;
  logic [`NUM_IDX-1:0][`NUM_WAY-2:0] select_prev;

  logic [`NUM_IDX-1:0][$clog2(`NUM_WAY)-1:0] MRU_bank_idx, next_MRU_bank_idx;

  logic [`NUM_IDX-1:0][$clog2(`NUM_WAY)-1:0] LRU_bank_idx;
  logic wr1_hit_out;

  //initialize the reset_bank_idx
  always_comb begin
    for(int j; j < `NUM_IDX; j++) begin
      for(int i; i < `NUM_WAY - 1; i++) begin
        reset_bank_idx[j][(i*$clog2(`NUM_WAY))+($clog2(`NUM_WAY)-1):i*$clog2(`NUM_WAY)] = i+1;
      end
    end
  end

  genvar idx;
  generate
    for (idx = 0; idx < `NUM_IDX; idx++) begin : generate_block_identifier
      LRU_logic LRU_controller [`NUM_WAY-2:0](
          .clock(clock),
          .reset(reset),
          .reset_bank_idx(reset_bank_idx[idx]),
          .select_prev(select_prev[idx]),
          .prev_bank_idx({bank_idx[idx][($clog2(`NUM_WAY)*(`NUM_WAY - 2))-1:0], MRU_bank_idx[idx]}),
          
          .bank_idx(bank_idx[idx])
          );
    end 
  endgenerate

  //MRU logic
  always_comb begin
    //know which is the most recently used set_idx
    //know which is the most recently used line in a set
    if(rd2_hit_out) begin
      next_MRU_bank_idx[rd2_idx] = rd2_hit_idx;
      next_RU_idx = rd2_idx;
    end
    else if(rd1_hit_out) begin
      next_MRU_bank_idx[rd1_idx] = rd1_hit_idx;
      next_RU_idx = rd1_idx;
    end
    // else if(wr2_en) begin
    //   next_MRU_bank_idx[wr2_idx] = wr2_hit_idx;
    //   next_RU_idx = wr2_idx;
    // end
    else if(wr1_en) begin
      next_MRU_bank_idx[wr1_idx] = wr1_hit_idx;
      next_RU_idx = wr1_idx;
    end
    else begin
      next_MRU_bank_idx = MRU_bank_idx;
      next_RU_idx = RU_idx;
    end
  end

  //LRU logic
  always_comb begin
    select_prev[next_RU_idx] = '{{(`NUM_WAY-1){1'b0}}};
    for(int i = 0; i >= `NUM_WAY-1; i++) begin
      if(bank_idx[next_RU_idx][(i*$clog2(`NUM_WAY))+($clog2(`NUM_WAY)-1):i*$clog2(`NUM_WAY)] == next_MRU_bank_idx) begin
        select_prev[next_RU_idx][i] = 1;
        break;
      end
    end
    // for(int i = `NUM_WAY-2; i >= 0; i--) begin
    //   if(i <= new_MRU_reg) begin
    //     select_prev[next_RU_idx][i] = 1;
    //   end
    //   else begin
    //     select_prev[next_RU_idx][i] = 0;
    //   end
    // end
  end

  always_ff @(posedge clock) begin
    if(reset) begin
      MRU_bank_idx <= `SD 0;
      RU_idx       <= `SD (0);
    end
    else begin
      MRU_bank_idx <= `SD next_MRU_bank_idx;
      RU_idx       <= `SD next_RU_idx;
    end
  end

  // LRU_bank_idx
  always_comb begin
    for(int i = 0; i < `NUM_IDX; i++) begin
       LRU_bank_idx[i] = bank_idx[i][($clog2(`NUM_WAY)*(`NUM_WAY - 2))-1:($clog2(`NUM_WAY)*(`NUM_WAY - 3))];
    end
  end

  assign LRU_bank_sel = (1 << LRU_bank_idx[next_RU_idx]);
  
  assign wr1_en_bus = (wr1_en & wr1_hit_out)? wr1_hit : //if data to store in cache, write to where it is hit
                      (wr1_en & !wr1_hit_out)? LRU_bank_sel : 0; //if data from mem and line not in cache, write to the LRU bank
  ////////////////////////////////////////////////////////~~~~~~~~~~~~~~ need to think through the wr operations of the cache  wr1_hit | wr1_en in bank
  cache_bank bank [`NUM_WAY-1:0] (
      .clock(clock),
      .reset(reset),
      .wr1_en(wr1_en_bus),
      // .wr2_en(wr2_en_bus),
      .wr1_idx(wr1_idx),
      // .wr2_idx(wr2_idx),
      .rd1_idx(rd1_idx),
      .rd2_idx(rd2_idx),
      .wr1_BO(wr1_BO),
      // .wr2_BO(wr2_BO),
      .rd1_BO(rd1_BO),
      .rd2_BO(rd2_BO),
      .wr1_tag(wr1_tag), 
      // .wr2_tag(wr2_tag), 
      .rd1_tag(rd1_tag), 
      .rd1_tag(rd1_tag),
      .wr1_data(wr1_data), 
      // .wr2_data(wr2_data),
      .wr1_hit(wr1_hit),
      // .wr2_hit(wr2_hit),
      .rd1_hit(rd1_hit),
      .rd2_hit(rd2_hit),
      .rd1_data(rd1_data),
      .rd2_data(rd2_data));

      always_comb begin
        rd1_hit_out = 0;
        for(int i = 0 ; i <`NUM_WAY; i++) begin
          if(rd1_hit[i]) begin
            rd1_data_out = rd1_data[(64*i)+63:64*i];
            rd1_hit_out = 1;
          end
        end
      end
      always_comb begin
        rd2_hit_out = 0;
        for(int i = 0 ; i <`NUM_WAY; i++) begin
          if(rd2_hit[i]) begin
            rd2_data_out = rd2_data[(64*i)+63:64*i];
            rd2_hit_out = 1;
          end
        end
      end
      always_comb begin
        wr1_hit_out = 0;
        for(int i = 0 ; i <`NUM_WAY; i++) begin
          if(wr1_hit[i]) begin
            wr1_data_out = wr1_data[(64*i)+63:64*i];
            wr1_hit_out = 1;
          end
        end
      end
      

  pe rd1_bank_sel (.gnt(rd1_hit),.enc(rd1_hit_idx));
  pe rd2_bank_sel (.gnt(rd2_hit),.enc(rd2_hit_idx));
  pe wr1_bank_sel (.gnt(wr1_hit),.enc(wr1_hit_idx));
  // pe wr2_bank_sel (.gnt(wr2_hit),.enc(wr2_hit_idx));

endmodule

// module cache_bank(
//         input logic                             clock, reset,
//         input logic                             wr1_en, wr2_en,
//         input logic [$clog2(`NUM_IDX)-1:0]      wr1_idx, wr2_idx, rd1_idx, rd2_idx,
//         input logic [$clog2(`NUM_BLOCK)-1:0]      wr1_BO, wr2_BO, rd1_BO, rd2_BO,
//         input logic [`NUM_D_TAG_BITS-1:0]       wr1_tag, wr2_tag, rd1_tag, rd1_tag,
//         input logic [63:0]                      wr1_data, wr2_data,

//         output logic                            wr1_hit, wr2_hit, rd1_hit, rd2_hit,
//         // output logic [`NUM_TAG_BITS-1:0]        wr1_tag,wr2_tag,rd1_tag,rd2_tag,
//         output logic [63:0]                     rd1_data, rd2_data
//     );
module cache_bank(
  input logic                             clock, reset,
  input logic                             wr1_en,
  input logic [$clog2(`NUM_IDX)-1:0]      wr1_idx, rd1_idx, rd2_idx,
  input logic [$clog2(`NUM_BLOCK)-1:0]      wr1_BO, rd1_BO, rd2_BO,
  input logic [`NUM_D_TAG_BITS-1:0]       wr1_tag, rd1_tag, rd1_tag,
  input logic [63:0]                      wr1_data,

  output logic                            wr1_hit, rd1_hit, rd2_hit,
  // output logic [`NUM_TAG_BITS-1:0]        wr1_tag,wr2_tag,rd1_tag,rd2_tag,
  output logic [63:0]                     rd1_data, rd2_data
);
    
  D_CACHE_LINE_t [`NUM_IDX-1:0] cache_bank;  

  //read
  assign rd1_hit = cache_bank[rd1_idx].valid[rd1_BO] && (rd1_tag == cache_bank[rd1_idx].tag);
  assign rd1_data = cache_bank[rd1_idx].data[rd1_BO];

  assign rd2_hit = cache_bank[rd2_idx].valid[rd2_BO] && (rd2_tag == cache_bank[rd2_idx].tag);
  assign rd2_data = cache_bank[rd2_idx].data[rd2_BO];

  //write
  assign wr1_hit = cache_bank[wr1_idx].valid[wr1_BO] && (wr1_tag == cache_bank[wr1_idx].tag);
  // assign wr2_hit = cache_bank[wr2_idx].valid[wr2_BO] && (wr2_tag == cache_bank[wr2_idx].tag);

  //write
  always_ff @(posedge clock) begin
    if(reset)
      for(int i=0; i < `NUM_IDX; i++) begin
        cache_bank[i].valid <= `SD 0;
      end
    else begin
      if(wr1_en) begin
        cache_bank[wr1_idx].valid[wr1_BO] <= `SD 1;
        cache_bank[wr1_idx].tag <= `SD wr1_tag;
        cache_bank[wr1_idx].data[wr1_BO] <= `SD wr1_data;
      end
      // if(wr2_en) begin
      //   cache_bank[wr2_idx].valid[wr2_BO] <= `SD 1;
      //   cache_bank[wr2_idx].tag <= `SD wr2_tag;
      //   cache_bank[wr2_idx].data[wr2_BO] <= `SD wr2_data;
      // end
    end
  end
endmodule

module LRU_logic (
  input logic clock, reset,
  input logic [$clog2(`NUM_WAY)-1:0] reset_bank_idx,
  input logic select_prev,
  input logic [$clog2(`NUM_WAY)-1:0] prev_bank_idx,
  
  output logic [$clog2(`NUM_WAY)-1:0] bank_idx
);

  logic [$clog2(`NUM_WAY)-1:0] next_bank_idx;

  assign next_bank_idx = (select_prev) ? prev_bank_idx : bank_idx;

  always_ff @(posedge clock) begin
    if(reset)
      bank_idx <= `SD reset_bank_idx;
    else
      bank_idx <= `SD next_bank_idx;
  end
  
endmodule

  module pe(gnt,enc);
    //synopsys template
    parameter OUT_WIDTH=$clog2(`NUM_WAY);
    parameter IN_WIDTH=1<<OUT_WIDTH;

  input   [IN_WIDTH-1:0] gnt;

  output [OUT_WIDTH-1:0] enc;
    wor    [OUT_WIDTH-1:0] enc;
    
    genvar i,j;
    generate
      for(i=0;i<OUT_WIDTH;i=i+1)
      begin : foo
        for(j=1;j<IN_WIDTH;j=j+1)
        begin : bar
          if (j[i])
            assign enc[i] = gnt[j];
        end
      end
    endgenerate
  endmodule

  module decoder_using_assign (
      input logic [$clog2(`NUM_WAY)-1:0] binary_in;
      output logic [`NUM_WAY-1:0] decoder_out; 
          );

    assign decoder_out = (1 << binary_in);

  endmodule