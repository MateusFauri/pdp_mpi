import os
import re
import pandas as pd
import matplotlib.pyplot as plt

# Diretório onde estão os arquivos de saída
OUTPUT_DIR = "pdp_mpi_outs"

# Expressão regular para capturar informações básicas do nome do arquivo
# Formato esperado: mpi_{tipo}_{tamanho}_{nprocs}_{cfg}_{jobid}.out
FILENAME_PATTERN = re.compile(
    r"mpi_(?P<tipo>\w+)_(?P<tamanho>\d+)_(?P<nprocs>\d+)_"
)

# Expressão regular para capturar tempo de execução (exemplo de saída)
# Ajuste conforme a saída do seu programa MPI
TIME_PATTERN = re.compile(
    r"(Tempo\s*total|Execution\s*time|Elapsed\s*time)\s*[:=]\s*(\d+\.?\d*)"
)

def extrair_resultados():
    resultados = []
    for filename in os.listdir(OUTPUT_DIR):
        if not filename.endswith(".out"):
            continue
        
        match = FILENAME_PATTERN.search(filename)
        if not match:
            continue
        
        tipo = match.group("tipo")
        tamanho = int(match.group("tamanho"))
        nprocs = int(match.group("nprocs"))
        
        tempo_exec = None
        with open(os.path.join(OUTPUT_DIR, filename), "r") as f:
            conteudo = f.read()
            tempo_match = TIME_PATTERN.search(conteudo)
            if tempo_match:
                tempo_exec = float(tempo_match.group(2))
        
        if tempo_exec is not None:
            resultados.append({
                "tipo": tipo,
                "tamanho_matriz": tamanho,
                "num_processos": nprocs,
                "tempo_exec": tempo_exec
            })

    return pd.DataFrame(resultados)

def gerar_graficos(df: pd.DataFrame):
    if df.empty:
        print("Nenhum resultado encontrado!")
        return
    
    os.makedirs("graficos_mpi", exist_ok=True)
    
    # Gráfico 1: Tempo x Num. de Processos (por tipo e tamanho)
    for tamanho in sorted(df["tamanho_matriz"].unique()):
        plt.figure()
        subset = df[df["tamanho_matriz"] == tamanho]
        for tipo in subset["tipo"].unique():
            tipo_data = subset[subset["tipo"] == tipo]
            plt.plot(tipo_data["num_processos"], tipo_data["tempo_exec"],
                     marker='o', label=tipo)
        plt.title(f"Tempo de Execução x Nº de Processos (Matriz {tamanho}x{tamanho})")
        plt.xlabel("Número de Processos")
        plt.ylabel("Tempo de Execução (s)")
        plt.legend()
        plt.grid(True)
        plt.savefig(f"graficos_mpi/tempo_vs_procs_{tamanho}.png")
        plt.close()
    
    # Gráfico 2: Speedup (comparado a execução com 1 processo)
    plt.figure()
    for tipo in df["tipo"].unique():
        tipo_data = df[df["tipo"] == tipo]
        for tamanho in tipo_data["tamanho_matriz"].unique():
            subset = tipo_data[tipo_data["tamanho_matriz"] == tamanho].sort_values("num_processos")
            tempo_serial = subset[subset["num_processos"] == 1]["tempo_exec"].min()
            if pd.notna(tempo_serial):
                subset["speedup"] = tempo_serial / subset["tempo_exec"]
                plt.plot(subset["num_processos"], subset["speedup"],
                         marker='o', label=f"{tipo} ({tamanho}x{tamanho})")
    plt.title("Speedup x Nº de Processos")
    plt.xlabel("Número de Processos")
    plt.ylabel("Speedup")
    plt.legend()
    plt.grid(True)
    plt.savefig("graficos_mpi/speedup.png")
    plt.close()

def main():
    df = extrair_resultados()
    if df.empty:
        print("Nenhum dado extraído. Verifique se os arquivos .out contêm o tempo de execução.")
        return
    print("Resumo dos resultados:")
    print(df)
    gerar_graficos(df)
    print("Gráficos salvos em ./graficos_mpi/")

if __name__ == "__main__":
    main()
