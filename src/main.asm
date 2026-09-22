; ENKA @ Ballhaus West -- Game Boy Color promo cartridge
; 32 KiB ROM, no MBC, CGB only. Build with ./build.sh (RGBDS 1.0).

INCLUDE "hardware.inc"
INCLUDE "gfx_defs.inc"

DEF LCDC_ON    EQU %10010111   ; LCD on, tiles $8000, map $9800, OBJ 8x16, OBJ on, BG on
DEF QUEUE_MAX  EQU 16
DEF KICK_FREQ  EQU $700

DEF SCR_TITLE  EQU 0
DEF SCR_MENU   EQU 1
DEF SCR_LINEUP EQU 2
DEF SCR_VENUE  EQU 3
DEF SCR_VIS    EQU 4
DEF SCR_TURN   EQU 5

DEF NUM_ITEMS  EQU 5
DEF ITEM_MUSIC EQU 4

DEF PADB_A      EQU 0
DEF PADB_B      EQU 1
DEF PADB_SELECT EQU 2
DEF PADB_START  EQU 3
DEF PADB_RIGHT  EQU 4
DEF PADB_LEFT   EQU 5
DEF PADB_UP     EQU 6
DEF PADB_DOWN   EQU 7

DEF NUM_NOTES  EQU 6
DEF NUM_STARS  EQU 20

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

; typewriter entry: big char, map row, map column
MACRO TYPE
    db \1
    dw _SCRN0 + (\2) * 32 + (\3)
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

    ; tiles: bank 0 = font/logo/sprites, bank 1 = 2x font
    ld hl, Tiles0
    ld de, _VRAM
    ld bc, Tiles0End - Tiles0
    call MemCopy
    ld a, 1
    ldh [rVBK], a
    ld hl, Tiles1
    ld de, _VRAM
    ld bc, Tiles1End - Tiles1
    call MemCopy
    xor a
    ldh [rVBK], a
    ldh [rSCY], a
    ldh [rSCX], a

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

    ; interrupts: VBlank + STAT (mode 0 / HBlank)
    ld a, %00001000
    ldh [rSTAT], a
    ld a, %00000011
    ldh [rIE], a

    ld a, 4
    ld [wFade], a
    ld a, SCR_TITLE
    ld [wScreen], a
    call EnterScreen

MainLoop:
    call WaitFrame
    call ReadJoy
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
    ld hl, StrNeedCGB1
    ld de, _SCRN0 + 7 * 32 + 3
    call DrawText
    ld hl, StrNeedCGB2
    ld de, _SCRN0 + 9 * 32 + 6
    call DrawText
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

    ld a, [wPalDirty]
    and a
    jr z, .noPal
    xor a
    ld [wPalDirty], a
    call UploadPalettes
.noPal:

    ld a, [wQueueLen]
    and a
    jr z, .noQueue
    ld b, a
    ld hl, wQueue
.queue:
    ld a, [hl+]
    ldh [rVBK], a
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
    ldh [rVBK], a
.noQueue:

    ld a, [wScxTable]
    ldh [rSCX], a
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
    ld hl, wPal
    ld a, $80
    ldh [rBCPS], a
    ld c, LOW(rBCPD)
    REPT 64
        ld a, [hl+]
        ldh [c], a
    ENDR
    ld a, $80
    ldh [rOCPS], a
    ld c, LOW(rOCPD)
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

; --- VRAM write queue (flushed in VBlank) -----------------------------

; a = value, de = VRAM address (bank 0). Preserves all registers.
QueueWrite:
    push hl
    push af
    ld a, [wQueueLen]
    cp QUEUE_MAX
    jr nc, .full
    add a, a
    add a, a
    ld hl, wQueue
    ADD_HL_A
    xor a
    ld [hl+], a
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
    ; red
    ld a, c
    and $1F
    call .map
    ldh [hTmpR], a
    ; green
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
    ; blue
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
    ld a, LCDC_ON
    ldh [rLCDC], a
    xor a
    ldh [rIF], a
    ei
    ld a, 3
.fadeIn:
    ld [wFade], a
    push af
    call ApplyFade
    call WaitFrame
    call WaitFrame
    pop af
    dec a
    cp $FF
    jr nz, .fadeIn
    ret

ScreenReset:
    xor a
    ldh [rVBK], a
    ld hl, _SCRN0
    ld bc, $400
    ld d, 0
    call MemFill
    ld a, 1
    ldh [rVBK], a
    ld hl, _SCRN0
    ld bc, $400
    call MemFill
    xor a
    ldh [rVBK], a

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

    xor a
    ld [wTimer], a
    ld [wBeatFlash], a
    ld [wScratchOn], a      ; any scratch tone was replaced by SfxBack
    ret

InitTable:
    dw TitleInit, MenuInit, LineupInit, VenueInit, VisInit, TurnInit
UpdateTable:
    dw TitleUpdate, MenuUpdate, LineupUpdate, VenueUpdate, VisUpdate, TurnUpdate

; Every screen: frame counter, beat flash on the background colour, borders.
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

; palette `a` colours 2/3 = rainbow, offset by `e`
; a = palette index (0-15), e = rainbow index
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

InitSparkles:
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

; b pressed -> back to menu (for sub screens). Returns nz if leaving.
CheckBack:
    ldh a, [hJoyPressed]
    and (1 << PADB_B) | (1 << PADB_START)
    ret z
    call SfxBack
    ld a, SCR_MENU
    call RequestScreen
    or 1
    ret

; ==========================================================================
; Title screen
; ==========================================================================
TitleInit:
    ld hl, LogoMap
    ld de, _SCRN0 + 2 * 32 + 2
    ld bc, (16 << 8) | 4
    call CopyRect
    ld a, 1
    ld de, _SCRN0 + 2 * 32 + 2
    ld bc, (16 << 8) | 4
    call SetAttrRect

    ld hl, StrVenue
    ld de, _SCRN0 + 7 * 32 + 2
    call DrawText

    ld hl, StrDateLong
    ld de, _SCRN0 + 9 * 32
    call DrawText
    ld a, 3
    ld de, _SCRN0 + 9 * 32
    ld bc, (19 << 8) | 1
    call SetAttrRect

    ld hl, StrPressStart
    ld de, _SCRN0 + 11 * 32 + 4
    call DrawText
    ld a, 5
    ld de, _SCRN0 + 11 * 32 + 4
    ld bc, (11 << 8) | 1
    call SetAttrRect

    ld hl, StrDJs
    ld de, _SCRN0 + 16 * 32 + 1
    call DrawText
    ld a, 2
    ld de, _SCRN0 + 16 * 32 + 1
    ld bc, (18 << 8) | 1
    call SetAttrRect

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

    ld a, 24
    ld [wSparkX0], a
    ld a, 127
    ld [wSparkXMask], a
    ld a, 12
    ld [wSparkY0], a
    ld a, 31
    ld [wSparkYMask], a
    jp InitSparkles

TitleUpdate:
    call CommonUpdate
    ldh a, [hJoyPressed]
    and (1 << PADB_START) | (1 << PADB_A)
    jr z, .noInput
    call SfxSelect
    ld a, SCR_MENU
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

    ; logo colour cycling
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
; Menu
; ==========================================================================
MenuInit:
    ld hl, BigEnka
    ld de, _SCRN0 + 1 * 32 + 6
    call DrawBig
    ld a, $08 | 1
    ld de, _SCRN0 + 1 * 32 + 6
    ld bc, (8 << 8) | 2
    call SetAttrRect

    ld hl, StrVenue
    ld de, _SCRN0 + 4 * 32 + 2
    call DrawText

    ; items: text + one palette per row
    ld hl, MenuItems
    ld de, _SCRN0 + 6 * 32 + 5
    ld c, 0
.item:
    push bc
    push de
    call DrawText
    pop de
    push hl
    ld a, c
    ld hl, ItemPal
    ADD_HL_A
    ld a, [hl]
    ld bc, (12 << 8) | 1
    push de
    call SetAttrRect
    pop de
    pop hl
    ld a, e
    add a, 64
    ld e, a
    adc a, d
    sub e
    ld d, a
    pop bc
    inc c
    ld a, c
    cp NUM_ITEMS
    jr nz, .item

    call MusicStateStr
    ld de, _SCRN0 + 14 * 32 + 12
    call DrawText

    ld hl, StrHint
    ld de, _SCRN0 + 16 * 32 + 3
    call DrawText

    ld a, 40
    ld [wSparkX0], a
    ld a, 63
    ld [wSparkXMask], a
    ld a, 2
    ld [wSparkY0], a
    ld a, 15
    ld [wSparkYMask], a
    jp InitSparkles

; -> hl = "ON " / "OFF"
ItemPal:
    db 2, 3, 4, 5, 7
ItemScreen:
    db SCR_LINEUP, SCR_VENUE, SCR_TURN, SCR_VIS

MusicStateStr:
    ld a, [wMusicOn]
    and a
    ld hl, StrOn
    ret nz
    ld hl, StrOff
    ret

MenuUpdate:
    call CommonUpdate
    ldh a, [hJoyPressed]
    ld b, a
    bit PADB_DOWN, b
    jr z, .notDown
    ld a, [wMenuSel]
    inc a
    cp NUM_ITEMS
    jr c, .downOk
    xor a
.downOk:
    ld [wMenuSel], a
    call SfxMove
.notDown:
    bit PADB_UP, b
    jr z, .notUp
    ld a, [wMenuSel]
    dec a
    cp NUM_ITEMS
    jr c, .upOk
    ld a, NUM_ITEMS - 1
.upOk:
    ld [wMenuSel], a
    call SfxMove
.notUp:
    bit PADB_B, b
    jr z, .notBack
    call SfxBack
    ld a, SCR_TITLE
    jp RequestScreen
.notBack:
    ld a, b
    and (1 << PADB_A) | (1 << PADB_START)
    jr z, .noAction
    ld a, [wMenuSel]
    cp ITEM_MUSIC
    jr z, .toggleMusic
    ld hl, ItemScreen
    ADD_HL_A
    ld a, [hl]
    push af
    call SfxSelect
    pop af
    jp RequestScreen
.toggleMusic:
    ld a, [wMusicOn]
    and a
    jr z, .turnOn
    call MusicStop
    jr .toggled
.turnOn:
    call MusicRestart
.toggled:
    call SfxSelect
    call MusicStateStr
    ld de, _SCRN0 + 14 * 32 + 12
    call QueueText
.noAction:

    ; item palettes: selected = rainbow, others = grey
    ld c, 0
.items:
    ld a, [wMenuSel]
    cp c
    jr nz, .grey
    ld a, [wFrame]
    add a, a
    and 31
    ld hl, RainbowHi
    push bc
    call GetWord
    jr .setItem
.grey:
    push bc
    ld bc, (22 << 10) | (15 << 5) | 13
.setItem:
    pop hl                  ; l = item index
    push hl
    ld a, l
    ld hl, ItemPal
    ADD_HL_A
    ld a, [hl]
    add a, a
    add a, a
    add a, 3
    call SetPalColor
    pop bc
    inc c
    ld a, c
    cp NUM_ITEMS
    jr nz, .items

    ld a, [wFrame]
    ld e, a
    ld a, 1
    call RainbowPal

    ; cursor sprite (slot 0), bobbing sideways
    ld a, [wMenuSel]
    add a, a
    add a, 6
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
    add a, 24 + 8
    ld [hl+], a
    ld a, SPR_CURSOR
    ld [hl+], a
    xor a
    ld [hl], a

    jp UpdateSparkles

; ==========================================================================
; Line-up
; ==========================================================================
LineupInit:
    ld hl, StrLineup
    ld de, _SCRN0 + 2 * 32 + 4
    call DrawText
    ld a, $08 | 1
    ld de, _SCRN0 + 5 * 32 + 6
    ld bc, (8 << 8) | 2
    call SetAttrRect
    ld a, $08 | 3
    ld de, _SCRN0 + 9 * 32
    ld bc, (20 << 8) | 2
    call SetAttrRect
    ld hl, StrVenue
    ld de, _SCRN0 + 13 * 32 + 2
    call DrawText
    ld hl, StrDate
    ld de, _SCRN0 + 14 * 32 + 5
    call DrawText
    ld a, 4
    ld de, _SCRN0 + 14 * 32 + 5
    ld bc, (10 << 8) | 1
    call SetAttrRect
    ld hl, StrBack
    ld de, _SCRN0 + 16 * 32 + 6
    call DrawText

    ld a, LOW(TypeLineup)
    ld [wTypePtr], a
    ld a, HIGH(TypeLineup)
    ld [wTypePtr + 1], a

    ; floating music notes
    ld hl, wNotes
    ld c, NUM_NOTES
    ld b, 40
.notes:
    call Rand
    and 127
    add a, 20
    ld [hl+], a             ; x
    ld a, b
    ld [hl+], a             ; y
    add a, 24
    ld b, a
    call Rand
    ld [hl+], a             ; phase
    dec c
    jr nz, .notes
    ret

LineupUpdate:
    call CommonUpdate
    call CheckBack
    ret nz

    ; typewriter
    ld a, [wTimer]
    inc a
    ld [wTimer], a
    cp 6
    jr c, .noType
    xor a
    ld [wTimer], a
    ld hl, wTypePtr
    ld a, [hl+]
    ld h, [hl]
    ld l, a
    ld a, [hl+]
    cp $FF
    jr z, .noType
    ld b, a
    ld a, [hl+]
    ld e, a
    ld a, [hl+]
    ld d, a
    ld a, l
    ld [wTypePtr], a
    ld a, h
    ld [wTypePtr + 1], a
    ld a, b
    call QueueBig
.noType:

    ; names: rainbow, flash white on the kick
    ld a, [wBeatFlash]
    cp 5
    jr c, .noFlash
    ld bc, $7FFF
    ld a, 1 * 4 + 3
    call SetPalColor
    ld bc, $7FFF
    ld a, 3 * 4 + 3
    call SetPalColor
    jr .notes
.noFlash:
    ld a, [wFrame]
    srl a
    ld e, a
    ld a, 1
    call RainbowPal
    ld a, [wFrame]
    srl a
    add a, 16
    ld e, a
    ld a, 3
    call RainbowPal
.notes:

    ld hl, wNotes
    ld de, wShadowOAM
    ld c, NUM_NOTES
.noteLoop:
    ; hl -> x, y, phase
    inc hl
    ld a, [wFrame]
    and 1
    jr nz, .noMove
    dec [hl]
.noMove:
    ld a, [hl]
    cp 8
    jr nc, .visible
    ld [hl], 176
    dec hl
    call Rand
    and 127
    add a, 20
    ld [hl+], a
.visible:
    ld a, [hl+]             ; y, hl -> phase
    ld [de], a
    inc de
    add a, a
    add a, [hl]
    push hl
    ld l, a
    ld h, HIGH(SineTab)
    ld a, [hl]
    pop hl
    sra a
    sra a
    dec hl
    dec hl
    add a, [hl]             ; + x
    ld [de], a
    inc de
    ld a, SPR_NOTE
    ld [de], a
    inc de
    ld a, $82               ; behind text, OBJ palette 2
    ld [de], a
    inc de
    inc hl
    inc hl
    inc hl
    dec c
    jr nz, .noteLoop
    ret

; ==========================================================================
; Date & venue
; ==========================================================================
VenueInit:
    ld hl, StrSaveDate
    ld de, _SCRN0 + 2 * 32 + 1
    call DrawText
    ld hl, BigDate
    ld de, _SCRN0 + 4 * 32
    call DrawBig
    ld a, $08 | 1
    ld de, _SCRN0 + 4 * 32
    ld bc, (20 << 8) | 2
    call SetAttrRect
    ld hl, StrWeekday
    ld de, _SCRN0 + 7 * 32 + 6
    call DrawText
    ld a, 4
    ld de, _SCRN0 + 7 * 32 + 6
    ld bc, (8 << 8) | 1
    call SetAttrRect
    ld hl, BigBallhaus
    ld de, _SCRN0 + 10 * 32 + 2
    call DrawBig
    ld hl, BigWest
    ld de, _SCRN0 + 12 * 32 + 6
    call DrawBig
    ld a, $08 | 3
    ld de, _SCRN0 + 10 * 32
    ld bc, (20 << 8) | 4
    call SetAttrRect
    ld hl, StrBack
    ld de, _SCRN0 + 16 * 32 + 6
    call DrawText

    ; parallax starfield
    ld hl, wStars
    ld c, NUM_STARS
.stars:
    call Rand
    ld [hl+], a             ; x
    call Rand
    and 127
    add a, 24
    ld [hl+], a             ; y
    ld a, c
    and 3
    jr nz, .speedOk
    inc a
.speedOk:
    ld [hl+], a             ; speed 1-3
    dec c
    jr nz, .stars
    ret

VenueUpdate:
    call CommonUpdate
    call CheckBack
    ret nz

    ld a, [wFrame]
    ld e, a
    ld a, 1
    call RainbowPal

    ; venue name wobble (lines 80-111)
    ld a, [wFrame]
    add a, a
    add a, a
    ld c, a
    ld hl, wScxTable + 80
    ld b, 32
    ld d, HIGH(SineTab)
.wave:
    ld e, c
    ld a, [de]
    sra a
    sra a
    sra a
    ld [hl+], a
    ld a, c
    add a, 4
    ld c, a
    dec b
    jr nz, .wave

    ld hl, wStars
    ld de, wShadowOAM
    ld c, NUM_STARS
.starLoop:
    ld a, [hl+]             ; x
    ld b, a
    ld a, [hl+]             ; y
    ld [de], a
    inc de
    ld a, b
    sub [hl]                ; x -= speed
    dec hl
    dec hl
    ld [hl+], a
    ld [de], a
    inc de
    inc hl
    ld a, [hl+]             ; speed
    cp 3
    ld a, SPR_STAR1
    jr z, .bright
    ld a, SPR_STAR0
.bright:
    ld [de], a
    inc de
    ld a, $83               ; behind text, OBJ palette 3
    ld [de], a
    inc de
    dec c
    jr nz, .starLoop
    ret

; ==========================================================================
; Visualizer
; ==========================================================================
VisInit:
    ld hl, StrNowPlaying
    ld de, _SCRN0 + 1 * 32 + 2
    call DrawText
    ld hl, StrTrack
    ld de, _SCRN0 + 2 * 32 + 3
    call DrawText
    ld a, 3
    ld de, _SCRN0 + 2 * 32 + 3
    ld bc, (14 << 8) | 1
    call SetAttrRect
    ld hl, _SCRN0 + 13 * 32
    ld b, 20
    ld a, TILE_FLOOR
    call FillBytes
    ld a, 2
    ld de, _SCRN0 + 13 * 32
    ld bc, (20 << 8) | 1
    call SetAttrRect
    ld hl, StrBPM
    ld de, _SCRN0 + 15 * 32 + 4
    call DrawText
    ld hl, StrBack
    ld de, _SCRN0 + 16 * 32 + 6
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

VisUpdate:
    call CommonUpdate
    call CheckBack
    ret nz

    ; decay
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

    ; music events -> bars
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
    add a, 30               ; higher notes -> higher bars
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

    ; draw 8 bars x 5 segments (8x16 sprites)
    ld hl, wShadowOAM
    ld de, wLevels
    ld c, 28                ; OAM x of first bar
.bar:
    ld a, [de]
    ld b, a                 ; remaining height
    push de
    ld d, 104               ; OAM y of bottom segment
    ld e, 0                 ; segment index
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
    push hl
    ld a, e
    ld hl, BarPalTab
    ADD_HL_A
    ld a, [hl]
    pop hl
    ld [hl+], a
.next:
    ld a, d
    sub 16
    ld d, a
    inc e
    ld a, e
    cp 5
    jr nz, .seg
    pop de
    inc de
    ld a, c
    add a, 16
    ld c, a
    cp 28 + 16 * 8
    jr nz, .bar
    ret

BarPalTab:
    db 4, 4, 5, 6, 7

; ==========================================================================
; Turntables: two decks, Up/Down picks a deck, Left/Right scratches,
; A starts/stops the platter (music plays while at least one deck spins)
; ==========================================================================
DEF DECK_A_CX     EQU 8 + 30    ; record centres in screen pixels
DEF DECK_B_CX     EQU 80 + 30
DEF DECK_CY       EQU 24 + 32
DEF VEL_ZERO      EQU 128       ; velocities are biased by 128, 1/16 angle unit per frame
DEF SPIN_SPEED    EQU VEL_ZERO + 40
DEF SCRATCH_SPEED EQU 120

TurnInit:
    ld hl, StrTurn
    ld de, _SCRN0 + 1 * 32 + 3
    call DrawText
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

    ld hl, StrDeckA
    ld de, _SCRN0 + 12 * 32 + 2
    call DrawText
    ld hl, StrDeckB
    ld de, _SCRN0 + 12 * 32 + 11
    call DrawText
    ld a, 2
    ld de, _SCRN0 + 12 * 32 + 2
    ld bc, (6 << 8) | 1
    call SetAttrRect
    ld a, 3
    ld de, _SCRN0 + 12 * 32 + 11
    ld bc, (6 << 8) | 1
    call SetAttrRect
    ld hl, StrTurnHint1
    ld de, _SCRN0 + 14 * 32 + 1
    call DrawText
    ld hl, StrTurnHint2
    ld de, _SCRN0 + 15 * 32 + 3
    call DrawText
    ld hl, StrBack
    ld de, _SCRN0 + 16 * 32 + 6
    call DrawText

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
    ret

TurnUpdate:
    call CommonUpdate
    call CheckBack
    ret nz

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
    ldh a, [hJoyHeld]
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
    ld bc, (22 << 10) | (15 << 5) | 13
    call SetPalColor

    ; scratch tone on CH1 while Left/Right is held
    ldh a, [hJoyHeld]
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
; Sound driver
; ==========================================================================
SECTION "Sound", ROM0

MusicRestart:
    xor a
    ld [wMusicOn], a        ; keep the VBlank driver out while we reset
    ld [wArpOn], a
    ld [wStepCount], a
    ld a, LOW(SongStart)
    ld [wSongPtr], a
    ld a, HIGH(SongStart)
    ld [wSongPtr + 1], a
    ld a, 1
    ld [wStepTimer], a
    ld [wMusicOn], a
    ret

MusicStop:
    xor a
    ld [wMusicOn], a
    ld [wArpOn], a
    ldh [rNR22], a
    ldh [rNR30], a
    ldh [rNR42], a
    ld a, [wSfxTimer]
    and a
    ret nz
    xor a
    ldh [rNR12], a
    ret

; called once per frame from VBlank
SoundUpdate:
    ld a, [wMusicOn]
    and a
    jr z, .sfx
    ld hl, wStepTimer
    dec [hl]
    call z, PlayStep
    call ArpUpdate
.sfx:
    ld a, [wSfxTimer]
    and a
    ret z
    dec a
    ld [wSfxTimer], a
    ret

PlayStep:
    ld hl, wSongPtr
    ld a, [hl+]
    ld h, [hl]
    ld l, a
    ld a, [hl+]
    ld [wStepDrums], a
    ld a, [hl+]
    ld [wStepBass], a
    ld a, [hl+]
    ld [wStepStab], a
    ld a, [hl+]
    ld [wStepLead], a
    ld a, l
    cp LOW(SongEnd)
    jr nz, .savePtr
    ld a, h
    cp HIGH(SongEnd)
    jr nz, .savePtr
    ld hl, SongLoop
.savePtr:
    ld a, l
    ld [wSongPtr], a
    ld a, h
    ld [wSongPtr + 1], a

    ; swing: on-beat 16ths last 8 frames, off-beat 16ths 6 frames (~128 BPM)
    ld a, [wStepCount]
    inc a
    ld [wStepCount], a
    and 1
    ld a, 6
    jr z, .setTimer
    ld a, 8
.setTimer:
    ld [wStepTimer], a

    ; drums
    ld a, [wStepDrums]
    bit 0, a
    call nz, PlayKick
    ld a, [wStepDrums]
    bit 3, a
    jr z, .noClap
    call PlayClap
    jr .drumsDone
.noClap:
    bit 2, a
    jr z, .noOpenHat
    call PlayOpenHat
    jr .drumsDone
.noOpenHat:
    bit 1, a
    call nz, PlayClosedHat
.drumsDone:

    ; bass (CH3)
    ld a, [wStepBass]
    and a
    jr z, .noBass
    ld [wEvBass], a
    call GetWaveFreq
    ld a, $80
    ldh [rNR30], a
    ld a, 232               ; ~90 ms pluck
    ldh [rNR31], a
    ld a, $20
    ldh [rNR32], a
    ld a, e
    ldh [rNR33], a
    ld a, d
    or $C0
    ldh [rNR34], a
.noBass:

    ; piano stab (CH2, arpeggiated chord)
    ld a, [wStepStab]
    and a
    jr z, .noStab
    ld [wEvStab], a
    add a, a
    add a, a
    ld hl, ChordTab
    ADD_HL_A
    ld a, l
    ld [wArpPtr], a
    ld a, h
    ld [wArpPtr + 1], a
    xor a
    ld [wArpPos], a
    ld a, [hl]
    call GetSqFreq
    ld a, $80
    ldh [rNR21], a
    ld a, $A3
    ldh [rNR22], a
    ld a, e
    ldh [rNR23], a
    ld a, d
    or $80
    ldh [rNR24], a
    ld a, 1
    ld [wArpOn], a
.noStab:

    ; lead (CH1, breakdown only)
    ld a, [wStepLead]
    and a
    ret z
    ld b, a
    ld a, [wSfxTimer]
    and a
    ret nz
    ld a, b
    call GetSqFreq
    xor a
    ldh [rNR10], a
    ld a, $40
    ldh [rNR11], a
    ld a, $97
    ldh [rNR12], a
    ld a, e
    ldh [rNR13], a
    ld a, d
    or $80
    ldh [rNR14], a
    ret

ArpUpdate:
    ld a, [wArpOn]
    and a
    ret z
    ld a, [wArpPos]
    inc a
    and 3
    ld [wArpPos], a
    ld hl, wArpPtr
    ld b, [hl]
    inc hl
    ld h, [hl]
    ld l, b
    ADD_HL_A
    ld a, [hl]
    call GetSqFreq
    ld a, e
    ldh [rNR23], a
    ld a, d                 ; no trigger: just retune
    ldh [rNR24], a
    ret

; a = note index -> de = frequency register value
GetSqFreq:
    ld hl, SqFreq
    jr GetFreq
GetWaveFreq:
    ld hl, WaveFreq
GetFreq:
    add a, a
    ADD_HL_A
    ld a, [hl+]
    ld e, a
    ld d, [hl]
    ret

PlayKick:
    ld a, 1
    ld [wEvKick], a
    ld a, 8
    ld [wBeatFlash], a
    ld a, [wSfxTimer]
    and a
    ret nz
    ld a, $1A               ; pitch sweep down fast
    ldh [rNR10], a
    ld a, $80
    ldh [rNR11], a
    ld a, $F1
    ldh [rNR12], a
    ld a, LOW(KICK_FREQ)
    ldh [rNR13], a
    ld a, $80 | HIGH(KICK_FREQ)
    ldh [rNR14], a
    ret

PlayClosedHat:
    ld a, 1
    ld [wEvHat], a
    ld a, 58
    ldh [rNR41], a
    ld a, $41
    ldh [rNR42], a
    xor a
    ldh [rNR43], a
    ld a, $C0
    ldh [rNR44], a
    ret

PlayOpenHat:
    ld a, 2
    ld [wEvHat], a
    ld a, $62
    ldh [rNR42], a
    ld a, $10
    ldh [rNR43], a
    ld a, $80
    ldh [rNR44], a
    ret

PlayClap:
    ld a, 1
    ld [wEvClap], a
    ld a, $91
    ldh [rNR42], a
    ld a, $52
    ldh [rNR43], a
    ld a, $80
    ldh [rNR44], a
    ret

; --- sound effects on CH1 (the music leaves CH1 alone while wSfxTimer > 0)

SfxMove:
    ld a, 6
    ld [wSfxTimer], a
    xor a
    ldh [rNR10], a
    ld a, $80
    ldh [rNR11], a
    ld a, $A1
    ldh [rNR12], a
    ld a, LOW(1923)
    ldh [rNR13], a
    ld a, $80 | HIGH(1923)
    ldh [rNR14], a
    ret

SfxSelect:
    ld a, 14
    ld [wSfxTimer], a
    ld a, $15               ; pitch sweep up
    ldh [rNR10], a
    ld a, $80
    ldh [rNR11], a
    ld a, $C2
    ldh [rNR12], a
    ld a, LOW(1750)
    ldh [rNR13], a
    ld a, $80 | HIGH(1750)
    ldh [rNR14], a
    ret

SfxBack:
    ld a, 10
    ld [wSfxTimer], a
    ld a, $1D               ; pitch sweep down
    ldh [rNR10], a
    ld a, $80
    ldh [rNR11], a
    ld a, $B2
    ldh [rNR12], a
    ld a, LOW(1800)
    ldh [rNR13], a
    ld a, $80 | HIGH(1800)
    ldh [rNR14], a
    ret

; ==========================================================================
; Text
; ==========================================================================
SECTION "Text", ROM0
StrNeedCGB1:   db "GAME BOY COLOR", $FF
StrNeedCGB2:   db "NEEDED!", $FF
StrVenue:      db "@ BALLHAUS WEST", $FF
StrDateLong:   db "THURSDAY 29.10.2026", $FF
StrDate:       db "29.10.2026", $FF
StrWeekday:    db "THURSDAY", $FF
StrPressStart: db "PRESS START", $FF
StrDJs:        db "SIMA + PATER JO~O", $FF
MenuItems:
    db "LINE UP", $FF
    db "DATE + VENUE", $FF
    db "TURNTABLES", $FF
    db "VISUALIZER", $FF
    db "MUSIC:", $FF
StrOn:         db "ON ", $FF
StrOff:        db "OFF", $FF
StrHint:       db "<UP><DN> MOVE  A:OK", $FF
StrLineup:     db "- LINE UP -", $FF
StrSaveDate:   db "- SAVE THE DATE -", $FF
StrBack:       db "B: BACK", $FF
StrNowPlaying: db "- NOW PLAYING -", $FF
StrTrack:      db "ENKA HOUSE JAM", $FF
StrBPM:        db "* 128 BPM *", $FF
StrTurn:       db "- TURNTABLES -", $FF
StrDeckA:      db "DECK A", $FF
StrDeckB:      db "DECK B", $FF
StrTurnHint1:  db "<UP><DN> DECK <LT><RT> SCRATCH", $FF
StrTurnHint2:  db "A: START/STOP", $FF

PUSHC
SETCHARMAP big
BigEnka:     db "ENKA", $FF
BigDate:     db "29.10.2026", $FF
BigBallhaus: db "BALLHAUS", $FF
BigWest:     db "WEST", $FF
MarqText:
    db "ENKA @ BALLHAUS WEST * THURSDAY 29.10.2026 * "
    db "DJS: SIMA + PATER JO~O * SEE YOU ON THE DANCEFLOOR! * ", $FF

TypeLineup:
    TYPE "S", 5, 6
    TYPE "I", 5, 8
    TYPE "M", 5, 10
    TYPE "A", 5, 12
    TYPE "P", 9, 0
    TYPE "A", 9, 2
    TYPE "T", 9, 4
    TYPE "E", 9, 6
    TYPE "R", 9, 8
    TYPE "J", 9, 12
    TYPE "O", 9, 14
    TYPE "~", 9, 16
    TYPE "O", 9, 18
    db $FF
POPC

; ==========================================================================
; Graphics & generated data
; ==========================================================================
SECTION "Tiles", ROM0
Tiles0:
    INCBIN "tiles0.2bpp"
Tiles0End:
Tiles1:
    INCBIN "tiles1.2bpp"
Tiles1End:

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
wRand:       db
wBeatFlash:  db
wQueueLen:   db
wQueue:      ds QUEUE_MAX * 4
wMenuSel:    db
wMarqScx:    db
wMarqPtr:    dw
wTypePtr:    dw
wSparkX0:    db
wSparkXMask: db
wSparkY0:    db
wSparkYMask: db
wSpark:      ds 4 * 3
wNotes:      ds NUM_NOTES * 3
wStars:      ds NUM_STARS * 3
wLevels:     ds 8
wDecks:      ds 2 * 4           ; running, velocity, angle lo, angle hi
wDeckSel:    db
wScratchOn:  db

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
hFadeOff:    db
hTmpR:       db
hTmpG:       db
