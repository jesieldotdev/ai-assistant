from kokoro import KPipeline
import soundfile as sf
import numpy as np

lang_code = 'p'

pipeline = KPipeline(lang_code=lang_code)

text = '''
    Vocês estão prontos para a aventura? O mundo de Kokoro é vasto e cheio de mistérios esperando para serem descobertos. Preparem-se para explorar terras desconhecidas, enfrentar desafios emocionantes e fazer amizades inesquecíveis. A jornada começa agora, e cada passo que vocês derem os levará mais perto de se tornarem verdadeiros heróis de Kokoro. Vamos juntos nessa incrível aventura!
'''

generator = pipeline(text, voice='pm_santa')

audio_chunks = []

for gs, ps, audio in generator:
    audio_chunks.append(audio)
    
audio_complete = np.concatenate(audio_chunks)
sf.write('kokoro_basic_output.wav', audio_complete, 24000)