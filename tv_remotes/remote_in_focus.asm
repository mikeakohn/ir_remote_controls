;; remote_lg
;;
;; Copyright 2016 - By Michael Kohn
;; http://www.mikekohn.net/
;; mike@mikekohn.net
;;
;; Control an LG TV with msp430g2231 with a button or timer

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
; r11 = interrupt bit count
; r12 =
; r13 =
; r14 =
; r15 = temp in interrupt

; 4,000,000 / (38000 * 2) = 52.6
; 76.0kHz = 13.1 microseconds
;
; header = 9ms / 4.5ms  = 680 interrupts on / 340 off
; short  = 0.56ms = 42 interrupts
; long   = 1.69ms = 128 interrupts

HEADER_ON equ 680
HEADER_OFF equ 340
SHORT equ 42
LONG equ 128
GAP_LENGTH equ 9206

.org 0xf800
start:
  ;; Turn off watchdog
  mov.w #(WDTPW|WDTHOLD), &WDTCTL

  ;; Turn off interrupts.
  dint

  ;; Set up stack pointer
  mov.w #0x0280, SP

  ;; Set MCLK to 4 MHz with DCO 
  ;mov.b #DCO_4, &DCOCTL
  mov.b #DCO_2, &DCOCTL
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

  ;; Enable interrupts.
  eint

main:
  bit.b #0x40, &P1IN
  jnz main

  ;; Turn on button debug LED.
  bis.b #0x10, &P1OUT

  ;; Debounce.
wait_button:
  bit.b #0x40, &P1IN
  jz wait_button

  ;; Turn off button debug LED.
  bic.b #0x10, &P1OUT

  ;; Set command to power button.
  mov.w #0xe172, &COMMAND
  mov.w #0xe817, &COMMAND+2
  mov.w #0x0000, &COMMAND+4
  mov.w #COMMAND, r4

  call #send_command
  jmp main

send_command:
  ;; Turn on send debug LED.
  bis.b #0x20, &P1OUT

  ;; Send header on.
  clr.w r9
  mov.b #1, r10
wait_header_on:
  cmp.w #HEADER_ON, r9
  jne wait_header_on
  mov.b #0, r10
  bic.b #1, &P1OUT

  ;; Send header off.
  clr.w r9
wait_header_off:
  cmp.w #HEADER_OFF, r9
  jne wait_header_off

  ;; for (r5 = 0; r5 < 33; r5++)
  clr.w r5
next_bit:

  ;; Turn bit on.
  clr.w r9
  mov.b #1, r10
wait_bit_on:
  cmp.w #SHORT, r9
  jne wait_bit_on
  mov.b #0, r10
  bic.b #1, &P1OUT

  ;; Compute length of bit.
  mov.w #SHORT, r11
  bit.w #0x8000, 0(r4)
  jz is_short
  mov.w #LONG, r11
is_short:

  ;; Turn bit off
  clr.w r9
wait_bit_off:
  cmp.w r11, r9
  jne wait_bit_off

  ;; Shift bit and increment count and possibly command pointer.
  add.w @r4, 0(r4)
  inc.w r5
  bit.w #0xf, r5          ; if ((count & 0xf) == 0) { command_ptr += 2 }
  jne dont_inc_command_ptr
  add.w #2, r4
dont_inc_command_ptr:

  ;; Next.
  cmp #33, r5
  jnz next_bit

  ;; Turn off send debug LED.
  bic.b #0x20, &P1OUT

  ;; Gap at end.
  clr.w r9
wait_gap:
  cmp.w #GAP_LENGTH, r9
  jne wait_gap

  ;; Done.
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



