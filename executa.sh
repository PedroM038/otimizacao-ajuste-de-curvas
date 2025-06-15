#!/bin/bash

# Verifica se foram passados os parâmetros corretos
if [ $# -ne 2 ]; then
    echo "Uso: $0 <K> <N>"
    echo "Onde K = número de pontos, N = grau do polinômio"
    exit 1
fi

K=$1
N=$2

echo "Gerando $K pontos para polinômio de grau $N..."
echo "========================================="

# Executa o pipeline
./gera_entrada $K $N | ./ajustePol

echo "========================================="
echo "Teste concluído!"
