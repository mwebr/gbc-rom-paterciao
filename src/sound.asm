; Sound driver: 4-channel classic house loop + sound effects on CH1
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
    ld a, [wMusicLayers]
    and LAYER_BASS
    jr z, .noBass
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
    ld a, [wMusicLayers]
    and LAYER_KEYS
    ret z                   ; no keys: no stabs, no lead
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


SfxDing:
    ld a, 20
    ld [wSfxTimer], a
    xor a
    ldh [rNR10], a
    ld a, $80
    ldh [rNR11], a
    ld a, $F3
    ldh [rNR12], a
    ld a, LOW(1985)
    ldh [rNR13], a
    ld a, $80 | HIGH(1985)
    ldh [rNR14], a
    ret

SfxBump:
    ld a, 6
    ld [wSfxTimer], a
    xor a
    ldh [rNR10], a
    ld a, $40
    ldh [rNR11], a
    ld a, $A1
    ldh [rNR12], a
    ld a, LOW(1400)
    ldh [rNR13], a
    ld a, $80 | HIGH(1400)
    ldh [rNR14], a
    ret
