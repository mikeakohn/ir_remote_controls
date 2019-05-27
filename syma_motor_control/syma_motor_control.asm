;; Syma Motor Control
;;
;; Copyright 2016-2019 - By Michael Kohn
;; http://www.mikekohn.net/
;; mike@mikekohn.net
;;
;; Read in Syma S107 IR controller data to control two motors.
;; pushing forward at a certain speed will cause the motors to spin
;; faster.  Turning left / right will slow down one of the motors.

.include "msp430x2xx.inc"

; 2.0 ms = 152 interrupts
; 0.3 ms = 23 interrupts
; 0.6 ms = 46 interrupts

; 500ms = 38000 interrupts

; HH YAW PTCH THROTTLE YAW_CORRECT
; YAW = 0-126  63
; PITCH = 0-126 63
; THROTTLE = 0-126
; CORR = 0-126 63

RAM equ 0x0200
HEADER equ 152
SHORT equ 23
LONG equ 46

YAW equ RAM
PITCH equ RAM+1
THROTTLE equ RAM+2
YAW_CORRECTION equ RAM+3

INTERRUPT_MAX equ 5000
WATCHDOG_RESET equ 20000
WATCHDOG equ RAM+16

;  r4 = state (0=idle, 1=header_on, 2=header_off, 3=first half, 4=second)
;  r5 = interupt count
;  r6 = pointer to next byte coming in
;  r7 = current byte
;  r8 = bit count
;  r9 = temp in main
; r10 = motor interrupt new count left
; r11 = motor interrupt new count right
; r12 = motor interrupt current count left
; r13 = motor interrupt current count right
; r14 = interrupt count
; r15 = P1OUT reset value

  .org 0xf800
start:
  ;; Turn off watchdog
  mov.w #(WDTPW|WDTHOLD), &WDTCTL

  ;; Turn off interrupts
  dint

  ;; Set up stack pointer
  mov.w #0x0280, SP

  ;; Set MCLK to 8 MHz with DCO
  mov.b #DCO_5, &DCOCTL
  mov.b #RSEL_13, &BCSCTL1
  mov.b #0, &BCSCTL2

  ;; Set up output pins
  ;; P1.1 = IR Input
  ;; P1.5 = Motor Left
  ;; P1.6 = Motor Right
  ;; P2.6 = Debug LED
  mov.b #0x60, &P1DIR
  mov.b #0x00, &P1OUT
  mov.b #0x40, &P2DIR
  mov.b #0x00, &P2OUT
  mov.b #0x00, &P2SEL

  ;; Set up Timer
  mov.w #105, &TACCR0
  mov.w #(TASSEL_2|MC_1), &TACTL ; SMCLK, DIV1, COUNT to TACCR0
  mov.w #CCIE, &TACCTL0
  mov.w #0, &TACCTL1

  mov.b #1, &YAW
  mov.b #1, &PITCH
  mov.b #1, &THROTTLE
  mov.b #1, &YAW_CORRECTION

  mov.w #0, r10
  mov.w #0, r11
  mov.w #0, r12
  mov.w #0, r13
  mov.w #0, r14
  mov.w #0, r15

  ;; Enable interrupts
  eint

main:
  bit.b #0x01, &P1IN
  jeq read_command
  jmp main

read_command:
  mov.w #0, r5
wait_low:
  bit.b #0x01, &P1IN
  jz wait_low

  ;; if r5 is less than 100, something went wrong.  Not sure how important
  ;; this check really is
  cmp.w #100, r5
  jlo main

  ;; Debug LED On
  bis.b #0x40, &P2OUT

  ;; Reset watchdog
  mov.w #WATCHDOG_RESET, &WATCHDOG

start_signal:

  ;; signal should be low, should we count?
  ;; check there is no IR
  mov.w #0, r5
wait_ir_off_header:
  cmp.w #200, r5
  jhs main                ; pause is wayyyy too long, bail out
  bit.b #0x01, &P1IN
  jnz wait_ir_off_header  ; wait for data on IR sensor

  mov.w #RAM, r6
receive_next_byte:
  mov.b #0, r7            ; shouldn't be needed
  mov.b #8, r8
receive_next_bit:

  ;; check IR signal is on
  mov.w #0, r5
wait_ir_on:
  cmp.w #120, r5
  jhs start_signal        ; looks like the start signal
  cmp.w #70, r5
  jhs main                ; signal is wayyyy too long, bail out
  bit.b #0x01, &P1IN
  jz wait_ir_on           ; wait for data on IR sensor

  ;; check there is no IR
  mov.w #0, r5
wait_ir_off:
  cmp.w #100, r5
  jhs main                ; pause is wayyyy too long, bail out
  bit.b #0x01, &P1IN
  jnz wait_ir_off         ; wait for data on IR sensor

  rla.b r7
  cmp #SHORT+12, r5
  jlo not_a_zero
  bis.b #1, r7

not_a_zero:
  dec.b r8
  jnz receive_next_bit

  mov.b r7, 0(r6)
  inc r6

  cmp.w #RAM+4, r6
  jne receive_next_byte

  ;; Set both motors to the throttle speed (divided by 8)
  ;; value should be somewhere between 0 and 15
  mov.b &THROTTLE, r7
  bic.w #0xff80, r7
  rra.w r7
  rra.w r7
  rra.w r7
  mov.w r7, r8

  mov.b &YAW, r9

  cmp.w #90, r9
  jl dont_turn_right
  mov.w #0, r7
  jmp set_interrupt_count

dont_turn_right:
  cmp.w #30, r9
  jge set_interrupt_count
  mov.w #0, r8

set_interrupt_count:
  ; Lookup left motor interrupt count
  rla.w r7
  mov.w speed(r7), r10

  ; Lookup right motor interrupt count
  rla.w r8
  mov.w speed(r8), r11

  mov.w #0, r9

  ; If left motor isn't 0, turn on motor
  cmp.w #0, r10
  jz leave_left_motor_off
  bis.b #0x20, r9
leave_left_motor_off:

  ; If right motor isn't 0, turn on motor
  cmp.w #0, r11
  jz leave_right_motor_off
  bis.b #0x40, r9
leave_right_motor_off:

  mov.b r9, r15

  ;; Debug LED On
  bic.b #0x40, &P2OUT

  jmp main

calibrate:
  mov.w #0, r5
calibrate_wait_1:
  cmp.w #762, r5
  jnz calibrate_wait_1
  bis.b #0x40, &P2OUT

  mov.w #0, r5
calibrate_wait_2:
  cmp.w #762, r5
  jnz calibrate_wait_2
  bic.b #0x40, &P2OUT
  ret

timer_interrupt:
  inc.w r5

  dec.w &WATCHDOG
  jnz watchdog_okay
  mov.w #0, r10
  mov.w #0, r11
  mov.w #0, r15
watchdog_okay:

  ; Increment interrupt count
  inc.w r14
  cmp.w #INTERRUPT_MAX, r14
  jnz dont_reset_motors

  ; Reset motors to 0
  mov.w #0, r14
  mov.w r10, r12
  mov.w r11, r13
  mov.b r15, &P1OUT

dont_reset_motors:
  cmp.w r12, r14
  jnz ignore_left_motor
  bic.b #0x20, &P1OUT
ignore_left_motor:

  cmp.w r13, r14
  jnz ignore_right_motor
  bic.b #0x40, &P1OUT
ignore_right_motor:

  reti

speed:
  dw     0,   300,   400,   500
  dw  1000,  1500,  2000,  2500
  dw  3000,  3500,  4000,  4500
  dw  5000,  5000,  5000,  5000

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



