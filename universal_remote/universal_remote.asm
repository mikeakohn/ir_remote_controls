;; universal_remote
;;
;; Copyright 2017 - By Michael Kohn
;; http://www.mikekohn.net/
;; mike@mikekohn.net
;;
;; Remote control configurable over UART.

.include "msp430x2xx.inc"

RAM equ 0x0200
DCO_INT_PER_SEC equ RAM+0
CPU_FREQ_LO equ RAM+2
CPU_FREQ_HI equ RAM+4
DCO_COUNT equ RAM+6
BAUD_DIV equ RAM+8
TIMER_DIV equ RAM+10
HEADER_ON equ RAM+12
HEADER_OFF equ RAM+14
ONE equ RAM+16
ZERO equ RAM+18
GAP_LENGTH equ RAM+20
SPACE equ RAM+22
BITS equ RAM+24

COMMAND equ RAM+32

;  r4 = data pointer
;  r5 = sent bit count
;  r6 = byte coming in from UART
;  r7 = pointer to data
;  r8 =
;  r9 = interrupt count
; r10 = interrupt toggle value
; r11 = interrupt bit count
; r12 = increments every 1 second with Timer B
; r13 = temp
; r14 = temp
; r15 = temp

; 4,000,000 / (38000 * 2) = 52.6
; 76.0kHz = 13.1 microseconds
;
.org 0xc000
start:
  ;; Turn off watchdog
  mov.w #(WDTPW|WDTHOLD), &WDTCTL

  ;; Turn off interrupts.
  dint

  ;; Set up stack pointer
  mov.w #0x0400, SP

  ;; Set up output pins
  ;; P1.0 = IR LED
  ;; P1.1 = RX
  ;; P1.2 = TX
  ;; P2.1 = Yellow LED
  ;; P1.2 = Green LED
  mov.b #0x01, &P1DIR
  mov.b #0x00, &P1OUT
  mov.b #0x06, &P1SEL
  mov.b #0x06, &P1SEL2
  mov.b #0x06, &P2DIR
  mov.b #0x06, &P2OUT

  ;; Set MCLK to 4 MHz with DCO
  mov.b #DCO_4, &DCOCTL
  mov.b #RSEL_11, &BCSCTL1
  mov.b #0, &BCSCTL2

  ;; Set SMCLK to 32.768kHz external crystal
  mov.b #XCAP_3, &BCSCTL3

  ;; Set up Timer A
  mov.w #512, &TACCR0
  mov.w #TASSEL_2|MC_1, &TACTL ; SMCLK, DIV1, COUNT to TACCR0
  mov.w #CCIE, &TACCTL0
  mov.w #0, &TACCTL1

  ;; Set up Timer B
  mov.w #32768, &TBCCR0  ; 32768 ticks = 1 second
  mov.w #TBSSEL_1|MC_1, &TBCTL ; ACLK, DIV1, COUNT to TBCCR0
  mov.w #CCIE, &TBCCTL0
  mov.w #0, &TBCCTL1

  ;; Enable interrupts.
  eint

  call #calibrate_baud_rate

  ;; Change interrupt count on Timer A
  mov.w &TIMER_DIV, &TACCR0

  ;; Disable Timer B
  mov.w #0, &TBCCTL0

  ;; Turn of LED's until stuff happens
  mov.b #0x00, &P2OUT

  ;; Setup UART
  mov.b #UCSSEL_2|UCSWRST, &UCA0CTL1
  mov.b #0, &UCA0CTL0
  mov.b &BAUD_DIV, &UCA0BR0
  mov.b &BAUD_DIV+1, &UCA0BR1
  bic.b #UCSWRST, &UCA0CTL1

  mov.b #0, r10

  ;; Default paramters
  mov.w #346, &HEADER_ON
  mov.w #346, &HEADER_OFF
  mov.w #125, &ONE
  mov.w #46, &ZERO
  mov.w #46, &SPACE
  mov.w #7547, &GAP_LENGTH
  mov.w #32, &BITS

  ;call #send_settings

main:
  bit.b #UCA0RXIFG, &IFG2
  jz main
  mov.b &UCA0RXBUF, r14
  mov.b r14, r15
  call #uart_send_char
  mov.b #'\r', r15
  call #uart_send_char
  mov.b #'\n', r15
  call #uart_send_char
  call #uart_read
  ;cmp.b #'p', r14
  ;jnz not_p
  ;call #send_settings
;not_p:
  jmp main

delay:
  mov.w #0xffff, r15
delay_loop:
  dec.w r15
  jnz delay_loop
  ret

.include "calibrate.inc"
.include "send_ir.inc"
.include "send_settings.inc"
.include "uart_read.inc"

// DCO based interrupt
timer_interrupt_a:
  xor.b r10, &P1OUT
  inc.w r9
  reti

;; 38.768kHz crystal interrupt
;; r12 increments every second
timer_interrupt_b:
  add.w #1, r12
  mov.w r9, &DCO_INT_PER_SEC
  mov.w #0, r9
  reti

.org 0xffe8
vectors:
.org 0xfff2
  dw timer_interrupt_a     ; Timer0_A3 TACCR0, CCIFG
.org 0xfffa
  dw timer_interrupt_b     ; Timer1_A3 TBCCR0, CCIFG
.org 0xfffe
  dw start                 ; Reset



