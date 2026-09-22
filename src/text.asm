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

StrPickDjs:     db "PICK YOUR 3 DJS", $FF
StrBooked3:     db "BOOKED: 0/3", $FF
StrDigCrates:   db "DIG THE CRATES!", $FF
StrJackpotLabels: db " HOUSE HOUSE HOUSE", $FF

StrTechSetup:   db "TECH SETUP", $FF
StrDeckA:       db "DECK A", $FF
StrDeckB:       db "DECK B", $FF
StrScratches:   db "SCRATCHES: 0/8", $FF

StrLoading:     db "LOADING PARTY...", $FF
; 16 characters each
LoadMsgs:
    db "PUMPING TIRES...", $FF
    db "WAXING THE FLOOR", $FF
    db "SORTING VINYL...", $FF
    db "CHILLING DRINKS.", $FF
    db "READY. LET'S GO!", $FF

StrDJs:         db "SIMA, PATER, JO~O", $FF
StrStart:       db "START: 18:00", $FF
StrYourTime:    db "YOUR TIME: ", $FF
StrSeeYou:      db "SEE YOU THERE!", $FF

; --- text box ---------------------------------------------------------------
DjTexts:
    dw TxtSima, TxtGuetta, TxtPater, TxtTiesto, TxtJoao, TxtCalvin
TxtSima:        db "SIMA IS BOOKED!", NL, "THE CROWD GOES", NL, "WILD! <3", EOT
TxtGuetta:      db "DAVID GUETTA?", NL, "BOOKED OUT IN", NL, "IBIZA. SORRY!", EOT
TxtPater:       db "PATER IS IN!", NL, "MAN BUN TIGHT,", NL, "DECKS READY.", EOT
TxtTiesto:      db "TIESTO?", NL, "STUCK AT THE", NL, "AIRPORT. NEXT!", EOT
TxtJoao:        db "JO~O IS IN!", NL, "SUNSHINE ON", NL, "THE DECKS!", EOT
TxtCalvin:      db "CALVIN HARRIS?", NL, "ON A SUMMER TOUR.", NL, "MAYBE NEXT YEAR!", EOT
TxtAlready:     db "ALREADY BOOKED!", NL, "PICK SOMEONE ELSE.", EOT
TxtLineupDone:  db "LINE UP COMPLETE!", NL, "SIMA, PATER, JO~O", NL, "WHAT A NIGHT!", EOT

TxtCratesIntro: db "DIG THE CRATES!", NL, "PRESS A TO STOP", NL, "EACH CRATE.", EOT
TxtJackpot:     db "JACKPOT!", NL, "3X HOUSE CLASSICS", NL, "IN THE BAG!", EOT

TxtIntro:       db "KARLSRUHE HBF.", NL, "RIDE TO BALLHAUS", NL, "WEST, HIRSCHSTR 18", PG
                db "DOORS OPEN 18:00.", NL, "FOLLOW THE ARROW!", EOT
TxtDoor:        db "BALLHAUS WEST!", NL, "BOUNCER: YOU'RE ON", NL, "THE LIST. COME IN!", EOT

TxtClubIntro:   db "THE CROWD IS", NL, "WAITING! GO TO THE", NL, "DECKS FOR THE", PG
                db "TECH SETUP.", EOT
TxtAtDecks:     db "LET'S CHECK THE", NL, "SOUND SYSTEM...", EOT
TxtTechIntro:   db "TECH SETUP!", NL, "SCRATCH 8 TIMES", NL, "WITH <LT> AND <RT>.", EOT
TxtScratchDone: db "SOUND CHECK: OK!", NL, "THE PARTY CAN", NL, "START. ENKA!", EOT

PUSHC
SETCHARMAP big
BigEnka:        db "ENKA", $FF
MarqText:
    db "PRESS START", "            ", $FF
POPC
