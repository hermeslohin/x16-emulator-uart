; LOOPTEST.PRG - the serial chip's own loopback (MCR bit 4): every byte sent goes straight back into
; its receive buffer, nothing reaches the ESP32/WiFi/hub. Sends all 256 values 40 times and reads
; them back with the same wait+read code running from main RAM, RAM bank 60 and RAM bank 10.
%import textio
%zeropage basicsafe

main {
    uword stub = memory("stub", 32, 0)
    ubyte[8] badw
    ubyte[8] badr
    ubyte nbadpairs

    ; wait for data (LSR bit 0, ~0.1 s timeout) then lda RBR; carry set = got a byte
    ubyte[] code = [$a0, $00, $a2, $00, $ad, $e5, $9f, $4a, $b0, $07, $ca, $d0, $f7, $88, $d0, $f4,
                    $60, $ad, $e0, $9f, $38, $60]

    asmsub run(uword addr @R0) -> ubyte @A, bool @Pc {
        %asm {{
            jmp  (cx16.r0)
        }}
    }

    sub start() {
        txt.lowercase()
        txt.print("LOOPTEST: tl16c2550 internal loopback\n")
        @($9fe7) = $a5
        if @($9fe7) != $a5 {
            txt.print("no serial card at $9fe0\n")
            return
        }
        sys.memcopy(&code, stub, len(code))
        cx16.rambank(60)
        sys.memcopy(&code, $a000, len(code))
        cx16.rambank(10)
        sys.memcopy(&code, $a000, len(code))
        cx16.rambank(0)
        ; 115200 8N1, FIFOs on (as X16Link), loopback with DTR+RTS
        @($9fe3) = $80
        @($9fe0) = 8
        @($9fe1) = 0
        @($9fe3) = $03
        @($9fe1) = 0
        @($9fe2) = $87
        @($9fe4) = $13
        ; empty the receive FIFO until it has been quiet for half a second
        uword t0 = cbm.RDTIM16()
        while cbm.RDTIM16() - t0 < 30 {
            if @($9fe5) & 1 != 0 {
                cx16.r0L = @($9fe0)
                t0 = cbm.RDTIM16()
            }
        }
        test(0)
        test(60)
        test(10)
        @($9fe4) = $23                      ; back to normal: DTR, RTS, AFE
        txt.print("done.\n")
    }

    sub test(ubyte where) {
        uword errs = 0
        uword ff_errs = 0
        uword timeouts = 0
        nbadpairs = 0
        uword addr = stub
        if where != 0
            addr = $a000
        repeat 40 {
            ubyte v = 0
            repeat 256 {
                while @($9fe5) & $20 == 0 {
                }
                @($9fe0) = v                ; THR
                cx16.rambank(where)
                ubyte r
                bool ok
                r, ok = run(addr)
                cx16.rambank(0)
                if not ok
                    timeouts++
                else if r != v {
                    errs++
                    if v == $ff
                        ff_errs++
                    note(v, r)
                }
                v++
            }
        }
        if where == 0
            txt.print("main ram: ")
        else {
            txt.print("bank ")
            txt.print_ub(where)
            txt.print(":   ")
        }
        txt.print_uw(errs)
        txt.print(" wrong, $ff wrong ")
        txt.print_uw(ff_errs)
        txt.print(" of 40, timeouts ")
        txt.print_uw(timeouts)
        txt.nl()
        if nbadpairs != 0 {
            txt.print("   sent>read:")
            ubyte i
            for i in 0 to nbadpairs - 1 {
                txt.print(" ")
                txt.print_ubhex(badw[i], false)
                txt.chrout('>')
                txt.print_ubhex(badr[i], false)
            }
            txt.nl()
        }
    }

    sub note(ubyte w, ubyte r) {
        ubyte i
        if nbadpairs != 0 {
            for i in 0 to nbadpairs - 1 {
                if badw[i] == w and badr[i] == r
                    return
            }
        }
        if nbadpairs < 8 {
            badw[nbadpairs] = w
            badr[nbadpairs] = r
            nbadpairs++
        }
    }
}
