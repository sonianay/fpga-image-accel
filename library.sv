/* @file library.sv */

/* @brief DFlipFlop module to store value for 1 clock edge. */
module DFlipFlop #(parameter WIDTH=8)
  (input  logic             clock, reset_n,
   input  logic [WIDTH-1:0] d, 
   output logic [WIDTH-1:0] q);

  always_ff @(posedge clock or negedge reset_n)
    if (~reset_n)
      q <= 1'b0;
    else
      q <= d;
endmodule : DFlipFlop

/* @brief Synchronizer module composed of two stages (used for async signals) */
module Synchronizer #(parameter WIDTH=8)
  (input  logic             clock, reset_n,
   input  logic [WIDTH-1:0] in, 
   output logic [WIDTH-1:0] out, 
   output logic [WIDTH-1:0] intermediate);

  always_ff @(posedge clock, negedge reset_n) begin
    if (~reset_n) begin
      intermediate <= 1'b0;
      out <= 1'b0;
    end
    else begin
      intermediate <= in;
      out <= intermediate;
    end
  end
endmodule : Synchronizer

/* @brief Seven segment hex module that converts data (hex) to segment values */
module SevenSegmentHex (
  input  logic [3:0] value,
  output logic [6:0] segments
);
  always_comb begin
    case (value)
      4'h0: segments = 7'b1000000;
      4'h1: segments = 7'b1111001;
      4'h2: segments = 7'b0100100;
      4'h3: segments = 7'b0110000;
      4'h4: segments = 7'b0011001;
      4'h5: segments = 7'b0010010;
      4'h6: segments = 7'b0000010;
      4'h7: segments = 7'b1111000;
      4'h8: segments = 7'b0000000;
      4'h9: segments = 7'b0010000;
      4'ha: segments = 7'b0001000;
      4'hb: segments = 7'b0000011;
      4'hc: segments = 7'b1000110;
      4'hd: segments = 7'b0100001;
      4'he: segments = 7'b0000110;
      4'hf: segments = 7'b0001110;
      default: segments = 7'b1111111;
    endcase
  end
endmodule : SevenSegmentHex

/* @brief FIFO (First In First Out) buffer with depth 4 
 *    
 * INTERFACE:
 *    - The buffer is initally empty
 *    - Reads are combinational, so data_out is valid unless empty is asserted
 *    - Removal from the queue is processed on the clock edge.
 *    - Writes are processed on the clock edge
 *    - If a write is pending while the buffer is full, do nothing
 *    - If a read is pending while the buffer is empty, do nothing
 */
module FIFO #(parameter WIDTH=32, 
                        MAX_SIZE=4, 
                        MAX_SIZE_BITS=$clog2(MAX_SIZE)) (
  input  logic              clock, reset_n,
  input  logic              we, re,
  input  logic [WIDTH-1:0]  data_in,
  output logic              full, empty,
  output logic [MAX_SIZE_BITS:0] count,
  output logic [WIDTH-1:0]  data_out);

  // Queue elements
  logic [WIDTH-1:0] Q_reg [MAX_SIZE-1:0];
  // we_idx points to next in
  // re_idx points to first out
  logic [MAX_SIZE_BITS-1:0] we_idx, re_idx;
  // Represents current size of queue
  logic [MAX_SIZE_BITS:0] size;

  always_comb begin
    full = (size == MAX_SIZE);
    empty = (size == 'd0);
    count = size;
    // Combinational read
    data_out = Q_reg[re_idx];
  end

  always_ff @(posedge clock, negedge reset_n) begin
    if (~reset_n) begin
      we_idx <= 'b0;
      re_idx <= 'b0;
      size <= 'b0;
    end
    else begin
      // Write and read asserted at same time
      if (we & re) begin
        // Can only write into empty FIFO
        if (empty) begin
          Q_reg[we_idx] <= data_in;
          we_idx <= we_idx + 1'b1;
          size <= size + 1'b1;
        end
        // Read frees space, so write can occur (even when full)
        else begin
          Q_reg[we_idx] <= data_in;
          we_idx <= we_idx + 1'b1;
          re_idx <= re_idx + 1'b1;
          // Size remains the same (size <= size)
        end
      end
      // Can only write when FIFO not full
      else if (we & ~full) begin
        Q_reg[we_idx] <= data_in;
        we_idx <= we_idx + 1'b1;
        size <= size + 1'b1;
      end
      // Can only read when FIFO not empty
      else if (re & ~empty) begin
        re_idx <= re_idx + 1'b1;
        size <= size - 1'b1;
      end
    end
  end
endmodule : FIFO
