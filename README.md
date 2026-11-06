# Tagant Stage — iPad two-screen karaoke (test build)

- **iPad screen:** native remote (choose creature, sky, mic, record, hear the last take).
- **TV / projector (HDMI):** the Godot stage only.
- Works on iPad (A16) with a free Apple ID through SideStore. No paid developer account.

## How it is built
1. `native/tagant_display/` — Swift plugin. It moves Godot's picture onto the external-display
   scene and draws the remote on the iPad. It talks to Godot over UDP on localhost (47100 in, 47101 out).
2. `godot/` — Godot 4.7.2 project (stage + audio). The plugin is in `godot/ios/plugins/tagant_display`.
3. `.github/workflows/build-ipa.yml` — a GitHub macOS runner builds the unsigned IPA and
   publishes it on the **latest** release page.

## Install on the iPad
Open the repo's Releases › *latest* in Safari › tap `TagantStage.ipa` › Share › SideStore.
Refresh in SideStore every 7 days.

## Commands (panel → stage), assembly edition: song:N water cam:N hud quality:N lang:en/ar rec play stop
`creature:N` · `sky:N` · `mic:on|off` · `rec:start|stop` · `play:last` · `stop`
