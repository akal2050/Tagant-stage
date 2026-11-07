TAGANT - ANIMAL KARAOKE   (Godot 4.7, GL Compatibility, Android-ready)
=====================================================================
Project folder : C:\Users\azoor\Documents\tagant-karaoke\animal-karaoke
Play on laptop : C:\Users\azoor\Documents\tagant-karaoke\animal-karaoke\PLAY_AnimalKaraoke.bat
Open in Godot  : C:\Users\azoor\Documents\tagant-karaoke\animal-karaoke\project.godot
Phone app      : TAGANT_Animal_Karaoke.apk (sent in the chat; copy to the phone and open it to install)

THE STAGE  (v2, 28 Oct 2026 - previous version kept in _versions\v01_rings_stage_2026-10-28)
  The Gallery 3 floor as a geological stage, from
  Desktop\TAGANT 1_ Ahwach n Ait Wadu (Project Treatment) AZ OOR\flutes\tagant_gallery 3_FINAL_C3_seven worlds spiral_ring 3.3m.blend
  positions enlarged x5 (room between the circles), cylinders and salt lines x3 so the animals stand life-size:
  - terracotta earth floor slab (the 7.5 x 12 m room, toward the screen) with geological strata on its edges
    (Poly Haven cracked_red_ground)
  - seven salt-crust circles; each rammed-earth cylinder centred on its own circle (heptagonal spiral),
    with the seven lime-wash circles on its top (Poly Haven red_laterite_soil_stones in the lifts)
  - the clay lines of the pentagon / heptagon speaker figures
  - the oil lake of the frogs at the centre listening point
  - Saharan sand band, then the Qur'anic gardens made with Taganat Arabesques: seven shamsa gardens of
    seven lobes, five arabesque-wrapped rammed-earth towers (5/7), arabesque bushes, date palms
    (City of Salt and Blood palm, salt crust removed); dunes and mountains; real sky (Poly Haven HDRI)
  - depth of field follows the singer (Mobile renderer; falls back to Compatibility on old devices)
  Gardens are pre-baked by tools\bake_gardens.gd into gardens\*.scn (ask Claude to re-bake new ones).

THE SINGERS  (body  <-  song)
  Myna               myna-headed hybrid (Dove Man horde)      <- myna_flock_01, hybrid_human_animal_01
  Dove               flying pigeon (Dove Man world)            <- dove_flock_01
  Camel              rigged camel (Dove Man world)             <- camel_flock_05, camel_choir_04
  Goat               goat of the Ait Wadu halqa                <- goat_herd_01 (bells)
  Hyena              spotted hyena (Ait Wadu world)            <- hyena_02
  Jackal             salt fennec (City of Salt and Blood)      <- jackal_night_01   [stand-in body]
  Donkey             salt Barb horse (City of Salt and Blood)  <- donkey_valley_01  [stand-in body]
  Imaginary species  Chimera family 01 (Eye and the Needle), floating over the oil lake <- imaginary_species_01
  Cylinders, small to large: 1 dove, 2 jackal, 3 goat, 4 hyena, 5 myna, 6 donkey, 7 camel.
  EACH BLOCK HAS OPTIONS: pick a block on the left, then at the bottom choose the creature (first list)
  and the voice (second list: its own voices first, then "other voices" for hybrids). All face outward.
    1  Dove / Dove standing / Vulture (salt) / Cobra (salt)
    2  Jackal (salt fennec) / Fennec (salt) / Chimera 02
    3  Goat (Ait Wadu) / Goat (salt) / Oryx (salt)
    4  Hyena (spotted) / Striped hyena (salt) / Chimera 03
    5  Myna (hybrid) / Bear (Ait Wadu) / Chimera 04
    6  Donkey (salt horse) / Oryx (salt) / Camel (walking)
    7  Camel / Camel (walking) / Chimera 05
  Extra voices added: Camel one call, Hyena 01, Myna one bird (clean A/B).
  Frogs              voices in the oil lake (ripples)          <- frogs_01
  Cicadas & crickets voices in the gardens (they sway)        <- cicadas_crickets_01
  Songs = your Pd renders from REAPER Media\TAGANT_pd\synth_animals\<animal>\renders (as .ogg).
  Original models and renders are untouched; the app uses lighter copies in models\ and songs\.

TYPE AND LANGUAGE
  Fonts (SIL Open Font License, files + licences in fonts\): Megrim for Latin titles, Tektur for Latin text,
  Handjet for all Arabic. The button under the four modes switches the whole interface English <-> عربي
  (right-to-left, Eastern Arabic numerals, Arabic names for creatures and voices).

THE FOUR MODES (right side)
  Listen    the animal sings, the lane shows its contour (white line = pitch, thickness = energy,
            grey band at the bottom = breath/energy for noisy calls).
  Sing      sing along; your voice is the red line, gold dots = in tune. "Fold to my voice" moves
            the animal's line by octaves into a human range and scores octave-free.
            Noisy calls (camel, hyena laugh) are scored on being there with the swell, not on a note.
  Rehearse  phrase by phrase (◀ phrase ▶), Loop, speed 1 / 0.75 / 0.5 (pitch kept),
            ● Record take -> ▷ Hear take. Takes are saved as wav in the app's user folder
            (on the laptop: %APPDATA%\Godot\app_userdata\TAGANT Animal Karaoke\takes).
  Dialogue  call and response: the animal calls one phrase, you answer in the gap.
            Scored on contour SHAPE (any key, any octave) + duration. >=60%: it goes on to the
            next phrase and a dove joins the flock; lower: it calls again.
  Tap any body on the stage: it calls one random phrase and becomes the singer.

HOW THE PITCH DATA WAS MADE
  tools\analyse_songs.py (YIN pitch tracker + phrase cutter) -> data\<song>.json
  To add a new Pd render: put the .ogg in songs\, run the script on a 22.05 kHz mono wav copy,
  add the song id to scripts\catalog.gd (ask Claude to do it).

ANDROID
  Package com.azoor.tagant.animalkaraoke, arm64, microphone permission asked at first start.
  Use headphones when singing (the phone speaker otherwise leaks into the microphone).

--- 2026-10-28 evening: stage v3 ---
* Spacing doubled: the seven rammed-earth blocks sit twice as far apart (stage.gd const S = 10). Gardens, backstage, flock and camera orbit are scaled to match.
* Five creatures per block (+ five above the lake): pick them with the on-screen arrows beside each creature. The list is in scripts/catalog.gd SLOTS.
* Facing: every creature faces outward, toward the audience. The old camera-turn is switched off, and each body has its own "yaw" in catalog.gd. All 40 were checked in tools/shot_facing.gd. Corrections: chimera 01 180, chimera 04 135, chimera 05 120.
* Spectrogram: the lane is now a scientific log-frequency spectrogram (50 Hz - 9 kHz, 72 dB, Hz + note axis, seconds, dB bar). The images are in spectra/ (tools/spectrogram.py).
* Interface frames: ui_frames/heptagram | arabesque | signal (made by tools/make_frames.py). To switch family, change const FRAME in scripts/ui.gd ("" = old flat boxes).

--- 2026-10-28 night: stage v4 (minimal screen, blue glazes) ---
* Size: each creature is sized to its own rammed-earth block. Its widest reach stays inside the block top, it grows to at most 1.4x, and its height is capped at 1.6x the block radius. Floating creatures only shrink. Test: tools/shot_fit.gd
* Facing: every creature turns (slowly, around its vertical axis) to look at the karaoke camera.
* Screen:
  - left = a slim strip of block numbers (glyphs for the lake, the frogs, the cicadas)
  - top right = one row of text tabs (modes | glaze | language)
  - spectrogram centred at the bottom
  - creatures are changed with thin chevrons
* Frames: "mix" = arabesque scroll + signal instrument (ui_frames/mix, icons in ui_frames/icons).
* Colours: new blue glazes, cycled with the glaze tab: sky zellige (default), majorelle, lapis, indigo. The old salt/clay/oil/bronze/natural are still in the cycle.

--- 2026-10-29: two sections ---
* ANIMALS: real animals only on the seven blocks (birds, fennec/cobra, goats/oryx, hyenas, bear, horse, camels), plus the frogs and cicadas. The drummer is removed.
* BESTIARY: the imaginary / speculative creatures, grouped by family (drifters, serpents, walkers, chimeras, the myna hybrid), and the space above the lake.
* Switch between them with the ANIMALS / BESTIARY tabs under the title.
* Voices still to build: SOUND_TODO.txt
