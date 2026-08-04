#!/usr/bin/env python3
"""
Cycle-accurate Python model of the AHB verification environment.

Faithfully mirrors (translated from SystemVerilog):
  * rtl/ahb_slave.sv          -- zero-wait-state AHB slave (registered addr/data)
  * tb/agent/ahb_driver.sv    -- pipelined driver schedule
  * tb/agent/ahb_monitor.sv   -- NEW per-beat monitor capture logic
  * tb/env/ahb_scoreboard.sv  -- NEW per-beat beat-by-beat checker

Purpose: validate that the pipeline timing the monitor relies on is correct for
1-, 2-, 3-, 4- and 8-beat read/write bursts, and that the scoreboard verifies
EVERY beat at its OWN address (and would FAIL on corrupted data).

This is NOT the SystemVerilog itself -- it is a faithful simulation model used to
reason about the timing. Run:  python3 sim/model_sim.py
"""
import sys

NONSEQ = 0b10
SEQ    = 0b11
IDLE   = 0b00

MEM_DEPTH  = 256
ADDR_WIDTH = 32

HADDR_MSB = 9   # MEM_DEPTH=256 -> $clog2=8 -> waddr = addr_d[9:2]
HADDR_LSB = 2

# ---------------------------------------------------------------------------
# DUT: rtl/ahb_slave.sv
# ---------------------------------------------------------------------------
class AhbSlave:
    def __init__(self):
        self.mem = [0]*MEM_DEPTH
        self.wr_en_d = 0
        self.rd_en_d = 0
        self.addr_d  = 0
        self.hsize_d = 0
        self.HRDATA  = 0
        self._old_addr_d = 0

    def _byte_en(self, hsize, addr):
        if hsize == 0b000:   # byte
            return 1 << addr[0:2]
        elif hsize == 0b001: # halfword
            return 0b0011 << (addr[1]*2)
        else:                # word
            return 0b1111

    def posedge(self, sig):
        # ---- DATA / MEM phase ---------------------------------------------
        # The data-phase always_ff blocks sample the PRE-EDGE registered values
        # (wr_en_d/rd_en_d/addr_d from the PREVIOUS edge) together with the
        # CURRENT bus data. This is exactly the AHB pipeline: address sampled at
        # edge N-1, its data applied at edge N.
        if self.wr_en_d:
            waddr = (self.addr_d >> HADDR_LSB) & (MEM_DEPTH-1)
            be = self._byte_en(self.hsize_d, self.addr_d)
            wd = sig['HWDATA'] & 0xFFFFFFFF
            for b in range(4):
                if be & (1 << b):
                    self.mem[waddr] = (self.mem[waddr] & ~(0xFF << (8*b))) | ((wd & (0xFF << (8*b))))

        # ---- ADDRESS phase: register for next cycle ------------------------
        addr_valid = sig['HSEL'] and sig['HREADY'] and sig['HTRANS'] in (NONSEQ, SEQ)
        self.wr_en_d = 1 if (addr_valid and sig['HWRITE']) else 0
        self.rd_en_d = 1 if (addr_valid and not sig['HWRITE']) else 0
        self.addr_d  = sig['HADDR'] & 0xFFFFFFFF
        self.hsize_d = sig['HSIZE']

        # READ DATA PHASE (combinational, proper AHB pipelining): HRDATA is
        # derived combinationally from the just-sampled address/read-enable, so
        # it is valid during the data-phase cycle (the cycle after the address
        # is sampled). No extra registered cycle on the read output.
        if self.rd_en_d:
            waddr = (self.addr_d >> HADDR_LSB) & (MEM_DEPTH-1)
            self.HRDATA = self.mem[waddr]
        else:
            self.HRDATA = 0

# ---------------------------------------------------------------------------
# BUS (vif)
# ---------------------------------------------------------------------------
class Bus:
    def __init__(self):
        self.HSEL=0; self.HADDR=0; self.HWRITE=0; self.HSIZE=0; self.HBURST=0
        self.HTRANS=IDLE; self.HPROT=0; self.HWDATA=0; self.HREADY=1; self.HRESP=0
        self.HRDATA=0

    def snapshot(self):
        return dict(HSEL=self.HSEL, HADDR=self.HADDR, HWRITE=self.HWRITE,
                    HSIZE=self.HSIZE, HBURST=self.HBURST, HTRANS=self.HTRANS,
                    HPROT=self.HPROT, HWDATA=self.HWDATA, HREADY=self.HREADY,
                    HRESP=self.HRESP, HRDATA=self.HRDATA)

# ---------------------------------------------------------------------------
# DRIVER: exact schedule from tb/agent/ahb_driver.sv
#   addr_inc = 4 for word transfers (this model only runs word transfers)
# ---------------------------------------------------------------------------
def driver_cycles(bus, slave, addr, hwrite, hburst, num_beats, wdata_base):
    """Run one drive_transfer() to completion, cycle by cycle."""
    cycle_log = []   # list of (cycle_index, bus_snapshot)
    beat_addr = addr
    # Address phase of beat 0 (NONSEQ)
    bus.HSEL=1; bus.HADDR=beat_addr; bus.HWRITE=hwrite; bus.HSIZE=0b010
    bus.HBURST=hburst; bus.HPROT=0b0011; bus.HTRANS=NONSEQ
    slave.posedge(bus.snapshot()); bus.HRDATA=slave.HRDATA
    cycle_log.append(("A0", bus.snapshot()))

    for beat in range(num_beats):
        beat_addr = beat_addr + 4
        if hwrite:
            bus.HWDATA = (wdata_base + beat*0x100) & 0xFFFFFFFF
        if beat < num_beats-1:
            bus.HADDR = beat_addr; bus.HTRANS = SEQ; bus.HSEL = 1
        else:
            bus.HTRANS = IDLE; bus.HSEL = 0; bus.HADDR = 0; bus.HWRITE = 0
        slave.posedge(bus.snapshot()); bus.HRDATA=slave.HRDATA
        cycle_log.append((f"B{beat}", bus.snapshot()))

    if not hwrite:
        # two extra edges, then sample HRDATA (driver)
        slave.posedge(bus.snapshot()); bus.HRDATA=slave.HRDATA
        cycle_log.append(("RD1", bus.snapshot()))
        slave.posedge(bus.snapshot()); bus.HRDATA=slave.HRDATA
        cycle_log.append(("RD2", bus.snapshot()))
        read_data = bus.HRDATA
    else:
        slave.posedge(bus.snapshot()); bus.HRDATA=slave.HRDATA
        cycle_log.append(("W1", bus.snapshot()))
        read_data = None
    return cycle_log, read_data

# ---------------------------------------------------------------------------
# MONITOR: NEW per-beat collect_transaction() logic
# ---------------------------------------------------------------------------
class Monitor:
    def collect(self, cycle_log):
        # cycle_log: list of (label, snapshot) in time order. Reconstruct the
        # bus values seen at each posedge exactly as vif would present them.
        # We model the monitor as sampling vif at posedge = the snapshot values
        # that were driving the DUT during that cycle (they persist, so sampling
        # the same bus yields the same signals).
        idx = 0
        # find first NONSEQ accepted by HREADY & HSEL
        while idx < len(cycle_log):
            s = cycle_log[idx][1]
            if s['HSEL'] and s['HTRANS']==NONSEQ and s['HREADY']:
                break
            idx += 1
        cur = cycle_log[idx][1]
        trans = dict(addr=cur['HADDR'], hwrite=cur['HWRITE'], hsize=cur['HSIZE'],
                     hburst=cur['HBURST'], hprot=cur['HPROT'], htrans=NONSEQ)
        cap_write = cur['HWRITE']
        beat=0; cur_addr=trans['addr']; nxt=None
        beat_addr_q=[]; beat_wdata_q=[]; beat_rdata_q=[]; resp=None

        idx += 1   # advance into data phase of beat 0 (one @(posedge))

        if cap_write:
            while True:
                s = cycle_log[idx][1]
                beat_wdata_q.append(s['HWDATA'] & 0xFFFFFFFF)
                beat_addr_q.append(cur_addr)
                resp = s['HRESP']
                beat+=1
                if s['HTRANS'] != SEQ:
                    break
                cur_addr = s['HADDR']
                idx += 1
        else:
            # READ (combinational HRDATA): at the data edge `idx`, beat i's data
            # is valid from the previous cycle (idx-1), while the bus already
            # carries the next beat's address (AHB pipelining). Pair each data
            # sample with the tracked address (cur_addr), grabbing the next
            # beat's address when HTRANS==SEQ.
            while True:
                beat_rdata_q.append(cycle_log[idx-1][1]['HRDATA'] & 0xFFFFFFFF)
                beat_addr_q.append(cur_addr)
                resp = cycle_log[idx][1]['HRESP']
                beat += 1
                if cycle_log[idx][1]['HTRANS'] != SEQ:
                    break
                cur_addr = cycle_log[idx][1]['HADDR'] & 0xFFFFFFFF
                idx += 1                     # advance to next data edge
        return dict(num_beats=beat, n_captured=beat,
                    beat_addr_q=beat_addr_q, beat_wdata_q=beat_wdata_q,
                    beat_rdata_q=beat_rdata_q, hwrite=cap_write,
                    write_data=(beat_wdata_q[0] if beat_wdata_q else None),
                    read_data=(beat_rdata_q[-1] if beat_rdata_q else None),
                    hresp=resp)

# ---------------------------------------------------------------------------
# SCOREBOARD: NEW per-beat checker
# ---------------------------------------------------------------------------
class Scoreboard:
    def __init__(self):
        self.ref = {}
        self.wr=0; self.rd=0; self.pass_=0; self.fail=0; self.uninit=0
    def write(self, t):
        if t['hresp'] != 0:
            self.fail += 1; return
        if t['hwrite']:
            for i in range(t['n_captured']):
                wa = t['beat_addr_q'][i] & ~3
                self.ref[wa] = t['beat_wdata_q'][i]
                self.wr += 1
        else:
            for i in range(t['n_captured']):
                wa = t['beat_addr_q'][i] & ~3
                self.rd += 1
                if wa not in self.ref:
                    self.uninit += 1; continue
                if t['beat_rdata_q'][i] == self.ref[wa]:
                    self.pass_ += 1
                else:
                    self.fail += 1
    def report(self):
        return (f"writes={self.wr} reads={self.rd} pass={self.pass_} "
                f"fail={self.fail} uninit_read={self.uninit}")

# ---------------------------------------------------------------------------
# Top-level runner: reuse ONE slave+bus across all transfers (like real sim)
# ---------------------------------------------------------------------------
def run_all():
    bus = Bus(); slave = AhbSlave(); mon = Monitor(); sb = Scoreboard()
    all_ok = True

    def do(addr, hwrite, hburst, nbeats, wbase):
        nonlocal all_ok
        cycles, _ = driver_cycles(bus, slave, addr, hwrite, hburst, nbeats, wbase)
        t = mon.collect(cycles)
        sb.write(t)
        # verify beat count matches
        if t['num_beats'] != nbeats:
            print(f"  !! MONITOR beat-count mismatch: exp={nbeats} got={t['num_beats']} "
                  f"burst={hburst:03b} addr=0x{addr:X}")
            all_ok = False
        return t

    print("== Run 1: 1-beat SINGLE write + read-back (0x00) ==")
    do(0x000, 1, 0b000, 1, 0xDEADBEEF)
    t = do(0x000, 0, 0b000, 1, 0)
    assert t['read_data']==0xDEADBEEF, f"single read-back mismatch {t['read_data']:#x}"

    print("== Run 2: INCR4 write (0x10) + INCR4 read-back ==")
    do(0x010, 1, 0b011, 4, 0x11110000)
    t = do(0x010, 0, 0b011, 4, 0)
    assert t['beat_rdata_q']==[0x11110000,0x11110100,0x11110200,0x11110300], t['beat_rdata_q']

    print("== Run 3: INCR8 write (0x80) + INCR8 read-back ==")
    do(0x080, 1, 0b101, 8, 0xA0000000)
    t = do(0x080, 0, 0b101, 8, 0)
    exp=[0xA0000000+i*0x100 for i in range(8)]
    assert t['beat_rdata_q']==exp, t['beat_rdata_q']

    print("== Run 4: INCR 2-beat + INCR 3-beat (the case that used to disagree) ==")
    do(0x200, 1, 0b001, 2, 0x12340000)
    t = do(0x200, 0, 0b001, 2, 0)
    assert t['beat_rdata_q']==[0x12340000,0x12340100]
    do(0x300, 1, 0b001, 3, 0x55550000)
    t = do(0x300, 0, 0b001, 3, 0)
    assert t['beat_rdata_q']==[0x55550000,0x55550100,0x55550200]

    print("== Run 5: NEGATIVE TEST - corrupted read MUST fail scoreboard ==")
    bus2=Bus(); slave2=AhbSlave(); mon2=Monitor(); sb2=Scoreboard()
    wcyc,_ = driver_cycles(bus2, slave2, 0x40, 1, 0b011, 4, 0x77770000)
    sb2.write(mon2.collect(wcyc))          # store the write burst in the ref model
    cycles,_ = driver_cycles(bus2, slave2, 0x40, 0, 0b011, 4, 0)
    t = mon2.collect(cycles)
    # flip a data byte on beat index 2
    t['beat_rdata_q'][2] ^= 0xFF
    sb2.write(t)
    assert sb2.fail>=1, "corrupted burst read did NOT fail scoreboard!"
    print("  (corruption on beat 2 correctly caught -> fail=%d)" % sb2.fail)

    print()
    print("== SCOREBOARD SUMMARY ==")
    print(" ", sb.report())
    print()
    print("PIPELINE TIMING + PER-BEAT VERIFICATION  :  ALL CHECKS PASSED" if all_ok else "!! FAILURES")
    return 0 if all_ok else 1

if __name__ == "__main__":
    sys.exit(run_all())
