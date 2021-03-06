;; universal_remote
;;
;; Copyright 2017 - By Michael Kohn
;; http://www.mikekohn.net/
;; mike@mikekohn.net
;;
;; Remote control configurable over UART.

uart_read:
  cmp.b #'p', r14
  jnz not_p
  call #send_settings
  ret
not_p:

  cmp.b #'z', r14
  jnz not_zero
  call #read_data
  mov.w r15, &ZERO
  ret
not_zero:

  cmp.b #'o', r14
  jnz not_one
  call #read_data
  mov.w r15, &ONE
  ret
not_one:

  cmp.b #'s', r14
  jnz not_space
  call #read_data
  mov.w r15, &SPACE
  ret
not_space:

  cmp.b #'n', r14
  jnz not_header_on
  call #read_data
  mov.w r15, &HEADER_ON
  ret
not_header_on:

  cmp.b #'f', r14
  jnz not_header_off
  call #read_data
  mov.w r15, &HEADER_OFF
  ret
not_header_off:

  cmp.b #'g', r14
  jnz not_gap_length
  call #read_data
  mov.w r15, &GAP_LENGTH
  ret
not_gap_length:

  cmp.b #'b', r14
  jnz not_bits
  call #read_data
  mov.w r15, &BITS
  ret
not_bits:

  cmp.b #'c', r14
  jnz not_code
  call #read_code
  call #send_command
  ret
not_code:

  ret

read_data:
  mov.w #0, r15
read_data_next:
  bit.b #UCA0RXIFG, &IFG2
  jz read_data_next
  mov.b &UCA0RXBUF, r14
  mov.b r14, &UCA0TXBUF
  cmp.w #'\r', r14
  jeq read_data_done
  cmp.w #'\n', r14
  jeq read_data_done
  cmp.w #'0', r14
  jlo read_data_not_number
  cmp.w #('9'+1), r14
  jhs read_data_not_number
  sub.w #'0', r14
  rla.w r15
  rla.w r15
  rla.w r15
  rla.w r15
  bis.w r14, r15
  jmp read_data_next
read_data_not_number:
  cmp.w #'a', r14
  jlo read_data_not_hex
  cmp.w #'g', r14
  jhs read_data_not_hex
  sub.w #('a'-10), r14
  rla.w r15
  rla.w r15
  rla.w r15
  rla.w r15
  bis.w r14, r15
  jmp read_data_next
read_data_not_hex:
  jmp read_data_next
read_data_done:
  ret

read_code:
  mov.w #COMMAND, r13
  mov.w #0, r15
read_code_next:
  bit.b #UCA0RXIFG, &IFG2
  jz read_code_next
  mov.b &UCA0RXBUF, r14
  mov.b r14, &UCA0TXBUF
  cmp.w #'\r', r14
  jeq read_code_done
  cmp.w #'\n', r14
  jeq read_code_done
  cmp.w #'0', r14
  jlo read_code_not_number
  cmp.w #('9'+1), r14
  jhs read_code_not_number
  sub.w #'0', r14
  rla.b @r13
  rla.b @r13
  rla.b @r13
  rla.b @r13
  bis.b r14, @r13
  add.w #1, r15
  bit.w #1, r15
  jnz read_code_next
  add.w #1, r13
  jmp read_code_next
read_code_not_number:
  cmp.w #'a', r14
  jlo read_code_not_hex
  cmp.w #'g', r14
  jhs read_code_not_hex
  sub.w #('a'-10), r14
  rla.b @r13
  rla.b @r13
  rla.b @r13
  rla.b @r13
  bis.b r14, @r13
  add.w #1, r15
  bit.w #1, r15
  jnz read_code_next
  add.w #1, r13
  jmp read_code_next
read_code_not_hex:
  jmp read_code_next
read_code_done:
  ret

