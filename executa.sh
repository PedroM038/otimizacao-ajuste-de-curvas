#!/bin/bash
# filepath: /home/pedro-marques/Documentos/Projects/scientific_computing/ep-03/executa.sh

# Verifica se foram passados os parâmetros corretos
if [ $# -ne 2 ]; then
    echo "Uso: $0 <K> <N>"
    echo "  K: número de pontos"
    echo "  N: grau do polinômio"
    exit 1
fi

K=$1
N=$2

echo "Executando com K=$K, N=$N"
echo "================================"

echo "Versão 1 (Original):"
./gera_entrada $K $N | ./ajustePolv1

echo ""
echo "Versão 2 (Otimizada):"
./gera_entrada $K $N | ./ajustePolv2