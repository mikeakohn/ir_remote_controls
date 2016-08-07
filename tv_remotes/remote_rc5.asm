;; remote_samsung
;;
;; Copyright 2016 - By Michael Kohn
;; http://www.mikekohn.net/
;; mike@mikekohn.net
;;
;; Control an RC5 LG TV with msp430g2231 with a button or timer

.include "msp430x2xx.inc"

RAM equ 0x0200
COMMAND equ RAM

;  r4 = data pointer
;  r5 = sent bit count
;  r6 = byte coming in from UART
;  r7 =
;  r8 =
;  r9 = interrupt count
; r10 = interrupt toggle value
; r11 = temp for bit calculation
; r12 =
; r13 =
; r14 =
; r15 =

; 4,000,000 / (38000 * 2) = 52.6
; 4,000,000 / (36000 * 2) = 55.5
; 76.0kHz = 13.1 microseconds
;
;  one = 0.889ms off, 0.889ms on
; zero = 0.889ms on,  0.889ms off
;

PULSE_LEN equ 67
;PULSE_LEN equ 65
GAP_LENGTH equ 5481

.org 0xf800
start:
  ;; Turn off watchdog
  mov.w #(WDTPW|WDTHOLD), &WDTCTL

  ;; Turn off interrupts.
  dint

  ;; Set up stack pointer
  mov.w #0x0280, SP

  ;; Set MCLK to 4 MHz with DCO 
  mov.b #DCO_4, &DCOCTL
  mov.b #RSEL_11, &BCSCTL1
  mov.b #0, &BCSCTL2

  ;; Set up output pins
  ;; P1.1 = IR LED
  ;; P1.4 = Yellow LED
  ;; P1.5 = Red LED
  ;; P1.6 = Button Input
  mov.b #0x31, &P1DIR
  mov.b #0x40, &P1OUT
  mov.b #0x40, &P1REN

  ;; Set up Timer
  mov.w #52, &TACCR0
  mov.w #(TASSEL_2|MC_1), &TACTL ; SMCLK, DIV1, COUNT to TACCR0
  mov.w #CCIE, &TACCTL0
  mov.w #0, &TACCTL1

  mov.b #0, r10

  ;; Not really needed
  ;mov.w #0x0000, &COMMAND+2
  ;mov.w #0x0000, &COMMAND+4

  ;; Enable interrupts.
  eint

main:
  bit.b #0x40, &P1IN
  jnz main

  ;; Turn on debug LED.
  bis.b #0x10, &P1OUT

  ;; Debounce.
wait_button:
  bit.b #0x40, &P1IN
  jz wait_button

  ;; Switch DEBUG LEDs.
  bic.b #0x10, &P1OUT
  bis.b #0x20, &P1OUT

  ;; Set command to power button.
  ;; LIRC has 0x100c and a plead of 0.889ms and toggle mask of 0x800 (or bit 2)
  ;; which fits RC5 protocol
  ;; 1                   <-- plead
  ;;   1 0000 0000 1100  <-- command (which includes 1/2 of start and toggle)
  ;;   0 1000 0000 0000  <-- toggle mask
  ;; leaves 11 bits of data, 2 bits start, and 1 bit of toggle
  mov.w #((0x100c | 0x2000) << 2), &COMMAND
  mov.w #COMMAND, r4
  call #send_command

  mov.w #((0x100c | 0x2800) << 2), &COMMAND
  mov.w #COMMAND, r4
  call #send_command

  ;; Turn off DEBUG LED.
  bic.b #0x20, &P1OUT

  jmp main

send_command:
  ;; for (r5 = 0; r5 < 16; r5++)
  clr.w r5
next_bit:

  ;; Compute if bit is 1 or 0.
  mov.w @r4, r11
  rlc.w r11
  rlc.w r11
  and.w #0x0001, r11
  xor.b #1, r11
  mov.b r11, r10

  ;; First half of bit.
  clr.w r9
wait_first_half:
  cmp.w #PULSE_LEN, r9
  jne wait_first_half

  ;; Reverse LED pulse value.
  xor.b #1, r10
  bic.b #1, &P1OUT

  ;; Second half of bit.
  clr.w r9
wait_second_half:
  cmp.w #PULSE_LEN, r9
  jne wait_second_half

  ;; Turn LED off.
  mov.b #0, r10
  bic.b #1, &P1OUT

  ;; Shift bit and increment count and possibly command pointer.
  add.w @r4, 0(r4)
  inc.w r5
  ;bit.w #0xf, r5          ; if ((count & 0xf) == 0) { command_ptr += 2 }
  ;jne dont_inc_command_ptr
  ;add.w #2, r4
;dont_inc_command_ptr:

  ;; Next.
  cmp.w #14, r5
  jnz next_bit

  ;; Gap at end.
  clr.w r9
wait_gap:
  cmp.w #GAP_LENGTH, r9
  jne wait_gap

  ;; Done. Return.
  ret 

timer_interrupt:
  xor.b r10, &P1OUT
  inc.w r9
  reti

  org 0xffe8
vectors:
  dw 0
  dw 0
  dw 0
  dw 0
  dw 0
  dw timer_interrupt       ; Timer_A2 TACCR0, CCIFG
  dw 0
  dw 0
  dw 0
  dw 0
  dw 0
  dw start                 ; Reset



