///////////////////////////////////////////////////////////////////////////////
//                                                                           //
//  Modulename : mem.v                                                       //
//                                                                           //
// Description : This is a clock-based latency, pipelined memory with        //
//               3 buses (address in, data in, data out) and a limit         //
//               on the number of outstanding memory operations allowed      //
//               at any time.                                                //
//                                                                           // 
///////////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

module mem (
			input         clk,              // Memory clock
			input  [63:0] proc2mem_addr,    // address for current command
			input  [63:0] proc2mem_data,    // address for current command
			input   [1:0] proc2mem_command, // BUS_NONE BUS_LOAD or BUS_STORE

			output logic  [3:0] mem2proc_response, // 0 = can't accept, other=tag of transaction
			output logic [63:0] mem2proc_data,     // data resulting from a load
			output logic  [3:0] mem2proc_tag       // 0 = no value, other=tag of transaction
           );

	logic [63:0] next_mem2proc_data;
	logic  [3:0] next_mem2proc_response, next_mem2proc_tag;

	logic [63:0] unified_memory [`MEM_64BIT_LINES - 1:0];
	logic [63:0] loaded_data    [`NUM_MEM_TAGS:1];
	
	logic [`NUM_MEM_TAGS:1] [15:0] cycles_left;
	logic [`NUM_MEM_TAGS:1]        waiting_for_bus;

	logic acquire_tag;
	logic bus_filled;

	wire valid_address = (proc2mem_addr[2:0]==3'b0) &
						 (proc2mem_addr<`MEM_SIZE_IN_BYTES);

	// Implement the Memory function
	always @(negedge clk)
	begin
		next_mem2proc_tag      = 4'b0;
		next_mem2proc_response = 4'b0;
		next_mem2proc_data     = 64'bx;
		bus_filled             = 1'b0;
		acquire_tag            =	((proc2mem_command==BUS_LOAD) ||
									(proc2mem_command==BUS_STORE)) && valid_address;

		for(int i=1;i<=`NUM_MEM_TAGS;i=i+1)
		begin
			if(cycles_left[i]>16'd0)
			begin
				cycles_left[i] = cycles_left[i]-16'd1;
			end
			else if(acquire_tag && !waiting_for_bus[i] && (cycles_left[i]==0))
			begin
				next_mem2proc_response = i;
				acquire_tag            = 1'b0;
				cycles_left[i]         = `MEM_LATENCY_IN_CYCLES; 
										// must add support for random lantencies
										// though this could be done via a non-number
										// definition for this macro

				if(proc2mem_command==BUS_LOAD)
				begin
					waiting_for_bus[i] = 1'b1;
					loaded_data[i]     = unified_memory[proc2mem_addr[63:3]];
				end
				else
				begin
					unified_memory[proc2mem_addr[63:3]]=proc2mem_data;
				end
			end

			if((cycles_left[i]==16'd0) && waiting_for_bus[i] && !bus_filled)
			begin
				bus_filled         = 1'b1;
				next_mem2proc_tag  = i;
				next_mem2proc_data = loaded_data[i];
				waiting_for_bus[i] = 1'b0;
			end
		end
		mem2proc_response <= `SD next_mem2proc_response;
		mem2proc_data     <= `SD next_mem2proc_data;
		mem2proc_tag      <= `SD next_mem2proc_tag;
	end

	// Initialise the entire memory
	initial
	begin
		for(int i=0; i<`MEM_64BIT_LINES; i=i+1)
		begin
			unified_memory[i] = 64'h0;
		end
		mem2proc_data=64'bx;
		mem2proc_tag=4'd0;
		mem2proc_response=4'd0;
		for(int i=1;i<=`NUM_MEM_TAGS;i=i+1)
		begin
			loaded_data[i]=64'bx;
			cycles_left[i]=16'd0;
			waiting_for_bus[i]=1'b0;
		end
	end

endmodule    // module mem
