; All on-screen text. Small-font strings end with $FF; text box strings use
; NL (new line), PG (next page) and EOT. Text box lines hold 18 characters.
; "~" is the A-with-tilde of JOAO.

SECTION "Strings", ROM0

StrNeedCGB1:    db "GAME BOY COLOR", $FF
StrNeedCGB2:    db "BENÖTIGT!", $FF
StrVenue:       db "@ BALLHAUS WEST", $FF
StrDateTime:    db "DO 29.10.2026 18:00", $FF
StrDateEnd:     db "29.10.2026 18:00", $FF
StrPressStart:  db "START DRÜCKEN", $FF
StrLineupTBA:   db "LINE UP: ???", $FF

StrPickDjs:     db "WÄHLE DEINE DJS!", $FF
StrBooked3:     db "GEBUCHT: 0/4", $FF
StrDjDots:      db "- - - - - -", $FF
StrLockedIn:    db "   EINGELOGGT!    ", $FF
StrNoStatus:    db "                  ", $FF
StrDigCrates:   db "PLATTEN DIGGEN!", $FF
StrJackpotLabels: db " HOUSE HOUSE HOUSE", $FF

StrTechSetup:   db "TECH SETUP", $FF
StrDeckA:       db "DECK A", $FF
StrDeckB:       db "DECK B", $FF
StrScratches:   db "SCRATCHES: 0/8", $FF

StrLoading:     db "PARTY LÄDT...", $FF
; 16 characters each
LoadMsgs:
    db "REIFEN AUFPUMPEN", $FF
    db "BODEN WACHSEN...", $FF
    db "VINYL SORTIEREN.", $FF
    db "DRINKS KÜHLEN...", $FF
    db "FERTIG. ABFAHRT!", $FF

StrDJs:         db "SIMA + PATER JO~O + DA:SYPODA", $FF
StrStart:       db "START: 18:00", $FF

; --- text box ---------------------------------------------------------------
DjTexts:                        ; the real DJs just lock in, no dialog
    dw 0, TxtGuetta, 0, TxtTiesto, 0, 0
TxtGuetta:      db "DAVID GUETTA?", NL, "AUSGEBUCHT AUF", NL, "IBIZA. SORRY!", EOT
TxtTiesto:      db "TIESTO? STECKT AM", NL, "FLUGHAFEN FEST.", NL, "NÄCHSTER!", EOT
TxtLineupDone:  db "LINE-UP KOMPLETT!", NL, "SIMA + PATER JO~O", NL, "+ DA:SYPODA", EOT

TxtCratesIntro: db "PLATTEN DIGGEN!", NL, "DRÜCK A, UM JEDE", NL, "KISTE ZU STOPPEN.", EOT
TxtJackpot:     db "JACKPOT!", NL, "3X HOUSE-KLASSIKER", NL, "IN DER TASCHE!", EOT

TxtIntro:       db "KARLSRUHE HBF.", NL, "FAHR ZUM BALLHAUS", NL, "WEST, HIRSCHSTR 18", PG
                db "EINLASS 18:00.", NL, "FOLGE DEM PFEIL!", EOT
TxtDoor:        db "BALLHAUS WEST!", NL, "TÜRSTEHER: LISTE?", NL, "PASST. KOMM REIN!", EOT

TxtClubIntro:   db "DIE MENGE WARTET!", NL, "AB ZU DEN DECKS", NL, "ZUM TECH SETUP.", EOT
TxtAtDecks:     db "CHECKEN WIR MAL", NL, "DIE ANLAGE...", EOT
TxtTechIntro:   db "TECH SETUP!", NL, "8X SCRATCHEN MIT", NL, "<LT> UND <RT>.", EOT
TxtScratchDone: db "SOUNDCHECK: OK!", NL, "DIE PARTY KANN", NL, "LOSGEHEN. ENKA!", EOT

PUSHC
SETCHARMAP big
BigEnka:        db "ENKA", $FF
MarqText:
    db "START DRÜCKEN", "            ", $FF
POPC
