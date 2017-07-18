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

;  r4 = data pointer
;  r5 = sent bit count
;  r6 = byte coming in from UART
;  r7 =
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
; header = 9ms / 4.5ms  = 680 interrupts on / 340 off
; divider  = 0.56ms = 42 interrupts
; one      = 4.5ms = 340 interrupts
; zero     = 2.25ms = 170 interrupts

HEADER_ON equ 680
HEADER_OFF equ 340
DIVIDER equ 42
ONE equ 340
ZERO equ 170
GAP_LENGTH equ 7547
DELAY_30MS equ 2264
DELAY_500MS equ 38461

KEY_1 equ 0x800f
KEY_2 equ 0x4007
KEY_3 equ 0xc00b
KEY_4 equ 0x2003
KEY_5 equ 0xa00d
KEY_6 equ 0x6005
KEY_7 equ 0xe009
KEY_8 equ 0x1001
KEY_9 equ 0x900e
KEY_0 equ 0x0000

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
  mov.b #DCO_2, &DCOCTL
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

  mov.b #0, r10

main:
  jmp main


delay:
  mov.w #0xffff, r15
delay_loop:
  dec.w r15
  jnz delay_loop
  ret

.include "calibrate.inc"
.include "send_ir.inc"

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



