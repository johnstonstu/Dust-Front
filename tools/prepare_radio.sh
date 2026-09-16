#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for clip in alpine volcanic complete; do
  ffmpeg -hide_banner -loglevel error -y -i "assets/audio/source/radio_${clip}.wav" -af 'highpass=f=350,lowpass=f=3400,acompressor=threshold=-18dB:ratio=4:attack=5:release=80,loudnorm=I=-18:TP=-2:LRA=7' -ar 44100 -ac 1 -c:a pcm_s16le "assets/audio/radio_${clip}.wav"
done
