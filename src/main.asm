; ENKA @ Ballhaus West -- Game Boy Color promo cartridge
; 32 KiB ROM, no MBC, CGB only. Build with ./build.sh (RGBDS 1.0).
;
; Flow: title -> DJ booking -> crate digging -> loading -> bike ride from
;       Karlsruhe Hbf to Ballhaus West -> inside: tech setup at the decks -> ending

INCLUDE "hardware.inc"
INCLUDE "gfx_defs.inc"

DEF LCDC_ON    EQU %11010111   ; LCD on, window map $9C00, tiles $8000, BG map $9800, OBJ 8x16
DEF LCDCF_WIN  EQU %00100000
DEF WIN_MAP    EQU $9C00
DEF WIN_Y      EQU 96          ; text box = bottom 6 tile rows
DEF QUEUE_MAX  EQU 24
DEF KICK_FREQ  EQU $700
DEF LAYER_DRUMS EQU %001
DEF LAYER_BASS  EQU %010
DEF LAYER_KEYS  EQU %100        ; piano stabs + lead

DEF SCR_TITLE   EQU 0
DEF SCR_DJS     EQU 1
DEF SCR_CRATES  EQU 2
DEF SCR_LOADING EQU 3
DEF SCR_MAP     EQU 4
DEF SCR_CLUB    EQU 5
DEF SCR_SCRATCH EQU 6
DEF SCR_END     EQU 7

DEF PADB_A      EQU 0
DEF PADB_B      EQU 1
DEF PADB_SELECT EQU 2
DEF PADB_START  EQU 3
DEF PADB_RIGHT  EQU 4
DEF PADB_LEFT   EQU 5
DEF PADB_UP     EQU 6
DEF PADB_DOWN   EQU 7

; text control codes
DEF NL  EQU $FE                 ; new line
DEF PG  EQU $FD                 ; wait for A, next page
DEF EOT EQU $FF                 ; wait for A, close

; text box states
DEF TB_CLOSED EQU 0
DEF TB_CLEAR  EQU 1
DEF TB_TYPE   EQU 2
DEF TB_MORE   EQU 3
DEF TB_END    EQU 4

DEF SCRATCH_GOAL EQU 8

DEF COL_GREY     EQU (22 << 10) | (15 << 5) | 13
DEF COL_GREEN    EQU (14 << 10) | (31 << 5) | 12

; hl += a (clobbers a)
MACRO ADD_HL_A
    add a, l
    ld l, a
    adc a, h
    sub l
    ld h, a
ENDM

; de += 32 (next map row, clobbers a)
MACRO NEXT_ROW_DE
    ld a, e
    add a, 32
    ld e, a
    adc a, d
    sub e
    ld d, a
ENDM

; LCD-off text: DRAW string, row, col [, attr, width]
MACRO DRAW
    ld hl, \1
    ld de, _SCRN0 + (\2) * 32 + (\3)
    call DrawText
    IF _NARG == 5
        ld a, \4
        ld de, _SCRN0 + (\2) * 32 + (\3)
        ld bc, ((\5) << 8) | 1
        call SetAttrRect
    ENDC
ENDM

; ==========================================================================
; Interrupt vectors & header
; ==========================================================================
SECTION "VBlank IRQ", ROM0[$40]
    jp VBlankHandler

SECTION "STAT IRQ", ROM0[$48]
    jp StatHandler

SECTION "Header", ROM0[$100]
    nop
    jp Start
    ds $150 - @, 0          ; filled in by rgbfix

; ==========================================================================
; Boot
; ==========================================================================
SECTION "Boot", ROM0[$150]
Start:
    di
    ld sp, $E000
    ld e, a                 ; A = $11 on Game Boy Color

.waitVBlank:
    ldh a, [rLY]
    cp 144
    jr c, .waitVBlank
    xor a
    ldh [rLCDC], a

    ; clear WRAM (leave the top page for the stack)
    ld hl, $C000
    ld bc, $1F00
    ld d, 0
    call MemFill
    ld a, e
    ld [wIsCGB], a

    ; clear HRAM, install OAM DMA routine
    ld hl, $FF80
    ld b, $7F
    xor a
.clearHRAM:
    ld [hl+], a
    dec b
    jr nz, .clearHRAM
    ld hl, DMARoutine
    ld de, hOAMDMA
    ld bc, DMARoutineEnd - DMARoutine
    call MemCopy

    ld a, [wIsCGB]
    cp $11
    jp nz, NotCGB

    ; clear both VRAM banks
    ld a, 1
    ldh [rVBK], a
    ld hl, _VRAM
    ld bc, $2000
    ld d, 0
    call MemFill
    xor a
    ldh [rVBK], a
    ld hl, _VRAM
    ld bc, $2000
    call MemFill

    ; fixed tiles: font, UI, shared sprites
    ld hl, Tiles0
    ld de, _VRAM
    ld bc, Tiles0End - Tiles0
    call MemCopy
    xor a
    ldh [rSCY], a
    ldh [rSCX], a
    ld a, WIN_Y
    ldh [rWY], a
    ld a, 7
    ldh [rWX], a

    ; sound
    ld a, $80
    ldh [rNR52], a
    ld a, $77
    ldh [rNR50], a
    ld a, $FF
    ldh [rNR51], a
    xor a
    ldh [rNR30], a
    ld hl, WaveData
    ld de, _WAVERAM
    ld bc, 16
    call MemCopy
    call MusicRestart

    ld a, $A5
    ld [wRand], a
    ld a, %00001000         ; STAT interrupt on HBlank (per-line scroll effects)
    ldh [rSTAT], a

    ld a, 4
    ld [wFade], a
    ld a, SCR_TITLE
    ld [wScreen], a
    call EnterScreen

MainLoop:
    call WaitFrame
    call ReadJoy
    ld a, [wTimerOn]
    and a
    jr z, .noTimer
    ld hl, wPlayTime
    inc [hl]
    jr nz, .noTimer
    inc hl
    inc [hl]
.noTimer:
    ld a, [wScreen]
    ld hl, UpdateTable
    call CallTable
    ld a, [wWindowOn]
    and a
    call nz, HideUnderWindow
    call ApplyFade
    ld a, [wChangeReq]
    and a
    jr z, MainLoop
    call DoChangeScreen
    jr MainLoop

; Shown on original Game Boy / Pocket (no colour hardware).
NotCGB:
    ld hl, Tiles0
    ld de, _VRAM
    ld bc, Tiles0End - Tiles0
    call MemCopy
    ld hl, _SCRN0
    ld bc, $400
    ld d, 0
    call MemFill
    DRAW StrNeedCGB1, 7, 3
    DRAW StrNeedCGB2, 9, 6
    ld a, %11100100
    ldh [rBGP], a
    ld a, %10010001
    ldh [rLCDC], a
.lock:
    halt
    jr .lock

; ==========================================================================
; Interrupt handlers
; ==========================================================================
SECTION "Handlers", ROM0
VBlankHandler:
    push af
    push bc
    push de
    push hl

    ld a, HIGH(wShadowOAM)
    call hOAMDMA

    ; a streamed map row/column takes this VBlank; queue and palettes wait a frame
    ld a, [wStreamMode]
    and a
    jr z, .noStream
    call StreamFlush
    jr .registers
.noStream:

    ; VRAM writes first: they are lost if they spill past VBlank
    ld a, [wQueueLen]
    and a
    jr z, .noQueue
    ld b, a
    ld hl, wQueue
.queue:
    ld a, [hl+]
    ld e, a
    ld a, [hl+]
    ld d, a
    ld a, [hl+]
    ld [de], a
    dec b
    jr nz, .queue
    xor a
    ld [wQueueLen], a
.noQueue:

    ld a, [wPalDirty]
    and a
    jr z, .noPal
    xor a
    ld [wPalDirty], a
    call UploadBgPalettes
    ld a, [wObjPalDirty]    ; sprite palettes only change with fades / new screens
    and a
    jr z, .noPal
    xor a
    ld [wObjPalDirty], a
    call UploadObjPalettes
.noPal:

.registers:
    ld a, [wWinY]
    ldh [rWY], a
    ld a, [wScxTable]
    ldh [rSCX], a
    ld a, [wSCY]
    ldh [rSCY], a
    ld a, [wWindowOn]
    and a
    ld a, LCDC_ON
    jr z, .noWindow
    or LCDCF_WIN
.noWindow:
    ldh [rLCDC], a

    ld a, 1
    ldh [hVBlankFlag], a

    ; music runs with interrupts enabled so the raster effects stay stable
    ei
    call SoundUpdate

    pop hl
    pop de
    pop bc
    pop af
    reti

; per-line horizontal scroll: during HBlank of line N set SCX for line N+1
StatHandler:
    push af
    push hl
    ldh a, [rLY]
    inc a
    ld l, a
    ld h, HIGH(wScxTable)
    ld a, [hl]
    ldh [rSCX], a
    pop hl
    pop af
    reti

UploadPalettes:
    call UploadBgPalettes
UploadObjPalettes:
    ld hl, wPal + 64
    ld a, $80
    ldh [rOCPS], a
    ld c, LOW(rOCPD)
    REPT 64
        ld a, [hl+]
        ldh [c], a
    ENDR
    ret

UploadBgPalettes:
    ld hl, wPal
    ld a, $80
    ldh [rBCPS], a
    ld c, LOW(rBCPD)
    REPT 64
        ld a, [hl+]
        ldh [c], a
    ENDR
    ret

DMARoutine:
    ldh [rDMA], a
    ld a, 40
.wait:
    dec a
    jr nz, .wait
    ret
DMARoutineEnd:

; ==========================================================================
; Utilities
; ==========================================================================
SECTION "Utils", ROM0

; hl = dest, bc = count (>0), d = value
MemFill:
    ld a, d
    ld [hl+], a
    dec bc
    ld a, b
    or c
    jr nz, MemFill
    ret

; hl = src, de = dest, bc = count (>0)
MemCopy:
    ld a, [hl+]
    ld [de], a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, MemCopy
    ret

; hl = dest, b = count, a = value
FillBytes:
    ld [hl+], a
    dec b
    jr nz, FillBytes
    ret

; a = index, hl = table of routine pointers
CallTable:
    add a, a
    ADD_HL_A
    ld a, [hl+]
    ld h, [hl]
    ld l, a
    jp hl

WaitFrame:
    xor a
    ldh [hVBlankFlag], a
.wait:
    halt
    ldh a, [hVBlankFlag]
    and a
    jr z, .wait
    ret

; hJoyHeld / hJoyPressed: bit 0-3 = A B Select Start, bit 4-7 = Right Left Up Down
ReadJoy:
    ld a, $20
    ldh [rP1], a
    ldh a, [rP1]
    ldh a, [rP1]
    cpl
    and $0F
    swap a
    ld b, a
    ld a, $10
    ldh [rP1], a
    REPT 6
        ldh a, [rP1]
    ENDR
    cpl
    and $0F
    or b
    ld b, a
    ld a, $30
    ldh [rP1], a
    ldh a, [hJoyHeld]
    cpl
    and b
    ldh [hJoyPressed], a
    ld a, b
    ldh [hJoyHeld], a
    ldh [hPadHeld], a
    ret

; text boxes / pop-ups stay on top: hide every sprite that reaches into the window
HideUnderWindow:
    ld a, [wWinY]
    ld b, a
    ld hl, wShadowOAM
    ld c, 40
.loop:
    ld a, [hl]
    cp b
    jr c, .keep
    jr z, .keep
    xor a
    ld [hl], a
.keep:
    ld a, l
    add a, 4
    ld l, a
    dec c
    jr nz, .loop
    ret

; ignore the pad for the rest of this frame (used while a text box is open).
; hJoyHeld keeps the real state so a held button is not seen as a new press.
MuteJoy:
    xor a
    ldh [hJoyPressed], a
    ldh [hPadHeld], a
    ret

; returns a pseudo-random byte in a (preserves other registers)
Rand:
    push bc
    ld a, [wRand]
    ld b, a
    add a, a
    add a, a
    add a, b
    inc a
    ld [wRand], a
    ld b, a
    ldh a, [rDIV]
    xor b
    pop bc
    ret

; hl / c -> de = quotient, a = remainder
DivHL:
    ld de, 0
.loop:
    ld a, l
    sub c
    ld l, a
    ld a, h
    sbc a, 0
    ld h, a
    jr c, .done
    inc de
    jr .loop
.done:
    ld a, l
    add a, c
    ret

; a = 0-99 -> two digit chars at hl (hl advanced)
TwoDigits:
    ld b, CH_0
.tens:
    cp 10
    jr c, .ones
    sub 10
    inc b
    jr .tens
.ones:
    ld c, a
    ld a, b
    ld [hl+], a
    ld a, c
    add a, CH_0
    ld [hl+], a
    ret

; must be called with IME off; waits for VBlank, then turns the LCD off
LCDOff:
    ldh a, [rLCDC]
    bit 7, a
    ret z
.wait:
    ldh a, [rLY]
    cp 144
    jr c, .wait
    xor a
    ldh [rLCDC], a
    ret

; --- tile sets (LCD off) --------------------------------------------------

LoadBigFont:
    ld a, [wBank1Set]
    cp 1
    ret z
    ld a, 1
    ld [wBank1Set], a
    ld hl, BigFontTiles
    ld bc, BigFontTilesEnd - BigFontTiles
    jr LoadBank1

LoadOwTiles:
    ld a, [wBank1Set]
    cp 2
    ret z
    ld a, 2
    ld [wBank1Set], a
    ld hl, OwTiles
    ld bc, OwTilesEnd - OwTiles
    jr LoadBank1

LoadAvatars:
    ld a, 4
    ld hl, AvatarTiles
    ld bc, AvatarTilesEnd - AvatarTiles
    jr LoadBank1Set
LoadCrates:
    ld a, 5
    ld hl, CrateTiles
    ld bc, CrateTilesEnd - CrateTiles
    jr LoadBank1Set
LoadClub:
    ld a, 6
    ld hl, ClubTiles
    ld bc, ClubTilesEnd - ClubTiles
; a = set id, hl = tiles (tile-set bank), bc = size
LoadBank1Set:
    ld d, a
    ld a, [wBank1Set]
    cp d
    ret z
    ld a, d
    ld [wBank1Set], a
    jr LoadBank1

; a = ROM bank, hl = src, de = map address, b = width, c = height
CopyRectBank:
    ld [rROMB0], a
    call CopyRect
    ld a, 1
    ld [rROMB0], a
    ret

LoadEndTiles:
    ld a, [wBank1Set]
    cp 3
    ret z
    ld a, 3
    ld [wBank1Set], a
    ld a, BANK(EndTiles)
    ld [rROMB0], a
    ld hl, EndTiles
    ld bc, EndTilesEnd - EndTiles
    jr LoadBank1Banked

; hl = tiles in the tile-set bank, bc = size -> VRAM bank 1 at $8000
LoadBank1:
    ld a, BANK(BigFontTiles)
    ld [rROMB0], a
LoadBank1Banked:
    ld a, 1
    ldh [rVBK], a
    ld de, _VRAM
    call MemCopy
    xor a
    ldh [rVBK], a
    inc a
    ld [rROMB0], a          ; back to the default bank
    ret

LoadLogo:
    ld a, 1
    ld hl, LogoTiles
    ld bc, LogoTilesEnd - LogoTiles
    jr LoadScene
LoadDeck:
    ld a, 2
    ld hl, DeckTiles
    ld bc, DeckTilesEnd - DeckTiles
    jr LoadScene
LoadOwSprites:
    ld a, 3
    ld hl, OwSprTiles
    ld bc, OwSprTilesEnd - OwSprTiles
; a = scene id, hl = tiles, bc = size
LoadScene:
    ld d, a
    ld a, [wSceneSet]
    cp d
    ret z
    ld a, d
    ld [wSceneSet], a
    ld a, BANK(LogoTiles)
    ld [rROMB0], a
    ld de, _VRAM + SCENE_BASE * 16
    call MemCopy
    ld a, 1
    ld [rROMB0], a
    ret

; --- drawing while the LCD is off ---------------------------------------

; hl = $FF-terminated string, de = map address
DrawText:
    ld a, [hl+]
    cp $FF
    ret z
    ld [de], a
    inc de
    jr DrawText

; hl = $FF-terminated big string, de = map address (2x2 tiles per char)
DrawBig:
    ld a, [hl+]
    cp $FF
    ret z
    push hl
    ld b, a
    ld h, d
    ld l, e
    ld [hl], b
    inc hl
    inc b
    ld [hl], b
    ld a, 31
    ADD_HL_A
    inc b
    ld [hl], b
    inc hl
    inc b
    ld [hl], b
    pop hl
    inc de
    inc de
    jr DrawBig

; hl = src, de = map address, b = width, c = height
CopyRect:
    push bc
    push de
.col:
    ld a, [hl+]
    ld [de], a
    inc de
    dec b
    jr nz, .col
    pop de
    NEXT_ROW_DE
    pop bc
    dec c
    jr nz, CopyRect
    ret

; a = attribute, de = map address, b = width, c = height
SetAttrRect:
    ld h, a
    ld a, 1
    ldh [rVBK], a
.row:
    push bc
    push de
.col:
    ld a, h
    ld [de], a
    inc de
    dec b
    jr nz, .col
    pop de
    NEXT_ROW_DE
    pop bc
    dec c
    jr nz, .row
    xor a
    ldh [rVBK], a
    ret

; --- VRAM write queue (bank 0, flushed in VBlank) ----------------------

; a = value, de = VRAM address. Preserves all registers.
QueueWrite:
    push hl
    push af
    ld a, [wQueueLen]
    cp QUEUE_MAX
    jr nc, .full
    ld l, a
    add a, a
    add a, l
    ld hl, wQueue
    ADD_HL_A
    ld a, e
    ld [hl+], a
    ld a, d
    ld [hl+], a
    pop af
    ld [hl], a
    ld hl, wQueueLen        ; publish the entry only once it is complete
    inc [hl]
    pop hl
    ret
.full:
    pop af
    pop hl
    ret

; a = big glyph base tile, de = map address
QueueBig:
    call QueueWrite
    inc de
    inc a
    call QueueWrite
    push af
    ld a, e
    add a, 31
    ld e, a
    adc a, d
    sub e
    ld d, a
    pop af
    inc a
    call QueueWrite
    inc de
    inc a
    jp QueueWrite

; hl = $FF-terminated string, de = map address
QueueText:
    ld a, [hl+]
    cp $FF
    ret z
    call QueueWrite
    inc de
    jr QueueText

; hl = $FF-terminated big string, de = map address
QueueBigText:
    ld a, [hl+]
    cp $FF
    ret z
    push de
    call QueueBig
    pop de
    inc de
    inc de
    jr QueueBigText

; --- palettes -----------------------------------------------------------

; a = colour slot (0-31 BG, 32-63 OBJ), bc = RGB555 colour
SetPalColor:
    add a, a
    ld l, a
    ld h, HIGH(wBasePal)
    ld [hl], c
    inc l
    ld [hl], b
    ret

; hl = table of words, a = index -> bc
GetWord:
    add a, a
    ADD_HL_A
    ld a, [hl+]
    ld c, a
    ld b, [hl]
    ret

; wBasePal -> wPal, darkened by wFade (0 = full colour, 4 = black)
ApplyFade:
    ld a, [wFade]
    and a
    jr nz, .fade
    ld hl, wBasePal
    ld de, wPal
    ld b, 128
.copy:
    ld a, [hl+]
    ld [de], a
    inc de
    dec b
    jr nz, .copy
    jr .done
.fade:
    swap a
    add a, a                ; * 32
    ldh [hFadeOff], a
    ld hl, wBasePal
    ld de, wPal
    ld b, 64
.loop:
    push bc
    ld a, [hl+]
    ld c, a                 ; lo: gggrrrrr
    ld a, [hl+]
    ld b, a                 ; hi: 0bbbbbgg
    push hl
    ld h, HIGH(FadeTab)
    ld a, c
    and $1F
    call .map
    ldh [hTmpR], a
    ld a, b
    and 3
    add a, a
    add a, a
    add a, a
    ld l, a
    ld a, c
    swap a
    rra
    and 7
    or l
    call .map
    ldh [hTmpG], a
    ld a, b
    rra
    rra
    and $1F
    call .map
    add a, a
    add a, a
    ld b, a
    ldh a, [hTmpG]
    ld c, a
    srl a
    srl a
    srl a
    or b
    ld b, a                 ; new hi
    ld a, c
    swap a
    add a, a
    and $E0
    ld c, a
    ldh a, [hTmpR]
    or c                    ; new lo
    pop hl
    ld [de], a
    inc de
    ld a, b
    ld [de], a
    inc de
    pop bc
    dec b
    jr nz, .loop
.done:
    ld a, 1
    ld [wPalDirty], a
    ret
.map:
    ld l, a
    ldh a, [hFadeOff]
    add a, l
    ld l, a
    ld a, [hl]
    ret

; palette `a` colours 2/3 = rainbow, e = rainbow index
RainbowPal:
    add a, a
    add a, a
    ld d, a
    ld a, e
    and 31
    ld hl, RainbowHi
    call GetWord
    ld a, d
    add a, 3
    call SetPalColor
    ld a, e
    add a, 4
    and 31
    ld hl, RainbowLo
    call GetWord
    ld a, d
    add a, 2
    jp SetPalColor

; ==========================================================================
; Text box (window layer, bottom of the screen)
; ==========================================================================
SECTION "TextBox", ROM0

; hl = text (NL / PG / EOT control codes)
OpenText:
    ld a, WIN_Y
    ld [wWinY], a
    xor a
    ld [wPopupTimer], a
    ld a, l
    ld [wTbPtr], a
    ld a, h
    ld [wTbPtr + 1], a
    ld a, TB_CLEAR
    ld [wTbState], a
    xor a
    ld [wTbRow], a
    ld [wTbDone], a
    ret

; Screens with a text box call this first. Returns z when no box is open.
; With a box open it runs the box, mutes the pad and returns nz;
; wTbDone is set on the frame the box closes.
TextStep:
    ld a, [wTbState]
    and a
    ret z
    call TextUpdate
    call MuteJoy
    or 1
    ret

TextUpdate:
    ld a, [wTbState]
    cp TB_CLEAR
    jr z, .clear
    cp TB_TYPE
    jr z, .type
    ; waiting for A: blink the arrow
    ld a, [wFrame]
    and 16
    ld a, CH_NEXT
    jr z, .arrow
    xor a
.arrow:
    ld de, WIN_MAP + 4 * 32 + 18
    call QueueWrite
    ldh a, [hJoyPressed]
    and (1 << PADB_A) | (1 << PADB_B)
    ret z
    ld a, [wTbState]
    cp TB_MORE
    jr nz, .close
    ld a, TB_CLEAR
    ld [wTbState], a
    xor a
    ld [wTbRow], a
    ret
.close:
    xor a
    ld [wTbState], a
    ld [wWindowOn], a
    inc a
    ld [wTbDone], a
    ret

.clear:                     ; one text row per frame
    ld a, [wQueueLen]
    cp QUEUE_MAX - 19
    ret nc
    ld a, [wTbRow]
    inc a
    swap a
    add a, a
    inc a                   ; (row + 1) * 32 + 1
    ld e, a
    ld d, HIGH(WIN_MAP)
    ld b, 18
    xor a
.clearLoop:
    call QueueWrite
    inc de
    dec b
    jr nz, .clearLoop
    ld a, [wTbRow]
    inc a
    ld [wTbRow], a
    cp 3
    ret nz
    xor a
    ld de, WIN_MAP + 4 * 32 + 18
    call QueueWrite
    ld [wTbRow], a
    ld a, LOW(WIN_MAP + 32 + 1)
    ld [wTbDest], a
    ld a, HIGH(WIN_MAP + 32 + 1)
    ld [wTbDest + 1], a
    ld a, TB_TYPE
    ld [wTbState], a
    ld a, 1
    ld [wWindowOn], a
    ret

.type:                      ; two characters per frame
    ld a, [wQueueLen]
    cp QUEUE_MAX - 2
    ret nc
    ld c, 2
.typeLoop:
    ld hl, wTbPtr
    ld a, [hl+]
    ld h, [hl]
    ld l, a
    ld a, [hl+]
    ld b, a
    ld a, l
    ld [wTbPtr], a
    ld a, h
    ld [wTbPtr + 1], a
    ld a, b
    cp NL
    jr z, .newLine
    cp PG
    jr z, .page
    cp EOT
    jr z, .end
    ld hl, wTbDest
    ld e, [hl]
    inc hl
    ld d, [hl]
    call QueueWrite
    inc de
    ld [hl], d
    dec hl
    ld [hl], e
    dec c
    jr nz, .typeLoop
    ret
.newLine:
    ld a, [wTbRow]
    inc a
    ld [wTbRow], a
    inc a
    swap a
    add a, a
    inc a
    ld [wTbDest], a
    ld a, HIGH(WIN_MAP)
    ld [wTbDest + 1], a
    jr .typeLoop
.page:
    ld a, TB_MORE
    ld [wTbState], a
    ret
.end:
    ld a, TB_END
    ld [wTbState], a
    ret

; ==========================================================================
; Screen management
; ==========================================================================
SECTION "Screens", ROM0

; a = screen id
RequestScreen:
    ld [wNextScreen], a
    ld a, 1
    ld [wChangeReq], a
    ret

DoChangeScreen:
    ld a, 1
.fadeOut:
    ld [wFade], a
    push af
    ld a, 1
    ld [wObjPalDirty], a
    call ApplyFade
    call WaitFrame
    call WaitFrame
    pop af
    inc a
    cp 5
    jr nz, .fadeOut
    di
    call LCDOff
    ld a, [wNextScreen]
    ld [wScreen], a
    ; fall through

; LCD off, IME off: build the screen, switch on, fade in
EnterScreen:
    xor a
    ld [wQueueLen], a
    ld [wChangeReq], a
    call ScreenReset
    ld a, [wScreen]
    ld hl, InitTable
    call CallTable
    call ApplyFade
    call UploadPalettes
    ld a, [wScxTable]
    ldh [rSCX], a
    ld a, [wSCY]
    ldh [rSCY], a
    ld a, LCDC_ON
    ldh [rLCDC], a
    xor a
    ldh [rIF], a
    ld a, [wRaster]
    add a, a
    or 1
    ldh [rIE], a
    ei
    ld a, 3
.fadeIn:
    ld [wFade], a
    push af
    ld a, 1
    ld [wObjPalDirty], a
    call ApplyFade
    call WaitFrame
    call WaitFrame
    pop af
    dec a
    cp $FF
    jr nz, .fadeIn
    ret

ScreenReset:
    ; both tile maps, both banks
    ld a, 1
    ldh [rVBK], a
    ld hl, _SCRN0
    ld bc, $800
    ld d, 0
    call MemFill
    xor a
    ldh [rVBK], a
    ld hl, _SCRN0
    ld bc, $800
    call MemFill

    ld hl, wShadowOAM
    ld bc, 160
    call MemFill
    ld hl, wScxTable
    ld bc, 256
    call MemFill

    ld hl, DefaultPalettes
    ld de, wBasePal
    ld bc, 128
    call MemCopy

    ; checkered borders top and bottom
    ld hl, _SCRN0
    ld b, 32
    ld a, TILE_CHECKER
    call FillBytes
    ld hl, _SCRN0 + 17 * 32
    ld b, 32
    call FillBytes
    ld a, 6
    ld de, _SCRN0
    ld bc, (32 << 8) | 1
    call SetAttrRect
    ld a, 6
    ld de, _SCRN0 + 17 * 32
    ld bc, (32 << 8) | 1
    call SetAttrRect

    ; text box frame in the window map
    ld hl, WIN_MAP
    ld a, TILE_TB_TL
    ld [hl+], a
    ld b, 18
    ld a, TILE_TB_T
    call FillBytes
    ld a, TILE_TB_TR
    ld [hl], a
    ld hl, WIN_MAP + 32
    ld c, 4
.boxRow:
    ld a, TILE_TB_L
    ld [hl], a
    ld a, 19
    ADD_HL_A
    ld a, TILE_TB_R
    ld [hl], a
    ld a, 13
    ADD_HL_A
    dec c
    jr nz, .boxRow
    ld a, TILE_TB_BL
    ld [hl+], a
    ld b, 18
    ld a, TILE_TB_B
    call FillBytes
    ld a, TILE_TB_BR
    ld [hl], a

    xor a
    ld [wTimer], a
    ld [wBeatFlash], a
    ld [wScratchOn], a      ; any scratch tone was replaced by another sound
    ld [wWindowOn], a
    ld [wTbState], a
    ld [wTbDone], a
    ld [wSCY], a
    ld [wRedraw], a
    ld [wStreamMode], a
    ld [wNoFlash], a
    ld a, WIN_Y
    ld [wWinY], a
    ld a, 1
    ld [wRaster], a
    ret

InitTable:
    dw TitleInit, DjsInit, CratesInit, LoadingInit, MapInit, ClubInit, ScratchInit, EndInit
UpdateTable:
    dw TitleUpdate, DjsUpdate, CratesUpdate, LoadingUpdate, MapUpdate, ClubUpdate, ScratchUpdate, EndUpdate

; Every non-map screen: frame counter, beat flash on the background, borders.
CommonUpdate:
    ld hl, wFrame
    inc [hl]
    ld a, [wBeatFlash]
    and a
    jr z, .noDecay
    dec a
    ld [wBeatFlash], a
.noDecay:
    ld a, [wNoFlash]        ; screens with pictures keep their backgrounds
    and a
    jr nz, .borders
    ld a, [wBeatFlash]
    ld hl, FlashTab
    call GetWord
    ld hl, wBasePal
    ld d, 8
.pal:
    ld [hl], c
    inc l
    ld [hl], b
    ld a, l
    add a, 7
    ld l, a
    dec d
    jr nz, .pal

.borders:
    ; scroll the checkered borders in opposite directions
    ld a, [wFrame]
    srl a
    ld hl, wScxTable
    ld b, 8
    call FillBytes
    cpl
    inc a
    ld hl, wScxTable + 136
    ld b, 8
    jp FillBytes

; 4 twinkling sparkles in OAM slots 1-4, inside the wSparkX0/Y0 box
UpdateSparkles:
    ld hl, wSpark
    ld de, wShadowOAM + 4
    ld c, 4
.loop:
    ld a, [hl]
    inc a
    cp 24
    jr c, .keep
    push hl
    inc hl
    call Rand
    ld b, a
    ld a, [wSparkXMask]
    and b
    ld b, a
    ld a, [wSparkX0]
    add a, b
    add a, 8
    ld [hl+], a
    call Rand
    ld b, a
    ld a, [wSparkYMask]
    and b
    ld b, a
    ld a, [wSparkY0]
    add a, b
    add a, 16
    ld [hl], a
    pop hl
    xor a
.keep:
    ld [hl+], a
    srl a
    srl a
    push hl
    ld hl, SparkAnim
    ADD_HL_A
    ld b, [hl]
    pop hl
    ld a, [hl+]             ; x
    push af
    ld a, [hl+]             ; y
    ld [de], a
    inc de
    pop af
    ld [de], a
    inc de
    ld a, b
    ld [de], a
    inc de
    ld a, 1
    ld [de], a
    inc de
    dec c
    jr nz, .loop
    ret

SparkAnim:
    db SPR_SPARK0, SPR_SPARK1, SPR_SPARK2, SPR_SPARK2, SPR_SPARK1, SPR_SPARK0

; b = x0, c = x mask, d = y0, e = y mask
InitSparkles:
    ld a, b
    ld [wSparkX0], a
    ld a, c
    ld [wSparkXMask], a
    ld a, d
    ld [wSparkY0], a
    ld a, e
    ld [wSparkYMask], a
    ld hl, wSpark
    ld a, 23
    ld c, 4
.loop:
    ld [hl+], a
    ld [hl], 0
    inc hl
    ld [hl], 0
    inc hl
    sub 6
    dec c
    jr nz, .loop
    ret

; ==========================================================================
; Title: animated ENKA logo + PRESS START in the big yellow font
; ==========================================================================
DEF TITLE_LOGO_ROW EQU 4
DEF TITLE_MARQ_ROW EQU 11

TitleInit:
    ld a, LAYER_DRUMS
    ld [wMusicLayers], a
    call LoadBigFont
    call LoadLogo
    ld hl, LogoMap
    ld de, _SCRN0 + TITLE_LOGO_ROW * 32 + 2
    ld bc, (16 << 8) | 4
    call CopyRect
    ld a, 1
    ld de, _SCRN0 + TITLE_LOGO_ROW * 32 + 2
    ld bc, (16 << 8) | 4
    call SetAttrRect

    ; marquee rows use the 2x font from VRAM bank 1
    ld a, $08 | 4
    ld de, _SCRN0 + TITLE_MARQ_ROW * 32
    ld bc, (32 << 8) | 2
    call SetAttrRect
    ld a, 255
    ld [wMarqScx], a
    ld a, LOW(MarqText)
    ld [wMarqPtr], a
    ld a, HIGH(MarqText)
    ld [wMarqPtr + 1], a

    ld bc, (24 << 8) | 127
    ld de, ((TITLE_LOGO_ROW * 8 - 4) << 8) | 31
    jp InitSparkles

TitleUpdate:
    call CommonUpdate
    ldh a, [hJoyPressed]
    and (1 << PADB_START) | (1 << PADB_A)
    jr z, .noInput
    call SfxSelect
    ; new game
    xor a
    ld [wPlayTime], a
    ld [wPlayTime + 1], a
    ld [wDjMask], a
    inc a
    ld [wTimerOn], a
    ld a, LAYER_DRUMS | LAYER_BASS
    ld [wMusicLayers], a
    ld a, SCR_DJS
    jp RequestScreen
.noInput:
    ld hl, wScxTable + TITLE_LOGO_ROW * 8
    call LogoWave

    ; marquee
    ld a, [wMarqScx]
    inc a
    ld [wMarqScx], a
    ld hl, wScxTable + TITLE_MARQ_ROW * 8
    ld b, 16
    call FillBytes
    ld a, [wMarqScx]
    and 15
    jr nz, .noMarq
    ld a, [wMarqScx]
    rrca
    rrca
    rrca
    add a, 20
    and 31
    ld hl, _SCRN0 + TITLE_MARQ_ROW * 32
    ADD_HL_A
    ld d, h
    ld e, l
    ld hl, wMarqPtr
    ld a, [hl+]
    ld h, [hl]
    ld l, a
    ld a, [hl+]
    cp $FF
    jr nz, .gotChar
    ld hl, MarqText
    ld a, [hl+]
.gotChar:
    ld b, a
    ld a, l
    ld [wMarqPtr], a
    ld a, h
    ld [wMarqPtr + 1], a
    ld a, b
    call QueueBig
.noMarq:
    ld a, [wFrame]
    srl a
    srl a
    ld e, a
    ld a, 1
    call RainbowPal
    jp UpdateSparkles

; hl -> first SCX table entry of the 32 logo lines: gentle wave
LogoWave:
    ld a, [wFrame]
    add a, a
    add a, a
    ld c, a
    ld b, 32
    ld d, HIGH(SineTab)
.wave:
    ld e, c
    ld a, [de]
    sra a
    sra a
    ld [hl+], a
    ld a, c
    add a, 3
    ld c, a
    dec b
    jr nz, .wave
    ret

; de = map address, b = first tile, c = attribute: 4x4 consecutive tiles (LCD off)
DrawBlock4:
    push de
    ld h, 4
.row:
    REPT 4
        ld a, b
        ld [de], a
        inc de
        inc b
    ENDR
    ld a, e
    add a, 28
    ld e, a
    adc a, d
    sub e
    ld d, a
    dec h
    jr nz, .row
    pop de
    ld a, c
    ld bc, (4 << 8) | 4
    jp SetAttrRect

; de = map address, b = first tile: queue a 4x4 block of tiles (bank 0 map)
QueueBlock4:
    ld c, 4
.row:
    REPT 4
        ld a, b
        call QueueWrite
        inc de
        inc b
    ENDR
    ld a, e
    add a, 28
    ld e, a
    adc a, d
    sub e
    ld d, a
    dec c
    jr nz, .row
    ret

; ==========================================================================
; Setup 1/2: book three DJs (portrait grid, 3 x 2)
; ==========================================================================
DEF NUM_DJS  EQU 6
DEF DJS_REAL EQU %010101        ; SIMA (0), PATER (2), JOAO (4)

DjsInit:
    call LoadAvatars
    ld a, 1
    ld [wNoFlash], a
    ld hl, DjPalettes
    ld de, wBasePal
    ld bc, 128
    call MemCopy
    DRAW StrPickDjs, 1, 3, 7, 14
    DRAW StrBooked3, 16, 5
    ld c, 0
.portrait:
    push bc
    ld a, c
    ld hl, DjCellMap
    call GetWord            ; bc = map address
    ld d, b
    ld e, c
    pop bc
    push bc
    ld a, c
    swap a                  ; first tile = index * 16
    ld b, a
    ld a, c
    inc a
    or $08                  ; palette 1-6, VRAM bank 1
    ld c, a
    call DrawBlock4
    pop bc
    inc c
    ld a, c
    cp NUM_DJS
    jr nz, .portrait
    xor a
    ld [wDjSel], a
    ld [wDjMask], a
    ld [wDjsDone], a
    call DjNameText
    ld de, _SCRN0 + 14 * 32 + 1
    jp DrawText

; -> hl = padded name of the selected DJ (19 bytes each)
DjNameText:
    ld a, [wDjSel]
    ld b, a
    swap a
    add a, b
    add a, b
    add a, b                ; * 19
    ld hl, DjNamesPadded
    ADD_HL_A
    ret

DjsUpdate:
    call CommonUpdate
    call TextStep
    jr z, .input
    ld a, [wTbDone]
    and a
    jp z, .draw
    xor a
    ld [wTbDone], a
    ld a, [wDjsDone]
    and a
    jr z, .notDone
    ld a, SCR_CRATES
    jp RequestScreen
.notDone:
    ld a, [wDjMask]
    cp DJS_REAL
    jp nz, .draw
    ld a, 1
    ld [wDjsDone], a
    ld hl, TxtLineupDone
    call OpenText
    jp .draw

.input:
    ldh a, [hJoyPressed]
    ld b, a
    ld a, [wDjSel]
    ld c, a
    bit PADB_RIGHT, b
    jr z, .notRight
    cp 2
    jr z, .notRight
    cp 5
    jr z, .notRight
    inc c
.notRight:
    bit PADB_LEFT, b
    jr z, .notLeft
    and a
    jr z, .notLeft
    cp 3
    jr z, .notLeft
    dec c
.notLeft:
    bit PADB_DOWN, b
    jr z, .notDown
    cp 3
    jr nc, .notDown
    add a, 3
    ld c, a
.notDown:
    bit PADB_UP, b
    jr z, .notUp
    cp 3
    jr c, .notUp
    sub 3
    ld c, a
.notUp:
    ld a, [wDjSel]
    cp c
    jr z, .noMove
    ld a, c
    ld [wDjSel], a
    call SfxMove
    call DjNameText
    ld de, _SCRN0 + 14 * 32 + 1
    call QueueText
.noMove:
    ldh a, [hJoyPressed]
    and (1 << PADB_A) | (1 << PADB_START)
    jr z, .draw
    call SfxSelect
    ld a, [wDjSel]
    ld c, a
    ld b, 1
    and a
    jr z, .gotBit
.bitLoop:
    sla b
    dec c
    jr nz, .bitLoop
.gotBit:
    ld a, b
    and DJS_REAL
    jr z, .reply            ; the big names politely decline
    ld a, [wDjMask]
    and b
    ld hl, TxtAlready
    jr nz, .say
    ld a, [wDjMask]
    or b
    ld [wDjMask], a
    ; booked counter
    ld c, CH_0
    ld b, 3
.count:
    rrca
    jr nc, .skipBit
    inc c
.skipBit:
    rrca
    dec b
    jr nz, .count
    ld a, c
    ld de, _SCRN0 + 16 * 32 + 13
    call QueueWrite
.reply:
    ld a, [wDjSel]
    ld hl, DjTexts
    call GetWord
    ld h, b
    ld l, c
.say:
    call OpenText

.draw:
    ; selection frame: 4 corner sprites (slots 0-3), blinking
    ld a, [wDjSel]
    add a, a
    ld hl, DjCellXY
    ADD_HL_A
    ld a, [hl+]
    ld c, a                 ; screen x of the portrait
    ld b, [hl]              ; screen y
    ld hl, wShadowOAM
    ld d, 0                 ; corner: x offset, y offset, attr
    ld e, 4
    push hl
    ld hl, CornerTab
.corner:
    ld a, [hl+]
    add a, c
    ld [wTmp], a            ; x
    ld a, [hl+]
    add a, b
    ld [wTmp + 1], a        ; y
    ld a, [hl+]
    ld [wTmp + 2], a        ; attr
    push hl
    ld hl, wShadowOAM
    ld a, d
    ADD_HL_A
    ld a, [wTmp + 1]
    ld [hl+], a
    ld a, [wTmp]
    ld [hl+], a
    ld a, SPR_CORNER
    ld [hl+], a
    ld a, [wTmp + 2]
    ld [hl], a
    pop hl
    ld a, d
    add a, 4
    ld d, a
    dec e
    jr nz, .corner
    pop hl
    ld a, 16
    ADD_HL_A
.hearts:
    ; hearts on booked DJs (slots 4-9)
    ld a, [wDjMask]
    ld d, a
    ld e, 0
.heart:
    rr d
    jr nc, .noHeart
    push hl
    ld a, e
    add a, a
    ld hl, DjCellXY
    ADD_HL_A
    ld a, [hl+]
    add a, 24 + 8
    ld c, a
    ld a, [hl]
    add a, 16 - 4
    pop hl
    ld [hl+], a
    ld a, c
    ld [hl+], a
    ld a, SPR_HEART
    ld [hl+], a
    ld a, 2
    ld [hl+], a
    jr .nextHeart
.noHeart:
    xor a
    ld [hl+], a
    ld [hl+], a
    ld [hl+], a
    ld [hl+], a
.nextHeart:
    inc e
    ld a, e
    cp NUM_DJS
    jr nz, .heart
    ret

; portrait cells: map address, screen position
DjCellMap:
    dw _SCRN0 + 3 * 32 + 2, _SCRN0 + 3 * 32 + 8, _SCRN0 + 3 * 32 + 14
    dw _SCRN0 + 9 * 32 + 2, _SCRN0 + 9 * 32 + 8, _SCRN0 + 9 * 32 + 14
DjCellXY:
    db 16, 24, 64, 24, 112, 24
    db 16, 72, 64, 72, 112, 72
; x, y offsets (OAM space) and flips for the 4 frame corners
CornerTab:
    db 8 - 4, 16 - 4, 0
    db 8 + 28, 16 - 4, $20
    db 8 - 4, 16 + 28 - 8, $40
    db 8 + 28, 16 + 28 - 8, $60

; ==========================================================================
; Setup 2/2: dig the record crates (slot machine)
; ==========================================================================
DEF NUM_REELS EQU 3

CratesInit:
    call LoadCrates
    ld a, 1
    ld [wNoFlash], a
    ld hl, CratePalettes
    ld de, wBasePal
    ld bc, 128
    call MemCopy
    DRAW StrDigCrates, 1, 2, 4, 16
    ; machine frame (tile rows 3-12)
    ld a, BANK(CrateFrameMap)
    ld hl, CrateFrameMap
    ld de, _SCRN0 + 3 * 32
    ld bc, (20 << 8) | 10
    call CopyRectBank
    ld a, $08 | 7
    ld de, _SCRN0 + 3 * 32
    ld bc, (20 << 8) | 10
    call SetAttrRect
    ld c, 0
.reel:
    push bc
    ld hl, wReelIdx
    ld a, c
    ADD_HL_A
    ld a, c
    add a, a
    ld [hl], a              ; start on sleeves 0, 2, 4
    ld hl, wReelTimer
    ld a, c
    ADD_HL_A
    ld a, c
    add a, 2
    ld [hl], a
    ld hl, wReelDelay
    ld a, c
    ADD_HL_A
    ld [hl], 3
    ld hl, wReelState
    ld a, c
    ADD_HL_A
    ld [hl], 0
    ; draw the sleeve
    ld a, c
    call ReelMapAddr
    ld a, c
    add a, a
    swap a
    add a, SLEEVE_BASE
    ld b, a
    ld a, c
    inc a
    or $08
    ld c, a
    call DrawBlock4
    pop bc
    push bc
    ld a, c
    call ReelPalette
    pop bc
    inc c
    ld a, c
    cp NUM_REELS
    jr nz, .reel
    xor a
    ld [wCratesDone], a
    ld [wReelDirty], a
    ld hl, TxtCratesIntro
    jp OpenText

; a = reel -> de = map address of its window
ReelMapAddr:
    ld e, a
    add a, a
    add a, e
    add a, a                ; * 6
    add a, LOW(_SCRN0 + 5 * 32 + 2)
    ld e, a
    ld d, HIGH(_SCRN0 + 5 * 32 + 2)
    ret

; a = reel: copy its sleeve's palette into BG palette reel + 1
ReelPalette:
    ld c, a
    ld hl, wReelIdx
    ADD_HL_A
    ld a, [hl]
    add a, a
    add a, a
    add a, a                ; * 8 bytes
    ld hl, SleevePalettes
    ADD_HL_A
    ld a, c
    inc a
    add a, a
    add a, a
    add a, a
    ld de, wBasePal
    add a, e
    ld e, a
    ld b, 8
.copy:
    ld a, [hl+]
    ld [de], a
    inc de
    dec b
    jr nz, .copy
    ret

CratesUpdate:
    call CommonUpdate
    call TextStep
    jr z, .input
    ld a, [wTbDone]
    and a
    jr z, .spin
    xor a
    ld [wTbDone], a
    ld a, [wCratesDone]
    and a
    jr z, .spin
    ld a, SCR_LOADING
    jp RequestScreen
.input:
    ldh a, [hJoyPressed]
    and (1 << PADB_A) | (1 << PADB_START)
    jr z, .spin
    ld hl, wReelState       ; stop the first reel that still spins
    ld c, 0
.find:
    ld a, [hl]
    and a
    jr z, .stop
    inc hl
    inc c
    ld a, c
    cp NUM_REELS
    jr nz, .find
    jr .spin
.stop:
    ld [hl], 1
    ld hl, wReelIdx         ; slow down and land on the jackpot sleeve
    ld a, c
    ADD_HL_A
    ld a, JACKPOT + NUM_SLEEVES
    sub [hl]
    cp NUM_SLEEVES
    jr c, .mod
    sub NUM_SLEEVES
.mod:
    add a, NUM_SLEEVES
    ld hl, wReelLeft
    ld b, a
    ld a, c
    ADD_HL_A
    ld [hl], b
    call SfxSelect

.spin:
    ld c, 0
.reelLoop:
    ld hl, wReelState
    ld a, c
    ADD_HL_A
    ld a, [hl]
    cp 2
    jr z, .nextReel
    ld hl, wReelTimer
    ld a, c
    ADD_HL_A
    dec [hl]
    jr nz, .nextReel
    ; next sleeve
    push bc
    ld hl, wReelIdx
    ld a, c
    ADD_HL_A
    ld a, [hl]
    inc a
    cp NUM_SLEEVES
    jr c, .noWrap
    xor a
.noWrap:
    ld [hl], a
    ld a, c
    call ReelPalette
    pop bc
    ld hl, wReelDirty
    ld a, c
    inc a
    ld b, 1
.dirtyBit:
    dec a
    jr z, .setDirty
    sla b
    jr .dirtyBit
.setDirty:
    ld a, [hl]
    or b
    ld [hl], a
    ld hl, wReelDelay
    ld a, c
    ADD_HL_A
    ld b, [hl]
    ld hl, wReelState
    ld a, c
    ADD_HL_A
    ld a, [hl]
    and a
    jr z, .rearm
    push hl                 ; stopping: count down, slow down
    ld hl, wReelLeft
    ld a, c
    ADD_HL_A
    dec [hl]
    pop hl
    jr nz, .slower
    ld [hl], 2              ; stopped
    call SfxMove
    jr .nextReel
.slower:
    inc b
    inc b
    push hl
    ld hl, wReelDelay
    ld a, c
    ADD_HL_A
    ld [hl], b
    pop hl
.rearm:
    ld hl, wReelTimer
    ld a, c
    ADD_HL_A
    ld [hl], b
.nextReel:
    inc c
    ld a, c
    cp NUM_REELS
    jp nz, .reelLoop

    ; redraw one changed reel per frame
    ld a, [wQueueLen]
    and a
    ret nz
    ld a, [wReelDirty]
    and a
    jr z, .allDrawn
    ld c, 0
    ld b, 1
.findDirty:
    ld a, [wReelDirty]
    and b
    jr nz, .draw
    inc c
    sla b
    jr .findDirty
.draw:
    ld a, [wReelDirty]
    xor b
    ld [wReelDirty], a
    ld a, c
    call ReelMapAddr
    ld hl, wReelIdx
    ld a, c
    ADD_HL_A
    ld a, [hl]
    swap a
    add a, SLEEVE_BASE
    ld b, a
    jp QueueBlock4
.allDrawn:
    ; all stopped?
    ld a, [wCratesDone]
    and a
    ret nz
    ld a, [wReelState]
    ld b, a
    ld a, [wReelState + 1]
    and b
    ld b, a
    ld a, [wReelState + 2]
    and b
    cp 2
    ret nz
    ld a, 1
    ld [wCratesDone], a
    call SfxSelect
    ld hl, StrJackpotLabels
    ld de, _SCRN0 + 13 * 32 + 1
    call QueueText
    ld hl, TxtJackpot
    jp OpenText

; ==========================================================================
; Setup 2/2: warm up the turntables
; Up/Down picks a deck, Left/Right scratches, A starts/stops the platter
; (music plays while at least one deck spins)
; ==========================================================================
DEF DECK_A_CX     EQU 8 + 30    ; record centres in screen pixels
DEF DECK_B_CX     EQU 80 + 30
DEF DECK_CY       EQU 24 + 32
DEF VEL_ZERO      EQU 128       ; velocities are biased by 128, 1/16 angle unit per frame
DEF SPIN_SPEED    EQU VEL_ZERO + 40
DEF SCRATCH_SPEED EQU 120

ScratchInit:
    call LoadDeck
    DRAW StrTechSetup, 1, 5, 7, 10
    ld hl, DeckMap
    ld de, _SCRN0 + 3 * 32 + 1
    ld bc, (9 << 8) | 8
    call CopyRect
    ld hl, DeckMap
    ld de, _SCRN0 + 3 * 32 + 10
    ld bc, (9 << 8) | 8
    call CopyRect
    ld a, 4
    ld de, _SCRN0 + 3 * 32 + 1
    ld bc, (9 << 8) | 8
    call SetAttrRect
    ld a, 5
    ld de, _SCRN0 + 3 * 32 + 10
    ld bc, (9 << 8) | 8
    call SetAttrRect
    DRAW StrDeckA, 12, 2, 2, 6
    DRAW StrDeckB, 12, 11, 3, 6
    DRAW StrScratches, 14, 3, 7, 14

    ld hl, DeckPalettes
    ld de, wBasePal + 4 * 8
    ld bc, 16
    call MemCopy

    ; decks spin if the music is on
    ld a, [wMusicOn]
    ld b, a
    ld hl, wDecks
    ld c, 2
    ld e, 0
.deck:
    ld a, b
    ld [hl+], a             ; running
    and a
    ld a, VEL_ZERO
    jr z, .still
    ld a, SPIN_SPEED
.still:
    ld [hl+], a             ; velocity
    xor a
    ld [hl+], a             ; angle (lo)
    ld a, e
    ld [hl+], a             ; angle (hi)
    ld e, 100
    dec c
    jr nz, .deck
    xor a
    ld [wDeckSel], a
    ld [wScratchCnt], a
    ld [wScratchDone], a
    ld hl, TxtTechIntro
    jp OpenText

ScratchUpdate:
    call CommonUpdate
    call TextStep
    jr z, .input
    ld a, [wTbDone]
    and a
    jr z, .input            ; box open: decks keep spinning, pad muted
    xor a
    ld [wTbDone], a
    ld a, [wScratchDone]
    and a
    jr z, .input
    ld a, SCR_END
    jp RequestScreen
.input:

    ldh a, [hJoyPressed]
    and (1 << PADB_UP) | (1 << PADB_DOWN)
    jr z, .noSwitch
    ld a, [wDeckSel]
    xor 1
    ld [wDeckSel], a
    call StopScratch
    call SfxMove
.noSwitch:

    ldh a, [hJoyPressed]
    bit PADB_A, a
    jr z, .noToggle
    call SelDeckPtr
    ld a, [hl]
    xor 1
    ld [hl], a
    call SyncMusic
.noToggle:

    ; count scratches
    ldh a, [hJoyPressed]
    and (1 << PADB_LEFT) | (1 << PADB_RIGHT)
    jr z, .noCount
    ld a, [wScratchCnt]
    cp SCRATCH_GOAL
    jr nc, .noCount
    inc a
    ld [wScratchCnt], a
    add a, CH_0
    ld de, _SCRN0 + 14 * 32 + 14
    call QueueWrite
    ld a, [wScratchCnt]
    cp SCRATCH_GOAL
    jr nz, .noCount
    ld a, 1
    ld [wScratchDone], a
    ld hl, TxtScratchDone
    call OpenText
.noCount:

    ; platter physics: motor pulls slowly, the hand pulls fast
    ld hl, wDecks
    ld c, 0
.phys:
    ld a, [hl+]             ; running?
    and a
    ld b, VEL_ZERO
    jr z, .motorOff
    ld b, SPIN_SPEED
.motorOff:
    ld e, 2
    ld a, [wDeckSel]
    cp c
    jr nz, .noHand
    ldh a, [hPadHeld]
    bit PADB_LEFT, a
    jr z, .notLeft
    ld b, VEL_ZERO - SCRATCH_SPEED
    ld e, 24
.notLeft:
    bit PADB_RIGHT, a
    jr z, .noHand
    ld b, VEL_ZERO + SCRATCH_SPEED
    ld e, 24
.noHand:
    ld a, [hl]
    call StepToward
    ld [hl+], a
    sub VEL_ZERO            ; angle += signed velocity
    ld e, a
    ld d, 0
    bit 7, a
    jr z, .fwd
    dec d
.fwd:
    ld a, [hl]
    add a, e
    ld [hl+], a
    ld a, [hl]
    adc a, d
    ld [hl+], a
    inc c
    ld a, c
    cp 2
    jr nz, .phys

    ; rotation markers
    ld hl, wShadowOAM
    ld de, wDecks + 3
    ld c, DECK_A_CX
    call DeckSprites
    ld de, wDecks + 7
    ld c, DECK_B_CX
    call DeckSprites

    ; deck labels: selected = rainbow, other = grey
    ld a, [wDeckSel]
    and a
    ld a, 2 * 4 + 3
    ld d, 3 * 4 + 3
    jr z, .labels
    ld a, 3 * 4 + 3
    ld d, 2 * 4 + 3
.labels:
    push de
    push af
    ld a, [wFrame]
    add a, a
    and 31
    ld hl, RainbowHi
    call GetWord
    pop af
    call SetPalColor
    pop af                  ; a = d (other label slot)
    ld bc, COL_GREY
    call SetPalColor

    ; scratch tone on CH1 while Left/Right is held
    ldh a, [hPadHeld]
    and (1 << PADB_LEFT) | (1 << PADB_RIGHT)
    jr z, StopScratch
    ld a, 4
    ld [wSfxTimer], a       ; keeps the music off CH1
    call SelDeckPtr
    inc hl
    ld a, [hl]
    sub VEL_ZERO
    jr nc, .abs
    cpl
    inc a
.abs:
    ld l, a                 ; freq = 1100 + |velocity| * 6
    ld h, 0
    add hl, hl
    ld d, h
    ld e, l
    add hl, hl
    add hl, de
    ld de, 1100
    add hl, de
    ld a, [wScratchOn]
    and a
    jr nz, .retune
    inc a
    ld [wScratchOn], a
    xor a
    ldh [rNR10], a
    ldh [rNR11], a
    ld a, $C0
    ldh [rNR12], a
    ld a, l
    ldh [rNR13], a
    ld a, h
    or $80
    ldh [rNR14], a
    ret
.retune:
    ld a, [wFrame]          ; flip duty every frame for grit
    rrca
    rrca
    and $40
    ldh [rNR11], a
    ld a, l
    ldh [rNR13], a
    ld a, h
    ldh [rNR14], a
    ret

StopScratch:
    ld a, [wScratchOn]
    and a
    ret z
    xor a
    ld [wScratchOn], a
    ldh [rNR12], a
    ret

; -> hl = selected deck
SelDeckPtr:
    ld a, [wDeckSel]
    add a, a
    add a, a
    ld hl, wDecks
    ADD_HL_A
    ret

; music plays while at least one deck is running
SyncMusic:
    ld a, [wDecks]
    ld b, a
    ld a, [wDecks + 4]
    or b
    ld b, a
    ld a, [wMusicOn]
    cp b
    ret z
    ld a, b
    and a
    jp z, MusicStop
    jp MusicRestart

; a = current, b = target, e = step -> a moved towards b
StepToward:
    cp b
    ret z
    jr c, .up
    sub e
    jr c, .clamp
    cp b
    ret nc
.clamp:
    ld a, b
    ret
.up:
    add a, e
    jr c, .clamp
    cp b
    ret c
    ld a, b
    ret

; de -> angle (hi), c = centre x, hl -> OAM; writes 2 opposite markers
DeckSprites:
    ld a, [de]
    call .marker
    ld a, [de]
    add a, 128
.marker:
    push de
    ld d, HIGH(SineTab)
    ld e, a
    ld a, [de]              ; dx = sin
    ld b, a
    ld a, e
    sub 64
    ld e, a
    ld a, [de]              ; dy = -cos
    add a, DECK_CY - 3 + 16
    ld [hl+], a
    ld a, b
    add a, c
    add a, 8 - 3
    ld [hl+], a
    ld a, SPR_DOT
    ld [hl+], a
    ld a, 3
    ld [hl+], a
    pop de
    ret

; ==========================================================================
; Loading
; ==========================================================================
LoadingInit:
    ld a, [wMusicOn]        ; decks may have been stopped: the party needs music
    and a
    call z, MusicRestart
    DRAW StrLoading, 6, 2, 4, 16
    ld hl, _SCRN0 + 9 * 32 + 2
    ld b, 16
    ld a, TILE_BAR_EMPTY
    call FillBytes
    ld a, 2
    ld de, _SCRN0 + 9 * 32 + 2
    ld bc, (16 << 8) | 1
    call SetAttrRect
    DRAW LoadMsgs, 12, 2, 3, 16
    ret

LoadingUpdate:
    call CommonUpdate
    ld a, [wTimer]
    inc a
    ld [wTimer], a
    cp 16 * 8 + 40
    jr c, .loading
    ld a, SCR_MAP
    jp RequestScreen
.loading:
    ld b, a
    and 7
    ret nz
    ld a, b
    rrca
    rrca
    rrca
    and 31
    cp 17
    ret nc
    dec a                   ; bar cell 0-15
    ld c, a
    ld hl, _SCRN0 + 9 * 32 + 2
    ADD_HL_A
    ld d, h
    ld e, l
    ld a, TILE_BAR_FULL
    call QueueWrite
    ld a, c                 ; every 4 cells: next message
    and 3
    cp 3
    ret nz
    ld a, c
    inc a
    srl a
    srl a                   ; message 1-4
    ld b, a
    swap a
    add a, b                ; * 17
    ld hl, LoadMsgs
    ADD_HL_A
    ld de, _SCRN0 + 12 * 32 + 2
    jp QueueText

; ==========================================================================
; Bike ride: Karlsruhe Hauptbahnhof -> Ballhaus West, Hirschstrasse 18
; The OpenStreetMap-based map (OW_W x OW_H blocks of 16x16 px) is streamed
; into the 32x32 tile BG ring as the camera moves, one row/column per tile.
; ==========================================================================
DEF CAM_MAX_X    EQU OW_W * 16 - 160
DEF CAM_MAX_Y    EQU OW_H * 16 - 144
DEF CAM_OFF_X    EQU 72
DEF CAM_OFF_Y    EQU 64
DEF STREAM_LEN   EQU 24
DEF WIN_Y_POPUP  EQU 128
DEF POPUP_TIME   EQU 100
DEF GOAL_EVENT   EQU 1

MapInit:
    call LoadOwTiles
    call LoadOwSprites
    xor a
    ld [wRaster], a         ; plain scrolling: no per-line effects
    ld hl, OwPalettes
    ld de, wBasePal
    ld bc, 128
    call MemCopy

    ld hl, wPX
    ld a, LOW(OW_START_X * 16)
    ld [hl+], a
    ld [hl], HIGH(OW_START_X * 16)
    ld hl, wPY
    ld a, LOW(OW_START_Y * 16)
    ld [hl+], a
    ld [hl], HIGH(OW_START_Y * 16)
    ld a, 1                 ; facing north, towards the city
    ld [wDir], a
    xor a
    ld [wMoveCnt], a
    ld [wBumpCool], a
    ld [wPendingEnd], a
    ld [wZone], a
    ld [wPopupTimer], a
    ld [wStreamMode], a

    call MapCamera
    ld a, [wNewTX]
    ld [wCamTX], a
    ld a, [wNewTY]
    ld [wCamTY], a

    ; fill the whole 32x32 ring around the camera (LCD is off)
    ld a, [wCamTY]
    sub 4
    ld b, a
    ld e, 32
.fill:
    push bc
    push de
    ld a, [wCamTX]
    sub 4
    ld c, a
    ld a, 32
    call PrepRow
    ld a, 1
    ld [wStreamMode], a
    call StreamFlush        ; tiles
    call StreamFlush        ; attributes
    pop de
    pop bc
    inc b
    dec e
    jr nz, .fill

    call ObjInit
    ld hl, TxtIntro
    call OpenText
    call MapSprites
    jp ObjDraw

MapUpdate:
    ld hl, wFrame
    inc [hl]
    ld a, [wBumpCool]
    and a
    jr z, .cool
    dec a
    ld [wBumpCool], a
.cool:
    ; Ballhaus West neon flicker
    ld a, [wFrame]
    and $3F
    cp 5
    jr z, .dim
    cp 9
    jr z, .dim
    ld bc, (24 << 10) | (8 << 5) | 31
    jr .neon
.dim:
    ld bc, (10 << 10) | (4 << 5) | 14
.neon:
    ld a, 7 * 4 + 2
    call SetPalColor

    call TextStep
    jr z, .play
    ld a, [wTbDone]
    and a
    jr z, .draw
    xor a
    ld [wTbDone], a
    ld a, [wPendingEnd]
    and a
    jr z, .draw
    ld a, SCR_CLUB
    jp RequestScreen
.play:
    call PlayerUpdate
    call ObjUpdate
    call ObjCollide
.draw:
    call MapCamera
    call MapScroll
    call PopupUpdate
    call MapSprites
    jp ObjDraw

PlayerUpdate:
    ld a, [wMoveCnt]
    and a
    jr z, .idle
    dec a
    ld [wMoveCnt], a
    call StepPlayer
    ld a, [wMoveCnt]
    and a
    ret nz
    jp CheckZone            ; arrived on a new block
.idle:
    ld a, [wHitCool]        ; knocked back by a tram: a short stun
    cp 90 - 24
    ret nc
    ldh a, [hJoyPressed]
    bit PADB_A, a
    jr z, .noA
    call FacingColl
    and $7F
    cp GOAL_EVENT
    jp z, ReachGoal
    ret
.noA:
    ldh a, [hPadHeld]
    ld b, 0
    bit PADB_DOWN, a
    jr nz, .dir
    inc b
    bit PADB_UP, a
    jr nz, .dir
    inc b
    bit PADB_LEFT, a
    jr nz, .dir
    inc b
    bit PADB_RIGHT, a
    ret z
.dir:
    ld a, b
    ld [wDir], a
    call FacingColl
    bit 7, a
    jr nz, .blocked
    ld hl, wPX              ; remember where this move started (tram bumps)
    ld de, wPrevX
    REPT 4
        ld a, [hl+]
        ld [de], a
        inc de
    ENDR
    ld a, 7
    ld [wMoveCnt], a
    jp StepPlayer
.blocked:
    and $7F
    cp GOAL_EVENT
    jp z, ReachGoal
    ld a, [wBumpCool]
    and a
    ret nz
    ld a, 16
    ld [wBumpCool], a
    jp SfxBump

ReachGoal:
    ld a, 1
    ld [wPendingEnd], a
    call SfxSelect
    ld hl, TxtDoor
    jp OpenText

; move the player 2 px in wDir (0 down, 1 up, 2 left, 3 right)
StepPlayer:
    ld a, [wDir]
    ld hl, wPY
    cp 2
    jr c, .axis
    ld hl, wPX
.axis:
    cp 1
    jr z, .minus
    cp 2
    jr z, .minus
    ld a, [hl]
    add a, 2
    ld [hl+], a
    ret nc
    inc [hl]
    ret
.minus:
    ld a, [hl]
    sub 2
    ld [hl+], a
    ret nc
    dec [hl]
    ret

; -> c = block x, b = block y of the player
PlayerBlock:
    ld a, [wPX + 1]
    swap a
    and $F0
    ld c, a
    ld a, [wPX]
    swap a
    and $0F
    or c
    ld c, a
    ld a, [wPY + 1]
    swap a
    and $F0
    ld b, a
    ld a, [wPY]
    swap a
    and $0F
    or b
    ld b, a
    ret

; -> a = collision byte of the block the player faces
FacingColl:
    call PlayerBlock
    ld a, [wDir]
    and a
    jr nz, .notDown
    inc b
    jr .look
.notDown:
    dec a
    jr nz, .notUp
    dec b
    jr .look
.notUp:
    dec a
    jr nz, .right
    dec c
    jr .look
.right:
    inc c
.look:
    call BlockAt
    ld l, a
    ld h, HIGH(OwColl)
    ld a, [hl]
    ret

; c = block x, b = block y -> a = metatile id (border outside the map)
BlockAt:
    ld a, c
    cp OW_W
    jr nc, .border
    ld a, b
    cp OW_H
    jr nc, .border
    add a, a
    ld l, a
    ld h, 0
    ld de, OwRowPtr
    add hl, de
    ld a, [hl+]
    ld h, [hl]
    ld l, a
    ld a, c
    ADD_HL_A
    ld a, [hl]
    ret
.border:
    ld a, OW_BORDER
    ret

; b = tile y, c = tile x (world) -> d = tile, e = attribute. Preserves bc.
GetTileAt:
    push bc
    srl b
    srl c
    call BlockAt
    pop bc
    ld l, a
    ld a, b
    and 1
    add a, a
    ld h, a
    ld a, c
    and 1
    add a, h
    add a, HIGH(OwMtTiles)
    ld h, a
    ld d, [hl]
    add a, 4
    ld h, a
    ld e, [hl]
    ret

; hl = position, c = centre offset, de = max -> hl = clamp(hl - c, 0, de)
CamAxis:
    ld a, l
    sub c
    ld l, a
    ld a, h
    sbc a, 0
    ld h, a
    jr nc, .notNeg
    ld hl, 0
    ret
.notNeg:
    ld a, e
    sub l
    ld a, d
    sbc a, h
    ret nc
    ld h, d
    ld l, e
    ret

; hl -> a = hl / 8
TileOf:
    srl h
    rr l
    srl h
    rr l
    srl h
    rr l
    ld a, l
    ret

MapCamera:
    ld hl, wPX
    ld a, [hl+]
    ld h, [hl]
    ld l, a
    ld c, CAM_OFF_X
    ld de, CAM_MAX_X
    call CamAxis
    ld a, l
    ld [wCamX], a
    ld [wScxTable], a
    ld a, h
    ld [wCamX + 1], a
    call TileOf
    ld [wNewTX], a
    ld hl, wPY
    ld a, [hl+]
    ld h, [hl]
    ld l, a
    ld c, CAM_OFF_Y
    ld de, CAM_MAX_Y
    call CamAxis
    ld a, l
    ld [wCamY], a
    ld [wSCY], a
    ld a, h
    ld [wCamY + 1], a
    call TileOf
    ld [wNewTY], a
    ret

; the camera crossed a tile edge: queue the row/column that comes into view next
MapScroll:
    ld a, [wStreamMode]
    and a
    ret nz                  ; previous one not flushed yet
    ld a, [wNewTX]
    ld b, a
    ld a, [wCamTX]
    cp b
    jr z, .checkY
    ld a, b
    ld [wCamTX], a
    jr c, .right
    dec a                   ; moved left: column left of the view
    jr .column
.right:
    add a, 21               ; moved right: column right of the view
.column:
    ld c, a
    ld a, [wCamTY]
    sub 2
    ld b, a
    ld a, STREAM_LEN
    call PrepColumn
    ld a, 2
    ld [wStreamMode], a
    ret
.checkY:
    ld a, [wNewTY]
    ld b, a
    ld a, [wCamTY]
    cp b
    ret z
    ld a, b
    ld [wCamTY], a
    jr c, .down
    dec a
    jr .row
.down:
    add a, 19
.row:
    ld b, a
    ld a, [wCamTX]
    sub 2
    ld c, a
    ld a, STREAM_LEN
    call PrepRow
    ld a, 1
    ld [wStreamMode], a
    ret

; b = tile y, c = first tile x, a = length -> row buffer + destination
PrepRow:
    ld [wStreamLen], a
    ld a, b
    and 31
    ld l, a
    ld h, 0
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    ld a, c
    and 31
    ld d, a
    or l
    ld l, a
    ld a, h
    add a, HIGH(_SCRN0)
    ld [wStreamDest + 1], a
    ld a, l
    ld [wStreamDest], a
    ld a, 32                ; first segment ends at the ring edge
    sub d
    call SetSegments
    ld hl, wStreamTiles
    ld a, [wStreamLen]
.loop:
    push af
    push hl
    call GetTileAt
    pop hl
    ld [hl], d
    ld a, l
    add a, 32
    ld l, a
    ld [hl], e
    sub 32 - 1
    ld l, a
    inc c
    pop af
    dec a
    jr nz, .loop
    ret

; b = first tile y, c = tile x, a = length -> column buffer + destination
PrepColumn:
    ld [wStreamLen], a
    ld a, b
    and 31
    ld d, a
    ld l, a
    ld h, 0
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    ld a, c
    and 31
    or l
    ld l, a
    ld a, h
    add a, HIGH(_SCRN0)
    ld [wStreamDest + 1], a
    ld a, l
    ld [wStreamDest], a
    ld a, 32
    sub d
    call SetSegments
    ld hl, wStreamTiles
    ld a, [wStreamLen]
.loop:
    push af
    push hl
    call GetTileAt
    pop hl
    ld [hl], d
    ld a, l
    add a, 32
    ld l, a
    ld [hl], e
    sub 32 - 1
    ld l, a
    inc b
    pop af
    dec a
    jr nz, .loop
    ret

; a = room before the ring wraps -> wStreamN1 / wStreamN2
SetSegments:
    ld d, a
    ld a, [wStreamLen]
    cp d
    jr c, .fits
    ld a, d
.fits:
    ld [wStreamN1], a
    ld d, a
    ld a, [wStreamLen]
    sub d
    ld [wStreamN2], a
    ret

; write the prepared row/column: tiles (bank 0) in one VBlank, attributes (bank 1)
; in the next, so each VBlank stays short. Modes: 1/2 = row/column tiles, 3/4 = attributes.
StreamFlush:
    ld a, [wStreamMode]
    cp 3
    jr nc, .attrs
    xor a
    ldh [rVBK], a
    ld hl, wStreamTiles
    call .copy
    ld hl, wStreamMode
    inc [hl]
    inc [hl]
    ret
.attrs:
    ld a, 1
    ldh [rVBK], a
    ld hl, wStreamAttrs
    call .copy
    xor a
    ldh [rVBK], a
    ld [wStreamMode], a
    ret
.copy:
    ld a, [wStreamMode]
    rra
    jr c, .rowCopy
    jr .colCopy

.rowCopy:
    ld a, [wStreamDest]
    ld e, a
    ld a, [wStreamDest + 1]
    ld d, a
    ld a, [wStreamN1]
    ld b, a
.r1:
    ld a, [hl+]
    ld [de], a
    inc e
    dec b
    jr nz, .r1
    ld a, [wStreamN2]
    and a
    ret z
    ld b, a
    ld a, e                 ; wrap to the start of the same map row
    sub 32
    ld e, a
.r2:
    ld a, [hl+]
    ld [de], a
    inc e
    dec b
    jr nz, .r2
    ret

.colCopy:
    ld a, [wStreamDest]
    ld e, a
    ld a, [wStreamDest + 1]
    ld d, a
    ld a, [wStreamN1]
    ld b, a
.c1:
    ld a, [hl+]
    ld [de], a
    ld a, e
    add a, 32
    ld e, a
    jr nc, .c1n
    inc d
.c1n:
    dec b
    jr nz, .c1
    ld a, [wStreamN2]
    and a
    ret z
    ld b, a
    ld d, HIGH(_SCRN0)      ; wrap to the top of the map
    ld a, e
    and 31
    ld e, a
.c2:
    ld a, [hl+]
    ld [de], a
    ld a, e
    add a, 32
    ld e, a
    jr nc, .c2n
    inc d
.c2n:
    dec b
    jr nz, .c2
    ret

; street name pop-up when entering a new street (like the location signs in the GBC games)
CheckZone:
    call PlayerBlock
    srl b
    srl c
    ld a, b
    add a, a
    ld l, a
    ld h, 0
    ld de, OwZoneRowPtr
    add hl, de
    ld a, [hl+]
    ld h, [hl]
    ld l, a
    ld a, c
    ADD_HL_A
    ld a, [hl]
    and a
    ret z
    ld b, a
    ld a, [wZone]
    cp b
    ret z
    ld a, [wTbState]
    and a
    ret nz
    ld a, [wQueueLen]
    and a
    ret nz
    ld a, b
    ld [wZone], a
    ld hl, OwStreetNames
    call GetWord
    ld h, b
    ld l, c
    ; centre the name in 18 columns
    push hl
    ld b, 0
.len:
    ld a, [hl+]
    cp $FF
    jr z, .gotLen
    inc b
    jr .len
.gotLen:
    pop hl
    ld a, 18
    sub b
    srl a
    ld c, a                 ; leading spaces
    ld de, WIN_MAP + 32 + 1
    ld b, 18
    and a
    jr z, .name
.lead:
    xor a
    call QueueWrite
    inc de
    dec b
    dec c
    jr nz, .lead
.name:
    ld a, [hl+]
    cp $FF
    jr z, .trail
    call QueueWrite
    inc de
    dec b
    jr nz, .name
    jr .show
.trail:
    xor a
    call QueueWrite
    inc de
    dec b
    jr nz, .trail
.show:
    xor a
    ld [wWindowOn], a
    ld a, WIN_Y_POPUP
    ld [wWinY], a
    ld a, POPUP_TIME
    ld [wPopupTimer], a
    ret

PopupUpdate:
    ld a, [wPopupTimer]
    and a
    ret z
    ld b, a
    ld a, [wTbState]
    and a
    jr nz, .cancel
    dec b
    ld a, b
    ld [wPopupTimer], a
    cp POPUP_TIME - 4       ; the name has been written by now
    jr nz, .notOn
    ld a, 1
    ld [wWindowOn], a
    ret
.notOn:
    and a
    ret nz
.cancel:
    xor a
    ld [wPopupTimer], a
    ld a, [wTbState]
    and a
    ret nz
    ld [wWindowOn], a
    ret

MapSprites:
    ld hl, wShadowOAM
    ; player tile by direction and pedal frame
    ld a, [wDir]
    add a, a
    ld b, a
    ld a, [wMoveCnt]
    and a
    jr z, .still
    ld a, [wFrame]
    rrca
    rrca
    and 1
    add a, b
    ld b, a
.still:
    push hl
    ld a, b
    ld hl, PlayerTiles
    ADD_HL_A
    ld d, [hl]
    pop hl
    ld a, [wDir]
    cp 3
    ld e, 0
    jr nz, .noFlip
    ld e, $20               ; facing right = left sprite mirrored
.noFlip:
    ; screen position = world - camera
    ld a, [wHitCool]        ; blink after a tram bump
    and 4
    jr z, .visible
    ld d, 0
    ld e, 0
.visible:
    ld a, [wCamX]
    ld c, a
    ld a, [wPX]
    sub c
    add a, 8
    ld c, a
    ld a, [wCamY]
    ld b, a
    ld a, [wPY]
    sub b
    add a, 16
    ld b, a
    ld [hl+], a
    ld a, c
    ld [hl+], a
    bit 5, e
    ld a, d
    jr z, .lt
    add a, 2
.lt:
    ld [hl+], a
    ld a, e
    ld [hl+], a
    ld a, b
    ld [hl+], a
    ld a, c
    add a, 8
    ld [hl+], a
    bit 5, e
    ld a, d
    jr nz, .rt
    add a, 2
.rt:
    ld [hl+], a
    ld a, e
    ld [hl+], a
    ; hl -> OAM slot 2: arrow towards Ballhaus West
    ; b, c = player OAM y / x
    ld a, [wTbState]
    and a
    jr nz, .hideArrow
    push hl
    push bc
    ld hl, wPX
    ld de, OW_GOAL_X * 16
    call Delta16            ; hl = goal - player x
    push hl
    ld hl, wPY
    ld de, OW_GOAL_Y * 16
    call Delta16            ; hl = goal - player y
    pop de                  ; de = dx
    call ArrowDir           ; a = 0 down 1 up 2 left 3 right, $FF = close enough
    pop bc
    pop hl
    cp $FF
    jr z, .hideArrow
    ld d, a
    ld a, [wFrame]          ; bob towards the target
    and 16
    rrca
    rrca
    rrca                    ; 0 or 2
    add a, 20
    ld e, a                 ; distance from the player
    ld a, d
    and a
    jr nz, .aUp
    ld a, b                 ; down
    add a, e
    ld [hl+], a
    ld a, c
    add a, 4
    ld [hl+], a
    ld a, SPR_ARROW_UP
    ld [hl+], a
    ld a, $41               ; Y flip, palette 1
    ld [hl], a
    ret
.aUp:
    dec a
    jr nz, .aLeft
    ld a, b
    sub e
    ld [hl+], a
    ld a, c
    add a, 4
    ld [hl+], a
    ld a, SPR_ARROW_UP
    ld [hl+], a
    ld a, 1
    ld [hl], a
    ret
.aLeft:
    dec a
    jr nz, .aRight
    ld a, b
    add a, 4
    ld [hl+], a
    ld a, c
    sub e
    add a, 4
    ld [hl+], a
    ld a, SPR_ARROW_RIGHT
    ld [hl+], a
    ld a, $21               ; X flip, palette 1
    ld [hl], a
    ret
.aRight:
    ld a, b
    add a, 4
    ld [hl+], a
    ld a, c
    add a, e
    add a, 4
    ld [hl+], a
    ld a, SPR_ARROW_RIGHT
    ld [hl+], a
    ld a, 1
    ld [hl], a
    ret
.hideArrow:
    xor a
    ld [hl], a
    ret

; hl -> 16-bit position, de = target -> hl = target - position (signed)
Delta16:
    ld a, [hl+]
    ld h, [hl]
    ld l, a
    ld a, e
    sub l
    ld l, a
    ld a, d
    sbc a, h
    ld h, a
    ret

; de = dx, hl = dy -> a = direction of the larger axis, $FF when both are small
ArrowDir:
    ld b, 1                 ; up if dy < 0
    bit 7, h
    jr nz, .dyNeg
    ld b, 0
    jr .dyAbs
.dyNeg:
    call NegHL
.dyAbs:
    ld c, 3                 ; right if dx >= 0
    bit 7, d
    jr z, .dxAbs
    ld c, 2
    push hl
    ld h, d
    ld l, e
    call NegHL
    ld d, h
    ld e, l
    pop hl
.dxAbs:
    ; both within 40 px -> no arrow
    ld a, h
    or d
    jr nz, .far
    ld a, l
    cp 40
    jr nc, .far
    ld a, e
    cp 40
    jr nc, .far
    ld a, $FF
    ret
.far:
    ; |dy| > |dx| ?
    ld a, e
    sub l
    ld a, d
    sbc a, h
    ld a, b
    ret c
    ld a, c
    ret

NegHL:
    xor a
    sub l
    ld l, a
    ld a, 0
    sbc a, h
    ld h, a
    ret

PlayerTiles:
    db SPR_BIKE_D0, SPR_BIKE_D1, SPR_BIKE_U0, SPR_BIKE_U1
    db SPR_BIKE_L0, SPR_BIKE_L1, SPR_BIKE_L0, SPR_BIKE_L1

; ==========================================================================
; Trams (yellow, on the real tram lines) and trains behind the Hauptbahnhof
; object: type (1 tram across, 2 tram along, 3 train), pos (dw), fixed (dw), min (dw), max (dw)
; ==========================================================================
DEF OBJ_SIZE  EQU 9
DEF MAX_OBJS  EQU 6

ObjInit:
    ld hl, wObjs
    ld b, MAX_OBJS * OBJ_SIZE
    xor a
    call FillBytes
    ld hl, OwTrams
    ld a, [hl+]
    ld c, a                 ; number of tram routes
    ld de, wObjs
.tram:
    ld a, c
    and a
    jr z, .trains
    ld a, [hl+]             ; 0 across, 1 along
    inc a
    ld [de], a
    inc de
    push hl                 ; pos = start (+ some offset so they are spread out)
    inc hl
    inc hl
    ld a, [hl+]
    ld b, [hl]
    pop hl
    ld [de], a
    inc de
    ld a, b
    ld [de], a
    inc de
    REPT 6                  ; fixed, min, max
        ld a, [hl+]
        ld [de], a
        inc de
    ENDR
    dec c
    jr .tram
.trains:
    ld hl, TrainInit
    ld b, 2 * OBJ_SIZE
.copy:
    ld a, [hl+]
    ld [de], a
    inc de
    dec b
    jr nz, .copy
    ret

TrainInit:
    db 3
    dw 40, OW_TRAIN_Y1, 0, OW_W * 16
    db 3
    dw 300, OW_TRAIN_Y2, 0, OW_W * 16

; move every object; everything wraps back to its route start
ObjUpdate:
    ld hl, wObjs
    ld c, MAX_OBJS
.loop:
    push bc
    push hl
    ld a, [hl+]
    and a
    jr z, .next
    ld b, 1
    cp 3
    jr nz, .speed
    ld b, 2
.speed:
    ld a, [hl]
    add a, b
    ld [hl+], a
    ld e, a
    ld a, [hl]
    adc a, 0
    ld [hl+], a
    ld d, a                 ; de = pos, hl -> fixed
    inc hl
    inc hl
    ld a, [hl+]
    ld c, a
    ld a, [hl+]
    ld b, a                 ; bc = min, hl -> max
    ld a, [hl+]
    sub e
    ld a, [hl]
    sbc a, d
    jr nc, .next            ; pos <= max
    pop hl
    push hl
    inc hl
    ld [hl], c
    inc hl
    ld [hl], b
.next:
    pop hl
    ld de, OBJ_SIZE
    add hl, de
    pop bc
    dec c
    jr nz, .loop
    ret

; player vs trams: bumped back one block with a ding (no text, keeps the pace)
ObjCollide:
    ld a, [wHitCool]
    and a
    jr z, .check
    dec a
    ld [wHitCool], a
    ret
.check:
    ld hl, wObjs
    ld c, MAX_OBJS
.loop:
    push bc
    ld a, [hl]
    cp 1
    jr z, .across
    cp 2
    jr z, .along
.next:
    pop bc
    ld de, OBJ_SIZE
    add hl, de
    dec c
    jr nz, .loop
    ret
.across:                    ; 32 x 16 at (pos, fixed)
    push hl
    inc hl
    call ReadPair           ; bc = pos, de = fixed
    push de
    ld hl, wPX
    ld a, 32
    call Overlap
    pop bc
    jr nc, .miss
    ld hl, wPY
    ld a, 16
    call Overlap
    jr nc, .miss
    jr .hit
.along:                     ; 16 x 32 at (fixed, pos)
    push hl
    inc hl
    call ReadPair           ; bc = pos, de = fixed
    push bc
    ld b, d
    ld c, e
    ld hl, wPX
    ld a, 16
    call Overlap
    pop bc
    jr nc, .miss
    ld hl, wPY
    ld a, 32
    call Overlap
    jr nc, .miss
.hit:
    pop hl
    pop bc
    ld a, 90
    ld [wHitCool], a
    xor a
    ld [wMoveCnt], a
    ld hl, wPrevX
    ld de, wPX
    REPT 4
        ld a, [hl+]
        ld [de], a
        inc de
    ENDR
    jp SfxDing
.miss:
    pop hl
    jr .next

; hl -> pos, fixed (words) -> bc = pos, de = fixed
ReadPair:
    ld a, [hl+]
    ld c, a
    ld a, [hl+]
    ld b, a
    ld a, [hl+]
    ld e, a
    ld d, [hl]
    ret

; hl -> player coordinate, bc = object coordinate, a = object size
; -> carry if player - object is in (-16, size)
Overlap:
    push af
    ld a, [hl+]
    add a, 16
    ld e, a
    ld a, [hl]
    adc a, 0
    ld d, a                 ; de = player + 16
    ld a, e
    sub c
    ld e, a
    ld a, d
    sbc a, b
    ld d, a                 ; de = player + 16 - object, need 0 < de < size + 16
    pop af
    add a, 16
    ld b, a
    ld a, d
    and a
    ret nz                  ; negative or large: no carry after 'and'
    ld a, e
    and a
    ret z
    cp b
    ret                     ; carry if e < size + 16

; draw all objects from OAM slot 3 (trams 4 entries, trains 8), clear the rest
ObjDraw:
    ld hl, wShadowOAM + 3 * 4
    ld de, wObjs
    ld c, MAX_OBJS
.loop:
    push bc
    ld a, [de]
    and a
    jr z, .next
    push de
    ld b, a
    inc de
    ld a, [de]
    ld [wObjX], a
    inc de
    ld a, [de]
    ld [wObjX + 1], a
    inc de
    ld a, [de]
    ld [wObjY], a
    inc de
    ld a, [de]
    ld [wObjY + 1], a
    ld a, b
    cp 2
    jr z, .along
    jr nc, .train
    ld de, (SPR_TRAM_H << 8) | 2
    call DrawPart
    call ObjRight16
    ld de, ((SPR_TRAM_H + 4) << 8) | 2
    call DrawPart
    jr .done
.along:                     ; pos is y, fixed is x
    call SwapObjXY
    ld de, (SPR_TRAM_V << 8) | 2
    call DrawPart
    call ObjDown16
    ld de, ((SPR_TRAM_V + 4) << 8) | 2
    call DrawPart
    jr .done
.train:
    ld de, (SPR_TRAIN_CAR << 8) | 3
    call DrawPart
    call ObjRight16
    ld de, ((SPR_TRAIN_CAR + 4) << 8) | 3
    call DrawPart
    call ObjRight16
    ld de, ((SPR_TRAIN_FRONT + 4) << 8) | $23   ; front car mirrored: nose to the right
    call DrawPart
    call ObjRight16
    ld de, (SPR_TRAIN_FRONT << 8) | $23
    call DrawPart
.done:
    pop de
.next:
    ld a, OBJ_SIZE
    add a, e
    ld e, a
    adc a, d
    sub e
    ld d, a
    pop bc
    dec c
    jr nz, .loop
.clear:                     ; unused slots up to 40
    ld a, l
    cp LOW(wShadowOAM + 160)
    ret z
    xor a
    ld [hl+], a
    jr .clear

SwapObjXY:
    ld a, [wObjX]
    ld b, a
    ld a, [wObjY]
    ld [wObjX], a
    ld a, b
    ld [wObjY], a
    ld a, [wObjX + 1]
    ld b, a
    ld a, [wObjY + 1]
    ld [wObjX + 1], a
    ld a, b
    ld [wObjY + 1], a
    ret

ObjRight16:
    ld a, [wObjX]
    add a, 16
    ld [wObjX], a
    ret nc
    ld a, [wObjX + 1]
    inc a
    ld [wObjX + 1], a
    ret

ObjDown16:
    ld a, [wObjY]
    add a, 16
    ld [wObjY], a
    ret nc
    ld a, [wObjY + 1]
    inc a
    ld [wObjY + 1], a
    ret

ClearPart:
    xor a
    REPT 8
        ld [hl+], a
    ENDR
    ret

; de = world coordinate, bc = camera, l = limit
; -> a = world - camera + 16 and carry set when 1 <= a < limit
ToScreen:
    ld a, e
    sub c
    ld e, a
    ld a, d
    sbc a, b
    ld d, a
    ld a, e
    add a, 16
    ld e, a
    ld a, d
    adc a, 0
    jr nz, .out
    ld a, e
    and a
    jr z, .out
    cp l
    ld a, e
    ret
.out:
    xor a
    ret

; 16x16 part at world (wObjX, wObjY), tile d, attribute e -> 2 OAM entries at hl
DrawPart:
    push de
    push hl
    ld hl, wObjX
    ld a, [hl+]
    ld e, a
    ld d, [hl]
    ld hl, wCamX
    ld a, [hl+]
    ld c, a
    ld b, [hl]
    ld l, 176
    call ToScreen
    jr nc, .hide
    ld [wTmp], a            ; screen x + 16
    ld hl, wObjY
    ld a, [hl+]
    ld e, a
    ld d, [hl]
    ld hl, wCamY
    ld a, [hl+]
    ld c, a
    ld b, [hl]
    ld l, 160
    call ToScreen
    jr nc, .hide
    ld b, a                 ; OAM y
    pop hl
    pop de
    ld a, [wWindowOn]
    and a
    jr z, .put
    ld a, [wWinY]
    cp b
    jp c, ClearPart
.put:
    ld a, [wTmp]
    sub 8
    ld c, a
    jp Put16
.hide:
    pop hl
    pop de
    jp ClearPart

; ==========================================================================
; Ballhaus West inside: walk to the decks
; ==========================================================================
ClubInit:
    ld a, LAYER_DRUMS | LAYER_BASS | LAYER_KEYS
    ld [wMusicLayers], a
    call LoadClub
    call LoadOwSprites
    xor a
    ld [wRaster], a
    ld a, BANK(ClubMap)
    ld hl, ClubMap
    ld de, _SCRN0
    ld bc, (20 << 8) | 18
    call CopyRectBank
    ld a, 1
    ldh [rVBK], a
    ld a, BANK(ClubAttr)
    ld hl, ClubAttr
    ld de, _SCRN0
    ld bc, (20 << 8) | 18
    call CopyRectBank
    xor a
    ldh [rVBK], a
    ld hl, ClubPalettes
    ld de, wBasePal
    ld bc, 128
    call MemCopy
    ld hl, wPX
    ld a, CLUB_START_X * 16
    ld [hl+], a
    ld [hl], 0
    ld hl, wPY
    ld a, CLUB_START_Y * 16
    ld [hl+], a
    ld [hl], 0
    xor a
    ld [wCamX], a
    ld [wCamX + 1], a
    ld [wCamY], a
    ld [wCamY + 1], a
    ld [wMoveCnt], a
    ld [wClubGo], a
    ld a, 1
    ld [wDir], a
    ld hl, TxtClubIntro
    call OpenText
    jp ClubSprites

ClubUpdate:
    ld hl, wFrame
    inc [hl]
    ld a, [wBeatFlash]
    and a
    jr z, .noDecay
    dec a
    ld [wBeatFlash], a
.noDecay:
    ; dance floor: rotate its four colours on every kick
    ld a, [wBeatFlash]
    cp 8
    jr nz, .noRotate
    ld hl, wBasePal + 3 * 8
    ld a, [hl+]
    ld c, a
    ld a, [hl+]
    ld b, a
    ld de, wBasePal + 3 * 8
    REPT 6
        ld a, [hl+]
        ld [de], a
        inc de
    ENDR
    ld a, c
    ld [de], a
    inc de
    ld a, b
    ld [de], a
.noRotate:
    call TextStep
    jr z, .play
    ld a, [wTbDone]
    and a
    jr z, .draw
    xor a
    ld [wTbDone], a
    ld a, [wClubGo]
    and a
    jr z, .draw
    ld a, SCR_SCRATCH
    jp RequestScreen
.play:
    call ClubPlayer
.draw:
    jp ClubSprites

ClubPlayer:
    ld a, [wMoveCnt]
    and a
    jr z, .idle
    dec a
    ld [wMoveCnt], a
    jp ClubStep
.idle:
    ldh a, [hJoyPressed]
    bit PADB_A, a
    jr z, .noA
    call ClubFacing
    cp $81
    jr z, .decks
    ret
.noA:
    ldh a, [hPadHeld]
    ld b, 0
    bit PADB_DOWN, a
    jr nz, .dir
    inc b
    bit PADB_UP, a
    jr nz, .dir
    inc b
    bit PADB_LEFT, a
    jr nz, .dir
    inc b
    bit PADB_RIGHT, a
    ret z
.dir:
    ld a, b
    ld [wDir], a
    call ClubFacing
    cp $81
    jr z, .decks
    bit 7, a
    jr nz, .bump
    ld a, 15
    ld [wMoveCnt], a
    jr ClubStep
.bump:
    ld a, [wBumpCool]
    and a
    ret nz
    ld a, 16
    ld [wBumpCool], a
    jp SfxBump
.decks:
    ld a, 1
    ld [wClubGo], a
    call SfxSelect
    ld hl, TxtAtDecks
    jp OpenText

; walk 1 px in wDir
ClubStep:
    ld a, [wDir]
    ld hl, wPY
    cp 2
    jr c, .axis
    ld hl, wPX
.axis:
    cp 1
    jr z, .minus
    cp 2
    jr z, .minus
    inc [hl]
    ret
.minus:
    dec [hl]
    ret

; -> a = club collision of the block the player faces
ClubFacing:
    ld a, [wBumpCool]
    and a
    jr z, .cool
    dec a
    ld [wBumpCool], a
.cool:
    ld a, [wPX]
    swap a
    and $0F
    ld c, a
    ld a, [wPY]
    swap a
    and $0F
    ld b, a
    ld a, [wDir]
    and a
    jr nz, .nd
    inc b
    jr .look
.nd:
    dec a
    jr nz, .nu
    dec b
    jr .look
.nu:
    dec a
    jr nz, .r
    dec c
    jr .look
.r:
    inc c
.look:
    ld a, c
    cp 10
    jr nc, .solid
    ld a, b
    cp 9
    jr nc, .solid
    add a, a
    ld e, a
    add a, a
    add a, a
    add a, e                ; y * 10
    add a, c
    ld hl, ClubColl
    ADD_HL_A
    ld a, [hl]
    ret
.solid:
    ld a, $80
    ret

ClubSprites:
    ld hl, wShadowOAM
    ld a, [wDir]
    add a, a
    ld b, a
    ld a, [wMoveCnt]
    and a
    jr z, .still
    ld a, [wFrame]
    rrca
    rrca
    rrca
    and 1
    add a, b
    ld b, a
.still:
    push hl
    ld a, b
    ld hl, WalkTiles
    ADD_HL_A
    ld d, [hl]
    pop hl
    ld a, [wDir]
    cp 3
    ld e, 0
    jr nz, .noFlip
    ld e, $20
.noFlip:
    ld a, [wPX]
    add a, 8
    ld c, a
    ld a, [wPY]
    add a, 16
    ld b, a
    call Put16
    ; three dancers bouncing to the beat
    ld de, Dancers
    ld c, 3
.dancer:
    push bc
    ld a, [de]
    add a, 8
    ld c, a
    inc de
    ld a, [wBeatFlash]
    cp 4
    ld a, [de]
    jr c, .down
    sub 3
.down:
    add a, 16
    ld b, a
    inc de
    ld a, [de]              ; palette
    inc de
    push de
    ld e, a
    ld a, [wFrame]
    and 32
    ld d, SPR_WALK_D0
    jr z, .pose
    ld d, SPR_WALK_L0
.pose:
    call Put16
    pop de
    pop bc
    dec c
    jr nz, .dancer
    ret

; b = OAM y, c = OAM x (left), d = tile, e = attr -> 2 entries at hl
Put16:
    ld a, b
    ld [hl+], a
    ld a, c
    ld [hl+], a
    bit 5, e
    ld a, d
    jr z, .lt
    add a, 2
.lt:
    ld [hl+], a
    ld a, e
    ld [hl+], a
    ld a, b
    ld [hl+], a
    ld a, c
    add a, 8
    ld [hl+], a
    bit 5, e
    ld a, d
    jr nz, .rt
    add a, 2
.rt:
    ld [hl+], a
    ld a, e
    ld [hl+], a
    ret

WalkTiles:
    db SPR_WALK_D0, SPR_WALK_D1, SPR_WALK_U0, SPR_WALK_U1
    db SPR_WALK_L0, SPR_WALK_L1, SPR_WALK_L0, SPR_WALK_L1
; x, y, palette
Dancers:
    db 40, 52, 1
    db 96, 64, 2
    db 64, 76, 3

; ==========================================================================
; Ending: night at Ballhaus West with the animated ENKA logo
; ==========================================================================
DEF NUM_CONFETTI EQU 12

EndInit:
    xor a
    ld [wTimerOn], a
    call LoadEndTiles
    ld a, BANK(EndMap)
    ld hl, EndMap
    ld de, _SCRN0
    ld bc, (20 << 8) | 14
    call CopyRectBank
    ld a, 1
    ldh [rVBK], a
    ld a, BANK(EndAttr)
    ld hl, EndAttr
    ld de, _SCRN0
    ld bc, (20 << 8) | 14
    call CopyRectBank
    xor a
    ldh [rVBK], a
    ; clear the bottom border row
    ld hl, _SCRN0 + 17 * 32
    ld b, 32
    xor a
    call FillBytes
    ld a, 0
    ld de, _SCRN0 + 17 * 32
    ld bc, (32 << 8) | 1
    call SetAttrRect

    ld hl, EndPalettes
    ld de, wBasePal
    ld bc, 128
    call MemCopy

    DRAW StrDateTime, 14, 0, 7, 20
    DRAW StrDJs, 15, 1, 6, 18
    DRAW StrYourTime, 16, 2
    DRAW StrSeeYou, 17, 3, 6, 14

    ; play time m:ss (capped at 9:59)
    ld hl, wPlayTime
    ld a, [hl+]
    ld h, [hl]
    ld l, a
    ld c, 60
    call DivHL              ; de = seconds
    ld a, d
    cp HIGH(600)
    jr c, .noCap
    jr nz, .cap
    ld a, e
    cp LOW(600)
    jr c, .noCap
.cap:
    ld de, 599
.noCap:
    ld h, d
    ld l, e
    ld c, 60
    call DivHL              ; e = minutes, a = seconds
    ld b, a
    ld hl, wBuf
    ld a, e
    add a, CH_0
    ld [hl+], a
    ld a, CH_COLON
    ld [hl+], a
    ld a, b
    call TwoDigits
    ld [hl], $FF
    ld hl, wBuf
    ld de, _SCRN0 + 16 * 32 + 13
    call DrawText

    ld hl, wConfetti
    ld c, NUM_CONFETTI
.conf:
    call Rand
    ld [hl+], a             ; x
    call Rand
    and $7F
    ld [hl+], a             ; y
    call Rand
    ld [hl+], a             ; phase
    dec c
    jr nz, .conf

    ld bc, (48 << 8) | 63
    ld de, (4 << 8) | 15
    jp InitSparkles

EndUpdate:
    ld hl, wFrame
    inc [hl]
    ld a, [wBeatFlash]
    and a
    jr z, .noDecay
    dec a
    ld [wBeatFlash], a
.noDecay:
    ldh a, [hJoyPressed]
    and (1 << PADB_START) | (1 << PADB_A)
    jr z, .stay
    call SfxSelect
    ld a, SCR_TITLE
    jp RequestScreen
.stay:
    ld a, [wFrame]
    ld e, a
    ld a, 1
    call RainbowPal
    ; search lights: colour cycle, white flash on the kick
    ld a, [wBeatFlash]
    cp 5
    ld bc, $7FFF
    jr nc, .beam
    ld a, [wFrame]
    srl a
    srl a
    and 31
    ld hl, RainbowHi
    call GetWord
.beam:
    ld a, 2 * 4 + 2
    call SetPalColor
    ld a, [wFrame]
    and 24
    ld bc, $7FFF
    jr nz, .star
    ld bc, (20 << 10) | (18 << 5) | 18
.star:
    ld a, 2 * 4 + 3
    call SetPalColor
    ld a, [wFrame]
    and $3F
    cp 7
    ld bc, (24 << 10) | (8 << 5) | 31
    jr nz, .neon
    ld bc, (10 << 10) | (4 << 5) | 14
.neon:
    ld a, 4 * 4 + 2
    call SetPalColor
    ld a, [wBeatFlash]
    and a
    ld bc, (28 << 10) | (18 << 5) | 31
    jr nz, .rim
    ld bc, (16 << 10) | (6 << 5) | 18
.rim:
    ld a, 5 * 4 + 3
    call SetPalColor
    call UpdateSparkles

    ; confetti in OAM slots 8-19
    ld hl, wConfetti
    ld de, wShadowOAM + 8 * 4
    ld c, NUM_CONFETTI
.conf:
    ld a, [hl+]
    ld b, a
    ld a, [hl]
    inc a
    ld [hl+], a
    cp 136
    jr c, .onScreen
    xor a
    dec hl
    ld [hl+], a
.onScreen:
    add a, 16
    ld [de], a
    inc de
    ld a, [hl]
    inc [hl]
    inc hl
    push hl
    push de
    ld e, a
    ld d, HIGH(SineTab)
    ld a, [de]
    pop de
    pop hl
    sra a
    sra a
    add a, b
    ld [de], a
    inc de
    ld a, SPR_CONFETTI
    ld [de], a
    inc de
    ld a, c
    and 3
    add a, 4
    ld [de], a
    inc de
    dec c
    jr nz, .conf
    ret

INCLUDE "sound.asm"
INCLUDE "text.asm"

; ==========================================================================
; Graphics & generated data
; ==========================================================================
SECTION "Tiles", ROM0
Tiles0:
    INCBIN "tiles0.2bpp"
Tiles0End:

INCLUDE "data.inc"

; ==========================================================================
; RAM
; ==========================================================================
SECTION "Shadow OAM", WRAM0, ALIGN[8]
wShadowOAM: ds 160

SECTION "SCX table", WRAM0, ALIGN[8]
wScxTable: ds 256

SECTION "Palette buffers", WRAM0, ALIGN[8]
wBasePal: ds 128
wPal:     ds 128

SECTION "Variables", WRAM0
wIsCGB:      db
wScreen:     db
wNextScreen: db
wChangeReq:  db
wFrame:      db
wTimer:      db
wFade:       db
wPalDirty:   db
wObjPalDirty: db
wRand:       db
wBeatFlash:  db
wRaster:     db
wSCY:        db
wRedraw:     db
wQueueLen:   db
wQueue:      ds QUEUE_MAX * 3
wBank1Set:   db
wSceneSet:   db
wBuf:        ds 8
wMarqScx:    db
wMarqPtr:    dw
wSparkX0:    db
wSparkXMask: db
wSparkY0:    db
wSparkYMask: db
wSpark:      ds 4 * 3
wLevels:     ds 8

; text box
wWindowOn:   db
wTbState:    db
wTbDone:     db
wTbRow:      db
wTbPtr:      dw
wTbDest:     dw

; game state
wTimerOn:    db
wPlayTime:   dw
wDjSel:      db
wDjMask:     db
wDjsDone:    db
wDecks:      ds 2 * 4           ; running, velocity, angle lo, angle hi
wDeckSel:    db
wScratchOn:  db
wScratchCnt: db

; overworld
wPX:         dw                 ; player position in pixels
wPY:         dw
wCamX:       dw
wCamY:       dw
wCamTX:      db                 ; camera position in tiles (last streamed)
wCamTY:      db
wNewTX:      db
wNewTY:      db
wDir:        db                 ; 0 down, 1 up, 2 left, 3 right
wMoveCnt:    db
wBumpCool:   db
wPendingEnd: db
wZone:       db
wPopupTimer: db
wWinY:       db
wStreamMode: db                 ; 0 none, 1/2 row/column tiles, 3/4 attributes
wStreamLen:  db
wStreamN1:   db
wStreamN2:   db
wStreamDest: dw
wConfetti:   ds 12 * 3
wPrevX:      dw
wPrevY:      dw
wHitCool:    db
wObjs:       ds 6 * 9
wObjX:       dw
wObjY:       dw
wClubGo:     db
wScratchDone: db
wMusicLayers: db
wNoFlash:    db
wTmp:        ds 4
wReelIdx:    ds 3
wReelTimer:  ds 3
wReelDelay:  ds 3
wReelState:  ds 3
wReelLeft:   ds 3
wReelDirty:  db
wCratesDone: db

SECTION "Stream buffer", WRAM0, ALIGN[6]
wStreamTiles: ds 32
wStreamAttrs: ds 32

SECTION "More variables", WRAM0

; sound driver
wMusicOn:    db
wSongPtr:    dw
wStepTimer:  db
wStepCount:  db
wStepDrums:  db
wStepBass:   db
wStepStab:   db
wStepLead:   db
wArpOn:      db
wArpPos:     db
wArpPtr:     dw
wSfxTimer:   db
wEvKick:     db
wEvBass:     db
wEvStab:     db
wEvClap:     db
wEvHat:      db

SECTION "HRAM", HRAM
hOAMDMA:     ds DMARoutineEnd - DMARoutine
hVBlankFlag: db
hJoyHeld:    db
hJoyPressed: db
hPadHeld:    db                 ; hJoyHeld as seen by the game (0 while muted)
hFadeOff:    db
hTmpR:       db
hTmpG:       db
hTmpSlot:    db
hObjX:       db
