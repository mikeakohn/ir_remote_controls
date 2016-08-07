;; syma_joystick
;;
;; Copyright 2012 - By Michael Kohn
;; http://www.mikekohn.net/
;; mike@mikekohn.net
;;
;; Read in Syma S107 IR controller info and pass it off to a computer
;; over rs232 so a joystick driver can use the data.

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

;  r4 = state (0=idle, 1=header_on, 2=header_off, 3=first half, 4=second)
;  r5 = interupt count
;  r6 = pointer to next byte coming in 
;  r7 = current byte
;  r8 = bit count
;  r9 = bit time len
; r10 =
; r11 =
; r12 =
; r13 = interrupt routine
; r14 =
; r15 =

  .org 0xc000
start:
  ;; Turn off watchdog
  mov.w #(WDTPW|WDTHOLD), &WDTCTL

  ;; Please don't interrupt me
  dint

  ;; r13 points to which interrupt routine should be called
  ;mov.w #led_off, r13

  ;; Set up stack pointer
  mov.w #0x0400, SP

  ;; Set MCLK to 16 MHz with DCO 
  mov.b #DCO_4, &DCOCTL
  mov.b #RSEL_15, &BCSCTL1
  mov.b #0, &BCSCTL2

.if 0
  ;; Set MCLK to 16 MHz external crystal
  bic.w #OSCOFF, SR
  bis.b #XTS, &BCSCTL1
  mov.b #LFXT1S_3, &BCSCTL3
  ;mov.b #LFXT1S_3|XCAP_1, &BCSCTL3
test_osc:
  bic.b #OFIFG, &IFG1
  mov.w #0x00ff, r15
dec_again:
  dec r15
  jnz dec_again
  bit.b #(OFIFG), &IFG1
  jnz test_osc
  mov.b #(SELM_3|SELS), &BCSCTL2
.endif

  ;; Set up output pins
  ;; P1.1 = IR Input
  mov.b #0, &P1DIR
  mov.b #0, &P1OUT
  mov.b #6, &P1SEL
  mov.b #6, &P1SEL2

  ;; Setup UART
  mov.b #UCSSEL_2|UCSWRST, &UCA0CTL1
  mov.b #0, &UCA0CTL0
  ;mov.b #0x8a, &UCA0BR0
  ;mov.b #0x00, &UCA0BR1
  mov.b #0x20, &UCA0BR0
  mov.b #0x06, &UCA0BR1
  bic.b #UCSWRST, &UCA0CTL1

  ;; Set up Timer
  mov.w #210, &TACCR0
  mov.w #(TASSEL_2|MC_1), &TACTL ; SMCLK, DIV1, COUNT to TACCR0
  mov.w #CCIE, &TACCTL0
  mov.w #0, &TACCTL1

  mov.b #1, &RAM    ; Yaw
  mov.b #1, &RAM+1  ; Pitch
  mov.b #1, &RAM+2  ; Throttle
  mov.b #1, &RAM+3  ; Yaw correction

  ;; Okay, I can be interrupted now
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
  ;;mov.w #RAM+16, r9
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

  ;mov.w r5, @r9
  ;add.w #2, r9

  ;; check there is no IR
  mov.w #0, r5
wait_ir_off:
  cmp.w #100, r5
  jhs main                ; pause is wayyyy too long, bail out
  bit.b #0x01, &P1IN
  jnz wait_ir_off         ; wait for data on IR sensor

  ;mov.w r5, @r9
  ;add.w #2, r9

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

  ;; We have a command now, send over UART
  mov.b #0xff, &UCA0TXBUF
wait_ff_tx:
  bit.b #UCA0TXIFG, &IFG2
  jz wait_ff_tx
  mov.w #RAM, r6
next_byte:
  ;mov.b #0x55, &UCA0TXBUF
  mov.b @r6+, &UCA0TXBUF
wait_tx:
  bit.b #UCA0TXIFG, &IFG2
  jz wait_tx
  cmp #RAM+4, r6
  jne next_byte
  jmp main

timer_interrupt:
  inc.w r5
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



