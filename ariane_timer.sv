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

module ariane_timer #(
    parameter int unsigned AXI_ADDR_WIDTH = 64,
    parameter int unsigned AXI_DATA_WIDTH = 64,
    parameter int unsigned AXI_ID_WIDTH   = 10,
    parameter int unsigned NR_CORES = 1 // Number of cores therefore also the number of timecmp registers and timer interrupts
)(
    // APB Slave
    input  logic           clk_i,     // Clock
    input  logic           rst_ni,  // Asynchronous reset active low

    AXI_BUS.Slave          slave,

    input  logic           rtc_i,    // Real-time clock in (usually 32.768 kHz)
    output logic    [63:0] time_o,   // Global Time out, this is the time-base of the whole SoC
    output logic           irq_o     // Timer interrupt
);
    // number of cycles the RTC signal has to be stable, if the main frequency is very slow you might
    // consider decreasing the number of cycles you require it to be stable.
    localparam int unsigned STABLE_CYCLES = 5;
    // register offset
    localparam logic [1:0] REG_CMP  = 2'h1;
    localparam logic [1:0] REG_TIME = 2'h3;
    // signals from AXI 4 Lite
    logic [AXI_ADDR_WIDTH-1:0] address;
    logic                      en;
    logic                      we;
    logic [63:0] wdata;
    logic [63:0] rdata;

    // bit 11 and 10 are determining the address offset
    logic [1:0] register_address;
    assign register_address = address[11:10];
    // cycle counter
    logic [$clog2(STABLE_CYCLES)-1:0] count_n, count_q;
    // actual registers
    logic [63:0]               mtime_n, mtime_q;
    logic [NR_CORES-1:0][63:0] mtimecmp_n, mtimecmp_q;

    // increase the timer
    logic increase_timer;

    // directly output the mtime_q register - this needs synchronization (but in the core).
    assign time_o = mtime_q;

    // -----------------------------
    // AXI Interface Logic
    // -----------------------------
    axi_lite_interface #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH ),
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH ),
        .AXI_ID_WIDTH   ( AXI_ID_WIDTH    )
    ) axi_lite_interface_i (
        .address_o ( address ),
        .en_o      ( en      ),
        .we_o      ( we      ),
        .data_i    ( rdata   ),
        .data_o    ( wdata   ),
        .*
    );

    // -----------------------------
    // Register Update Logic
    // -----------------------------
    // APB register write logic
    always_comb begin
        mtime_n    = mtime_q;
        mtimecmp_n = mtimecmp_q;

        // RTC says we should increase the timer
        if (increase_timer)
            mtime_n = mtime_q + 1;

        // written from APB bus - gets priority
        if (en && we) begin
            case (register_address)
                REG_TIME:
                    mtime_n = wdata;

                REG_CMP:
                    mtimecmp_n[$unsigned(address[NR_CORES-1+3:3])] = wdata;
                default:;
            endcase
        end
    end

    // APB register read logic
    always_comb begin
        rdata = 'b0;

        if (en && !we) begin
            case (register_address)
                REG_TIME:
                    rdata = mtime_q;

                REG_CMP:
                    rdata = mtimecmp_q[$unsigned(address[NR_CORES-1+3:3])];
                default:;
            endcase
        end
    end

    // -----------------------------
    // IRQ Generation
    // -----------------------------
    // The mtime register has a 64-bit precision on all RV32, RV64, and RV128 systems. Platforms provide a 64-bit
    // memory-mapped machine-mode timer compare register (mtimecmp), which causes a timer interrupt to be posted when the
    // mtime register contains a value greater than or equal (mtime >= mtimecmp) to the value in the mtimecmp register.
    // The interrupt remains posted until it is cleared by writing the mtimecmp register. The interrupt will only be taken
    // if interrupts are enabled and the MTIE bit is set in the mie register.
    always_comb begin : irq_gen
        // check that the mtime cmp register is set to a meaningful value
        if (mtimecmp_q != 0 && mtime_q >= mtimecmp_q)
            irq_o = 1'b1;
        else
            irq_o = 1'b0;
    end
    // -----------------------------
    // RTC time tracking facilities
    // -----------------------------
    // 1. Put the RTC input through a classic two stage synchronizer to filter out any
    //    metastability effects (or at least make them unlikely :-))
    // 2. Count the number of cycles the signal is high, this should ensure that the
    //    update of the timer register is consistent (e.g.: it is happening exactly once/RTC cycle) and
    //    and not more often because of slow signal ramps. You have to imagine that we are going to sample this signal
    //    with a couple of hundred MHz while the RTC signal is only in the regime of kHz.
    // 3. If this process detects a stable clock signal it asserts the increase_timer signal which will increase
    //    the mtime register accordingly ~> increase_timer should be high for exactly one cycle.
    //
    // synchronized RTC signal
    logic rtc_synch;
    // Ad (1):
    synch synch_i (.clk_i(clk_i), .rst_ni(rst_ni), .a_i(rtc_i), .z_o(rtc_synch));
    // wait for the next rising edge, wait for the next falling edge, start counting or give the increase_timer signal
    enum logic [1:0] {WAIT_HIGH, WAIT_LOW, COUNT, INCREASE_TIMER} CS, NS;

    always_comb begin : rtc_update
        increase_timer = 1'b0;
        NS             = CS;
        count_n        = count_q;

        // Ad (2):
        case (CS)
            // wait for a high RTC signal
            WAIT_HIGH: begin
                if (rtc_synch == 1'b1) begin
                    // the RTC is high, start counting
                    NS = COUNT;
                    // reset the cycle counter
                    count_n = 0;
                end
                // if it is low, just wait here
            end
            // wait for a low RTC signal
            WAIT_LOW: begin
                if (rtc_synch == 1'b0) begin
                    NS = WAIT_HIGH;
                end
            end
            // start counting,
            COUNT: begin
                // if we got the amount of stable cycles we requested ~> increase the timer
                if (count_q == STABLE_CYCLES[$clog2(STABLE_CYCLES)-1:0])
                    NS = INCREASE_TIMER;

                // if the RTC became low again wait for the high signal in the WAIT_HIGH state
                if (rtc_synch == 1'b0)
                    NS = WAIT_HIGH;
                else // if the RTC signal is high increase the counter
                    count_n = count_q + 1;
            end

            // Ad (3):
            INCREASE_TIMER: begin
                increase_timer = 1'b1;
                // wait again for the signal to become low
                NS = WAIT_LOW;
            end

            default:;
        endcase
    end

    // Registers
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if(~rst_ni) begin
            CS         <= WAIT_HIGH;
            count_q    <= 'b0;
            mtime_q    <= 64'b0;
            mtimecmp_q <= 'b0;
        end else begin
            CS         <= NS;
            count_q    <= count_n;
            mtime_q    <= mtime_n;
            mtimecmp_q <= mtimecmp_n;
        end
    end

    // -------------
    // Assertions
    // --------------
    `ifndef SYNTHESIS
    `ifndef VERILATOR
    // Static assertion check for appropriate bus width
        initial begin
            assert (AXI_DATA_WIDTH == 64) else $fatal("Timer needs to interface with a 64 bit bus, everything else is not supported");
        end
    `endif
    `endif
endmodule
