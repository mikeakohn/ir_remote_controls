;; universal_remote
;;
;; Copyright 2017 - By Michael Kohn
;; http://www.mikekohn.net/
;; mike@mikekohn.net
;;
;; Remote control configurable over UART.

send_command:
  ;; Turn on send debug LED.
  bis.b #0x02, &P2OUT

  mov.w #COMMAND, r7

  ;; Send header on.
  clr.w r9
  mov.b #1, r10
wait_header_on:
  cmp.w &HEADER_ON, r9
  jne wait_header_on
  mov.b #0, r10
  bic.b #1, &P1OUT

  ;; Send header off.
  clr.w r9
wait_header_off:
  cmp.w &HEADER_OFF, r9
  jne wait_header_off

  ;; for (r5 = 0; r5 < BITS; r5++)
  mov.w #0, r5
next_bit:

  bit.w #0x7, r5
  jnz dont_inc_pointer
  mov.b @r7, r4
  inc.w r7

dont_inc_pointer:

  ;; Turn bit on.
  clr.w r9
  mov.b #1, r10
wait_bit_on:
  cmp.w &DIVIDER, r9
  jne wait_bit_on
  mov.b #0, r10
  bic.b #1, &P1OUT

  ;; Compute length of bit.
  mov.w &ZERO, r11
  bit.w #0x80, r4
  jz is_zero
  mov.w &ONE, r11
is_zero:

  ;; Turn bit off
  clr.w r9
wait_bit_off:
  cmp.w r11, r9
  jne wait_bit_off

  ;; Shift bit and increment count and possibly command pointer.
  add.w r4, r4

  ;; Next.
  inc.w r5
  cmp.w &BITS, r5
  jnz next_bit

  ;; Send ptrail
  clr.w r9
  mov.b #1, r10
wait_ptrail:
  cmp.w &DIVIDER, r9
  jne wait_ptrail
  mov.b #0, r10
  bic.b #1, &P1OUT

  ;; Turn off send debug LED.
  bic.b #0x02, &P2OUT

  ;; Gap at end.
  clr.w r9
wait_gap:
  cmp.w &GAP_LENGTH, r9
  jne wait_gap

  ;; Done. Repeat.
  ret

