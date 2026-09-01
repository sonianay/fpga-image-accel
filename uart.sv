/* @file uart.sv
 *
 * 115200 baud rate, 8 data bit, no parity bit, 1 stop bit UART receive/transmit 
 * path for RP2040 connection.
 * Serial data is transferred LSB first.
 */

module UART_RX
  #(parameter integer CLOCK_FREQ = 50_000_000,
    parameter integer BAUD_RATE  = 115_200) 
  (input  logic       clock,
   input  logic       reset_n,
   input  logic       serial_in,
   output logic [7:0] data,
   output logic       data_valid,
   output logic       start_bit_detected,
   output logic       framing_error);

  localparam integer CLOCKS_PER_BIT = CLOCK_FREQ / BAUD_RATE;
  localparam integer HALF_BIT_CLOCKS = CLOCKS_PER_BIT / 2;
  localparam integer COUNT_WIDTH = $clog2(CLOCKS_PER_BIT);

  logic [COUNT_WIDTH-1:0] baud_count;
  logic [2:0] bit_index;
  logic [7:0] shift_register;

  // State assignment
  typedef enum logic [1:0] {RX_IDLE, RX_START, RX_DATA, RX_STOP} rx_state_t;
  rx_state_t state;

  logic serial_meta, serial_sync;
  // Synchronizer
  always_ff @(posedge clock, negedge reset_n) begin
    if (~reset_n) begin
      serial_meta <= 1'b1;
      serial_sync <= 1'b1;
    end else begin
      serial_meta <= serial_in;
      serial_sync <= serial_meta;
    end
  end

  // State register, also output generator
  always_ff @(posedge clock, negedge reset_n) begin
    if (~reset_n) begin
      state              <= RX_IDLE;
      baud_count         <= '0;
      bit_index          <= '0;
      shift_register     <= '0;
      data               <= '0;
      data_valid         <= 1'b0;
      start_bit_detected <= 1'b0;
      framing_error      <= 1'b0;
    end 
    else begin
      data_valid         <= 1'b0;
      start_bit_detected <= 1'b0;
      framing_error      <= 1'b0;

      case (state)
        RX_IDLE: begin
          baud_count <= '0;
          bit_index  <= '0;
          if (~serial_sync)
            state <= RX_START;
        end

        RX_START: begin
          if (baud_count == HALF_BIT_CLOCKS - 1) begin
            baud_count <= '0;
            if (~serial_sync) begin
              start_bit_detected <= 1'b1;
              state <= RX_DATA;
            end 
            else begin
              state <= RX_IDLE;
            end
          end 
          else begin
            if (~serial_sync) begin
              baud_count <= baud_count + 1'b1;
            end
            else begin
              baud_count <= 'b0;
              state <= RX_IDLE;
            end
          end
        end

        RX_DATA: begin
          if (baud_count == CLOCKS_PER_BIT - 1) begin
            baud_count <= '0;
            shift_register[bit_index] <= serial_sync;
            if (bit_index == 3'd7) begin
              state <= RX_STOP;
            end 
            else begin
              bit_index <= bit_index + 1'b1;
            end
          end 
          else begin
            baud_count <= baud_count + 1'b1;
          end
        end

        RX_STOP: begin
          if (baud_count == CLOCKS_PER_BIT - 1) begin
            baud_count <= '0;
            state <= RX_IDLE;
            if (serial_sync) begin
              data <= shift_register;
              data_valid <= 1'b1;
            end 
            else begin
              framing_error <= 1'b1;
            end
          end 
          else begin
            baud_count <= baud_count + 1'b1;
          end
        end

        default: state <= RX_IDLE;
      endcase
    end
  end
endmodule : UART_RX

module UART_TX 
  #(parameter integer CLOCK_FREQ = 50_000_000,
    parameter integer BAUD_RATE  = 115_200) 
  (input  logic       clock,
   input  logic       reset_n,
   input  logic [7:0] data,
   input  logic       start,
   output logic       serial_out,
   output logic       busy,
   output logic       done);

  localparam integer CLOCKS_PER_BIT = CLOCK_FREQ / BAUD_RATE;
  localparam integer COUNT_WIDTH = $clog2(CLOCKS_PER_BIT);

  typedef enum logic [1:0] {TX_IDLE, TX_START, TX_DATA, TX_STOP} tx_state_t;
  tx_state_t state;

  logic [COUNT_WIDTH-1:0] baud_count;
  logic [2:0] bit_index;
  logic [7:0] shift_register;

  assign busy = (state != TX_IDLE);

  always_ff @(posedge clock or negedge reset_n) begin
    if (~reset_n) begin
      state          <= TX_IDLE;
      baud_count     <= '0;
      bit_index      <= '0;
      shift_register <= '0;
      serial_out     <= 1'b1;
      done           <= 1'b0;
    end else begin
      done <= 1'b0;

      case (state)
        TX_IDLE: begin
          serial_out <= 1'b1;
          baud_count <= '0;
          bit_index  <= '0;
          if (start) begin
            shift_register <= data;
            serial_out <= 1'b0;
            state <= TX_START;
          end
        end

        TX_START: begin
          if (baud_count == CLOCKS_PER_BIT - 1) begin
            baud_count <= '0;
            serial_out <= shift_register[0];
            state <= TX_DATA;
          end 
          else begin
            baud_count <= baud_count + 1'b1;
          end
        end

        TX_DATA: begin
          if (baud_count == CLOCKS_PER_BIT - 1) begin
            baud_count <= '0;
            if (bit_index == 3'd7) begin
              serial_out <= 1'b1;
              state <= TX_STOP;
            end 
            else begin
              bit_index <= bit_index + 1'b1;
              serial_out <= shift_register[bit_index + 1'b1];
            end
          end 
          else begin
            baud_count <= baud_count + 1'b1;
          end
        end

        TX_STOP: begin
          if (baud_count == CLOCKS_PER_BIT - 1) begin
            baud_count <= '0;
            serial_out <= 1'b1;
            done <= 1'b1;
            state <= TX_IDLE;
          end 
          else begin
            baud_count <= baud_count + 1'b1;
          end
        end

        default: state <= TX_IDLE;
      endcase
    end
  end
endmodule : UART_TX

module UART 
  #(parameter integer CLOCK_FREQ = 50_000_000,
    parameter integer BAUD_RATE  = 115_200,
    parameter integer TX_FIFO_DEPTH = 4) 
  (input  logic       clock,
   input  logic       reset_n,
   input  logic       serial_rx,
   output logic       serial_tx,
   output logic [7:0] rx_data,
   output logic       rx_data_valid,
   output logic       start_bit_detected,
   output logic       framing_error,
   output logic       rx_overflow,
   output logic       tx_busy,
   output logic       monochrome);

  localparam integer FIFO_COUNT_WIDTH = $clog2(TX_FIFO_DEPTH) + 1;

  logic fifo_full, fifo_empty;
  logic [7:0] fifo_data;
  logic [FIFO_COUNT_WIDTH-1:0] fifo_count;
  logic fifo_read;
  logic [7:0] monochrome_uart_data;
  logic monochrome_uart_start;
  logic tx_done;

  UART_RX #(.CLOCK_FREQ(CLOCK_FREQ),
            .BAUD_RATE(BAUD_RATE)) 
    receiver (.clock,
              .reset_n,
              .serial_in(serial_rx),
              .data(rx_data),
              .data_valid(rx_data_valid),
              .start_bit_detected,
              .framing_error);

  FIFO #(.WIDTH(8),
         .MAX_SIZE(TX_FIFO_DEPTH)) 
    transmit_fifo (.clock,
                   .reset_n,
                   .we(rx_data_valid),
                   .re(fifo_read),
                   .data_in(rx_data),
                   .full(fifo_full),
                   .empty(fifo_empty),
                   .count(fifo_count),
                   .data_out(fifo_data));

  RGBMonochrome #(.FIFO_COUNT_WIDTH(FIFO_COUNT_WIDTH)) 
    pixel_converter (.clock,
                     .reset_n,
                     .data_in(fifo_data),
                     .fifo_count,
                     .fifo_read,
                     .uart_busy(tx_busy),
                     .uart_data(monochrome_uart_data),
                     .uart_start(monochrome_uart_start),
                     .monochrome);

  UART_TX #(.CLOCK_FREQ(CLOCK_FREQ),
            .BAUD_RATE(BAUD_RATE)) 
    transmitter (.clock,
                 .reset_n,
                 .data(monochrome_uart_data),
                 .start(monochrome_uart_start),
                 .serial_out(serial_tx),
                 .busy(tx_busy),
                 .done(tx_done));

  // Register for detecting if RP2040 sending too much
  always_ff @(posedge clock, negedge reset_n) begin
    if (~reset_n) begin
      rx_overflow <= 1'b0;
    end
    else if (rx_data_valid & fifo_full & ~fifo_read) begin
      rx_overflow <= 1'b1;
    end
  end
endmodule : UART
