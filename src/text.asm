; All on-screen text. Small-font strings end with $FF; text box strings use
; NL (new line), PG (next page) and EOT. Text box lines hold 18 characters.
; "~" is the A-with-tilde of JOAO.

SECTION "Strings", ROM0

StrNeedCGB1:    db "GAME BOY COLOR", $FF
StrNeedCGB2:    db "NEEDED!", $FF
StrVenue:       db "@ BALLHAUS WEST", $FF
StrDateTime:    db "THU 29.10.2026 18:00", $FF
StrPressStart:  db "PRESS START", $FF
StrLineupTBA:   db "LINE UP: ???", $FF

StrSetup2:      db "SETUP 1/2: DJS", $FF
StrBookDjs:     db "BOOK TWO DJS!", $FF
StrBooked:      db "BOOKED: 0/2", $FF
StrDjHint:      db "<UP><DN> PICK A: BOOK", $FF
DjNames:
    db "SIMA", $FF
    db "ONKEL HORST", $FF
    db "PATER JO~O", $FF
    db "A GOAT", $FF
    db "SHUFFLE MODE", $FF

StrSetup3:      db "SETUP 2/2: DECKS", $FF
StrDeckA:       db "DECK A", $FF
StrDeckB:       db "DECK B", $FF
StrScratches:   db "SCRATCHES: 0/8", $FF
StrTurnHint1:   db "<UP><DN> DECK <LT><RT> SCRATCH", $FF
StrTurnHint2:   db "A: START/STOP", $FF

StrLoading:     db "LOADING PARTY...", $FF
; 16 characters each
LoadMsgs:
    db "PUMPING TIRES...", $FF
    db "WAXING THE FLOOR", $FF
    db "SORTING VINYL...", $FF
    db "CHILLING DRINKS.", $FF
    db "READY. LET'S GO!", $FF
StrOsm1:        db "MAP: OPENSTREETMAP", $FF

StrDJs:         db "SIMA + PATER JO~O", $FF
StrStart:       db "START: 18:00", $FF
StrYourTime:    db "YOUR TIME: ", $FF
StrSeeYou:      db "SEE YOU THERE!", $FF

; --- text box ---------------------------------------------------------------
DjTexts:
    dw TxtSima, TxtHorst, TxtPater, TxtGoatDj, TxtShuffle
TxtSima:        db "SIMA IS BOOKED!", NL, "THE CROWD GOES", NL, "WILD! <3", EOT
TxtHorst:       db "ONKEL HORST ONLY", NL, "PLAYS SCHLAGER.", NL, "NOPE NOPE NOPE.", EOT
TxtPater:       db "PATER JO~O IS IN!", NL, "HE WILL BLESS", NL, "THE DECKS.", EOT
TxtGoatDj:      db "THE GOAT ATE THE", NL, "RECORDS. BAAAH!", NL, "NOT BOOKED.", EOT
TxtShuffle:     db "SHUFFLE MODE?", NL, "NO SOUL, NO HANDS", NL, "IN THE AIR. NEXT!", EOT
TxtAlready:     db "ALREADY BOOKED!", NL, "PICK SOMEONE ELSE.", EOT
TxtLineupDone:  db "LINE UP COMPLETE!", NL, "SIMA + PATER JO~O", NL, "WHAT A NIGHT!", EOT
TxtScratchDone: db "WICKA WICKA!", NL, "THE DECKS ARE", NL, "WARMED UP.", EOT

TxtIntro:       db "KARLSRUHE HBF.", NL, "RIDE TO BALLHAUS", NL, "WEST, HIRSCHSTR 18", PG
                db "DOORS OPEN 18:00.", NL, "FOLLOW THE ARROW!", EOT
TxtDoor:        db "BALLHAUS WEST!", NL, "BOUNCER: SIMA AND", NL, "PATER JO~O ARE ON.", PG
                db "COME IN, LEGEND!", EOT

PUSHC
SETCHARMAP big
BigEnka:        db "ENKA", $FF
MarqText:
    db "ENKA @ BALLHAUS WEST * HIRSCHSTRASSE 18 KARLSRUHE * THURSDAY 29.10.2026 18:00 * "
    db "LINE UP: ??? * PRESS START TO SET UP THE PARTY! * ", $FF
POPC
