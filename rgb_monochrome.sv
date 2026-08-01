/* @file rgb_to_monochrome.sv
 *
 * Consumes complete RGB triplets from a byte-wide FIFO and converts each
 * triplet to one monochrome bit. RGB bytes arrive in red, green, blue order.
 *
 * A pixel is white when its unweighted average is at least 50% gray:
 *   (red + green + blue) >= (3 * 128)
 * The one-bit result is zero-extended for the byte-oriented UART transmitter.
 */

module RGBMonochrome 
  #(parameter integer FIFO_COUNT_WIDTH = 3,
    parameter logic [9:0] GRAY_THRESHOLD = 10'd384) 
  (input  logic                        clock,
   input  logic                        reset_n,
   input  logic [7:0]                  data_in,
   input  logic [FIFO_COUNT_WIDTH-1:0] fifo_count,
   input  logic                        uart_busy,
   output logic                        fifo_read,
   output logic [7:0]                  uart_data,
   output logic                        uart_start,
   output logic                        monochrome);

  // State assignment
  typedef enum logic [1:0] {
    WAIT_FOR_RGB,
    READ_GREEN,
    READ_BLUE,
    WAIT_FOR_UART
  } converter_state_t;

  converter_state_t state;
  logic [7:0] red;
  logic [7:0] green;

  assign uart_data = {7'b0, monochrome};

  // Combinational since reads from FIFO are combinational
  always_comb begin
    fifo_read = 1'b0;
    uart_start = 1'b0;

    case (state)
      WAIT_FOR_RGB: begin
        if (fifo_count >= 3)
          fifo_read = 1'b1;
      end

      READ_GREEN,
      READ_BLUE: fifo_read = 1'b1;

      WAIT_FOR_UART: begin
        if (~uart_busy)
          uart_start = 1'b1;
      end

      default: begin
        fifo_read = 1'b0;
        uart_start = 1'b0;
      end
    endcase
  end

  // State register, output generator
  always_ff @(posedge clock, negedge reset_n) begin
    if (~reset_n) begin
      state <= WAIT_FOR_RGB;
      red <= '0;
      green <= '0;
      monochrome <= 1'b0;
    end else begin
      case (state)
        WAIT_FOR_RGB: begin
          if (fifo_count >= 3) begin
            red <= data_in;
            state <= READ_GREEN;
          end
        end

        READ_GREEN: begin
          green <= data_in;
          state <= READ_BLUE;
        end

        READ_BLUE: begin
          monochrome <= ({2'b0, red} +
                         {2'b0, green} +
                         {2'b0, data_in}) >= GRAY_THRESHOLD;
          state <= WAIT_FOR_UART;
        end

        WAIT_FOR_UART: begin
          if (~uart_busy) begin
            state <= WAIT_FOR_RGB;
          end
        end

        default: state <= WAIT_FOR_RGB;
      endcase
    end
  end
endmodule : RGBMonochrome
