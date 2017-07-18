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

  ;; Send header on.
  call #send_header_on

  ;; Send header off.
  clr.w r9
wait_header_off:
  cmp.w #HEADER_OFF, r9
  jne wait_header_off

  ;; for (r5 = 0; r5 < 33; r5++)
  mov.w #16, r5
next_bit:

  ;; Turn bit on.
  clr.w r9
  mov.b #1, r10
wait_bit_on:
  cmp.w #DIVIDER, r9
  jne wait_bit_on
  mov.b #0, r10
  bic.b #1, &P1OUT

  ;; Compute length of bit.
  mov.w #ZERO, r11
  bit.w #0x8000, r4
  jz is_zero
  mov.w #ONE, r11
is_zero:

  ;; Turn bit off
  clr.w r9
wait_bit_off:
  cmp.w r11, r9
  jne wait_bit_off

  ;; Shift bit and increment count and possibly command pointer.
  add.w r4, r4

  ;; Next.
  dec.w r5
  jnz next_bit

  ;; Send ptrail
  call #send_ptrail

  ;; Wait 30ms and send half header and ptrail
  call #wait_30ms
  call #send_header_on
  call #wait_2_25ms
  call #send_ptrail

  ;; Wait 90ms and send half header and ptrail
  call #wait_30ms
  call #wait_30ms
  call #wait_30ms
  call #send_header_on
  call #wait_2_25ms
  call #send_ptrail

  ;; Turn off send debug LED.
  bic.b #0x02, &P2OUT

  ;; Gap at end.
  clr.w r9
wait_gap:
  cmp.w #GAP_LENGTH, r9
  jne wait_gap

  ;; Done. Repeat.
  ret

send_header_on:
  clr.w r9
  mov.b #1, r10
wait_header_on:
  cmp.w #HEADER_ON, r9
  jne wait_header_on
  mov.b #0, r10
  bic.b #1, &P1OUT
  ret

send_ptrail:
  clr.w r9
  mov.b #1, r10
wait_ptrail:
  cmp.w #DIVIDER, r9
  jne wait_ptrail
  mov.b #0, r10
  bic.b #1, &P1OUT
  ret

wait_30ms:
  clr.w r9
wait_30ms_loop:
  cmp.w #DELAY_30MS, r9
  jne wait_30ms_loop
  ret

wait_500ms:
  clr.w r9
wait_500ms_loop:
  cmp.w #DELAY_500MS, r9
  jne wait_500ms_loop
  ret

wait_2_25ms:
  clr.w r9
wait_2_25ms_loop:
  cmp.w #ZERO, r9
  jne wait_2_25ms_loop
  ret

