from faster_whisper import WhisperModel
import sounddevice as sd
import soundfile as sf
import numpy as np
import sys

MODEL_SIZE = "small"
LANGUAGE = "pt"
SAMPLE_RATE = 16000
AUDIO_FILE = "/tmp/gravacao.wav"

model = WhisperModel(MODEL_SIZE, device="cpu", compute_type="int8")

print("Whisper pronto!", flush=True)

for line in sys.stdin:
    cmd = line.strip()
    if cmd != "gravar":
        continue

    frames = []

    def callback(indata, *_):
        frames.append(indata.copy())

    with sd.InputStream(samplerate=SAMPLE_RATE, channels=1, callback=callback):
        sys.stdin.readline()  # aguarda linha vazia (Enter do bash)

    if not frames:
        print("__vazio__", flush=True)
        continue

    audio = np.concatenate(frames)
    sf.write(AUDIO_FILE, audio, SAMPLE_RATE)

    segments, _ = model.transcribe(AUDIO_FILE, language=LANGUAGE)
    texto = " ".join(seg.text.strip() for seg in segments).strip()

    print(texto if texto else "__vazio__", flush=True)