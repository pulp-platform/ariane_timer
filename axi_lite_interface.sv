// Author: Florian Zaruba, ETH Zurich
// Date: 17/07/2017
// Description: AXI Lite compatible interface
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

module axi_lite_interface #(
    parameter int unsigned AXI_ADDR_WIDTH = 64,
    parameter int unsigned AXI_DATA_WIDTH = 64,
    parameter int unsigned AXI_ID_WIDTH   = 10
)(
    input logic                       clk_i,    // Clock
    input logic                       rst_ni,  // Asynchronous reset active low

    AXI_BUS.Slave                     slave,

    output logic [AXI_ADDR_WIDTH-1:0] address_o,
    output logic                      en_o,        // transaction is valid
    output logic                      we_o,        // write
    input  logic [AXI_DATA_WIDTH-1:0] data_i,      // data
    output logic [AXI_DATA_WIDTH-1:0] data_o
);

    // The RLAST signal is not required, and is considered asserted for every transfer on the read data channel.
    enum logic [1:0] { IDLE, READ, WRITE } CS, NS;
    // save the trans id, we will need it for reflection otherwise we are not plug compatible to the AXI standard
    logic [AXI_ID_WIDTH-1:0]   trans_id_n, trans_id_q;
    // address register
    logic [AXI_ADDR_WIDTH-1:0] address_n,  address_q;

    // pass through read data on the read data channel
    assign slave.r_data = data_i;
    // send back the transaction id we've latched
    assign slave.r_id = trans_id_q;
    assign slave.b_id = trans_id_q;
    // set w_last and r_last to one as defined by the AXI4 - Lite standard
    assign slave.w_last = 1'b1;
    assign slave.r_last = 1'b1;
    // we do not support any errors so set response flag to all zeros
    assign slave.b_resp = 2'b0;
    // ------------------------
    // AXI4-Lite State Machine
    // ------------------------
    always_comb begin
        // default signal assignment
        NS         = CS;
        address_n  = address_q;
        trans_id_n = trans_id_q;

        // we'll answer a write request only if we got address and data
        slave.aw_ready = 1'b0;
        slave.w_ready  = 1'b0;
        slave.b_valid  = 1'b0;

        slave.ar_ready = 1'b1;
        slave.r_valid  = 1'b0;

        address_o      = '0;
        we_o           = 1'b0;
        en_o           = 1'b0;

        case (CS)
            // we are ready to accept a new request
            IDLE: begin
                // we've git a valid write request, we also know that we have asserted the aw_ready
                if (slave.aw_valid && slave.w_valid) begin
                    NS = WRITE;
                    // save address
                    address_o = slave.aw_addr;
                    data_o    = slave.w_data;
                    en_o      = 1'b1;
                    we_o      = 1'b1;
                    // save the transaction id for reflection
                    trans_id_n = slave.aw_id;
                // we've got a valid read request, we also know that we have asserted the ar_ready
                end else if (slave.ar_valid) begin
                    NS = READ;
                    address_n = slave.ar_addr;
                    // also request the word from the memory-like interface
                    address_o = slave.ar_addr;
                    // save the transaction id for reflection
                    trans_id_n = slave.ar_id;
                    // enable the ram-like
                    en_o       = 1'b1;
                end
            end
            // We've got a read request at least one cycle earlier
            // so data_i will already contain the data we'd like tor read
            READ: begin
                // we are not ready for another request here
                slave.ar_ready = 1'b0;
                // further assert the correct address
                address_o = address_q;
                // the read is valid
                slave.r_valid = 1'b1;
                // check if we got a valid r_ready and go back to IDLE
                if (slave.r_ready)
                    NS = IDLE;
            end
            // We've got a write request at least one cycle earlier
            // wait here for the data
            WRITE: begin
                // we are not ready for another request here
                slave.ar_ready = 1'b0;
                slave.b_valid  = 1'b1;
                // we've already performed the write here so wait for the ready signal
                if (slave.b_ready)
                    NS = IDLE;
            end

            default:;

        endcase
    end

    // ------------------------
    // Registers
    // ------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if(~rst_ni) begin
            CS         <= IDLE;
            address_q  <= '0;
            trans_id_q <= '0;
        end else begin
            CS         <= NS;
            address_q  <= address_n;
            trans_id_q <= trans_id_n;
        end
    end

    // ------------------------
    // Assertions
    // ------------------------
    // Listen for illegal transactions
    `ifndef SYNTHESIS
    `ifndef VERILATOR
        // check that burst length is just one
        assert property (@(posedge clk_i) slave.ar_valid |->  ((slave.ar_len == 8'b1) && (slave.ar_size == AXI_DATA_WIDTH/8)))
        else begin $error("AXI Lite does not support bursts larger than 1 or byte length unequal to the native bus size"); $stop(); end
        // do the same for the write channel
        assert property (@(posedge clk_i) slave.aw_valid |->  ((slave.aw_len == 8'b1) && (slave.aw_size == AXI_DATA_WIDTH/8)))
        else begin $error("AXI Lite does not support bursts larger than 1 or byte length unequal to the native bus size"); $stop(); end
    `endif
    `endif
endmodule
