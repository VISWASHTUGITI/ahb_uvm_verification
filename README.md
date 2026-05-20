# AHB UVM Verification Environment

[![SystemVerilog](https://img.shields.io/badge/Language-SystemVerilog-blue)](https://en.wikipedia.org/wiki/SystemVerilog)
[![UVM](https://img.shields.io/badge/Methodology-UVM-green)](https://www.accellera.org/downloads/standards/uvm)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A complete, production-ready **UVM-based functional verification environment** for an AHB (Advanced High-performance Bus) Slave with full support for **pipelined transfers**, burst transactions, functional coverage, and self-checking scoreboard.

---

## Table of Contents

- [Protocol Overview](#protocol-overview)
- [Pipelined Transfers](#pipelined-transfers)
- [Features](#features)
- [Project Structure](#project-structure)
- [Architecture](#architecture)
- [Test Cases](#test-cases)
- [Coverage](#coverage)
- [How to Run](#how-to-run)
- [Waveform Guide](#waveform-guide)
- [Future Improvements](#future-improvements)

---

## Protocol Overview

**AHB (Advanced High-performance Bus)** is part of the ARM AMBA bus family, designed for high-bandwidth on-chip communication. Key signals:

| Signal | Direction | Description |
|--------|-----------|-------------|
| `HCLK` | Input | Bus clock |
| `HRESETn` | Input | Active-low reset |
| `HADDR[31:0]` | Master→Slave | Transfer address |
| `HTRANS[1:0]` | Master→Slave | Transfer type (IDLE/NONSEQ/SEQ) |
| `HWRITE` | Master→Slave | 1 = Write, 0 = Read |
| `HSIZE[2:0]` | Master→Slave | Transfer size (byte/half/word) |
| `HBURST[2:0]` | Master→Slave | Burst type (SINGLE/INCR/INCR4/INCR8) |
| `HWDATA[31:0]` | Master→Slave | Write data |
| `HRDATA[31:0]` | Slave→Master | Read data |
| `HREADY` | Slave→Master | Transfer complete (slave ready) |
| `HRESP[1:0]` | Slave→Master | Transfer response (OKAY/ERROR) |

---

## Pipelined Transfers

AHB uses a **2-phase pipeline**: the address phase of the next transfer overlaps with the data phase of the current one.

```
Clock   : __|‾|__|‾|__|‾|__|‾|__|‾|__
HADDR   :   [ADDR-1 ][ADDR-2 ][ADDR-3 ]
HTRANS  :   [NONSEQ ][  SEQ  ][ IDLE  ]
HWDATA  :            [WDATA-1][WDATA-2]
HRDATA  :                     [RDATA-1]
```

- **Address Phase**: Master drives `HADDR`, `HTRANS`, `HWRITE`, `HSIZE`, `HBURST`
- **Data Phase**: Master drives `HWDATA` (write) or samples `HRDATA` (read)
- The slave **registers** address-phase signals (`addr_d`, `wr_en_d`) and acts on them in the data phase

For a detailed explanation with code snippets, see [`docs/pipeline_explanation.md`](docs/pipeline_explanation.md).

---

## Features

- **Full UVM methodology** — sequence item, sequences, driver, monitor, agent, scoreboard, coverage, environment, tests
- **Pipelined AHB driver** — correctly overlaps address and data phases for all burst types
- **Pipelined monitor** — captures address-phase metadata and data-phase payload separately
- **Self-checking scoreboard** — maintains a reference memory model; flags mismatches automatically
- **Functional coverage** — transaction coverage, cross coverage (direction × burst × size × address), back-to-back sequence tracking
- **Protocol assertions (SVA)** — `HREADY` stuck-low detection, word-alignment check
- **Interface-level covergroup** — monitors `HTRANS`, `HBURST`, `HSIZE`, `HWRITE` at the signal level
- **Parameterized DUT** — configurable `MEM_DEPTH`, `ADDR_WIDTH`, `DATA_WIDTH`
- **VCD waveform dump** — `dump.vcd` generated automatically
- **Questa & VCS support** — single `run.sh` supports both simulators

---

## Project Structure

```
ahb_uvm_verification/
│
├── rtl/
│   └── ahb_slave.sv              # DUT: AHB slave memory (256×32-bit)
│
├── interface/
│   └── ahb_if.sv                 # AHB interface + SVA assertions + protocol covergroup
│
├── tb/
│   ├── ahb_uvm_pkg.sv            # Master UVM package (includes all TB files)
│   │
│   ├── top/
│   │   └── top.sv                # Testbench top: DUT instantiation, clock, reset, config_db
│   │
│   ├── seq_item/
│   │   └── ahb_seq_item.sv       # Transaction class with constraints
│   │
│   ├── sequences/
│   │   ├── ahb_base_seq.sv       # Base sequence
│   │   ├── ahb_write_seq.sv      # Single & burst write sequences
│   │   ├── ahb_read_seq.sv       # Single & burst read sequences
│   │   └── ahb_burst_seq.sv      # Composite sequences (write-read, random, boundary, etc.)
│   │
│   ├── agent/
│   │   ├── ahb_driver.sv         # Pipelined AHB driver
│   │   ├── ahb_monitor.sv        # Pipelined AHB monitor
│   │   ├── ahb_sequencer.sv      # UVM sequencer typedef
│   │   └── ahb_agent.sv          # Agent (active): driver + monitor + sequencer
│   │
│   ├── env/
│   │   ├── ahb_scoreboard.sv     # Self-checking scoreboard with reference model
│   │   └── ahb_env.sv            # Environment: agent + scoreboard + coverage
│   │
│   ├── tests/
│   │   └── ahb_test.sv           # All test classes
│   │
│   └── coverage/
│       └── ahb_coverage.sv       # Functional coverage subscriber
│
├── sim/
│   ├── flist.f                   # Compile-order file list
│   └── run.sh                    # Simulation run script (Questa / VCS)
│
├── docs/
│   └── pipeline_explanation.md   # Detailed AHB pipeline timing explanation
│
└── README.md
```

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    ahb_tb_top                        │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │                  ahb_env                      │   │
│  │                                               │   │
│  │  ┌───────────────────────────────────────┐   │   │
│  │  │              ahb_agent                │   │   │
│  │  │                                       │   │   │
│  │  │  ┌────────────┐   ┌───────────────┐  │   │   │
│  │  │  │ ahb_driver │   │  ahb_monitor  │  │   │   │
│  │  │  └─────┬──────┘   └───────┬───────┘  │   │   │
│  │  │        │                   │ ap        │   │   │
│  │  │  ┌─────┴──────┐           │           │   │   │
│  │  │  │ahb_sequencer│          │           │   │   │
│  │  │  └────────────┘           │           │   │   │
│  │  └───────────────────────────┼───────────┘   │   │
│  │                              │               │   │
│  │              ┌───────────────┼───────────┐   │   │
│  │              │               │           │   │   │
│  │    ┌─────────┴──────┐  ┌────┴─────────┐ │   │   │
│  │    │ ahb_scoreboard │  │ ahb_coverage │ │   │   │
│  │    └────────────────┘  └─────────────┘ │   │   │
│  └──────────────────────────────────────────┘   │   │
│                                                  │   │
│  ┌───────────────────────────────────────────┐  │   │
│  │         ahb_if (interface + SVA)           │  │   │
│  └───────────────┬───────────────────────────┘  │   │
│                  │                               │   │
│  ┌───────────────┴───────────────────────────┐  │   │
│  │        ahb_slave_mem (DUT)                 │  │   │
│  └───────────────────────────────────────────┘  │   │
└─────────────────────────────────────────────────────┘
```

---

## Test Cases

| Test Name | Description |
|-----------|-------------|
| `ahb_single_rw_test` | Single word write followed by read-back at 3 fixed addresses; verifies basic read/write correctness |
| `ahb_burst_test` | INCR4 burst write to `0x10`, followed by INCR4 burst read-back; verifies burst pipeline |
| `ahb_random_test` | 30 (configurable) random single-beat transactions; mixed read/write to random addresses |
| `ahb_back2back_test` | 5 back-to-back writes to `0x280–0x2FC`, then sequential reads; stresses pipelining |
| `ahb_boundary_test` | Write+read at boundary addresses `0x300`, `0x304`, `0x3F8`, `0x3FC` |
| `ahb_all_burst_test` | Exercises SINGLE, INCR4, and INCR8 burst types in sequence |
| `ahb_full_test` | Full regression: runs all the above in phases across the complete address space |

### Configuring Random Test Count

```bash
./sim/run.sh ahb_random_test +num_txns=50
```

---

## Coverage

### Functional Coverage (ahb_coverage)

| Coverpoint | Description |
|------------|-------------|
| `cp_direction` | Read vs Write |
| `cp_size` | Byte / Halfword / Word transfers |
| `cp_burst` | SINGLE / INCR / INCR4 / INCR8 |
| `cp_addr_quad` | Address space quadrant (bits [9:8]) |
| `cp_wdata_pat` | Write data patterns (all-0, all-1, 0xAA, 0x55, others) |
| `cp_beats` | Number of beats (1 / 4 / 8) |
| `cx_dir_burst` | Cross: direction × burst type |
| `cx_dir_size` | Cross: direction × transfer size |
| `cx_burst_size` | Cross: burst type × transfer size |
| `cx_dir_addr` | Cross: direction × address quadrant |
| `back2back_cg` | Back-to-back transaction sequences (WR→WR, WR→RD, RD→WR, RD→RD) |

### Protocol Coverage (ahb_if)

| Coverpoint | Description |
|------------|-------------|
| `cp_htrans` | IDLE / NONSEQ / SEQ transfer types |
| `cp_hburst` | Burst types observed on the bus |
| `cp_hsize` | Transfer sizes observed on the bus |
| `cp_hwrite` | Read vs write direction |
| `cx_burst_rw` | Cross: burst × direction |
| `cx_size_rw` | Cross: size × direction |

### Assertions (SVA)

| Assertion | Condition Checked |
|-----------|------------------|
| `ap_hready` | `HREADY` must not stay low for more than 16 cycles |
| `ap_word_align` | Word-size transfers (`HSIZE=2'b010`) must have `HADDR[1:0]==2'b00` |

---

## How to Run

### Prerequisites

- Questa (ModelSim) or Synopsys VCS
- UVM library available (`$UVM_HOME` set)

### Quick Start — Questa

```bash
cd ahb_uvm_verification
chmod +x sim/run.sh

# Run the full regression test (default)
./sim/run.sh

# Run a specific test
./sim/run.sh ahb_single_rw_test
./sim/run.sh ahb_burst_test
./sim/run.sh ahb_random_test
./sim/run.sh ahb_back2back_test
./sim/run.sh ahb_boundary_test
./sim/run.sh ahb_all_burst_test
./sim/run.sh ahb_full_test
```

### Quick Start — VCS

```bash
TOOL=vcs ./sim/run.sh ahb_full_test
```

### Manual Compilation (Questa)

```bash
cd ahb_uvm_verification
vlib work
vlog -sv -f sim/flist.f +define+UVM_NO_DEPRECATED
vsim -c work.ahb_tb_top +UVM_TESTNAME=ahb_full_test +UVM_VERBOSITY=UVM_LOW -do "run -all; quit -f"
```

### Manual Compilation (VCS)

```bash
cd ahb_uvm_verification
vcs -sverilog -f sim/flist.f -ntb_opts uvm -o simv
./simv +UVM_TESTNAME=ahb_full_test +UVM_VERBOSITY=UVM_LOW
```

---

## Waveform Guide

A VCD file `dump.vcd` is generated automatically. Open it in GTKWave or your simulator's waveform viewer.

**Key signals to observe:**

| Signal | What to look for |
|--------|-----------------|
| `HCLK` | 10 ns period clock |
| `HRESETn` | Goes high after 6 clock cycles |
| `HTRANS` | `2'b10` (NONSEQ) starts a transfer, `2'b11` (SEQ) continues burst, `2'b00` (IDLE) ends |
| `HADDR` | Changes one cycle **before** `HWDATA`/`HRDATA` — confirms pipelining |
| `HWDATA` | Appears one cycle **after** the corresponding `HADDR` |
| `HRDATA` | Valid two cycles after the read address phase |
| `HREADY`/`HREADYOUT` | Always `1` (zero-wait-state slave) |
| `HRESP` | Always `2'b00` (OKAY) for valid transfers |

---

## Future Improvements

- [ ] Add wait-state injection (variable `HREADYOUT`) to test multi-cycle slave responses
- [ ] Add `HRESP=ERROR` response sequences and scoreboard handling
- [ ] Extend to multi-master arbitration using `HMASTLOCK`
- [ ] Add byte and halfword transfer test sequences
- [ ] Integrate with a coverage-driven closure flow (CDG)
- [ ] Add UVM register model (RAL) layer
- [ ] CI/CD integration via GitHub Actions

---

## License

This project is released under the [MIT License](LICENSE).

---

*Built with UVM 1.2 | Compatible with Questa 2021.x+ and VCS 2021.x+*
