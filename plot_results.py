import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import os

RESULTS_FILE = "resultados_mpi.csv"
OUTPUT_DIR = "graficos_network"
os.makedirs(OUTPUT_DIR, exist_ok=True)

sns.set(style="whitegrid", font_scale=1.2)

df = pd.read_csv(RESULTS_FILE)

df["versao_legenda"] = df["versao"].replace(
    {
        "mpi_coletiva": "Coletiva",
        "mpi_p2p_bloqueante": "P2P Bloqueante",
        "mpi_p2p_naobloqueante": "P2P Não Bloqueante",
    }
)


def plot_metric_vs_machines(metric, ylabel, filename_suffix):
    for n in sorted(df["tamanho"].unique()):
        plt.figure(figsize=(8, 6))
        subset = df[df["tamanho"] == n]

        sns.lineplot(
            data=subset,
            x="n_maquinas",
            y=metric,
            hue="versao_legenda",
            style="versao_legenda",
            markers=True,
            dashes=False,
        )

        plt.title(f"{ylabel} vs Número de Máquinas (Matriz {n}x{n})")
        plt.xlabel("Número de Máquinas")
        plt.ylabel(ylabel)
        plt.xticks([1, 2, 4])
        plt.legend(title="Versão")
        plt.tight_layout()

        filename = os.path.join(OUTPUT_DIR, f"{filename_suffix}_{n}.png")
        plt.savefig(filename, dpi=300)
        plt.close()
        print(f"Gráfico salvo: {filename}")


plot_metric_vs_machines("tempo_total", "Tempo Total (s)", "tempo_total")
plot_metric_vs_machines(
    "tempo_comunicacao", "Tempo de Comunicação (s)", "tempo_comunicacao"
)
plot_metric_vs_machines(
    "tempo_computacao", "Tempo de Computação (s)", "tempo_computacao"
)

resumo = df.groupby(["versao_legenda", "n_maquinas", "tamanho"], as_index=False).agg(
    {"tempo_total": "mean", "tempo_comunicacao": "mean", "tempo_computacao": "mean"}
)
print("\nRESUMO MÉDIO POR VERSÃO / NÚMERO DE MÁQUINAS / TAMANHO:")
print(resumo.to_string(index=False))
