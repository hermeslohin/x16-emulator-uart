# UART RBR read quirk: test programs

Two small Commander X16 programs for the quirk that `-uart-bankread-ff` emulates. They need only the
serial card at `$9FE0`: no modem, WiFi or server. The serial card is left in its normal state
afterwards.

Built with Prog8 12.3.5 (`prog8c -target cx16 scrtest.p8`). The `.PRG` files are those builds.
Load from the SD card or host FS: `LOAD "LOOPTEST.PRG"`, then `RUN`. Each takes a few seconds.

Each program runs the same few bytes of 6502 code three times: from main RAM, then a copy at `$A000`
in RAM bank 60, then a copy in bank 10. It prints how many values read back wrong, and up to 8
`written>read` pairs.

## SCRTEST.PRG: scratch register (`$9FE7`)

Writes every value `$00-$FF` to the scratch register 40 times and reads it back
(`sta $9fe7 / lda $9fe7 / rts`).

Expected everywhere, on the real X16 below and in x16emu with or without `-uart-bankread-ff`:

```
SCRTEST: scratch register $9fe7
main ram: 0 wrong of 10240, $ff wrong 0 of 40
bank 60:   0 wrong of 10240, $ff wrong 0 of 40
bank 10:   0 wrong of 10240, $ff wrong 0 of 40
done.
```

## LOOPTEST.PRG: received data (RBR `$9FE0`) in internal loopback

Sets 115200 8N1 with the FIFOs on, then turns on loopback (`MCR=$13`), so each byte written to THR
goes straight into the receive FIFO. It sends every value 40 times. After each byte it runs the
wait-and-read code (poll LSR bit 0, then `lda $9fe0`) from main RAM, bank 60 and bank 10. At the end
it sets `MCR=$23`.

**Real X16** (ROM R49, 2 MB, TexElec serial/ESP32 card), photo 2026-11-25:

```
LOOPTEST: tl16c2550 internal loopback
main ram: 0 wrong, $ff wrong 0 of 40, timeouts 0
bank 60:   57 wrong, $ff wrong 40 of 40, timeouts 0
   sent>read: ff>00 7f>00
bank 10:   59 wrong, $ff wrong 40 of 40, timeouts 0
   sent>read: 7f>00 ff>00
done.
```

`$FF` reads as `$00` every time, and `$7F` reads as `$00` about half the time, but only when the read
instruction runs from banked RAM. Every other value is read correctly. `$FE`, for example, is fine.

**x16emu without the switch**, run with `-uart1 ximodem` or any `-uart1` target so the UART exists:
every line shows `0 wrong`.

**x16emu with `-uart-bankread-ff`:**

```
main ram: 0 wrong, $ff wrong 0 of 40, timeouts 0
bank 60:   60 wrong, $ff wrong 40 of 40, timeouts 0
   sent>read: 7f>00 ff>00
bank 10:   60 wrong, $ff wrong 40 of 40, timeouts 0
   sent>read: 7f>00 ff>00
```

A non-zero `timeouts` count means the loopback didn't deliver a byte. That would point to a different
problem.
