// /////////////////////////////////////////////////////////////////////////
// //                                                                     //
// //   Modulename :  id_stage.v                                          //
// //                                                                     //
// //  Description :  instruction decode (ID) stage of the pipeline;      // 
// //                 decode the instruction fetch register operands, and // 
// //                 compute immediate operand (if applicable)           // 
// //                                                                     //
// /////////////////////////////////////////////////////////////////////////


`timescale 1ns/100ps

module id_stage(
  input         clock,                // system clock
  input         reset,                // system reset
  input WB_REG_PACKET wb_reg_packet_in,
  input IF_ID_PACKET if_id_packet_in,
  output ID_EX_PACKET id_packet_out
);
  DECODER_PACKET_OUT decoder_packet_out;
  assign id_packet_out.NPC = if_id_packet_in.NPC;
  assign id_packet_out.inst = if_id_packet_in.inst;
  assign id_packet_out.opa_select = decoder_packet_out.opa_select;
  assign id_packet_out.opb_select = decoder_packet_out.opb_select;
  assign id_packet_out.alu_func = decoder_packet_out.alu_func;
  assign id_packet_out.rd_mem = decoder_packet_out.rd_mem;
  assign id_packet_out.wr_mem = decoder_packet_out.wr_mem;
  assign id_packet_out.ldl_mem = decoder_packet_out.ldl_mem;
  assign id_packet_out.stc_mem = decoder_packet_out.stc_mem;
  assign id_packet_out.cond_branch = decoder_packet_out.cond_branch;
  assign id_packet_out.uncond_branch = decoder_packet_out.uncond_branch;
  assign id_packet_out.halt = decoder_packet_out.halt;
  assign id_packet_out.cpuid = decoder_packet_out.cpuid;
  assign id_packet_out.illegal = decoder_packet_out.illegal;
  assign id_packet_out.valid = decoder_packet_out.valid;
  assign id_packet_out.dest_reg_idx = decoder_packet_out.dest_reg_idx;

  // instruction fields read from IF/ID pipeline register
  wire    [4:0] ra_idx = if_id_packet_in.inst.op.rega_idx;   // inst operand A register index
  wire    [4:0] rb_idx = if_id_packet_in.inst.op.regb_idx;   // inst operand B register index
  wire    [4:0] rc_idx = if_id_packet_in.inst.op.regc_idx;     // inst operand C register index

  // Instantiate the register file used by this pipeline
  regfile regf_0 (
    .rda_idx(ra_idx),
    .rda_out(id_packet_out.rega_value), 
    .rdb_idx(rb_idx),
    .rdb_out(id_packet_out.regb_value),
    .wr_clk(clock),
    .wr_en(wb_reg_packet_in.wr_en),
    .wr_idx(wb_reg_packet_in.wr_idx),
    .wr_data(wb_reg_packet_in.wr_data)
  );

  // instantiate the instruction decoder
  decoder decoder_0 (
    .decoder_packet_in(if_id_packet_in),
    .decoder_packet_out(decoder_packet_out)
  );
endmodule // module id_stage