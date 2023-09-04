;; Listener
;;
;; Copyright 2016 - By Michael Kohn
;; https://www.mikekohn.net/
;; mike@mikekohn.net
;;
;; Using a TSOP388, listen for IR data and store in RAM so a debugger
;; can figure out the protocol.

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

; 50 / 1,000,000 = 50us
; 76.0kHz = 13.1 microseconds
;
; header = 4.5ms / 4.5ms  = 340 interrupts on / 340 off
; short  = 0.56ms = 42 interrupts
; long   = 1.69ms = 128 interrupts

HEADER_ON equ 340
HEADER_OFF equ 340
SHORT equ 42
LONG equ 128
GAP_LENGTH equ 12000

.org 0xf800
start:
  ;; Turn off watchdog
  mov.w #(WDTPW|WDTHOLD), &WDTCTL

  ;; Turn off interrupts.
  dint

  ;; Set up stack pointer
  mov.w #0x0280, SP

  ;; Set MCLK to 1 MHz with DCO 
  mov.b #DCO_3, &DCOCTL
  mov.b #RSEL_7, &BCSCTL1
  mov.b #0, &BCSCTL2

  ;; Set up output pins
  ;; P1.1 = IR Sensor
  mov.b #0x00, &P1DIR
  mov.b #0x00, &P1OUT
  ;mov.b #0x40, &P1REN

  ;; Set up Timer
  mov.w #50, &TACCR0
  mov.w #(TASSEL_2|MC_1), &TACTL ; SMCLK, DIV1, COUNT to TACCR0
  mov.w #CCIE, &TACCTL0
  mov.w #0, &TACCTL1

  mov.w #0x200, r12
memset:
  mov.w #0, @r12
  add.w #2, r12
  cmp.w #0x230, r12
  jnz memset

  ;; Enable interrupts.
  eint

main:
  bit.b #0x01, &P1IN
  jnz main

read_data:
  mov.w #0x200, r10

read_data_next:
  ;; Count how long the signal is on.
  mov.w #0, r9
read_data_wait_on:
  cmp.w #200, r9
  jeq main
  bit.b #0x01, &P1IN
  jz read_data_wait_on
  mov.w r9, @r10
  add.w #2, r10

  ;; Count how long the signal is off.
  mov.w #0, r9
read_data_wait_off:
  cmp.w #200, r9
  jeq main
  bit.b #0x01, &P1IN
  jnz read_data_wait_off
  mov.w r9, @r10
  add.w #2, r10

  jmp read_data_next

timer_interrupt:
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

