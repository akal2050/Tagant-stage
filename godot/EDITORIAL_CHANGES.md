# TAGANT / حداء خلان الريح — editorial changes (7 Nov 2026)

Applied to the combined app (The Seven Circles + Ait Wadu), laptop and iPad builds. Original standalone
projects (animal-karaoke, herding-karaoke), audio, Pd patches, models, pitch and spectrogram data: untouched.

## Implemented
- **Opening** (start/start.gd): TAGANT · حداء خلان الريح, the five paragraphs and the question from the brief,
  EN/عربي switch, "Enter the forest / ادخل الغابة" appears once both worlds are loaded (at least 4 s of reading);
  a truthful error line if a world cannot load. Functional subtitle at the bottom.
- **Two entrances**: "Where will your voice go? / إلى أين سيمضي صوتك؟" — THE SEVEN CIRCLES / الدوائر السبع and
  AIT WADU / أيت وادو · The People of the Wind / أهل الريح, with the brief's one-line descriptions. One tap each.
  Returning from a world shows the entrances (with a way back to the opening).
- **Central lexicon**: lexicon/lexicon.json holds every visitor-facing word (opening, entrances, interface,
  categories, voice titles, origin labels). The worlds read it first (Tr.t / HTr.t, Tr.voice / HTr.voice);
  internal IDs unchanged.
- **Categories**: The Animals / الحيوان · The Bestiary / سِفْر الوَحِيش · AIT WADU · The Calls / أيت وادو · النداءات ·
  ADU · The Winds / أضو · الرياح · AGHANIM · Flutes and Flocks / أغانيم · الناي والقطعان.
- **Modes**: Listen / أصغِ · Sing With / غنِّ معه · Practice / تمرّن · Answer / أجب; Previous / Next Call, Record Your
  Voice, Hear Yourself, Your turn, The call returns, Listen again, Back to TAGANT.
- **"Bring the line closer / قرّب منحنى الصوت"** replaces "Fold to my voice", with the tooltip
  "Moves the reference line by octaves. The original voice does not change."
- **No grades in the public view**: percentages, gold "in tune" dots and the score are hidden; Answer replies
  with "… heard you — the call goes on", "The call returns", "Listen again — follow its breath".
  Thresholds and analysis are unchanged underneath.
- **See the sound / انظر إلى الصوت**: default lane = the voice's line (thicker) + your line, no axes; the toggle
  shows the full spectrogram, axes, dB bar, percentages, "Bring the line closer" and the glaze tab.
  Audio and microphone are not affected.
- **Voice origin** under the title: From the archive / من الأرشيف (+ archive code when the title is provisional),
  Synthesised voice / صوت مُركَّب, Imagined voice / صوت متخيَّل, Borrowed voice / صوت مُستعار — "this body sings with
  another animal's voice until its own is made" (storks, vulture, cobra, oryx, bear, horse).
- **Voice titles**: 37 display titles (EN + AR) keyed by the existing IDs; each marked verified (taken from the
  source's own title) or provisional.
- **Fixes found while testing**: Ait Wadu opened on a place that is not in its first section, and its section
  switch jumped to Seven-Circles places ("b1"/"x1"); both now open the first place of the section. Each world
  starts fresh when re-entered.

## Tested (headless walk-through, tools/qa_run.gd, run with `-- --qa`)
Opening → both entrances → both worlds in English and Arabic → all four modes → play/stop → See the sound on/off
→ every section (The Animals, The Bestiary, The Calls, The Winds, Flutes and Flocks) → language switch inside a
world → Back to TAGANT. 0 script errors. Not testable here: the real microphone, real sound output, how the screens
look (no GPU on the build machine), the iPad itself.

## Decisions for the artist (see lexicon.json)
- All animal and wind titles are provisional (e.g. "The Hyena's Other Voice"); archive titles from the source
  list are marked verified; T2090 R12, T2095 R01, R12, R17 are "A Call from the Archive, I–IV" until listened to.
- سِفْر الوَحِيش for the Bestiary; أيت وادو spelling; the Arabic of the wind names.
- Whether the opening should also show the English gloss "The Chant of the Wind's Companions".
- iPad: the TV mirrors the iPad (controls are visible on both). A tablet-only control surface is a later step.
