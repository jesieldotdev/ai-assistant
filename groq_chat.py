#!/usr/bin/env python3
"""
Servidor de chat Groq com contexto.
Lê do stdin: modelo e pergunta separados por newline.
Responde no stdout.
"""
import sys
import json
import os
from openai import OpenAI

HISTORICO = "/tmp/ia-voz-historico.json"
SYSTEM_PROMPT = "Você é um assistente útil. Responda em português brasileiro de forma direta e curta."

api_key = os.environ.get("GROQ_API_KEY", "")
client = OpenAI(api_key=api_key, base_url="https://api.groq.com/openai/v1")

# Carrega ou inicia histórico
def carregar():
    if os.path.exists(HISTORICO):
        with open(HISTORICO) as f:
            return json.load(f)
    return []

def salvar(historico):
    with open(HISTORICO, "w") as f:
        json.dump(historico, f)

print("Groq pronto!", flush=True)

for line in sys.stdin:
    linha = line.strip()
    if not linha:
        continue

    # Formato: MODEL\nPERGUNTA (separados por \x1f - unit separator)
    if "\x1f" not in linha:
        continue

    model, pergunta = linha.split("\x1f", 1)

    historico = carregar()
    mensagens = [{"role": "system", "content": SYSTEM_PROMPT}]
    mensagens += historico
    mensagens.append({"role": "user", "content": pergunta})

    try:
        response = client.chat.completions.create(
            model=model,
            messages=mensagens,
            max_tokens=500
        )
        resposta = response.choices[0].message.content.strip()
    except Exception as e:
        resposta = f"Erro: {e}"

    historico.append({"role": "user", "content": pergunta})
    historico.append({"role": "assistant", "content": resposta})
    salvar(historico)

    # Envia resposta como linha única (newlines viram espaço)
    print(resposta.replace("\n", " "), flush=True)