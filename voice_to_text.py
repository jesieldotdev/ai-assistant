#!/usr/bin/env python3

import sys
import threading
import numpy as np
import sounddevice as sd
import soundfile as sf
from faster_whisper import WhisperModel

# --- Configurações ---
SAMPLE_RATE = 16000
CHANNELS = 1
MODEL_SIZE = "small"  # tiny, base, small, medium, large
LANGUAGE = "pt"       # português
AUDIO_FILE = "/tmp/gravacao.wav"

# --- Carrega modelo (baixa na primeira vez) ---
print(f"Carregando modelo Whisper '{MODEL_SIZE}'...")
model = WhisperModel(MODEL_SIZE, device="cpu", compute_type="int8")
print("Modelo carregado!\n")

def gravar() -> np.ndarray:
    """Grava áudio até o usuário pressionar Enter."""
    frames = []
    gravando = True

    def callback(indata, frame_count, time_info, status):
        if gravando:
            frames.append(indata.copy())

    print("🔴 Gravando... pressione Enter para parar.")
    with sd.InputStream(samplerate=SAMPLE_RATE, channels=CHANNELS, callback=callback):
        input()  # aguarda Enter

    return np.concatenate(frames, axis=0) if frames else np.array([])

def transcrever(audio: np.ndarray) -> str:
    """Transcreve o áudio com Whisper."""
    # Salva temporariamente em arquivo
    sf.write(AUDIO_FILE, audio, SAMPLE_RATE)
    segments, info = model.transcribe(AUDIO_FILE, language=LANGUAGE)
    texto = " ".join(seg.text.strip() for seg in segments)
    return texto

def main():
    print("=== Voz para Texto ===")
    print("Pressione Enter para iniciar a gravação.\n")

    while True:
        try:
            input()  # aguarda Enter para começar
            audio = gravar()

            if audio.size == 0:
                print("Nenhum áudio capturado.\n")
                continue

            print("⏳ Transcrevendo...")
            texto = transcrever(audio)

            print(f"\n📝 {texto}\n")
            print("-" * 40)
            print("Pressione Enter para gravar novamente. Ctrl+C para sair.\n")

        except KeyboardInterrupt:
            print("\nSaindo.")
            sys.exit(0)

if __name__ == "__main__":
    main()