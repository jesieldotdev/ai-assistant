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

# Inicia Kokoro em background com pipe
FIFO=/tmp/kokoro_in
rm -f $FIFO
mkfifo $FIFO

cd ~/Documentos/kokoro-tts && uv run kokoro_server.py < $FIFO &
KOKORO_PID=$!
exec 3>$FIFO

sleep 3
echo "Kokoro carregado! Digite 'sair' para encerrar."

while true; do
  read -p "Você: " PERGUNTA
  [[ "$PERGUNTA" == "sair" ]] && break

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

kill $KOKORO_PID
exec 3>&-
rm -f $FIFO
