# ~/kokoro_fala.py
import sys
from kokoro import KPipeline
import pyaudio
import numpy as np

pipeline = KPipeline(lang_code='p')

def falar(texto):
    pa = pyaudio.PyAudio()
    stream = pa.open(format=pyaudio.paFloat32, channels=1, rate=24000, output=True)
    
    generator = pipeline(texto, voice='pm_santa')
    chunks = []
    for gs, ps, audio in generator:
        chunks.append(audio)
    
    if chunks:
        audio = np.concatenate(chunks)
        stream.write(audio.tobytes())
    
    stream.stop_stream()
    stream.close()
    pa.terminate()

if __name__ == "__main__":
    texto = " ".join(sys.argv[1:])
    if texto:
        falar(texto)