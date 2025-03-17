; <<PAS Throttle Cruise>>
;
; (C) 2025 S.D.Smith all rights reserved

(gpio-configure 'pin-tx 'pin-mode-in-pu)
(gpio-configure 'pin-rx 'pin-mode-in-pu)

(def pasPedalCount 0)
(def pasPedalRPM 0)


(def prevH1 (gpio-read 'pin-tx))
(def prevH2 (gpio-read 'pin-rx))
(def sendRate 100)
(def sendCount sendRate)

(loopwhile t
{
    (def h1 (gpio-read 'pin-tx))
    (def h2 (gpio-read 'pin-rx))

    (if (or (not ( = prevH1 h1)) (not ( = prevH2 h2)) )
    {

    (def cur (+ h1 (* h2 2)) )
    (def prev (+ prevH1 (* prevH2 2)) )

    (setq prevH1 h1)
    (setq prevH2 h2)

    (def pCPC pasPedalCount)

    (if (and (= prev 2) (= cur 0)) (setq pasPedalCount (+ pasPedalCount 1))    )
    (if (and (= prev 0) (= cur 1)) (setq pasPedalCount (+ pasPedalCount 1))    )
    (if (and (= prev 1) (= cur 3)) (setq pasPedalCount (+ pasPedalCount 1))    )
    (if (and (= prev 3) (= cur 2)) (setq pasPedalCount (+ pasPedalCount 1))    )

    (if (and (= prev 0) (= cur 2)) (setq pasPedalCount (- pasPedalCount 1))    )
    (if (and (= prev 1) (= cur 0)) (setq pasPedalCount (- pasPedalCount 1))    )
    (if (and (= prev 3) (= cur 1)) (setq pasPedalCount (- pasPedalCount 1))    )
    (if (and (= prev 2) (= cur 3)) (setq pasPedalCount (- pasPedalCount 1))    )
    (setq pasPedalRPM (+ pasPedalRPM (- pasPedalCount pCPC)))
    }
    )

    (setq sendCount (- sendCount 1))
    (if (< sendCount 0)
        {
        (setq sendCount sendRate)

        (def temppc (+ pasPedalCount 8388608))
        (send-data (list (+ (* pasPedalRPM 10) 128) (mod temppc 256) (mod (/ temppc 256) 256) (mod (/ temppc 65536) 256) ));
        }
    )

    (setq pasPedalRPM (* pasPedalRPM 0.95))

    (sleep 0.001)
}
)