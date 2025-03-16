; <<PAS Throttle Cruise>>
;
; (C) 2025 S.D.Smith all rights reserved
;
; Simply counts the rotation movement on the pedal crank
; and sends it to QML via AppCustomData, only sends to QML when it's changed
;
;
; Tested on a BBSHD
; BBSHD pedal sensor seems to have 24 magnets
; This code uses 4x encoder counting, which gives us 96 distinct positions on the crank pedal

; SDS - You may need to swap H1 and H2 tx,rx reads to get the correct orientation - depending how youv'e wired
; up the PAS sensor

; Encoder states:
; Forwards:
; 0 1   2
; 0 0   0
; 1 0   1
; 1 1   3

; Backwards:
; 0 0    0
; 0 1    2
; 1 1    3
; 1 0    1

; SDS - 'pin-mode-in-pd didn't work at all (gpio pull-down)
; so using 'pin-mode-in-pu which does work (gpio pull-up).
; no idea which way it should actually be!

(def EncMat[ 1 1 1 1 -1 -1 -1 -1])

(bufget-i8 EncMat 0)

(gpio-configure 'pin-tx 'pin-mode-in-pu)
(gpio-configure 'pin-rx 'pin-mode-in-pu)

(def pasPedalCount 0)
(def pasPedalRPM 0)

; Previous Hall sensors 1&2
(def prevH1 (gpio-read 'pin-tx))
(def prevH2 (gpio-read 'pin-rx))
(def sendRate 100) ; SDS - QML data send rate in ms = 60hz
(def sendCount sendRate)
; SDS - Should really use pin interrupts for this - no idea how to set that up in lisp - or if it's possible
; so we run as fast as possible so as to not miss any events
(loopwhile t
{
    ; Read the Hall sensors
    (def h1 (gpio-read 'pin-tx))
    (def h2 (gpio-read 'pin-rx))
    ; if H1 or H2 are different from the previous reading - pasSensor has moved
    (if (or (not ( = prevH1 h1)) (not ( = prevH2 h2)) )
    {
    ; Calc h1+h2*2 index number
    (def cur (+ h1 (* h2 2)) )
    (def prev (+ prevH1 (* prevH2 2)) )

    (setq prevH1 h1)
    (setq prevH2 h2)
    ; SDS - this is some ugly shit - cmon better algo for this shit!
    ; Forwards
    (def pCPC pasPedalCount)
    ; 2 4 8 9
    (if (and (= prev 2) (= cur 0)) (setq pasPedalCount (+ pasPedalCount 1))    )
    (if (and (= prev 0) (= cur 1)) (setq pasPedalCount (+ pasPedalCount 1))    )
    (if (and (= prev 1) (= cur 3)) (setq pasPedalCount (+ pasPedalCount 1))    )
    (if (and (= prev 3) (= cur 2)) (setq pasPedalCount (+ pasPedalCount 1))    )
    ; Backwards
    ; 6 1 7 9
    (if (and (= prev 0) (= cur 2)) (setq pasPedalCount (- pasPedalCount 1))    )
    (if (and (= prev 1) (= cur 0)) (setq pasPedalCount (- pasPedalCount 1))    )
    (if (and (= prev 3) (= cur 1)) (setq pasPedalCount (- pasPedalCount 1))    )
    (if (and (= prev 2) (= cur 3)) (setq pasPedalCount (- pasPedalCount 1))    )
    (setq pasPedalRPM (+ pasPedalRPM (- pasPedalCount pCPC)))
    }
    )
; SDS - no shift in lisp so / and mod!


    ; SDS - Send data to QML at a fixed rate sendRate (currently 10hz)
    (setq sendCount (- sendCount 1))
    (if (< sendCount 0)
        {
        (setq sendCount sendRate)
        ; brake switch should be
        ; my brakes are simple 2 wire switches
        ; so adc
        ; 3.3v -> 10k ohm resistor -> adc pin
        ; adc pin -> switch->ground


        ; temp pdeal count
        (def temppc (+ pasPedalCount 8388608))
        ; send the pedal count in 3 bytes offset with 8388608 (256*256*256/2) to handle negatives
        ; send the pedal rpm offset with 128 to handle negatives
        (send-data (list (+ (* pasPedalRPM 10) 128) (mod temppc 256) (mod (/ temppc 256) 256) (mod (/ temppc 65536) 256) ));
        }
    )
    ; SDS - leaky integrate the pasRPM
    ; no NAN checking needed - LispBM and the STM32 seems to handle this just fine
    (setq pasPedalRPM (* pasPedalRPM 0.95))
    ; SDS - run at 1000hz uses 10% VESC STM cpu
    (sleep 0.001)
}
)