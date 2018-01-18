// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the “License”); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Florian Zaruba, ETH Zurich
// Date: 19/08/2017
// Description: A edge triggered synchronizer
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
