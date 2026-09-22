; ENKA @ Ballhaus West -- Game Boy Color promo cartridge
; 32 KiB ROM, no MBC, CGB only. Build with ./build.sh (RGBDS 1.0).
;
; Flow: title -> setup (start time, DJs, scratch practice) -> loading ->
;       bike ride through Karlsruhe to Ballhaus West @ Europaplatz -> ending

INCLUDE "hardware.inc"
INCLUDE "gfx_defs.inc"

DEF LCDC_ON    EQU %11010111   ; LCD on, window map $9C00, tiles $8000, BG map $9800, OBJ 8x16
DEF LCDCF_WIN  EQU %00100000
DEF WIN_MAP    EQU $9C00
DEF WIN_Y      EQU 96          ; text box = bottom 6 tile rows
DEF QUEUE_MAX  EQU 24
DEF KICK_FREQ  EQU $700

DEF SCR_TITLE   EQU 0
DEF SCR_TIME    EQU 1
DEF SCR_DJS     EQU 2
DEF SCR_SCRATCH EQU 3
DEF SCR_LOADING EQU 4
DEF SCR_MAP     EQU 5
DEF SCR_END     EQU 6

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

DEF NUM_TIMES    EQU 5
DEF NUM_DJS      EQU 5
DEF DJS_REAL     EQU %00101     ; SIMA (0) + PATER JOAO (2)
DEF SCRATCH_GOAL EQU 8
DEF DOOR_EVENT   EQU 31
DEF TRACK_Y      EQU 8 * 16

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
LoadBank1:
    ld a, 1
    ldh [rVBK], a
    ld de, _VRAM
    call MemCopy
    xor a
    ldh [rVBK], a
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
    ld de, _VRAM + SCENE_BASE * 16
    jp MemCopy

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
    inc a
    ld [wRaster], a
    ret

InitTable:
    dw TitleInit, TimeInit, DjsInit, ScratchInit, LoadingInit, MapInit, EndInit
UpdateTable:
    dw TitleUpdate, TimeUpdate, DjsUpdate, ScratchUpdate, LoadingUpdate, MapUpdate, EndUpdate

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
; Title
; ==========================================================================
TitleInit:
    call LoadBigFont
    call LoadLogo
    ld hl, LogoMap
    ld de, _SCRN0 + 2 * 32 + 2
    ld bc, (16 << 8) | 4
    call CopyRect
    ld a, 1
    ld de, _SCRN0 + 2 * 32 + 2
    ld bc, (16 << 8) | 4
    call SetAttrRect

    DRAW StrVenue, 7, 2
    DRAW StrDateLong, 9, 0, 3, 19
    DRAW StrPressStart, 11, 4, 5, 11
    DRAW StrLineupTBA, 16, 4, 2, 12

    ; marquee rows use the 2x font from VRAM bank 1
    ld a, $08 | 4
    ld de, _SCRN0 + 13 * 32
    ld bc, (32 << 8) | 2
    call SetAttrRect
    ld a, 255
    ld [wMarqScx], a
    ld a, LOW(MarqText)
    ld [wMarqPtr], a
    ld a, HIGH(MarqText)
    ld [wMarqPtr + 1], a

    ld bc, (24 << 8) | 127
    ld de, (12 << 8) | 31
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
    ld [wTramBumps], a
    ld [wDjMask], a
    ld a, 2
    ld [wTimeSel], a
    ld a, 1
    ld [wTimerOn], a
    ld a, SCR_TIME
    jp RequestScreen
.noInput:

    ; wavy logo (lines 16-47)
    ld a, [wFrame]
    add a, a
    add a, a
    ld c, a
    ld hl, wScxTable + 16
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

    ; marquee (lines 104-119)
    ld a, [wMarqScx]
    inc a
    ld [wMarqScx], a
    ld hl, wScxTable + 104
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
    ld hl, _SCRN0 + 13 * 32
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

    ; blinking PRESS START
    ld a, [wFrame]
    and 32
    ld bc, $7FFF
    jr z, .blinkOn
    ld hl, wBasePal + 5 * 8 ; hide: text colour = background colour
    ld c, [hl]
    inc l
    ld b, [hl]
.blinkOn:
    ld a, 5 * 4 + 3
    call SetPalColor

    jp UpdateSparkles

; ==========================================================================
; Setup 1/3: start time
; ==========================================================================
TimeInit:
    call LoadBigFont
    DRAW StrSetup1, 1, 2, 4, 16
    DRAW StrPickTime, 3, 0
    DRAW StrArrowUp, 6, 9, 3, 1
    DRAW StrArrowDn, 10, 9, 3, 1
    DRAW StrTimeHint, 15, 2
    ld a, $08 | 1
    ld de, _SCRN0 + 7 * 32 + 5
    ld bc, (10 << 8) | 2
    call SetAttrRect
    ld a, 2
    ld de, _SCRN0 + 12 * 32 + 2
    ld bc, (16 << 8) | 1
    call SetAttrRect
    call TimeBigPtr
    ld de, _SCRN0 + 7 * 32 + 5
    call DrawBig
    call TimeCommentPtr
    ld de, _SCRN0 + 12 * 32 + 2
    jp DrawText

; -> hl = big "22:00" string for wTimeSel
TimeBigPtr:
    ld hl, TimesBig
    jr TimeEntry
; -> hl = small "22:00" string
TimeSmallPtr:
    ld hl, TimesSmall
TimeEntry:
    ld a, [wTimeSel]
    ld b, a
    add a, a
    add a, b
    add a, a                ; * 6
    ADD_HL_A
    ret
; -> hl = comment for wTimeSel (17 bytes each)
TimeCommentPtr:
    ld a, [wTimeSel]
    ld b, a
    swap a                  ; * 16
    add a, b                ; * 17
    ld hl, TimeComments
    ADD_HL_A
    ret

TimeUpdate:
    call CommonUpdate

    ; redraw in two frames: big digits (20 writes), then the comment (16)
    ld a, [wRedraw]
    and a
    jr z, .noRedraw
    dec a
    ld [wRedraw], a
    jr z, .comment
    call TimeBigPtr
    ld de, _SCRN0 + 7 * 32 + 5
    call QueueBigText
    jr .noRedraw
.comment:
    call TimeCommentPtr
    ld de, _SCRN0 + 12 * 32 + 2
    call QueueText
.noRedraw:

    ldh a, [hJoyPressed]
    ld b, a
    and (1 << PADB_UP) | (1 << PADB_RIGHT)
    jr z, .notUp
    ld a, [wTimeSel]
    inc a
    cp NUM_TIMES
    jr c, .setTime
    xor a
    jr .setTime
.notUp:
    ld a, b
    and (1 << PADB_DOWN) | (1 << PADB_LEFT)
    jr z, .notDown
    ld a, [wTimeSel]
    dec a
    cp NUM_TIMES
    jr c, .setTime
    ld a, NUM_TIMES - 1
.setTime:
    ld [wTimeSel], a
    ld a, 2
    ld [wRedraw], a
    call SfxMove
    jr .anim
.notDown:
    ld a, b
    and (1 << PADB_A) | (1 << PADB_START)
    jr z, .anim
    call SfxSelect
    ld a, SCR_DJS
    jp RequestScreen

.anim:
    ld a, [wFrame]
    ld e, a
    ld a, 1
    call RainbowPal
    ; arrows pulse
    ld a, [wFrame]
    and 16
    ld bc, (31 << 10) | (12 << 5) | 12
    jr z, .arrowCol
    ld bc, $7FFF
.arrowCol:
    ld a, 3 * 4 + 3
    jp SetPalColor

; ==========================================================================
; Setup 2/3: book the DJs
; ==========================================================================
DjsInit:
    DRAW StrSetup2, 1, 2, 4, 16
    DRAW StrBookDjs, 2, 3
    DRAW StrBooked, 9, 4
    DRAW StrDjHint, 11, 2
    ; list rows 4-8, one palette each
    ld hl, DjNames
    ld de, _SCRN0 + 4 * 32 + 4
    ld c, 0
.row:
    push bc
    push de
    call DrawText
    pop de
    push hl
    ld a, c
    ld hl, RowPal
    ADD_HL_A
    ld a, [hl]
    ld bc, (15 << 8) | 1
    push de
    call SetAttrRect
    pop de
    pop hl
    NEXT_ROW_DE
    pop bc
    inc c
    ld a, c
    cp NUM_DJS
    jr nz, .row
    xor a
    ld [wDjSel], a
    ld [wDjMask], a
    ld [wDjsDone], a
    ret

RowPal:
    db 1, 2, 3, 5, 7

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
    ld a, SCR_SCRATCH
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
    bit PADB_DOWN, b
    jr z, .notDown
    ld a, [wDjSel]
    inc a
    cp NUM_DJS
    jr c, .setSel
    xor a
    jr .setSel
.notDown:
    bit PADB_UP, b
    jr z, .notUp
    ld a, [wDjSel]
    dec a
    cp NUM_DJS
    jr c, .setSel
    ld a, NUM_DJS - 1
.setSel:
    ld [wDjSel], a
    call SfxMove
    jr .draw
.notUp:
    ld a, b
    and (1 << PADB_A) | (1 << PADB_START)
    jr z, .draw
    call SfxSelect
    ; bit for this DJ
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
    jr z, .reply            ; joke candidates just get a reply
    ld a, [wDjMask]
    and b
    ld hl, TxtAlready
    jr nz, .say
    ld a, [wDjMask]
    or b
    ld [wDjMask], a
    ; heart next to the name + counter
    ld a, [wDjSel]
    swap a
    add a, a                ; * 32
    ld hl, _SCRN0 + 4 * 32 + 17
    ADD_HL_A
    ld d, h
    ld e, l
    ld a, CH_HEART
    call QueueWrite
    ld a, [wDjMask]
    ld b, CH_0 + 1
    cp DJS_REAL
    jr nz, .count
    inc b
.count:
    ld a, b
    ld de, _SCRN0 + 9 * 32 + 12
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
    ld c, 0
.pal:
    push bc
    call DjRowColor
    pop bc
    inc c
    ld a, c
    cp NUM_DJS
    jr nz, .pal

    ; cursor
    ld a, [wDjSel]
    add a, 4
    add a, a
    add a, a
    add a, a
    add a, 16
    ld hl, wShadowOAM
    ld [hl+], a
    ld a, [wFrame]
    add a, a
    add a, a
    ld e, a
    ld d, HIGH(SineTab)
    ld a, [de]
    sra a
    sra a
    sra a
    add a, 16 + 8
    ld [hl+], a
    ld a, SPR_CURSOR
    ld [hl+], a
    xor a
    ld [hl], a
    ret

; c = row: selected = rainbow, booked = green, others = grey
DjRowColor:
    ld a, c
    ld hl, RowPal
    ADD_HL_A
    ld a, [hl]
    add a, a
    add a, a
    add a, 3
    ldh [hTmpSlot], a
    ld a, [wDjSel]
    cp c
    jr nz, .notSel
    ld a, [wFrame]
    add a, a
    and 31
    ld hl, RainbowHi
    call GetWord
    jr .set
.notSel:
    ld a, [wDjMask]
    inc c
.shift:
    dec c
    jr z, .test
    rrca
    jr .shift
.test:
    bit 0, a
    ld bc, COL_GREY
    jr z, .set
    ld bc, COL_GREEN
.set:
    ldh a, [hTmpSlot]
    jp SetPalColor

; ==========================================================================
; Setup 3/3: warm up the turntables
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
    DRAW StrSetup3, 1, 2, 7, 16
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
    DRAW StrTurnHint1, 15, 1
    DRAW StrTurnHint2, 16, 3

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
    ret

ScratchUpdate:
    call CommonUpdate
    call TextStep
    jr z, .input
    ld a, [wTbDone]
    and a
    jr z, .input            ; box open: decks keep spinning, pad muted
    ld a, SCR_LOADING
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
    DRAW StrLoading, 4, 2, 4, 16
    ld hl, _SCRN0 + 7 * 32 + 2
    ld b, 16
    ld a, TILE_BAR_EMPTY
    call FillBytes
    ld a, 2
    ld de, _SCRN0 + 7 * 32 + 2
    ld bc, (16 << 8) | 1
    call SetAttrRect
    DRAW LoadMsgs, 10, 2, 3, 16
    DRAW StrDJs, 13, 1, 2, 17
    DRAW StrStartLbl, 14, 4
    call TimeSmallPtr
    ld de, _SCRN0 + 14 * 32 + 11
    jp DrawText

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
    ld hl, _SCRN0 + 7 * 32 + 2
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
    ld de, _SCRN0 + 10 * 32 + 2
    jp QueueText

; ==========================================================================
; Bike ride: Karlsruhe, Marktplatz -> Europaplatz
; ==========================================================================
MapInit:
    call LoadOwTiles
    call LoadOwSprites
    xor a
    ld [wRaster], a         ; plain scrolling: no per-line effects
    ld hl, OwMap
    ld de, _SCRN0
    ld bc, 1024
    call MemCopy
    ld a, 1
    ldh [rVBK], a
    ld hl, OwAttr
    ld de, _SCRN0
    ld bc, 1024
    call MemCopy
    xor a
    ldh [rVBK], a
    ld hl, OwPalettes
    ld de, wBasePal
    ld bc, 128
    call MemCopy

    ld a, OW_START_X * 16
    ld [wPX], a
    ld [wPrevX], a
    ld a, OW_START_Y * 16
    ld [wPY], a
    ld [wPrevY], a
    ld a, 2                 ; facing left
    ld [wDir], a
    xor a
    ld [wMoveCnt], a
    ld [wLastBump], a
    ld [wPendingEnd], a
    ld [wBumpCool], a
    ld a, 200
    ld [wTramX], a
    call MapCamera
    ld hl, TxtIntro
    call OpenText
    jp MapSprites

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
    and $7F
    cp 3
    jr z, .dim
    cp 7
    jr z, .dim
    ld bc, (24 << 10) | (8 << 5) | 31
    jr .neon
.dim:
    ld bc, (10 << 10) | (4 << 5) | 14
.neon:
    ld a, 5 * 4 + 2
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
    ld a, SCR_END
    jp RequestScreen
.play:
    ld hl, wTramX
    dec [hl]
    dec [hl]
    call PlayerUpdate
    call TramCheck
.draw:
    call MapCamera
    jp MapSprites

PlayerUpdate:
    ld a, [wMoveCnt]
    and a
    jr z, .idle
    dec a
    ld [wMoveCnt], a
    jp StepPlayer
.idle:
    ldh a, [hJoyPressed]
    bit PADB_A, a
    jr z, .noA
    call FacingTile
    cp $FF
    ret z
    ld l, a
    ld h, HIGH(OwColl)
    ld a, [hl]
    and $1F
    ret z
    jp TriggerEvent
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
    call FacingTile
    cp $FF
    jr z, .bump
    ld l, a
    ld h, HIGH(OwColl)
    ld a, [hl]
    bit 7, a
    jr nz, .blocked
    ; free: start riding
    ld a, [wPX]
    ld [wPrevX], a
    ld a, [wPY]
    ld [wPrevY], a
    xor a
    ld [wLastBump], a
    ld a, 7
    ld [wMoveCnt], a
    jr StepPlayer
.blocked:
    and $1F
    jr z, .bump
    ld b, a                 ; riding into someone/something talks once
    ld a, [wLastBump]
    cp b
    jr z, .bump
    ld a, b
    ld [wLastBump], a
    jr TriggerEvent
.bump:
    ld a, [wBumpCool]
    and a
    ret nz
    ld a, 16
    ld [wBumpCool], a
    jp SfxBump

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
    inc [hl]
    inc [hl]
    ret
.minus:
    dec [hl]
    dec [hl]
    ret

; -> a = index (y * 16 + x) of the tile the player faces, $FF = outside the map
FacingTile:
    ld a, [wPX]
    swap a
    and $0F
    ld c, a                 ; tile x
    ld a, [wPY]
    swap a
    and $0F
    ld b, a                 ; tile y
    ld a, [wDir]
    and a
    jr nz, .notDown
    ld a, b
    cp 15
    jr z, .outside
    inc b
    jr .index
.notDown:
    dec a
    jr nz, .notUp
    ld a, b
    and a
    jr z, .outside
    dec b
    jr .index
.notUp:
    dec a
    jr nz, .right
    ld a, c
    and a
    jr z, .outside
    dec c
    jr .index
.right:
    ld a, c
    cp 15
    jr z, .outside
    inc c
.index:
    ld a, b
    swap a
    or c
    ret
.outside:
    ld a, $FF
    ret

; a = event id: 1-15 signs/doors, 16+ NPCs, DOOR_EVENT = Ballhaus West
TriggerEvent:
    cp DOOR_EVENT
    jr nz, .notDoor
    ld a, 1
    ld [wPendingEnd], a
    ld hl, TxtDoor
    jp OpenText
.notDoor:
    cp 16
    jr c, .static
    sub 16                  ; NPC index -> type
    ld b, a
    add a, a
    add a, b
    ld hl, OwNpcs + 2
    ADD_HL_A
    ld a, [hl]
    ld hl, NpcTexts
    jr .say
.static:
    ld hl, EventTexts
.say:
    call GetWord
    ld h, b
    ld l, c
    jp OpenText

; the tram runs along row 8 from right to left
TramCheck:
    ld a, [wPY]
    sub TRACK_Y
    jr nc, .absY
    cpl
    inc a
.absY:
    cp 16
    ret nc
    ld a, [wTramX]
    ld b, a
    ld a, [wPX]
    sub b                   ; player within the tram's 48 px?
    cp 48
    jr c, .hit
    ld a, [wPX]
    ld c, a
    ld a, b
    sub c                   ; tram front less than 16 px ahead of the player?
    cp 16
    ret nc
.hit:
    ; back to where this move started, off the tracks
    xor a
    ld [wMoveCnt], a
    ld a, [wPrevY]
    cp TRACK_Y
    jr nz, .setY
    ld a, TRACK_Y + 16
.setY:
    ld [wPY], a
    ld a, [wPrevX]          ; row 9 is walkable between columns 1 and 14
    cp 16
    jr nc, .xMin
    ld a, 16
.xMin:
    cp 14 * 16 + 1
    jr c, .xMax
    ld a, 14 * 16
.xMax:
    ld [wPX], a
    ld a, [wTramBumps]
    cp 99
    jr z, .maxBumps
    inc a
    ld [wTramBumps], a
.maxBumps:
    call SfxDing
    ld hl, TxtTram
    jp OpenText

MapCamera:
    ld a, [wPX]
    sub 72
    jr nc, .x1
    xor a
.x1:
    cp 97
    jr c, .x2
    ld a, 96
.x2:
    ld [wScxTable], a
    ld [wCamX], a
    ld a, [wPY]
    sub 56
    jr nc, .y1
    xor a
.y1:
    cp 113
    jr c, .y2
    ld a, 112
.y2:
    ld [wSCY], a
    ld [wCamY], a
    ret

MapSprites:
    ld hl, wShadowOAM
    ; player
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
    ld a, [wPX]
    ld c, a
    ld a, [wPY]
    ld b, a
    call DrawObj

    ; NPCs
    ld de, OwNpcs
    ld a, OW_NUM_NPCS
.npc:
    push af
    ld a, [de]
    ld c, a
    inc de
    ld a, [de]
    ld b, a
    inc de
    ld a, [de]
    inc de
    push de
    push hl
    ld hl, NpcSprites
    add a, a
    ADD_HL_A
    ld a, [hl+]
    ld d, a
    ld e, [hl]
    pop hl
    call DrawObj
    pop de
    pop af
    dec a
    jr nz, .npc

    ; tram (3 x 16 px)
    ld a, [wTramX]
    ld c, a
    ld b, TRACK_Y
    ld d, SPR_TRAM
    ld e, 6
    call DrawObj
    ld a, c
    add a, 16
    ld c, a
    ld d, SPR_TRAM + 4
    call DrawObj
    ld a, c
    add a, 16
    ld c, a
    ld d, SPR_TRAM + 8
    jp DrawObj

; 16x16 object at world (c, b), tiles d..d+3, attr e -> 2 OAM entries at hl.
; Preserves bc, de.
DrawObj:
    push bc
    ld a, c
    ldh [hObjX], a
    ; y on screen
    ld a, [wCamY]
    ld c, a
    ld a, b
    sub c
    jr nc, .yBelow
    cp 256 - 15
    jr c, .hide
    jr .yOk
.yBelow:
    cp 144
    jr nc, .hide
.yOk:
    add a, 16
    ld b, a                 ; OAM y
    ld a, [wWindowOn]       ; keep sprites off the text box
    and a
    jr z, .xPos
    ld a, b
    cp WIN_Y + 1
    jr nc, .hide
.xPos:
    ld a, [wCamX]
    ld c, a
    ldh a, [hObjX]
    sub c
    jr nc, .xRight
    cp 256 - 15
    jr c, .hide
    jr .xOk
.xRight:
    cp 160
    jr nc, .hide
.xOk:
    add a, 8
    ld c, a                 ; OAM x (left half)
    ld a, b
    ld [hl+], a
    ld a, c
    ld [hl+], a
    bit 5, e
    ld a, d
    jr z, .leftTile
    add a, 2
.leftTile:
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
    jr nz, .rightTile
    add a, 2
.rightTile:
    ld [hl+], a
    ld a, e
    ld [hl+], a
    pop bc
    ret
.hide:
    xor a
    REPT 8
        ld [hl+], a
    ENDR
    pop bc
    ret

PlayerTiles:
    db SPR_BIKE_D0, SPR_BIKE_D1, SPR_BIKE_U0, SPR_BIKE_U1
    db SPR_BIKE_L0, SPR_BIKE_L1, SPR_BIKE_L0, SPR_BIKE_L1

; per NPC type: tile, OAM attribute (palette)
NpcSprites:
    db SPR_PERSON, 1        ; oma
    db SPR_WORKER, 3        ; construction worker
    db SPR_PERSON, 2        ; doener guy
    db SPR_GOAT, 5          ; the goat
    db SPR_BOUNCER, 4       ; bouncer

; ==========================================================================
; Ending
; ==========================================================================
EndInit:
    xor a
    ld [wTimerOn], a
    call LoadBigFont
    ld hl, BigEnka
    ld de, _SCRN0 + 1 * 32 + 6
    call DrawBig
    ld a, $08 | 1
    ld de, _SCRN0 + 1 * 32 + 6
    ld bc, (8 << 8) | 2
    call SetAttrRect
    DRAW StrMadeIt, 4, 4, 4, 12
    DRAW StrDateShort, 6, 3, 3, 14
    DRAW StrStartLbl, 7, 4, 3, 12
    call TimeSmallPtr
    ld de, _SCRN0 + 7 * 32 + 11
    call DrawText
    DRAW StrBallhaus, 8, 3
    DRAW StrEuropaplatz, 9, 4
    DRAW StrKarlsruhe, 10, 5
    DRAW StrDJs, 11, 1, 2, 17
    DRAW StrRideTime, 13, 2
    DRAW StrTramBumps, 14, 3
    DRAW StrPressStart, 16, 4, 5, 11

    ; ride time m:ss (capped at 9:59)
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
    ld de, _SCRN0 + 13 * 32 + 13
    call DrawText

    ld hl, wBuf
    ld a, [wTramBumps]
    cp 10
    jr nc, .twoDigits
    add a, CH_0
    ld [hl+], a
    jr .bumpsDone
.twoDigits:
    call TwoDigits
.bumpsDone:
    ld [hl], $FF
    ld hl, wBuf
    ld de, _SCRN0 + 14 * 32 + 15
    call DrawText

    ld hl, wLevels
    ld b, 8
    xor a
    call FillBytes
    ld [wEvKick], a
    ld [wEvBass], a
    ld [wEvStab], a
    ld [wEvClap], a
    ld [wEvHat], a

    ld bc, (40 << 8) | 63
    ld de, (0 << 8) | 15
    jp InitSparkles

EndUpdate:
    call CommonUpdate
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
    ld a, [wFrame]
    add a, 16
    ld e, a
    ld a, 4
    call RainbowPal
    call UpdateSparkles
    ; fall through: party bars

; 8 equalizer bars dancing to the music, behind the text (OAM slots 8-23)
PartyBars:
    ld hl, wLevels
    ld b, 8
.decay:
    ld a, [hl]
    sub 2
    jr nc, .decayOk
    xor a
.decayOk:
    ld [hl+], a
    dec b
    jr nz, .decay

    ld hl, wEvKick
    ld a, [hl]
    and a
    jr z, .noKick
    ld [hl], 0
    ld hl, wLevels + 0
    ld a, 80
    call SetBarPair
.noKick:
    ld hl, wEvBass
    ld a, [hl]
    and a
    jr z, .noBass
    ld [hl], 0
    add a, 30
    ld hl, wLevels + 2
    call SetBarPair
.noBass:
    ld hl, wEvStab
    ld a, [hl]
    and a
    jr z, .noStab
    ld [hl], 0
    ld hl, wLevels + 4
    ld a, 72
    call SetBarPair
.noStab:
    ld hl, wEvClap
    ld a, [hl]
    and a
    jr z, .noClap
    ld [hl], 0
    ld a, 78
    ld [wLevels + 6], a
.noClap:
    ld hl, wEvHat
    ld a, [hl]
    and a
    jr z, .noHat
    ld [hl], 0
    call Rand
    and 15
    add a, 40
    ld [wLevels + 7], a
.noHat:

    ; 2 segments per bar, height = level / 2
    ld hl, wShadowOAM + 8 * 4
    ld de, wLevels
    ld c, 28                ; OAM x of first bar
.bar:
    ld a, [de]
    push de
    srl a
    ld b, a
    ld d, 136               ; OAM y of bottom segment (screen rows 120-135)
    ld e, 0
.seg:
    ld a, b
    cp 16
    jr c, .partial
    sub 16
    ld b, a
    ld a, SPR_BAR + 14
    jr .put
.partial:
    cp 2
    jr c, .hide
    srl a
    dec a
    add a, a
    add a, SPR_BAR
    ld b, 0
    jr .put
.hide:
    xor a
    ld [hl+], a
    ld [hl+], a
    ld [hl+], a
    ld [hl+], a
    jr .next
.put:
    push af
    ld a, d
    ld [hl+], a
    ld a, c
    ld [hl+], a
    pop af
    ld [hl+], a
    ld a, e
    add a, $80 | 4          ; behind the text, green / yellow
    ld [hl+], a
.next:
    ld a, d
    sub 16
    ld d, a
    inc e
    ld a, e
    cp 2
    jr nz, .seg
    pop de
    inc de
    ld a, c
    add a, 16
    ld c, a
    cp 28 + 16 * 8
    jr nz, .bar
    ret

; a = level for bar pair, hl -> first bar level (adds some jitter to the 2nd)
SetBarPair:
    ld [hl+], a
    ld b, a
    call Rand
    and 15
    ld c, a
    ld a, b
    sub c
    ld [hl], a
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
wTimeSel:    db
wDjSel:      db
wDjMask:     db
wDjsDone:    db
wDecks:      ds 2 * 4           ; running, velocity, angle lo, angle hi
wDeckSel:    db
wScratchOn:  db
wScratchCnt: db

; overworld
wPX:         db
wPY:         db
wPrevX:      db
wPrevY:      db
wDir:        db                 ; 0 down, 1 up, 2 left, 3 right
wMoveCnt:    db
wLastBump:   db
wBumpCool:   db
wPendingEnd: db
wTramX:      db
wTramBumps:  db
wCamX:       db
wCamY:       db

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
