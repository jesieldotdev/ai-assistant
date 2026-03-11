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
echo "  4) $ICON_CLOUD Llama 3.1 8B   (Groq, online)"
echo "─────────────────────────────"
read -p "  Modelo: " op

case $op in
  1) MODEL=~/qwen3b.gguf                  ; MODO="local" ; MODELO_NOME="Qwen 3B (local)" ;;
  2) MODEL=~/qwen7b.gguf                  ; MODO="local" ; MODELO_NOME="Qwen 7B (local)" ;;
  3) GROQ_MODEL="llama-3.3-70b-versatile" ; MODO="groq"  ; MODELO_NOME="Llama 3.3 70B (Groq)" ;;
  4) GROQ_MODEL="llama-3.1-8b-instant"    ; MODO="groq"  ; MODELO_NOME="Llama 3.1 8B (Groq)" ;;
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

# --- Inicia servidor Groq (se modo groq) ---
if [[ "$MODO" == "groq" ]]; then
    FIFO_GROQ_IN=/tmp/groq_in
    FIFO_GROQ_OUT=/tmp/groq_out
    rm -f $FIFO_GROQ_IN $FIFO_GROQ_OUT
    mkfifo $FIFO_GROQ_IN $FIFO_GROQ_OUT
    cd ~/Documentos/kokoro-tts && GROQ_API_KEY="$GROQ_API_KEY" uv run python3 ~/Documentos/kokoro-tts/groq_chat.py < $FIFO_GROQ_IN > $FIFO_GROQ_OUT 2>/dev/null &
    GROQ_PID=$!
    exec 6>$FIFO_GROQ_IN
    exec 7<$FIFO_GROQ_OUT
    # Descarta "Groq pronto!"
    read -r _ <&7
fi

# Limpa histórico anterior
echo '[]' > /tmp/ia-voz-historico.json

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
    # Envia modelo + pergunta separados por unit separator (\x1f)
    printf '%s\x1f%s\n' "$GROQ_MODEL" "$PERGUNTA" >&6
    read -r RESPOSTA <&7
  else
    # Monta prompt com histórico local
    HISTORICO_PROMPT=$(python3 -c "
import json
try:
    with open('/tmp/ia-voz-historico.json') as f:
        h = json.load(f)
except:
    h = []
prompt = ''
for m in h:
    role = 'Usuário' if m['role']=='user' else 'Assistente'
    prompt += f\"{role}: {m['content']}\n\"
print(prompt, end='')
")
    PROMPT_FINAL="${HISTORICO_PROMPT}Usuário: ${PERGUNTA}\nAssistente:"

    RESPOSTA=$(printf '%s' "$PROMPT_FINAL" | ~/llama.cpp/build/bin/llama-completion \
      -m $MODEL \
      -sys "Você é um assistente útil. Responda em português brasileiro de forma direta e curta." \
      -f /dev/stdin \
      -n 500 \
      --no-display-prompt \
      --no-perf 2>/dev/null | sed 's/> //g' | sed '/^$/d' | sed 's/EOF by user.*$//' | sed 's/Usuário:.*$//' | tr '\n' ' ')

    # Salva no histórico local
    python3 - "$PERGUNTA" "$RESPOSTA" << 'PYEOF'
import json, sys
pergunta, resposta = sys.argv[1], sys.argv[2]
try:
    with open('/tmp/ia-voz-historico.json') as f:
        h = json.load(f)
except:
    h = []
h.append({'role':'user','content':pergunta})
h.append({'role':'assistant','content':resposta})
with open('/tmp/ia-voz-historico.json','w') as f:
    json.dump(h,f)
PYEOF
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
[[ "$MODO" == "groq" ]] && kill $GROQ_PID 2>/dev/null
exec 3>&- 4>&- 5>&-
[[ "$MODO" == "groq" ]] && exec 6>&- 7>&-
rm -f $FIFO_KOKORO $FIFO_WHISPER $FIFO_WHISPER_OUT /tmp/ia-voz-historico.json
[[ "$MODO" == "groq" ]] && rm -f $FIFO_GROQ_IN $FIFO_GROQ_OUT