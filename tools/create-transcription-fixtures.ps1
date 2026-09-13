param([string]$Ffmpeg = $env:FFMPEG_PATH)
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$output = Join-Path $workspace 'branch-verification\transcription'
$raw = Join-Path $workspace 'entry\src\ohosTest\resources\rawfile'
if (!$Ffmpeg) {
  $bundled = Join-Path $output 'python-deps\imageio_ffmpeg\binaries'
  if (Test-Path -LiteralPath $bundled) {
    $Ffmpeg = Get-ChildItem -LiteralPath $bundled -Filter 'ffmpeg*.exe' | Select-Object -First 1 -ExpandProperty FullName
  }
}
if (!$Ffmpeg -or !(Test-Path -LiteralPath $Ffmpeg)) { throw 'Set FFMPEG_PATH or pass -Ffmpeg with a local ffmpeg executable.' }
New-Item -ItemType Directory -Path $output, $raw -Force | Out-Null
Add-Type -AssemblyName System.Speech
$voice = New-Object System.Speech.Synthesis.SpeechSynthesizer
$wav = Join-Path $output 'fixture-source.wav'
try {
  $voice.SelectVoice('Microsoft Huihui Desktop')
  $format = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(48000, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono)
  $voice.SetOutputToWaveFile($wav, $format)
  $voice.Speak('我们正在学习应用开发。这是一段面试录音。语音识别可以把录音转换成文字，方便学习和复习。')
} finally { $voice.Dispose() }
& $Ffmpeg -hide_banner -loglevel error -y -i $wav -af 'apad=pad_dur=1' -ar 48000 -ac 1 -c:a aac -b:a 100k (Join-Path $raw 'transcription_fixture.m4a')
if ($LASTEXITCODE -ne 0) { throw 'Speech fixture encoding failed' }
& $Ffmpeg -hide_banner -loglevel error -y -f lavfi -i 'anullsrc=r=48000:cl=mono' -t 2 -c:a aac (Join-Path $raw 'transcription_silence.m4a')
if ($LASTEXITCODE -ne 0) { throw 'Silence fixture encoding failed' }
& $Ffmpeg -hide_banner -loglevel error -y -stream_loop 4 -i (Join-Path $raw 'transcription_fixture.m4a') -c copy (Join-Path $raw 'transcription_long.m4a')
if ($LASTEXITCODE -ne 0) { throw 'Long speech fixture encoding failed' }
Write-Output 'Generated synthetic Mandarin and silence fixtures for ohosTest only; no microphone recording.'
