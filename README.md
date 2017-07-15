# Timer for Ariane

This repository contains a RISC-V privilege spec 1.11 (WIP) compatible timer for the Ariane Core.

|      Address      | Description |                      Note                      |
|-------------------|-------------|------------------------------------------------|
| `BASE` + `0x4000` | mtimecmp    | Machine mode timer compare register for Hart 0 |
| `BASE` + `0xC000` | mtime       | Timer register                                 |
