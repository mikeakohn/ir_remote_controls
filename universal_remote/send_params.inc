;; universal_remote
;;
;; Copyright 2017 - By Michael Kohn
;; http://www.mikekohn.net/
;; mike@mikekohn.net
;;
;; Remote control configurable over UART.

send_params:
  ;; Turn on send debug LED.
  bis.b #0x04, &P2OUT

  mov.w #open_json, r15
  call #send_string

  mov.w #header_on_const, r15
  mov.w &HEADER_ON, r14
  call #send_single_param

  mov.w #header_off_const, r15
  mov.w &HEADER_OFF, r14
  call #send_single_param

  mov.w #one_const, r15
  mov.w &ONE, r14
  call #send_single_param

  mov.w #zero_const, r15
  mov.w &ZERO, r14
  call #send_single_param

  mov.w #gap_length_const, r15
  mov.w &GAP_LENGTH, r14
  call #send_single_param

  mov.w #divider_const, r15
  mov.w &DIVIDER, r14
  call #send_single_param

  mov.w #close_json, r15
  call #send_string

  ;; Turn off send debug LED.
  bic.b #0x04, &P2OUT
  ret

send_single_param:
  call #send_string
  mov.w r14, r15
  mov.w r14, r13
  swpb r15
  call #send_hex
  mov.w r13, r15
  call #send_hex
  mov.w #eol_const, r15
  call #send_string
  ret

send_string:
  cmp.b #0, 0(r15)
  jz send_string_exit
send_string_wait_tx:
  bit.b #UCA0TXIFG, &IFG2
  jz send_string_wait_tx
  mov.b @r15+, &UCA0TXBUF
  ;add #1, r15
  jmp send_string
send_string_exit:
  call #delay
  ret

send_hex:
  mov.b r15, r14
  and.b #0x0f, r14
  rrc.b r15
  rrc.b r15
  rrc.b r15
  rrc.b r15
  and.b #0x0f, r15
  add.w #hex_table, r15
  add.w #hex_table, r14
send_hex_wait_tx1:
  bit.b #UCA0TXIFG, &IFG2
  jz send_hex_wait_tx1
  mov.b @r15, &UCA0TXBUF
send_hex_wait_tx2:
  bit.b #UCA0TXIFG, &IFG2
  jz send_hex_wait_tx2
  mov.b @r14, &UCA0TXBUF
  ret

.align 16
hex_table:
.db "0123456789abcdef"

.align 16
open_json:
.asciiz "{\r\n"

.align 16
header_on_const:
.asciiz "  'header_on': 0x"

.align 16
header_off_const:
.asciiz "  'header_off': 0x"

.align 16
one_const:
.asciiz "  'one': 0x"

.align 16
zero_const:
.asciiz "  'zero': 0x"

.align 16
gap_length_const:
.asciiz "  'gap_length': 0x"

.align 16
divider_const:
.asciiz "  'divider': 0x"

.align 16
eol_const:
.asciiz ",\r\n"

.align 16
close_json:
.asciiz "}\r\n"

.align 16

