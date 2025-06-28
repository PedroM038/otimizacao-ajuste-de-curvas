#!/bin/bash

# DISCIPLINA: CI164 - Introdução à Computação Científica
# Relatório de Desempenho: Ajuste Polinomial com Mínimos Quadrados e Eliminação de Gauss

# OBSERVAÇÃO: este script leva em conta que as variáveis de ambiente já estão alteradas, utilizando
# os comandos:
# 	- export PATH=/home/soft/likwid/bin:/home/soft/likwid/sbin:$PATH
#	- export LD_LIBRARY_PATH=/home/soft/likwid/lib:$LD_LIBRARY_PATH
# e que a frequência do processador já está configurado e fixado no máximo, com o comando:
#	- echo "performance" > /sys/devices/system/cpu/cpufreq/policy3/scaling_governor 

# FORMA DE EXECUÇÃO: ./analise_performance.sh

set -e  # Sair em caso de erro

# Configurações
CPU_CORE=3
N1=10
N2=1000

# Parâmetros de teste - Número de pontos (K)
declare -a K_VALUES=(64 128 200 256 512 600 800 1024)
declare -a K_EXTRA=(2000)  # Apenas para N1

# Grupos LIKWID para diferentes métricas
declare -a LIKWID_GROUPS=("L3CACHE" "ENERGY" "FLOPS_DP")

# Diretórios de saída
RESULTS_DIR="resultados"
GRAPHS_DIR="graficos"
TABLES_DIR="tabelas"

# Criar diretórios se não existirem
mkdir -p $RESULTS_DIR $GRAPHS_DIR $TABLES_DIR

echo "=== INICIANDO ANÁLISE DE DESEMPENHO ==="
echo "Data: $(date)"
echo

# Função para compilar os programas
compile_programs() {
    echo "Compilando programas com gcc -O3 -mavx -march=native..."
    make clean
    make CC=gcc CFLAGS="-O3 -mavx -march=native -DLIKWID_PERFMON" all
    echo "Compilação concluída."
    echo
}


# Função para obter informações da arquitetura
get_architecture_info() {
    echo "=== INFORMAÇÕES DA ARQUITETURA ==="
    likwid-topology -g -c > $RESULTS_DIR/arquitetura.txt
    echo "Informações salvas em $RESULTS_DIR/arquitetura.txt"
    echo
}

# Função para executar teste com LIKWID
run_likwid_test() {
    local program=$1
    local group=$2
    local k=$3
    local n=$4
    local output_file=$5
    
    echo "Executando: $program com K=$k, N=$n, Grupo=$group"
    
    # Gerar entrada e executar com LIKWID
    timeout 300 bash -c "./gera_entrada $k $n | likwid-perfctr -C $CPU_CORE -g $group -m ./$program" >> $output_file 2>&1 || {
        echo "TIMEOUT ou ERRO para K=$k N=$n" >> $output_file
        return 1
    }
    
    return 0
}

# Função para executar teste de tempo (sem LIKWID)
run_time_test() {
    local program=$1
    local k=$2
    local n=$3
    local output_file=$4
    
    echo "Executando teste de tempo: $program com K=$k, N=$n"
    
    echo "=== Execução ===" >> $output_file
    timeout 300 bash -c "./gera_entrada $k $n | ./$program" >> $output_file 2>&1 || {
        echo "TIMEOUT ou ERRO para K=$k N=$n" >> $output_file
        return 1
    }
    return 0
}

# Função principal de testes
run_performance_tests() {
    local program=$1
    local version=${program#ajustePol}  # v1 ou v2
    
    echo "=== TESTANDO $program ==="
    
    # Para cada grau do polinômio
    for N in $N1 $N2; do
        echo "Testando com N=$N"
        
        # Determinar valores de K para teste
        local k_array=("${K_VALUES[@]}")
        if [ $N -eq $N1 ]; then
            k_array+=("${K_EXTRA[@]}")
        fi
        
        # Teste de tempo (sem LIKWID)
        local time_file="$RESULTS_DIR/tempo_${version}_N${N}.txt"
        echo "=== TESTES DE TEMPO ===" > $time_file
        echo "Programa: $program, N=$N" >> $time_file
        echo >> $time_file
        
        for K in "${k_array[@]}"; do
            echo "K=$K" >> $time_file
            run_time_test $program $K $N $time_file
            echo >> $time_file
        done
        
        # Testes com LIKWID
        for group in "${LIKWID_GROUPS[@]}"; do
            local likwid_file="$RESULTS_DIR/${group}_${version}_N${N}.txt"
            echo "=== TESTES LIKWID - GRUPO $group ===" > $likwid_file
            echo "Programa: $program, N=$N" >> $likwid_file
            echo >> $likwid_file
            
            for K in "${k_array[@]}"; do
                echo "K=$K" >> $likwid_file
                run_likwid_test $program $group $K $N $likwid_file
                echo >> $likwid_file
                
                # Pequena pausa entre testes
                sleep 1
            done
        done
    done
    
    echo "Testes de $program concluídos."
    echo
}

# Função para extrair dados e gerar CSVs
extract_and_generate_csv() {
    echo "=== EXTRAINDO DADOS E GERANDO CSVs ==="
    
    # Processar dados de tempo
    extract_time_data

    # Processar dados de energia
    extract_energy_data

    # Processar dados de FLOPS
    extract_flops_data

    echo "CSVs gerados com sucesso em $TABLES_DIR/"
    echo
}

# Função auxiliar para extrair dados de FLOPS
extract_flops_data() {
    echo "Extraindo dados de FLOPS..."
    
    # Para cada grau de polinômio
    for N in $N1 $N2; do
        # Para cada versão
        for version in "v1" "v2"; do
            local input_file="$RESULTS_DIR/FLOPS_DP_${version}_N${N}.txt"
            local output_file="$TABLES_DIR/flops_${version}_N${N}.csv"
            
            if [[ ! -f "$input_file" ]]; then
                echo "Arquivo $input_file não encontrado, pulando..."
                continue
            fi
            
            echo "Processando $input_file -> $output_file"
            
            # Criar cabeçalho do CSV
            echo "K,FlopsDP_GeraSL,FlopsAVX_GeraSL,FlopsDP_ElimGauss,FlopsAVX_ElimGauss" > "$output_file"
            
            # Processar cada seção K do arquivo
            local current_k=""
            local dp_gerasl=""
            local avx_gerasl=""
            local dp_elimgauss=""
            local avx_elimgauss=""
            local in_gerasl_region=false
            local in_elimgauss_region=false
            
            while IFS= read -r line; do
                # Detectar início de uma nova seção K
                if [[ $line =~ ^K=([0-9]+)$ ]]; then
                    current_k="${BASH_REMATCH[1]}"
                    dp_gerasl=""
                    avx_gerasl=""
                    dp_elimgauss=""
                    avx_elimgauss=""
                    in_gerasl_region=false
                    in_elimgauss_region=false
                    continue
                fi
                
                # Detectar início das regiões
                if [[ $line =~ "Region ajustePolGeraSL, Group 1: FLOPS_DP" ]]; then
                    in_gerasl_region=true
                    in_elimgauss_region=false
                    continue
                fi
                
                if [[ $line =~ "Region ajustePolElimGauss, Group 1: FLOPS_DP" ]]; then
                    in_gerasl_region=false
                    in_elimgauss_region=true
                    continue
                fi
                
                # Procurar pelas linhas com DP [MFLOP/s] e AVX DP [MFLOP/s]
                if [[ $line =~ \|[[:space:]]*DP[[:space:]]\[MFLOP/s\][[:space:]]*\|[[:space:]]*([0-9]+\.?[0-9]*([eE][+-]?[0-9]+)?)[[:space:]]*\| ]]; then
                    local dp_value="${BASH_REMATCH[1]}"
                    
                    if [[ $in_gerasl_region == true ]]; then
                        dp_gerasl="$dp_value"
                        echo "  K=$current_k: DP GeraSL = $dp_gerasl MFLOP/s"
                    elif [[ $in_elimgauss_region == true ]]; then
                        dp_elimgauss="$dp_value"
                        echo "  K=$current_k: DP ElimGauss = $dp_elimgauss MFLOP/s"
                    fi
                fi
                
                if [[ $line =~ \|[[:space:]]*AVX[[:space:]]DP[[:space:]]\[MFLOP/s\][[:space:]]*\|[[:space:]]*([0-9]+\.?[0-9]*([eE][+-]?[0-9]+)?)[[:space:]]*\| ]]; then
                    local avx_value="${BASH_REMATCH[1]}"
                    
                    if [[ $in_gerasl_region == true ]]; then
                        avx_gerasl="$avx_value"
                        echo "  K=$current_k: AVX DP GeraSL = $avx_gerasl MFLOP/s"
                    elif [[ $in_elimgauss_region == true ]]; then
                        avx_elimgauss="$avx_value"
                        echo "  K=$current_k: AVX DP ElimGauss = $avx_elimgauss MFLOP/s"
                        
                        # Quando temos todos os valores, adicionar ao CSV
                        if [[ -n "$dp_gerasl" && -n "$avx_gerasl" && -n "$dp_elimgauss" && -n "$avx_elimgauss" && -n "$current_k" ]]; then
                            echo "$current_k,$dp_gerasl,$avx_gerasl,$dp_elimgauss,$avx_elimgauss" >> "$output_file"
                            echo "  K=$current_k: Linha adicionada ao CSV"
                        fi
                    fi
                fi
                
            done < "$input_file"
            
            echo "  Arquivo $output_file gerado com sucesso"
        done
    done
}

# Função auxiliar para extrair dados de energia
extract_energy_data() {
    echo "Extraindo dados de energia..."
    
    # Para cada grau de polinômio
    for N in $N1 $N2; do
        # Para cada versão
        for version in "v1" "v2"; do
            local input_file="$RESULTS_DIR/ENERGY_${version}_N${N}.txt"
            local output_file="$TABLES_DIR/energy_${version}_N${N}.csv"
            
            if [[ ! -f "$input_file" ]]; then
                echo "Arquivo $input_file não encontrado, pulando..."
                continue
            fi
            
            echo "Processando $input_file -> $output_file"
            
            # Criar cabeçalho do CSV
            echo "K,Energy_GeraSL(J),Energy_ElimGauss(J)" > "$output_file"
            
            # Processar cada seção K do arquivo
            local current_k=""
            local energy_gerasl=""
            local energy_elimgauss=""
            local in_gerasl_region=false
            local in_elimgauss_region=false
            
            while IFS= read -r line; do
                # Detectar início de uma nova seção K
                if [[ $line =~ ^K=([0-9]+)$ ]]; then
                    current_k="${BASH_REMATCH[1]}"
                    energy_gerasl=""
                    energy_elimgauss=""
                    in_gerasl_region=false
                    in_elimgauss_region=false
                    continue
                fi
                
                # Detectar início das regiões
                if [[ $line =~ "Region ajustePolGeraSL, Group 1: ENERGY" ]]; then
                    in_gerasl_region=true
                    in_elimgauss_region=false
                    continue
                fi
                
                if [[ $line =~ "Region ajustePolElimGauss, Group 1: ENERGY" ]]; then
                    in_gerasl_region=false
                    in_elimgauss_region=true
                    continue
                fi
                
                # Procurar pela linha com Energy [J] dentro da região apropriada
                if [[ $line =~ \|[[:space:]]*Energy[[:space:]]\[J\][[:space:]]*\|[[:space:]]*([0-9]+\.?[0-9]*([eE][+-]?[0-9]+)?)[[:space:]]*\| ]]; then
                    local energy_value="${BASH_REMATCH[1]}"
                    
                    if [[ $in_gerasl_region == true ]]; then
                        energy_gerasl="$energy_value"
                        echo "  K=$current_k: Energy GeraSL = $energy_gerasl J"
                    elif [[ $in_elimgauss_region == true ]]; then
                        energy_elimgauss="$energy_value"
                        echo "  K=$current_k: Energy ElimGauss = $energy_elimgauss J"
                        
                        # Quando temos ambos os valores, adicionar ao CSV
                        if [[ -n "$energy_gerasl" && -n "$energy_elimgauss" && -n "$current_k" ]]; then
                            echo "$current_k,$energy_gerasl,$energy_elimgauss" >> "$output_file"
                            echo "  K=$current_k: Linha adicionada ao CSV"
                        fi
                    fi
                fi
                
            done < "$input_file"
            
            echo "  Arquivo $output_file gerado com sucesso"
        done
    done
}

# Função auxiliar para extrair dados de tempo
extract_time_data() {
    echo "Extraindo dados de tempo..."
    
    # Para cada grau de polinômio
    for N in $N1 $N2; do
        # Para cada versão
        for version in "v1" "v2"; do
            local input_file="$RESULTS_DIR/tempo_${version}_N${N}.txt"
            local output_file="$TABLES_DIR/tempo_${version}_N${N}.csv"
            
            if [[ ! -f "$input_file" ]]; then
                echo "Arquivo $input_file não encontrado, pulando..."
                continue
            fi
            
            echo "Processando $input_file -> $output_file"
            
            # Criar cabeçalho do CSV
            echo "K,Tempo_GeraSL,Tempo_ElimGauss" > "$output_file"
            
            # Processar cada seção K do arquivo
            local current_k=""
            local tempo_gerasl=""
            local tempo_elimgauss=""
            
            while IFS= read -r line; do
                # Detectar início de uma nova seção K
                if [[ $line =~ ^K=([0-9]+)$ ]]; then
                    current_k="${BASH_REMATCH[1]}"
                    tempo_gerasl=""
                    tempo_elimgauss=""
                    continue
                fi
                
                # Procurar pela linha com os tempos (última linha com 3 números)
                if [[ $line =~ ^[0-9]+[[:space:]]+([0-9]+\.[0-9]+e?[+-]?[0-9]*)[[:space:]]+([0-9]+\.[0-9]+e?[+-]?[0-9]*)$ ]]; then
                    local k_value="${line%% *}"  # Primeiro número (K)
                    local times_part="${line#* }"  # Resto da linha após o primeiro espaço
                    
                    # Extrair os dois tempos
                    tempo_gerasl=$(echo "$times_part" | cut -d' ' -f1)
                    tempo_elimgauss=$(echo "$times_part" | cut -d' ' -f2)
                    
                    # Verificar se temos um K válido
                    if [[ -n "$current_k" && "$k_value" == "$current_k" ]]; then
                        
                        # Adicionar linha ao CSV
                        echo "$current_k,$tempo_gerasl,$tempo_elimgauss" >> "$output_file"
                        echo "  K=$current_k: GeraSL=$tempo_gerasl, ElimGauss=$tempo_elimgauss"
                    fi
                fi
                
            done < "$input_file"
            
            echo "  Arquivo $output_file gerado com sucesso"
        done
    done
}

# Função para gerar gráficos com gnuplot
generate_graphs() {
    echo "=== GERANDO GRÁFICOS ==="
    
    # Verificar se gnuplot está disponível
    if ! command -v gnuplot &> /dev/null; then
        echo "ERRO: gnuplot não encontrado."
        return 1
    fi
    
    # Verificar se os arquivos CSV existem e têm dados
    check_csv_files
    
    # Gerar gráficos de tempo
    generate_time_graphs
    
    # Gerar gráficos de energia
    generate_energy_graphs
    
    # Gerar gráficos de FLOPS DP
    generate_flops_dp_graphs
    
    # Gerar gráficos de FLOPS AVX
    generate_flops_avx_graphs
    
    echo "Gráficos gerados com sucesso em $GRAPHS_DIR/"
    echo
}

# Função para verificar arquivos CSV
check_csv_files() {
    echo "Verificando arquivos CSV..."
    
    local csv_files=(
        "tempo_v1_N10.csv" "tempo_v1_N1000.csv" 
        "tempo_v2_N10.csv" "tempo_v2_N1000.csv"
        "energy_v1_N10.csv" "energy_v1_N1000.csv"
        "energy_v2_N10.csv" "energy_v2_N1000.csv"
        "flops_v1_N10.csv" "flops_v1_N1000.csv"
        "flops_v2_N10.csv" "flops_v2_N1000.csv"
    )
    
    for file in "${csv_files[@]}"; do
        local filepath="$TABLES_DIR/$file"
        if [[ -f "$filepath" ]]; then
            local line_count=$(wc -l < "$filepath")
            echo "  $file: $line_count linhas"
            if [[ $line_count -gt 1 ]]; then
                echo "    Primeiras linhas:"
                head -3 "$filepath" | sed 's/^/      /'
            else
                echo "    AVISO: Arquivo vazio ou só com cabeçalho!"
            fi
        else
            echo "  $file: NÃO ENCONTRADO!"
        fi
        echo
    done
}

# Função para gerar gráficos de tempo
generate_time_graphs() {
    echo "Gerando gráficos de tempo..."
    
    # Verificar se pelo menos um arquivo de tempo existe e tem dados
    local has_data=false
    for version in "v1" "v2"; do
        for n in "$N1" "$N2"; do
            local file="$TABLES_DIR/tempo_${version}_N${n}.csv"
            if [[ -f "$file" ]] && [[ $(wc -l < "$file") -gt 1 ]]; then
                has_data=true
                break 2
            fi
        done
    done
    
    if [[ $has_data == false ]]; then
        echo "  ERRO: Nenhum arquivo de tempo válido encontrado!"
        return 1
    fi
    
    # Gráfico de tempo - GeraSL
    cat > $GRAPHS_DIR/tempo_gerasl.plt << 'EOF'
set terminal png size 1200,800
set output 'graficos/tempo_gerasl.png'
set title 'Tempo de Execução - Geração do Sistema Linear'
set xlabel 'Número de Pontos (K)' font ',12'
set ylabel 'Tempo (s)' font ',12'
set logscale x
set logscale y
set grid
set key outside right
set datafile separator ","

plot 'tabelas/tempo_v1_N10.csv' using 1:2 with linespoints title 'N=10, v1' lw 2 pt 7 ps 1.2, \
     'tabelas/tempo_v1_N1000.csv' using 1:2 with linespoints title 'N=1000, v1' lw 2 pt 5 ps 1.2, \
     'tabelas/tempo_v2_N10.csv' using 1:2 with linespoints title 'N=10, v2' lw 2 pt 9 ps 1.2, \
     'tabelas/tempo_v2_N1000.csv' using 1:2 with linespoints title 'N=1000, v2' lw 2 pt 11 ps 1.2
EOF

    # Gráfico de tempo - ElimGauss
    cat > $GRAPHS_DIR/tempo_elimgauss.plt << 'EOF'
set terminal png size 1200,800
set output 'graficos/tempo_elimgauss.png'
set title 'Tempo de Execução - Eliminação de Gauss'
set xlabel 'Número de Pontos (K)' font ',12'
set ylabel 'Tempo (s)' font ',12'
set logscale x
set logscale y
set grid
set key outside right
set datafile separator ","

plot 'tabelas/tempo_v1_N10.csv' using 1:3 with linespoints title 'N=10, v1' lw 2 pt 7 ps 1.2, \
     'tabelas/tempo_v1_N1000.csv' using 1:3 with linespoints title 'N=1000, v1' lw 2 pt 5 ps 1.2, \
     'tabelas/tempo_v2_N10.csv' using 1:3 with linespoints title 'N=10, v2' lw 2 pt 9 ps 1.2, \
     'tabelas/tempo_v2_N1000.csv' using 1:3 with linespoints title 'N=1000, v2' lw 2 pt 11 ps 1.2
EOF

    # Executar os scripts gnuplot
    cd $PWD
    if gnuplot $GRAPHS_DIR/tempo_gerasl.plt 2>/dev/null; then
        echo "  tempo_gerasl.png gerado com sucesso"
    else
        echo "  ERRO ao gerar tempo_gerasl.png"
    fi
    
    if gnuplot $GRAPHS_DIR/tempo_elimgauss.plt 2>/dev/null; then
        echo "  tempo_elimgauss.png gerado com sucesso"
    else
        echo "  ERRO ao gerar tempo_elimgauss.png"
    fi
}

# Função para gerar gráficos de energia
generate_energy_graphs() {
    echo "Gerando gráficos de energia..."
    
    # Gráfico de energia - GeraSL
    cat > $GRAPHS_DIR/energy_gerasl.plt << 'EOF'
set terminal png size 1200,800
set output 'graficos/energy_gerasl.png'
set title 'Consumo de Energia - Geração do Sistema Linear'
set xlabel 'Número de Pontos (K)' font ',12'
set ylabel 'Energia (J)' font ',12'
set logscale x
set grid
set key outside right
set datafile separator ","

plot 'tabelas/energy_v1_N10.csv' using 1:2 with linespoints title 'N=10, v1' lw 2 pt 7 ps 1.2, \
     'tabelas/energy_v1_N1000.csv' using 1:2 with linespoints title 'N=1000, v1' lw 2 pt 5 ps 1.2, \
     'tabelas/energy_v2_N10.csv' using 1:2 with linespoints title 'N=10, v2' lw 2 pt 9 ps 1.2, \
     'tabelas/energy_v2_N1000.csv' using 1:2 with linespoints title 'N=1000, v2' lw 2 pt 11 ps 1.2
EOF

    # Gráfico de energia - ElimGauss
    cat > $GRAPHS_DIR/energy_elimgauss.plt << 'EOF'
set terminal png size 1200,800
set output 'graficos/energy_elimgauss.png'
set title 'Consumo de Energia - Eliminação de Gauss'
set xlabel 'Número de Pontos (K)' font ',12'
set ylabel 'Energia (J)' font ',12'
set logscale x
set grid
set key outside right
set datafile separator ","

plot 'tabelas/energy_v1_N10.csv' using 1:3 with linespoints title 'N=10, v1' lw 2 pt 7 ps 1.2, \
     'tabelas/energy_v1_N1000.csv' using 1:3 with linespoints title 'N=1000, v1' lw 2 pt 5 ps 1.2, \
     'tabelas/energy_v2_N10.csv' using 1:3 with linespoints title 'N=10, v2' lw 2 pt 9 ps 1.2, \
     'tabelas/energy_v2_N1000.csv' using 1:3 with linespoints title 'N=1000, v2' lw 2 pt 11 ps 1.2
EOF

    # Executar os scripts gnuplot
    if gnuplot $GRAPHS_DIR/energy_gerasl.plt 2>/dev/null; then
        echo "  energy_gerasl.png gerado com sucesso"
    else
        echo "  ERRO ao gerar energy_gerasl.png"
    fi
    
    if gnuplot $GRAPHS_DIR/energy_elimgauss.plt 2>/dev/null; then
        echo "  energy_elimgauss.png gerado com sucesso"
    else
        echo "  ERRO ao gerar energy_elimgauss.png"
    fi
}

# Função para gerar gráficos de FLOPS DP
generate_flops_dp_graphs() {
    echo "Gerando gráficos de FLOPS DP..."
    
    # Gráfico de FLOPS DP - GeraSL
    cat > $GRAPHS_DIR/flops_dp_gerasl.plt << 'EOF'
set terminal png size 1200,800
set output 'graficos/flops_dp_gerasl.png'
set title 'Performance FLOPS DP - Geração do Sistema Linear'
set xlabel 'Número de Pontos (K)' font ',12'
set ylabel 'FLOPS DP (MFLOP/s)' font ',12'
set logscale x
set grid
set key outside right
set datafile separator ","

plot 'tabelas/flops_v1_N10.csv' using 1:2 with linespoints title 'N=10, v1' lw 2 pt 7 ps 1.2, \
     'tabelas/flops_v1_N1000.csv' using 1:2 with linespoints title 'N=1000, v1' lw 2 pt 5 ps 1.2, \
     'tabelas/flops_v2_N10.csv' using 1:2 with linespoints title 'N=10, v2' lw 2 pt 9 ps 1.2, \
     'tabelas/flops_v2_N1000.csv' using 1:2 with linespoints title 'N=1000, v2' lw 2 pt 11 ps 1.2
EOF

    # Gráfico de FLOPS DP - ElimGauss
    cat > $GRAPHS_DIR/flops_dp_elimgauss.plt << 'EOF'
set terminal png size 1200,800
set output 'graficos/flops_dp_elimgauss.png'
set title 'Performance FLOPS DP - Eliminação de Gauss'
set xlabel 'Número de Pontos (K)' font ',12'
set ylabel 'FLOPS DP (MFLOP/s)' font ',12'
set logscale x
set grid
set key outside right
set datafile separator ","

plot 'tabelas/flops_v1_N10.csv' using 1:4 with linespoints title 'N=10, v1' lw 2 pt 7 ps 1.2, \
     'tabelas/flops_v1_N1000.csv' using 1:4 with linespoints title 'N=1000, v1' lw 2 pt 5 ps 1.2, \
     'tabelas/flops_v2_N10.csv' using 1:4 with linespoints title 'N=10, v2' lw 2 pt 9 ps 1.2, \
     'tabelas/flops_v2_N1000.csv' using 1:4 with linespoints title 'N=1000, v2' lw 2 pt 11 ps 1.2
EOF

    # Executar os scripts gnuplot
    if gnuplot $GRAPHS_DIR/flops_dp_gerasl.plt 2>/dev/null; then
        echo "  flops_dp_gerasl.png gerado com sucesso"
    else
        echo "  ERRO ao gerar flops_dp_gerasl.png"
    fi
    
    if gnuplot $GRAPHS_DIR/flops_dp_elimgauss.plt 2>/dev/null; then
        echo "  flops_dp_elimgauss.png gerado com sucesso"
    else
        echo "  ERRO ao gerar flops_dp_elimgauss.png"
    fi
}

# Função para gerar gráficos de FLOPS AVX
generate_flops_avx_graphs() {
    echo "Gerando gráficos de FLOPS AVX..."
    
    # Gráfico de FLOPS AVX - GeraSL
    cat > $GRAPHS_DIR/flops_avx_gerasl.plt << 'EOF'
set terminal png size 1200,800
set output 'graficos/flops_avx_gerasl.png'
set title 'Performance FLOPS AVX DP - Geração do Sistema Linear'
set xlabel 'Número de Pontos (K)' font ',12'
set ylabel 'FLOPS AVX DP (MFLOP/s)' font ',12'
set logscale x
set grid
set key outside right
set datafile separator ","

plot 'tabelas/flops_v1_N10.csv' using 1:3 with linespoints title 'N=10, v1' lw 2 pt 7 ps 1.2, \
     'tabelas/flops_v1_N1000.csv' using 1:3 with linespoints title 'N=1000, v1' lw 2 pt 5 ps 1.2, \
     'tabelas/flops_v2_N10.csv' using 1:3 with linespoints title 'N=10, v2' lw 2 pt 9 ps 1.2, \
     'tabelas/flops_v2_N1000.csv' using 1:3 with linespoints title 'N=1000, v2' lw 2 pt 11 ps 1.2
EOF

    # Gráfico de FLOPS AVX - ElimGauss
    cat > $GRAPHS_DIR/flops_avx_elimgauss.plt << 'EOF'
set terminal png size 1200,800
set output 'graficos/flops_avx_elimgauss.png'
set title 'Performance FLOPS AVX DP - Eliminação de Gauss'
set xlabel 'Número de Pontos (K)' font ',12'
set ylabel 'FLOPS AVX DP (MFLOP/s)' font ',12'
set logscale x
set grid
set key outside right
set datafile separator ","

plot 'tabelas/flops_v1_N10.csv' using 1:5 with linespoints title 'N=10, v1' lw 2 pt 7 ps 1.2, \
     'tabelas/flops_v1_N1000.csv' using 1:5 with linespoints title 'N=1000, v1' lw 2 pt 5 ps 1.2, \
     'tabelas/flops_v2_N10.csv' using 1:5 with linespoints title 'N=10, v2' lw 2 pt 9 ps 1.2, \
     'tabelas/flops_v2_N1000.csv' using 1:5 with linespoints title 'N=1000, v2' lw 2 pt 11 ps 1.2
EOF

    # Executar os scripts gnuplot
    if gnuplot $GRAPHS_DIR/flops_avx_gerasl.plt 2>/dev/null; then
        echo "  flops_avx_gerasl.png gerado com sucesso"
    else
        echo "  ERRO ao gerar flops_avx_gerasl.png"
    fi
    
    if gnuplot $GRAPHS_DIR/flops_avx_elimgauss.plt 2>/dev/null; then
        echo "  flops_avx_elimgauss.png gerado com sucesso"
    else
        echo "  ERRO ao gerar flops_avx_elimgauss.png"
    fi
}

# EXECUÇÃO PRINCIPAL
main() {
    echo "Iniciando análise completa de desempenho..."
    echo "Isso pode levar várias horas dependendo dos parâmetros."
    echo
    
    # Verificar se os programas existem
    if [[ ! -f "ajustePolv1" || ! -f "ajustePolv2" || ! -f "gera_entrada" ]]; then
        echo "Programas não encontrados. Compilando..."
        compile_programs
    fi
    
    # Obter informações da arquitetura
    get_architecture_info
    
    # Executar testes para ambas as versões
    run_performance_tests "ajustePolv1"
    run_performance_tests "ajustePolv2"
    
    # Processar dados
    extract_and_generate_csv
    
    # Gerar gráficos
    generate_graphs
        
    echo "=== ANÁLISE CONCLUÍDA ==="
    echo "Resultados disponíveis em:"
    echo "- Dados brutos: $RESULTS_DIR/"
    echo "- Tabelas CSV: $TABLES_DIR/"
    echo "- Gráficos: $GRAPHS_DIR/"
    echo "- Relatório: LEIAME.txt"
    echo
    echo "Para criar o pacote final:"
    echo "tar -czf analise_performance.tar.gz *.c *.h Makefile analise_performance.sh $RESULTS_DIR $TABLES_DIR $GRAPHS_DIR LEIAME.txt"
}

# Verificar dependências
check_dependencies() {
    local deps=("gcc" "likwid-perfctr" "likwid-topology" "python3" "gnuplot")
    
    for dep in "${deps[@]}"; do
        if ! command -v $dep &> /dev/null; then
            echo "ERRO: $dep não encontrado. Instale antes de continuar."
            exit 1
        fi
    done
}

# Executar verificações e main
check_dependencies
main
