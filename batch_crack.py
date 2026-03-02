#!/usr/bin/env python3
"""
batch_crack.py — Roda todas as senhas do senhas.csv contra o backend via CLI
e salva os resultados em batch_results.csv com classificação de força.

Uso:
    python3 batch_crack.py
"""

import csv
import re
import time
import json
import subprocess
import os
from datetime import datetime

# ── Configuração ──────────────────────────────────────────────────
INPUT_FILE  = "senhas.csv"
OUTPUT_FILE = "batch_results.csv"
ENV_FILE    = "config.env"

# MUDE AQUI para o caminho real do seu executável C++/Haskell/etc
BIN_PATH    = "./kracken" 

DELAY_SEC   = 0.1 # pausa entre execuções (opcional)
# ─────────────────────────────────────────────────────────────────

def ler_kdf_do_env():
    """Lê o arquivo config.env e retorna o valor de KDF."""
    if not os.path.exists(ENV_FILE):
        print(f"[AVISO] Arquivo {ENV_FILE} não encontrado. Usando kdf=default")
        return "default"
    
    with open(ENV_FILE, "r", encoding="utf-8") as f:
        for linha in f:
            linha = linha.strip()
            if linha.startswith("KDF="):
                return linha.split("=", 1)[1].strip()
                
    print("[AVISO] Variável KDF não encontrada no config.env. Usando default")
    return "default"

def classificar_senha(senha):
    """
    Critérios ATUALIZADOS (espelho do novo classifier.js):
    1 ponto para cada: maiúscula, número, caractere especial.
    - Strong : >= 2 pontos
    - Medium : == 1 ponto
    - Weak   : 0 pontos
    """
    if not senha:
        return "weak"

    tem_upper   = bool(re.search(r'[A-Z]', senha))
    tem_number  = bool(re.search(r'[0-9]', senha))
    tem_special = bool(re.search(r'[!@#$%^&*()_+\-=\[\]{};\':"\\|,.<>/?`~]', senha))

    score = sum([tem_upper, tem_number, tem_special])

    if score >= 2:
        return "strong"
    elif score == 1:
        return "medium"
    else:
        return "weak"


def crack(password, strength, kdf_value):
    """
    Chama o executável via subprocess passando:
    <binario> <senha> <strength> kdf=<kdf_value>
    Espera que a saída padrão (stdout) do executável seja um JSON válido.
    """
    
    # Monta o comando (ex: ./kracken MinhaSenha1! strong kdf=argon2)
    comando = [BIN_PATH, password, strength, f"kdf={kdf_value}"]
    
    try:
        resultado = subprocess.run(
            comando, 
            capture_output=True, 
            text=True, 
            check=True
        )
        # Tenta interpretar a saída do terminal como JSON
        return json.loads(resultado.stdout)
    
    except subprocess.CalledProcessError as e:
        print(f"    [ERRO DE EXECUÇÃO] Código {e.returncode}")
        print(f"    [SAÍDA DE ERRO] {e.stderr.strip()}")
        return None
    except json.JSONDecodeError:
        print(f"    [ERRO] A saída do terminal não é um JSON válido: {resultado.stdout.strip()}")
        return None
    except Exception as e:
        print(f"    [ERRO DESCONHECIDO] {e}")
        return None


def fmt_time(seconds):
    try:
        s = float(seconds)
        if s < 0.001:
            return f"{s*1e6:.2f} µs"
        if s < 1:
            return f"{s*1000:.2f} ms"
        return f"{s:.3f} s"
    except (ValueError, TypeError):
        return "—"


def fmt_num(n):
    try:
        n = int(n)
        if n > 1_000_000:
            return f"{n/1e6:.2f}M"
        if n > 1_000:
            return f"{n/1e3:.1f}k"
        return str(n)
    except (ValueError, TypeError):
        return "—"


def main():
    # Pega o KDF antes de começar
    kdf_atual = ler_kdf_do_env()

    # Lê senhas
    try:
        with open(INPUT_FILE, encoding="utf-8") as f:
            passwords = [line.strip() for line in f if line.strip()]
    except FileNotFoundError:
        print(f"Erro: Arquivo '{INPUT_FILE}' não encontrado.")
        return

    total = len(passwords)
    print(f"\n{'='*55}")
    print(f"  KRACKEN — Batch Mode (CLI)")
    print(f"  KDF Alvo: {kdf_atual}")
    print(f"  {total} senhas encontradas em '{INPUT_FILE}'")
    print(f"  Saída: {OUTPUT_FILE}")
    print(f"{'='*55}\n")

    fieldnames = [
        "password", "strength_class",
        "leaked", "verdict", "method",
        "crack_time", "attempts", "dict_entries",
        "latency_ns", "engine", "timestamp", "kdf_used"
    ]

    with open(OUTPUT_FILE, "w", newline="", encoding="utf-8") as out_f:
        writer = csv.DictWriter(out_f, fieldnames=fieldnames)
        writer.writeheader()

        for i, pwd in enumerate(passwords, 1):
            strength = classificar_senha(pwd)
            print(f"  [{i:>3}/{total}] {pwd:<20} ({strength})", end=" → ", flush=True)

            data = crack(pwd, strength, kdf_atual)

            if data is None:
                print("FALHA")
                writer.writerow({
                    "password":       pwd,
                    "strength_class": strength,
                    "leaked":         "error",
                    "verdict":        "ERROR",
                    "method":         "—",
                    "crack_time":     "—",
                    "attempts":       "—",
                    "dict_entries":   "—",
                    "latency_ns":     "—",
                    "engine":         "—",
                    "timestamp":      datetime.now().isoformat(),
                    "kdf_used":       kdf_atual
                })
                continue

            # Verdict
            leaked = data.get("leaked") == "yes"
            method = data.get("method", "not_found")

            if leaked:
                verdict = "LEAKED"
            elif method in ["brute_force", "brute_force_gpu"]:
                verdict = "CRACKED"
            else:
                verdict = "SURVIVED"

            print(f"{verdict:<10}  {fmt_time(data.get('cracktime_s', 0))}")

            writer.writerow({
                "password":       pwd,
                "strength_class": strength,
                "leaked":         data.get("leaked", "—"),
                "verdict":        verdict,
                "method":         method.upper().replace("_", " "),
                "crack_time":     fmt_time(data.get("cracktime_s", 0)),
                "attempts":       fmt_num(data.get("attempts", 0)),
                "dict_entries":   fmt_num(data.get("dict_entries_checked", 0)),
                "latency_ns":     f"{float(data.get('latency_ns', 0)):.2f}" if data.get('latency_ns') else "—",
                "engine":         "GPU" if data.get("binary") == "gpu" else "CPU",
                "timestamp":      data.get("timestamp", datetime.now().isoformat()),
                "kdf_used":       kdf_atual
            })

            out_f.flush()  # salva linha a linha para não perder progresso
            if DELAY_SEC > 0:
                time.sleep(DELAY_SEC)

    print(f"\n{'='*55}")
    print(f"  Concluído! Resultados em '{OUTPUT_FILE}'")
    print(f"{'='*55}\n")

if __name__ == "__main__":
    main()