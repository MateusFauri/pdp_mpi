import os
import re
import pandas as pd
import matplotlib.pyplot as plt

OUTPUT_DIR = "pdp_mpi_outs"
GRAPH_DIR = "graficos"
os.makedirs(GRAPH_DIR, exist_ok=True)

re_process_type = re.compile(r"Running process type:\s*(\w+)")
re_matrix_size = re.compile(r"Matrix size:\s*(\d+)")
re_num_procs = re.compile(r"Number of processes:\s*(\d+)")
re_exec_time = re.compile(r"Execution time:\s*([\d.]+)")
re_comm_time = re.compile(r"Rank\s+\d+\s+-\s+Communication time:\s*([\d.]+)")

records = []

for filename in os.listdir(OUTPUT_DIR):
    if not filename.endswith(".out"):
        continue

    filepath = os.path.join(OUTPUT_DIR, filename)
    with open(filepath, "r") as f:
        content = f.read()

    process_match = re_process_type.search(content)
    matrix_match = re_matrix_size.search(content)
    procs_match = re_num_procs.search(content)
    exec_match = re_exec_time.search(content)
    comm_matches = re_comm_time.findall(content)

    if not (process_match and matrix_match and procs_match and exec_match):
        print(f"Ignorando arquivo incompleto: {filename}")
        continue

    process_type = process_match.group(1).strip()
    matrix_size = int(matrix_match.group(1))
    num_procs = int(procs_match.group(1))
    exec_time = float(exec_match.group(1))

    comm_times = [float(t) for t in comm_matches if float(t) >= 0]
    avg_comm_time = sum(comm_times) / len(comm_times) if comm_times else 0.0

    if num_procs <= 0 or matrix_size <= 0 or exec_time <= 0:
        print(f"Dados inválidos em {filename}, ignorando.")
        continue

    records.append(
        {
            "process_type": process_type,
            "matrix_size": matrix_size,
            "num_procs": num_procs,
            "exec_time": exec_time,
            "avg_comm_time": avg_comm_time,
        }
    )

df = pd.DataFrame(records)
if df.empty:
    print("Nenhum dado válido encontrado em", OUTPUT_DIR)
    exit()


def plot_metric(df, metric, ylabel, filename_prefix):
    for process_type, group_type in df.groupby("process_type"):
        plt.figure(figsize=(8, 5))
        for size, group in group_type.groupby("matrix_size"):
            group = group.sort_values("num_procs")
            plt.plot(
                group["num_procs"], group[metric], marker="o", label=f"{size}x{size}"
            )
        plt.title(f"{ylabel} — Comunicação: {process_type}")
        plt.xlabel("Número de Processos MPI")
        plt.ylabel(ylabel)
        plt.legend(title="Tamanho da Matriz")
        plt.grid(True)
        plt.tight_layout()
        plt.savefig(f"{GRAPH_DIR}/{filename_prefix}_{process_type}.png", dpi=300)
        plt.close()


plot_metric(df, "exec_time", "Tempo Total de Execução (s)", "tempo_execucao")
plot_metric(df, "avg_comm_time", "Tempo Médio de Comunicação (s)", "tempo_comunicacao")

speedup_data = []
for (ptype, size), group in df.groupby(["process_type", "matrix_size"]):
    base = group[group["num_procs"] == 1]["exec_time"].values
    if len(base) == 0:
        print(
            f"Sem execução base (1 processo) para {ptype} / matriz {size} — ignorando speedup."
        )
        continue
    base_time = base[0]
    for _, row in group.iterrows():
        s = base_time / row["exec_time"]
        e = s / row["num_procs"]
        speedup_data.append(
            {
                "process_type": ptype,
                "matrix_size": size,
                "num_procs": row["num_procs"],
                "speedup": s,
                "efficiency": e,
            }
        )

speedup_df = pd.DataFrame(speedup_data)

if not speedup_df.empty:
    plot_metric(speedup_df, "speedup", "Speedup", "speedup")
    plot_metric(speedup_df, "efficiency", "Eficiência Paralela", "eficiencia")
else:
    print("Nenhum dado de speedup/eficiência disponível.")
