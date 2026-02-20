#!/usr/bin/env python3
"""
batch_crack.py — Roda todas as senhas do senhas.csv contra o backend
e salva os resultados em batch_results.csv com classificação de força.

Uso:
    python3 batch_crack.py

Requisitos:
    - Backend rodando em http://localhost:8082
    - senhas.csv na mesma pasta
"""

import csv
import re
import time
import urllib.request
import urllib.parse
import json
from datetime import datetime

# ── Configuração ──────────────────────────────────────────────────
INPUT_FILE   = "senhas.csv"
OUTPUT_FILE  = "batch_results.csv"
API_URL      = "http://localhost:8082/crack"
USE_GPU      = False          # muda para True se quiser rodar na GPU
DELAY_SEC    = 0.1            # pausa entre requisições (evita sobrecarga)
# ─────────────────────────────────────────────────────────────────


def classificar_senha(senha):
    """
    Critérios (espelho do regex.js):
      Weak   — < 7 chars, OU tem espaço, OU tem tripla repetição (aaa)
      Medium — ≥ 7 chars, sem triplas, sem espaço, mas não atende todos
               os critérios avançados (maiúscula + número + especial)
      Strong — ≥ 9 chars, sem pares repetidos (xyxy), sem espaço,
               tem maiúscula + número + especial
    """
    if not senha:
        return "Weak"

    tem_espaco  = bool(re.search(r'\s', senha))
    tem_tripla  = bool(re.search(r'(.)\1\1', senha))
    tem_par     = bool(re.search(r'(..).*\1', senha))

    tem_upper   = bool(re.search(r'[A-Z]', senha))
    tem_number  = bool(re.search(r'[0-9]', senha))
    tem_special = bool(re.search(r'[!@#$%^&*()\-_=+\[\]{};:\'",.<>/?`~\\|]', senha))

    if tem_espaco or tem_tripla or len(senha) < 7:
        return "Weak"

    advanced = sum([tem_upper, tem_number, tem_special])
    if len(senha) >= 9 and not tem_par and advanced == 3:
        return "Strong"

    return "Medium"


def crack(password, strength):
    """Chama POST /crack e retorna o dict JSON ou None em caso de erro."""
    body = urllib.parse.urlencode({
        "password": password,
        "strength": strength,
        "gpu":      "true" if USE_GPU else "false",
    }).encode("utf-8")

    req = urllib.request.Request(
        API_URL,
        data=body,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=320) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        print(f"    [ERRO] {e}")
        return None


def fmt_time(seconds):
    s = float(seconds)
    if s < 0.001:
        return f"{s*1e6:.2f} µs"
    if s < 1:
        return f"{s*1000:.2f} ms"
    return f"{s:.3f} s"


def fmt_num(n):
    n = int(n)
    if n > 1_000_000:
        return f"{n/1e6:.2f}M"
    if n > 1_000:
        return f"{n/1e3:.1f}k"
    return str(n)


def main():
    # Lê senhas
    with open(INPUT_FILE, encoding="utf-8") as f:
        passwords = [line.strip() for line in f if line.strip()]

    total = len(passwords)
    print(f"\n{'='*55}")
    print(f"  KRACKEN — Batch Mode")
    print(f"  {total} senhas encontradas em '{INPUT_FILE}'")
    print(f"  Saída: {OUTPUT_FILE}")
    print(f"{'='*55}\n")

    fieldnames = [
        "password", "strength_class",
        "leaked", "verdict", "method",
        "crack_time", "attempts", "dict_entries",
        "latency_ns", "engine", "timestamp",
    ]

    with open(OUTPUT_FILE, "w", newline="", encoding="utf-8") as out_f:
        writer = csv.DictWriter(out_f, fieldnames=fieldnames)
        writer.writeheader()

        for i, pwd in enumerate(passwords, 1):
            strength = classificar_senha(pwd)
            print(f"  [{i:>3}/{total}] {pwd:<20} ({strength})", end=" → ", flush=True)

            data = crack(pwd, strength)

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
                })
                continue

            # Verdict
            leaked = data.get("leaked") == "yes"
            method = data.get("method", "not_found")

            if leaked:
                verdict = "LEAKED"
            elif method == "brute_force":
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
                "latency_ns":     f"{float(data.get('latency_ns', 0)):.2f}",
                "engine":         "GPU" if data.get("binary") == "gpu" else "CPU",
                "timestamp":      data.get("timestamp", datetime.now().isoformat()),
            })

            out_f.flush()          # salva linha a linha (não perde progresso)
            time.sleep(DELAY_SEC)

    print(f"\n{'='*55}")
    print(f"  Concluído! Resultados em '{OUTPUT_FILE}'")
    print(f"{'='*55}\n")


if __name__ == "__main__":
    main()
