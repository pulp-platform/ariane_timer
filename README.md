# Timer for Ariane

This repository contains a RISC-V privilege spec 1.11 (WIP) compatible timer for the Ariane Core.

The timer plugs into an existing AXI Bus with an AXI 4 Lite interface. The IP mirrors transaction IDs and is fully pin-compatible with the full AXI 4 interface. It does not support burst transfers (as specified in the AMBA 4 Bus specifcation)

|      Address      | Description |                      Note                      |
|-------------------|-------------|------------------------------------------------|
| `BASE` + `0x4000` | mtimecmp    | Machine mode timer compare register for Hart 0 |
| `BASE` + `0xC000` | mtime       | Timer register                                 |
