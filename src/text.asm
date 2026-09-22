; All on-screen text. Small-font strings end with $FF; text box strings use
; NL (new line), PG (next page) and EOT. Text box lines hold 18 characters.
; "~" is the A-with-tilde of JOAO.

SECTION "Strings", ROMX

StrNeedCGB1:    db "GAME BOY COLOR", $FF
StrNeedCGB2:    db "NEEDED!", $FF
StrVenue:       db "@ BALLHAUS WEST", $FF
StrDateLong:    db "THURSDAY 29.10.2026", $FF
StrDateShort:   db "THU 29.10.2026", $FF
StrPressStart:  db "PRESS START", $FF
StrLineupTBA:   db "LINE UP: ???", $FF

StrSetup1:      db "SETUP 1/3: TIME", $FF
StrPickTime:    db "PICK THE START TIME:", $FF
StrArrowUp:     db "<UP>", $FF
StrArrowDn:     db "<DN>", $FF
StrTimeHint:    db "<UP><DN> CHANGE A: OK", $FF

StrSetup2:      db "SETUP 2/3: DJS", $FF
StrBookDjs:     db "BOOK TWO DJS!", $FF
StrBooked:      db "BOOKED: 0/2", $FF
StrDjHint:      db "<UP><DN> PICK A: BOOK", $FF
DjNames:
    db "SIMA", $FF
    db "ONKEL HORST", $FF
    db "PATER JO~O", $FF
    db "A GOAT", $FF
    db "SHUFFLE MODE", $FF

StrSetup3:      db "SETUP 3/3: DECKS", $FF
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

StrDJs:         db "SIMA + PATER JO~O", $FF
StrStartLbl:    db "START: ", $FF
StrMadeIt:      db "YOU MADE IT!", $FF
StrBallhaus:    db "BALLHAUS WEST", $FF
StrEuropaplatz: db "EUROPAPLATZ", $FF
StrKarlsruhe:   db "KARLSRUHE", $FF
StrRideTime:    db "YOUR TIME: ", $FF
StrTramBumps:   db "TRAM BUMPS: ", $FF

; start time choices: 6 bytes each
TimesSmall:
    db "20:00", $FF
    db "21:00", $FF
    db "22:00", $FF
    db "23:00", $FF
    db "00:00", $FF
; 16 characters each
TimeComments:
    db "EARLY BIRD!     ", $FF
    db "WARM-UP VIBES.  ", $FF
    db "SWEET SPOT!     ", $FF
    db "FASHIONABLY LATE", $FF
    db "BERLIN HOURS?!  ", $FF

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

TxtIntro:       db "RIDE YOUR BIKE TO", NL, "BALLHAUS WEST AT", NL, "EUROPAPLATZ. GO!", EOT
TxtDoor:        db "BOUNCER: NAME?", PG
                db "...YOU BOOKED SIMA", NL, "AND PATER JO~O?", NL, "COME IN, LEGEND!", EOT
TxtTram:        db "DING DING!!", NL, "THE TRAM ALWAYS", NL, "WINS. WATCH OUT!", EOT

; indexed by map event id
EventTexts:
    dw 0, TxtPyramid, TxtEuropa, TxtHouseDoor, TxtKaiser, TxtBarrier
TxtPyramid:     db "THE PYRAMID.", NL, "KARLSRUHE'S", NL, "FOUNDER RESTS HERE", EOT
TxtEuropa:      db "EUROPAPLATZ", NL, "<LT> BALLHAUS WEST", EOT
TxtHouseDoor:   db "LOCKED. SOMEONE IS", NL, "STILL SLEEPING OFF", NL, "LAST WEEKEND.", EOT
TxtKaiser:      db "KAISERSTRASSE.", NL, "SHOPPING? NO TIME,", NL, "PARTY FIRST!", EOT
TxtBarrier:     db "BAUSTELLE.", NL, "ROAD CLOSED.", NL, "SINCE FOREVER.", EOT

; indexed by NPC type
NpcTexts:
    dw TxtOma, TxtWorker, TxtDoener, TxtGoat, TxtBouncer
TxtOma:         db "OMA: ENKA TONIGHT?", NL, "TAKE A JACKET,", NL, "IT'S OCTOBER!", EOT
TxtWorker:      db "BAUSTELLE! WE'VE", NL, "BEEN DIGGING HERE", NL, "SINCE 2010.", PG
                db "TAKE THE SIDE", NL, "STREET SOUTH, OVER", NL, "THE TRAM TRACKS.", EOT
TxtDoener:      db "WANT A DOENER?", NL, "...NO TIME? THEN", NL, "RIDE, BUDDY, RIDE!", EOT
TxtGoat:        db "BAAAH! I WANTED TO", NL, "DJ TONIGHT. THEY", NL, "SAID NO. RUDE.", EOT
TxtBouncer:     db "NO BIKES INSIDE,", NL, "BUDDY. THE DOOR", NL, "IS RIGHT THERE.", EOT

PUSHC
SETCHARMAP big
BigEnka:        db "ENKA", $FF
TimesBig:
    db "20:00", $FF
    db "21:00", $FF
    db "22:00", $FF
    db "23:00", $FF
    db "00:00", $FF
MarqText:
    db "ENKA @ BALLHAUS WEST * EUROPAPLATZ KARLSRUHE * THURSDAY 29.10.2026 * "
    db "LINE UP: ??? * PRESS START TO SET UP THE PARTY! * ", $FF
POPC
