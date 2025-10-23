import os
import re
import pandas as pd
import matplotlib.pyplot as plt

RESULTS_DIR = "pdp_mpi_outs"
OUTPUT_DIR = "pdp_mpi_plots"

os.makedirs(OUTPUT_DIR, exist_ok=True)

regex_line = re.compile(
    r"Finished running (\w+) with matrix size (\d+) and (\d+) processes after ([\d\.]+) seconds"
)

records = []

for fname in os.listdir(RESULTS_DIR):
    if not fname.endswith(".out"):
        continue
    fpath = os.path.join(RESULTS_DIR, fname)
    with open(fpath, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            match = regex_line.search(line)
            if match:
                process_type = match.group(1)
                matrix_size = int(match.group(2))
                num_procs = int(match.group(3))
                time_sec = float(match.group(4))
                records.append({
                    "process_type": process_type,
                    "matrix_size": matrix_size,
                    "num_procs": num_procs,
                    "time_sec": time_sec,
                })

if not records:
    print("Nenhum resultado encontrado em", RESULTS_DIR)
    exit()

df = pd.DataFrame(records)
df.sort_values(by=["process_type", "matrix_size", "num_procs"], inplace=True)
print("Total de resultados:", len(df))
print(df.head())

for (matrix_size, process_type), subset in df.groupby(["matrix_size", "process_type"]):
    plt.figure(figsize=(8,5))
    plt.plot(subset["num_procs"], subset["time_sec"], marker='o')
    plt.title(f"Tempo x Nº de Processos\n{process_type} - Matriz {matrix_size}")
    plt.xlabel("Número de processos")
    plt.ylabel("Tempo (s)")
    plt.grid(True)
    plt.tight_layout()

    outpath = os.path.join(OUTPUT_DIR, f"time_{process_type}_{matrix_size}.png")
    plt.savefig(outpath)
    plt.close()

for matrix_size, subset in df.groupby("matrix_size"):
    plt.figure(figsize=(8,5))
    for process_type, group in subset.groupby("process_type"):
        base_time = group[group["num_procs"] == 1]["time_sec"].min()
        if pd.isna(base_time):
            continue
        group = group.sort_values("num_procs")
        speedup = base_time / group["time_sec"]
        plt.plot(group["num_procs"], speedup, marker='o', label=process_type)

    plt.title(f"Speedup x Nº de Processos - Matriz {matrix_size}")
    plt.xlabel("Número de processos")
    plt.ylabel("Speedup (T1 / Tp)")
    plt.legend()
    plt.grid(True)
    plt.tight_layout()

    outpath = os.path.join(OUTPUT_DIR, f"speedup_{matrix_size}.png")
    plt.savefig(outpath)
    plt.close()

print(f"Gráficos gerados em: {OUTPUT_DIR}/")
