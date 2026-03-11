#!/bin/bash

echo "Escolha o modelo:"
echo "1) Qwen 3B (rápido)"
echo "2) Qwen Coder 7B (melhor)"
read -p "Opção: " op

case $op in
  1) MODEL=~/qwen3b.gguf ;;
  2) MODEL=~/qwen7b.gguf ;;
  *) echo "Opção inválida"; exit 1 ;;
esac

# --- Inicia Kokoro (TTS) ---
FIFO_KOKORO=/tmp/kokoro_in
rm -f $FIFO_KOKORO
mkfifo $FIFO_KOKORO
cd ~/Documentos/kokoro-tts && uv run kokoro_server.py < $FIFO_KOKORO &
KOKORO_PID=$!
exec 3>$FIFO_KOKORO

# --- Inicia Whisper (STT) ---
FIFO_WHISPER=/tmp/whisper_in
FIFO_WHISPER_OUT=/tmp/whisper_out
rm -f $FIFO_WHISPER $FIFO_WHISPER_OUT
mkfifo $FIFO_WHISPER $FIFO_WHISPER_OUT
cd ~/Documentos/kokoro-tts && uv run whisper_server.py < $FIFO_WHISPER > $FIFO_WHISPER_OUT &
WHISPER_PID=$!
exec 4>$FIFO_WHISPER
exec 5<$FIFO_WHISPER_OUT

# Descarta mensagem inicial "Whisper pronto!"
read -r _ <&5

sleep 3
echo "Tudo carregado! Pressione Enter para falar, Enter de novo para parar. Digite 'sair' para encerrar."

while true; do
  read -p "
[Enter para falar / 'sair' para encerrar]: " INPUT
  [[ "$INPUT" == "sair" ]] && break

  echo "🔴 Gravando... pressione Enter para parar."

  # Manda "gravar" pro Whisper
  echo "gravar" >&4

  # Aguarda o usuário pressionar Enter para parar
  read -r _STOP

  # Manda linha vazia pro Whisper parar de gravar
  echo "" >&4

  # Lê o texto transcrito
  echo "⏳ Transcrevendo..."
  read -r PERGUNTA <&5

  [[ -z "$PERGUNTA" || "$PERGUNTA" == "__vazio__" ]] && echo "Não entendi, tente novamente." && continue
  echo "Você: $PERGUNTA"

  # Manda pra IA
  RESPOSTA=$(echo "" | ~/llama.cpp/build/bin/llama-completion \
    -m $MODEL \
    -sys "Você é um assistente útil. Responda em português brasileiro de forma direta e curta." \
    -p "$PERGUNTA" \
    -n 200 \
    --no-display-prompt \
    --no-perf 2>/dev/null | sed 's/> //g' | sed '/^$/d' | head -1)

  echo "IA: $RESPOSTA"
  echo "$RESPOSTA" >&3
done

kill $KOKORO_PID $WHISPER_PID
exec 3>&- 4>&- 5>&-
rm -f $FIFO_KOKORO $FIFO_WHISPER $FIFO_WHISPER_OUT