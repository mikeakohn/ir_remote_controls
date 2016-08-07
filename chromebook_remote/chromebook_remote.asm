;; Samsung Chromebook Remote
;;
;; Copyright 2013 - By Michael Kohn
;; http://www.mikekohn.net/
;; mike@mikekohn.net
;;
;; Control a Samsung TV through rs232 connected to a Google Chromebook

.include "msp430x2xx.inc"

RAM equ 0x0200
QUEUE equ RAM
DATA equ RAM+32

;  r4 = data pointer
;  r5 = sent bit count
;  r6 = byte coming in from UART
;  r7 = head of queue
;  r8 = tail of queue
;  r9 = interrupt count
; r10 = interrupt routine
; r11 = interrupt count peak (bit length)
; r12 =
; r13 =
; r14 =
; r15 = temp in interrupt

; 16,000,000 / (39.2 *2 ) = 204.08
; 78.4kHz = 13.3 microseconds
;
; header = 4.5ms / 4.5ms  = 352 interrupts on / 352 off
; short  = 0.56ms = 44 cycles
; long   = 1.69ms = 132 cycles

  .org 0xc000
start:
  ;; Turn off watchdog
  mov.w #(WDTPW|WDTHOLD), &WDTCTL

  ;; Please don't interrupt me
  dint

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
  ;; P1.1 = RX
  ;; P1.2 = TX
  mov.b #0x00, &P1DIR
  mov.b #0x00, &P1OUT
  mov.b #0x06, &P1SEL
  mov.b #0x06, &P1SEL2
  mov.b #0x01, &P2DIR
  mov.b #0x00, &P2OUT
  mov.b #0x00, &P2SEL

  ;; Set up Timer
  mov.w #204, &TACCR0  ; 16,000,000 / (39.2 *2 ) = 204.08
  mov.w #(TASSEL_2|MC_1), &TACTL ; SMCLK, DIV1, COUNT to TACCR0
  mov.w #CCIE, &TACCTL0
  mov.w #0, &TACCTL1

  ;; Setup UART
  mov.b #UCSSEL_2|UCSWRST, &UCA0CTL1
  mov.b #0, &UCA0CTL0
  mov.b #0x82, &UCA0BR0
  mov.b #0x06, &UCA0BR1
  ;mov.b #0xf8, &UCA0BR0
  ;mov.b #0x05, &UCA0BR1
  bic.b #UCSWRST, &UCA0CTL1

  ;; Point queue head and tail to the start of the queue
  mov.w #QUEUE, r7
  mov.w r7,r8

  ;; Set up interrupts
  mov.w #idle_interrupt, r10

  ;; DEBUG
  mov.b #'A', &DATA
  mov.b #'B', &DATA+1

  ;; Okay, I can be interrupted now
  eint

  ; DEBUG
  ; mov.b #'A', &UCA0TXBUF

main:
  bit.b #UCA0RXIFG, &IFG2
  jz main

  mov.b &UCA0RXBUF, 0(r8)
  inc.w r8
  cmp.w #QUEUE+16, r8
  jne main
  mov.w #QUEUE, r8
  jmp main

timer_interrupt:
  br r10

idle_interrupt:
  cmp.w r7, r8
  jeq exit_interrupt
  mov.b @r7, r15
  cmp.b #'-', r15 
  jne not_dash
  mov.w #0xc43b, &DATA+2
  jmp change_interrupt
not_dash:
  cmp.w #'0', r15 
  jl skip_queue
  cmp.w #'9'+1, r15 
  jge skip_queue
  sub.b #'0', r15
  rla.w r15
  add.w #numbers_table, r15
  mov.w @r15, &DATA+2
change_interrupt:
  mov #start_send, r10
  mov.w #0xe0e0, &DATA
  mov.w #0x0000, &DATA+4
  mov.w #DATA, r4    ; data_ptr = DATA
  clr.w r5           ; count=0
skip_queue:
  inc.w r7
  cmp.w #QUEUE+16, r7 ; if head > QUEUE+16, head = QUEUE
  jne exit_interrupt
  mov.w #QUEUE, r7
  reti


start_send:
  mov #send_header_on, r10
  clr.w r9
  reti

send_header_on:
  inc.w r9
  xor.b #1, &P2OUT
  cmp.w #352, r9
  jne exit_interrupt
  mov.w #send_header_off, r10
  clr.w r9
  bic.b #1, &P2OUT
  reti

send_header_off:
  inc.w r9
  cmp.w #352, r9
  jne exit_interrupt
  mov.w #send_bit_on, r10
  mov.w #44, r11
  clr.w r9
  reti

send_bit_on:
  inc.w r9
  xor.b #1, &P2OUT
  cmp.w r11, r9
  jne exit_interrupt
  bic.b #1, &P2OUT
  mov.w #send_bit_off, r10
  clr.w r9
  mov.w #44, r11
  bit.w #0x8000, 0(r4)
  jz exit_interrupt
  mov.w #132, r11
  reti 

send_bit_off:
  inc.w r9
  cmp r11, r9
  jne exit_interrupt
  mov.w #send_bit_on, r10
  clr.w r9
  add.w @r4, 0(r4)               ; shift out last bit
  mov.w #44, r11
  inc.w r5                ; count++
  cmp.w #33, r5           ; if (count==33) finish_sending
  jeq finish_send
  bit.w #0xf, r5          ; if ((count&0xf)==0) data_ptr+=2
  jne exit_interrupt
  add.w #2, r4
  reti 
finish_send:
  mov.w #pause_interrupt, r10
  reti

;; Not sure if this is needed...
pause_interrupt:
  inc.w r9
  cmp #12000, r9   ; recovery time
  jne exit_interrupt
  mov.w #idle_interrupt, r10
  reti 

exit_interrupt:
  reti 

numbers_table:
  dw 0x8877, 0x20df, 0xa05f, 0x609f, 0x10ef
  dw 0x906f, 0x50af, 0x30cf, 0xb04f, 0x708f

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



