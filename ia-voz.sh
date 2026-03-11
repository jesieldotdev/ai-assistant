#!/bin/bash

# Ícones Nerd Font
ICON_BOT=$'\uf544'      # 
ICON_MIC=$'\uf130'      # 
ICON_SPIN=$'\uf110'     # 
ICON_USER=$'\uf007'     # 
ICON_WARN=$'\uf071'     # 
ICON_OFF=$'\uf011'      # 
ICON_MSG=$'\uf27b'      # 
ICON_PLAY=$'\uf054'     # 

clear
echo "$ICON_BOT  IA-Voz"
echo "─────────────────────────"
echo "  1) Qwen 3B  (rápido)"
echo "  2) Qwen 7B  (melhor)"
echo "─────────────────────────"
read -p "  Modelo: " op

case $op in
  1) MODEL=~/qwen3b.gguf ;;
  2) MODEL=~/qwen7b.gguf ;;
  *) echo "$ICON_WARN Opção inválida"; exit 1 ;;
esac

echo ""
echo "$ICON_SPIN  Carregando modelos..."

# --- Inicia Kokoro (TTS) ---
FIFO_KOKORO=/tmp/kokoro_in
rm -f $FIFO_KOKORO
mkfifo $FIFO_KOKORO
cd ~/Documentos/kokoro-tts && uv run kokoro_server.py < $FIFO_KOKORO 2>/dev/null &
KOKORO_PID=$!
exec 3>$FIFO_KOKORO

# --- Inicia Whisper (STT) ---
FIFO_WHISPER=/tmp/whisper_in
FIFO_WHISPER_OUT=/tmp/whisper_out
rm -f $FIFO_WHISPER $FIFO_WHISPER_OUT
mkfifo $FIFO_WHISPER $FIFO_WHISPER_OUT
cd ~/Documentos/kokoro-tts && uv run whisper_server.py < $FIFO_WHISPER > $FIFO_WHISPER_OUT 2>/dev/null &
WHISPER_PID=$!
exec 4>$FIFO_WHISPER
exec 5<$FIFO_WHISPER_OUT

# Descarta mensagem inicial "Whisper pronto!"
read -r _ <&5

sleep 3
clear
echo "$ICON_BOT  IA-Voz"
echo "────────────────────────────────────────────"
echo "  $ICON_MIC  Enter em branco  →  gravar voz"
echo "  $ICON_MSG  Digite texto     →  enviar por texto"
echo "  $ICON_OFF  sair             →  encerrar"
echo "────────────────────────────────────────────"

while true; do
  read -p $'\n\uf054 ' INPUT

  [[ "$INPUT" == "sair" ]] && break

  if [[ -z "$INPUT" ]]; then
    echo "$ICON_MIC  Gravando... pressione Enter para parar."
    echo "gravar" >&4
    read -r _STOP
    echo "" >&4

    echo "$ICON_SPIN  Transcrevendo..."
    read -r PERGUNTA <&5

    [[ -z "$PERGUNTA" || "$PERGUNTA" == "__vazio__" ]] && echo "$ICON_WARN  Não entendi, tente novamente." && continue
    echo "$ICON_USER  $PERGUNTA"
  else
    PERGUNTA="$INPUT"
  fi

  RESPOSTA=$(echo "" | ~/llama.cpp/build/bin/llama-completion \
    -m $MODEL \
    -sys "Você é um assistente útil. Responda em português brasileiro de forma direta e curta." \
    -p "$PERGUNTA" \
    -n 200 \
    --no-display-prompt \
    --no-perf 2>/dev/null | sed 's/> //g' | sed '/^$/d' | sed 's/EOF by user.*$//' | tr '\n' ' ')

  echo "$ICON_BOT  $RESPOSTA"
  echo "$RESPOSTA" >&3
done

echo ""
echo "$ICON_OFF  Encerrando..."
kill $KOKORO_PID $WHISPER_PID 2>/dev/null
exec 3>&- 4>&- 5>&-
rm -f $FIFO_KOKORO $FIFO_WHISPER $FIFO_WHISPER_OUT