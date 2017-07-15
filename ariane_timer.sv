// Author: Florian Zaruba, ETH Zurich
// Date: 15/07/2017
// Description: A RISC-V privilege spec 1.11 (WIP) compatible timer
//
//
// Copyright (C) 2017 ETH Zurich, University of Bologna
// All rights reserved.
//
// This code is under development and not yet released to the public.
// Until it is released, the code is under the copyright of ETH Zurich and
// the University of Bologna, and may contain confidential and/or unpublished
// work. Any reuse/redistribution is strictly forbidden without written
// permission from ETH Zurich.
//
// Bug fixes and contributions will eventually be released under the
// SolderPad open hardware license in the context of the PULP platform
// (http://www.pulp-platform.org), under the copyright of ETH Zurich and the
// University of Bologna.
//

// Platforms provide a real-time counter, exposed as a memory-mapped machine-mode register, mtime. mtime must run at
// constant frequency, and the platform must provide a mechanism for determining the timebase of mtime.
//
// The mtime register has a 64-bit precision on all RV32, RV64, and RV128 systems. Platforms provide a 64-bit
// memory-mapped machine-mode timer compare register (mtimecmp), which causes a timer interrupt to be posted when the
// mtime register contains a value greater than or equal (mtime >= mtimecmp) to the value in the mtimecmp register.
// The interrupt remains posted until it is cleared by writing the mtimecmp register. The interrupt will only be taken
// if interrupts are enabled and the MTIE bit is set in the mie register.

module ariane_timer #(
    parameter int unsigned APB_ADDR_WIDTH = 12,  //APB slaves are 4KB by default
    parameter int unsigned NR_CORES = 1 // Number of cores therefore also the number of timecmp registers and timer interrupts
)(
    // APB Slave
    input  logic                      HCLK,            // Clock
    input  logic                      HRESETn,         // Asynchronous reset active low
    input  logic [APB_ADDR_WIDTH-1:0] PADDR,
    input  logic               [63:0] PWDATA,
    input  logic                      PWRITE,
    input  logic                      PSEL,
    input  logic                      PENABLE,
    output logic               [63:0] PRDATA,
    output logic                      PREADY,
    output logic                      PSLVERR,

    input  logic                      rtc_i,            // Real-time clock in (usually 32.768 kHz)
    output logic               [63:0] time_o,           // Global Time out, this is the time-base of the whole SoC
    output logic                      timer_interrupt_o // Timer interrupt
);
    logic [63:0]         mtime_n, mtime_q;
    logic [NR_CORES-1:0] mtimecmp_n, mtimecmp_q;

    assign time_o = mtime_q;
    // Registers
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            mtime_q    <= 64'0;
            mtimecmp_q <= '0;
        end else begin
            mtime_q    <= mtime_n;
            mtimecmp_q <= mtimecmp_n;
        end
    end
endmodule