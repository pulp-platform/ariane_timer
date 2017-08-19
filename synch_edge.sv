// Author: Florian Zaruba, ETH Zurich
// Date: 19/08/2017
// Description: A edge triggered synchronizer
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

module synch_edge #(
    parameter int unsigned STAGES = 2
)(
    input  logic clk_i,
    input  logic rst_ni,
    input  logic en_i,
    input  logic a_i,
    output logic rising_edge_o,
    output logic falling_edge_o,
    output logic serial_o
);

    logic [STAGES-1:0] synch_q;

    assign serial_o       =  synch_q[0];
    assign falling_edge_o = !synch_q[1] &  synch_q[0];
    assign rising_edge_o  =  synch_q[1] & !synch_q[0];

    // -------------
    // Registers
    // --------------
    always_ff @(posedge clk_i, negedge rst_ni) begin
        if(!rst_ni)
            synch_q <= '0;
        else
            if (en_i)
                synch_q <= {a_i, synch_q[STAGES-1:1]};
    end

    // -------------
    // Assertions
    // --------------
    `ifndef SYNTHESIS
    `ifndef VERILATOR
    // Static assertion check for appropriate bus width
    initial begin
        assert (STAGES >= 2) else $fatal("Edge-triggered synchronizer needs at least 2 stages");
    end
    `endif
    `endif

endmodule
