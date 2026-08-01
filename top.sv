/* @file top.sv
 *
 * DE0-CV chip interface for the RP2040 UART.
 *   GPIO_0[0] : UART RX into FPGA
 *   GPIO_0[1] : UART TX from FPGA
 *
 * @author Anay Soni
 */

module top
  (input              CLOCK2_50,
   input              CLOCK3_50,
   inout              CLOCK4_50,
   input              CLOCK_50,

   output      [12:0] DRAM_ADDR,
   output      [1:0]  DRAM_BA,
   output             DRAM_CAS_N,
   output             DRAM_CKE,
   output             DRAM_CLK,
   output             DRAM_CS_N,
   inout       [15:0] DRAM_DQ,
   output             DRAM_LDQM,
   output             DRAM_RAS_N,
   output             DRAM_UDQM,
   output             DRAM_WE_N,

   inout       [35:0] GPIO_0,
   inout       [35:0] GPIO_1,

   output      [6:0]  HEX0,
   output      [6:0]  HEX1,
   output      [6:0]  HEX2,
   output      [6:0]  HEX3,
   output      [6:0]  HEX4,
   output      [6:0]  HEX5,

   input       [3:0]  KEY,
   output      [9:0]  LEDR,

   inout              PS2_CLK,
   inout              PS2_CLK2,
   inout              PS2_DAT,
   inout              PS2_DAT2,

   input              RESET_N,

   output             SD_CLK,
   inout              SD_CMD,
   inout       [3:0]  SD_DATA,

   input       [9:0]  SW,

   output      [3:0]  VGA_B,
   output      [3:0]  VGA_G,
   output             VGA_HS,
   output      [3:0]  VGA_R,
   output             VGA_VS);

  // UART RX/TX
  logic uart_rx, uart_tx;
  logic [7:0] uart_data;
  logic uart_data_valid;
  // SOF (start of frame) is qualified at the midpoint of the start bit
  // midpoint is chosen instead of endpoint b/c want to check for instability
  // midpoint also chosen b/c want to avoid missing data b/c of mixed clocks
  logic uart_sof;
  logic uart_framing_error;
  logic uart_overflow;
  logic uart_tx_busy;
  logic monochrome;

  UART #(.CLOCK_FREQ(50_000_000),
         .BAUD_RATE(115_200)) 
    uart_endpoint (.clock(CLOCK_50),
                   .reset_n(RESET_N),
                   .serial_rx(uart_rx),
                   .serial_tx(uart_tx),
                   .rx_data(uart_data),
                   .rx_data_valid(uart_data_valid),
                   .start_bit_detected(uart_sof),
                   .framing_error(uart_framing_error),
                   .rx_overflow(uart_overflow),
                   .tx_busy(uart_tx_busy),
                   .monochrome);

  assign uart_rx = GPIO_0[0];
  assign GPIO_0[1] = uart_tx;
  assign GPIO_0[35:2] = 'z;
  assign GPIO_1 = 'z;

  // HEX displays
  SevenSegmentHex hex_data (.value(uart_data[3:0]), 
                            .segments(HEX0));
  SevenSegmentHex hex_monochrome (.value({3'b0, monochrome}),
                                  .segments(HEX2));
  assign HEX1 = 7'h7f;
  assign HEX3 = 7'h7f;
  assign HEX4 = 7'h7f;
  assign HEX5 = 7'h7f;

  // LED tracking is too slow... SOF/verification occurs too quickly
  // assign LEDR[0]   = uart_sof;
  // assign LEDR[1]   = uart_data_valid;
  // assign LEDR[2]   = uart_framing_error;
  // assign LEDR[3]   = uart_overflow;
  // assign LEDR[9:4] = '0;

endmodule : top
