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
ICON_CLOUD=$'\uf0c2'    # 

# --- Carrega variáveis de ambiente (API keys) ---
source ~/.config/ia-voz.env

clear
echo "$ICON_BOT  IA-Voz"
echo "─────────────────────────────"
echo "  1) Qwen 3B       (local, rápido)"
echo "  2) Qwen 7B       (local, melhor)"
echo "  3) $ICON_CLOUD Llama 3.3 70B  (Groq, online)"
echo "  4) $ICON_CLOUD Gemma 2 9B     (Groq, online)"
echo "─────────────────────────────"
read -p "  Modelo: " op

case $op in
  1) MODEL=~/qwen3b.gguf                  ; MODO="local" ; MODELO_NOME="Qwen 3B (local)" ;;
  2) MODEL=~/qwen7b.gguf                  ; MODO="local" ; MODELO_NOME="Qwen 7B (local)" ;;
  3) GROQ_MODEL="llama-3.3-70b-versatile" ; MODO="groq"  ; MODELO_NOME="Llama 3.3 70B (Groq)" ;;
  4) GROQ_MODEL="gemma2-9b-it"            ; MODO="groq"  ; MODELO_NOME="Gemma 2 9B (Groq)" ;;
  *) echo "$ICON_WARN Opção inválida"; exit 1 ;;
esac

echo ""
echo "$ICON_SPIN  Carregando..."

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

# Função: limpa texto pra fala (remove markdown/unicode)
limpar_para_voz() {
    echo "$1" \
        | sed 's/\*\*//g' \
        | sed 's/\*//g' \
        | sed 's/^#{1,6} //g' \
        | sed 's/`//g' \
        | sed 's/^[0-9]\+\. //g' \
        | sed 's/^- //g' \
        | sed 's/^  - //g' \
        | tr '\n' ' ' \
        | sed 's/  */ /g'
}

sleep 3
clear
echo "$ICON_BOT  IA-Voz  │  $MODELO_NOME"
echo "────────────────────────────────────────────"
echo "  $ICON_MIC  Enter em branco  →  gravar voz"
echo "  $ICON_MSG  Digite texto     →  enviar por texto"
echo "  $ICON_OFF  sair             →  encerrar"
echo "────────────────────────────────────────────"

groq_resposta() {
    local pergunta="$1"
    cd ~/Documentos/kokoro-tts && uv run python3 - << PYEOF
from openai import OpenAI

client = OpenAI(
    api_key="$GROQ_API_KEY",
    base_url="https://api.groq.com/openai/v1"
)

response = client.chat.completions.create(
    model="$GROQ_MODEL",
    messages=[
        {"role": "system", "content": "Você é um assistente útil. Responda em português brasileiro de forma direta e curta."},
        {"role": "user", "content": """$pergunta"""}
    ],
    max_tokens=500
)
print(response.choices[0].message.content.strip(), end="")
PYEOF
}

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

  echo "$ICON_SPIN  Pensando..."

  if [[ "$MODO" == "groq" ]]; then
    RESPOSTA=$(groq_resposta "$PERGUNTA")
  else
    RESPOSTA=$(echo "" | ~/llama.cpp/build/bin/llama-completion \
      -m $MODEL \
      -sys "Você é um assistente útil. Responda em português brasileiro de forma direta e curta." \
      -p "$PERGUNTA" \
      -n 500 \
      --no-display-prompt \
      --no-perf 2>/dev/null | sed 's/> //g' | sed '/^$/d' | sed 's/EOF by user.*$//')
  fi

  # Exibe formatado no terminal
  echo ""
  echo -e "\033[33m$ICON_BOT  $RESPOSTA\033[0m" | sed 's/^/  /'
  echo ""

  # Envia limpo pro Kokoro falar
  VOZ=$(limpar_para_voz "$RESPOSTA")
  echo "$VOZ" >&3
done

echo ""
echo "$ICON_OFF  Encerrando..."
kill $KOKORO_PID $WHISPER_PID 2>/dev/null
exec 3>&- 4>&- 5>&-
rm -f $FIFO_KOKORO $FIFO_WHISPER $FIFO_WHISPER_OUT