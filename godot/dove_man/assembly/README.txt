THE ASSEMBLY - claiming water from the titan
============================================
A scene built on the latest Dove Man set (crowd_fix): the desert, Dove Man, the palms,
the rock camels, the wreckage hills, the petrified crowds and the doves. Nobody walks:
the creatures stand together in a crescent, facing the water titan (your Godzilla model
with the water-titan skin), and sing a chant to claim water.

Open: double-click PLAY_DoveMan_assembly.bat (in tagant-00)
Scene: res://dove_man/assembly/dove_man_assembly.tscn

TWO VERSIONS: English and Arabic
  C:\Users\azoor\Documents\tagant-karaoke\assembly-karaoke\PLAY_AssemblyKaraoke_EN.bat
  C:\Users\azoor\Documents\tagant-karaoke\assembly-karaoke\PLAY_AssemblyKaraoke_AR.bat
  The chant lines are Amazigh and Arabic (fusha). Amazigh lines show Tifinagh under the Latin (EN)
  or under the Arabic letters (AR). Fonts: Noto Sans / Noto Naskh Arabic / Noto Sans Tifinagh (OFL).

THE OPENING (first song): about 50 s before the singing starts -
  1 the desert from high, drifting toward Dove Man  2 low among the petrified crowds
  3 Dove Man from below  4 the titan comes out of the haze: two steps, seen from the sand in front of it
  5 the counter view over the titan's shoulder: the crowd coming across the desert.
  Later songs: only 4 and 5. Any camera key (0-6) skips it. Key 6 = the view from under the titan.

HERDS, NOT ROWS (Oct 30)
  The crowd stands in 12 herds of different sizes, each dominated by one kind (mynas, snake-heads,
  hyenas, or mixed), loosely facing the titan. With the people-animals walk ordinary animals:
  hyenas, ibexes, camels, mules (bodies from the Eye and the Needle beasts, wings and props hidden)
  and doves that fly in and land. Everyone has the same skin family (one earth colour, lighter/darker).
  Settings: "herds" in assembly.json. Models: dove_man\assembly\animals\

THE TITAN does not sing. It stands planted and only attacks: a water cannon sweeping the crowd.
  Whoever is hit is knocked down, gets up and runs; the whole crowd breaks away from it,
  then walks back (faster while you sing). Key W = the water now.

YOUR PART: sing your own chant about water, in your own language. The line for each round is
  shown on screen, from dove_man\assembly\lyrics_water.txt (placeholders - put your own words there).

(older notes) Who stands where (facing the titan, Dove Man behind them)
  front rows  : mynas (3 rows)
  then        : hyenas (2 rows), long-ears (2 rows)
  then        : the six wounded giants, the two camels
  at the back : the four dinosaurs
  rock camels stay where they always were, like an outer audience.

The chant (one cycle, ~96 s, then it repeats)
  gathering (dinosaurs hum) -> call: mynas -> response: all -> call: hyenas -> all
  -> call: long-ears -> all -> call: camels + wounded giants -> all
  -> the titan answers (wind) -> silence, the doves -> all together -> breath

Voices (from the animal karaoke recordings, in voices/)
  mynas: myna_flock_01      hyenas: hyena_02         long-ears: donkey_valley_01
  giants: hybrid_human_animal_01                     camels: camel_choir_04
  dinosaurs: camel_flock_05 pitched down             doves: dove_flock_01
  titan: wind_haboob (from the herding karaoke's Pd winds), pitched down

How singing moves the bodies
  - mynas switch to their talking clip; hyenas and long-ears lift neck and head
  - camels lift their necks and open the jaw with the loudness of the voice
  - dinosaurs raise their heads out of grazing and swell their chests
  - everyone leans back when the titan answers; the titan shifts its weight foot to foot
  - the voice ripples from the front rows to the back

THE KARAOKE (songs on the left; Tab = next song)
  1 · Workers' call   - led by the caravan camel
  2 · Long-ears' call - led by a donkey
  3 · The chant       - the automatic choir, no singer needed
  In 1 and 2 the crowd first walks in from the desert and gathers. Then:
    LISTEN      the leader calls a phrase (cut from its own recording)
    YOUR TURN   repeat it into the microphone; the crowd repeats it with you,
                louder the louder you sing. Your voice is drawn over the phrase (green).
                "the crowd follows you" = how close your answer is to the call.
    WATER       after 3 rounds, then every 4, the titan turns its water on the crowd
                like a police water cannon; whoever is hit or near runs away.
    REGROUP     they walk back to their places - faster while you keep singing.
  The song is 14 rounds, ends with everyone together, and starts again.
  Without a microphone the crowd still answers, quietly.

Keys: 0 auto camera · 1 wide · 2 behind the choir · 3 what the titan sees
      4 portrait of a singer · 5 from above · H hide the text · Esc quit

Everything (rows, distances, voices, the chant, the songs, the leaders, the water attacks) is in assembly.json.
No existing Dove Man file was changed.
