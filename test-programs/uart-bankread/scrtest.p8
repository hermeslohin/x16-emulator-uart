; SCRTEST.PRG - write every value to the serial card's scratch register ($9FE7) and read it back,
; from code in main RAM and from the same code copied into RAM bank 60 and bank 10.
; No modem/network needed. Shows whether a bank-RAM read of the card turns $FF into $00.
%import textio
%zeropage basicsafe

main {
    uword stub = memory("stub", 16, 0)
    ubyte[8] badw
    ubyte[8] badr
    ubyte nbadpairs

    ; sta $9fe7 / lda $9fe7 / rts
    ubyte[] code = [$8d, $e7, $9f, $ad, $e7, $9f, $60]

    asmsub run(ubyte v @A, uword addr @R0) -> ubyte @A {
        %asm {{
            jmp  (cx16.r0)
        }}
    }

    sub start() {
        txt.lowercase()
        txt.print("SCRTEST: scratch register $9fe7\n")
        ; is the card there?
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
        test(0)
        test(60)
        test(10)
        txt.print("done.\n")
    }

    sub test(ubyte where) {
        uword errs = 0
        uword ff_errs = 0
        nbadpairs = 0
        uword addr = stub
        if where != 0
            addr = $a000
        cx16.rambank(where)
        repeat 40 {
            ubyte v = 0
            repeat 256 {
                ubyte r = run(v, addr)
                if r != v {
                    errs++
                    if v == $ff
                        ff_errs++
                    note(v, r)
                }
                v++
            }
        }
        cx16.rambank(0)
        if where == 0
            txt.print("main ram: ")
        else {
            txt.print("bank ")
            txt.print_ub(where)
            txt.print(":   ")
        }
        txt.print_uw(errs)
        txt.print(" wrong of 10240, $ff wrong ")
        txt.print_uw(ff_errs)
        txt.print(" of 40\n")
        if nbadpairs != 0 {
            txt.print("   wrote->read:")
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
