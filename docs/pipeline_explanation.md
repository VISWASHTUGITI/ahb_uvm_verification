# AHB Pipelined Transfer Explanation

## What is Pipelining in AHB?

The AHB (Advanced High-performance Bus) protocol uses a **2-phase pipelined transfer** mechanism. This means the address phase of the next transfer can overlap with the data phase of the current transfer, improving bus throughput.

---

## Pipeline Phases

```
Clock  :  __|‾|__|‾|__|‾|__|‾|__|‾|__
          
Phase  :   [ADDR-A][DATA-A][ADDR-B][DATA-B]
                   [ADDR-B]        [ADDR-C]
```

| Clock Edge | Bus Activity |
|------------|-------------|
| Edge 1 | Master drives HADDR, HWRITE, HSIZE, HTRANS (Address Phase of Beat 1) |
| Edge 2 | Master drives HWDATA (Data Phase of Beat 1) + simultaneously drives HADDR for Beat 2 |
| Edge 3 | Data Phase of Beat 2 overlaps with Address Phase of Beat 3 |

---

## How the Driver Implements Pipelining

In `ahb_driver.sv`, the `drive_transfer` task:

1. **Cycle 1** — Drives address signals (`HADDR`, `HWRITE`, `HSIZE`, `HBURST`, `HTRANS=NONSEQ`)
2. **Cycle 2** — Drives `HWDATA` for the previous address **and simultaneously** drives the next `HADDR` with `HTRANS=SEQ`
3. **Last beat** — Sets `HTRANS=IDLE` and deasserts `HSEL`

```systemverilog
// Address phase — beat 0
@(posedge vif.HCLK);
vif.HSEL   <= 1'b1;
vif.HADDR  <= beat_addr;
vif.HTRANS <= 2'b10;   // NONSEQ

for (int beat = 0; beat < req.num_beats; beat++) begin
  beat_addr = beat_addr + addr_inc;
  @(posedge vif.HCLK);
  // Data phase of current beat
  if (req.hwrite)
    vif.HWDATA <= req.write_data + (beat * 32'h100);
  // Address phase of NEXT beat (pipelined)
  if (beat < req.num_beats - 1) begin
    vif.HADDR  <= beat_addr;
    vif.HTRANS <= 2'b11;   // SEQ
  end else begin
    vif.HTRANS <= 2'b00;   // IDLE — end of burst
    vif.HSEL   <= 1'b0;
  end
end
```

---

## How the Slave Handles Pipelining

In `ahb_slave.sv`, the slave registers the address-phase signals on each rising clock edge:

```systemverilog
always_ff @(posedge HCLK) begin
  wr_en_d <= addr_valid &&  HWRITE;  // registered write enable
  rd_en_d <= addr_valid && !HWRITE;  // registered read enable
  addr_d  <= HADDR;                  // registered address
end
```

The `_d` suffix signals are used in the **data phase** (next cycle), perfectly matching the pipeline timing.

---

## HTRANS Encoding

| HTRANS[1:0] | Name   | Meaning                          |
|-------------|--------|----------------------------------|
| `2'b00`     | IDLE   | No transfer requested            |
| `2'b10`     | NONSEQ | First beat of a transfer/burst   |
| `2'b11`     | SEQ    | Subsequent beats of a burst      |

---

## Read Pipeline Timing

For reads, data appears **one cycle after** the data-phase clock edge because the slave's `HRDATA` is registered:

```
Clock  :  __|‾|__|‾|__|‾|__|‾|
HADDR  :  [ADDR ]
HTRANS :  [NONSEQ][IDLE ]
HRDATA :         [????][DATA ]   ← valid one extra cycle later
```

This is why the monitor and driver both do **two extra `@(posedge HCLK)`** waits before sampling `HRDATA`.

---

## Burst Types Supported

| HBURST | Name   | Beats |
|--------|--------|-------|
| `3'b000` | SINGLE | 1   |
| `3'b001` | INCR   | 1–4 (undefined length) |
| `3'b011` | INCR4  | 4   |
| `3'b101` | INCR8  | 8   |
