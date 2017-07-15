// Author: Florian Zaruba, ETH Zurich
// Date: 15/07/2017
// Description: A classic n-stage synchronizer
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

module synch #(
    parameter int unsigned STAGES = 2
)(
    input  logic clk_i,   // Clock
    input  logic rst_ni,  // Asynchronous reset active low

    input  logic a_i,     // signal to synchronize
    output logic z_o      // synchronized signal
);

    logic [STAGES-1:0] synch_q;

    always_ff @(posedge clk_i, negedge rst_ni) begin
        if(!rst_ni)
            synch_q <= 'h0;
        else
            synch_q <= {synch_q[STAGES-2:0], a_i};
        end

    assign z_o   =  synch_q[STAGES-1];

endmodule
