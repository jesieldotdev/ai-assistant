from kokoro import KPipeline
import pyaudio
import numpy as np
import sys

pipeline = KPipeline(lang_code='p')
pa = pyaudio.PyAudio()
stream = pa.open(format=pyaudio.paFloat32, channels=1, rate=24000, output=True)

print("Kokoro pronto!", flush=True)

for line in sys.stdin:
    texto = line.strip()
    if not texto:
        continue
    
    chunks = []
    for gs, ps, audio in pipeline(texto, voice='pm_santa'):
        chunks.append(audio)
    
    if chunks:
        audio = np.concatenate(chunks)
        stream.write(audio.tobytes())
    
    print("ok", flush=True)
