# Recorded audio overrides

Place original WAV recordings in this folder. The macOS build copies WAV files from
this folder over the generated placeholder effects when packaging the app.

Use these exact base names (44.1 kHz PCM WAV is recommended):

- tool_swing.wav
- device_tap.wav
- device_thud.wav
- glass_tap.wav
- glass_shatter.wav
- surface_scratch.wav
- wood_knock.wav
- metal_clang.wav
- plastic_click.wav
- carpet_thump.wav
- device_rattle.wav
- glass_crackle.wav
- debris_scatter.wav

Only add recordings you created or have permission to use. If a file is absent,
the build keeps the generated placeholder for that sound.
