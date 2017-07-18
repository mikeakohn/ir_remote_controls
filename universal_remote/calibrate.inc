;; universal_remote
;;
;; Copyright 2017 - By Michael Kohn
;; http://www.mikekohn.net/
;; mike@mikekohn.net
;;
;; Remote control configurable over UART.

.list

calibrate_baud_rate:
  call #wait_for_sample

  ;; 2000 = 2 * 2 * 2 * 2 * 5 * 5 * 5
  ;; 512 = 2^9
  mov.w &DCO_INT_PER_SEC, r14
  ;; r15:r14 = 32 bit integer representing DCO_INT_PER_DEC * 512
  mov.w #0, r15
  mov.w #9, r13
mul_512:
  add.w r14, r14
  addc.w r15, r15
  dec r13
  jnz mul_512


  ;; r15:r14 now contains cpu frequency
  mov.w r14, &CPU_FREQ_LO
  mov.w r15, &CPU_FREQ_HI
  ;; Divide frequency by baud rate to get BAUD_DIV
  mov.w #9600, r4
  mov.w #0, r13
divide_baud:
  add.w #1, r13
  sub.w r4, r14
  subc.w #0, r15
  jn divide_baud_done
  jmp divide_baud
divide_baud_done:
  mov.w r13, &BAUD_DIV
  mov.w r13, &TIMER_DIV
  rra.w &TIMER_DIV
  rra.w &TIMER_DIV
  rra.w &TIMER_DIV
  ret

calibrate_ir:
  ret

wait_for_sample:
  mov #0, r12
wait_for_sample_loop:
  cmp #4, r12
  jne wait_for_sample_loop
  ret


