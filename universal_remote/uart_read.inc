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
not_p:
  cmp.b #'z', r14
  jnz not_zero
  call #read_data
  mov.w r15, &ZERO
not_zero:
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

