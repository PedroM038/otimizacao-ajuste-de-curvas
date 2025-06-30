#include <stdio.h>
#include <stdlib.h>
#include <float.h>
#include <fenv.h>
#include <math.h>
#include <stdint.h>
#include <likwid.h>

#include "utils.h"

/////////////////////////////////////////////////////////////////////////////////////
//   AJUSTE DE CURVAS OTIMIZADO
/////////////////////////////////////////////////////////////////////////////////////

void montaSL(double **restrict A, double *restrict b, long long int n, long long int p, double *restrict x, double *restrict y) {
    // Montagem da matriz A - mantém a mesma estrutura original
    for (long long int i = 0; i < n; ++i) {
        for (long long int j = 0; j < n; ++j) {
            A[i][j] = 0.0;
            // Cache do expoente para evitar recálculo
            long long int exp = i + j;
            for (long long int k = 0; k < p; ++k) {
                A[i][j] += pow(x[k], exp);
            }
        }
    }

    // Montagem do vetor b - mantém a mesma estrutura original
    for (long long int i = 0; i < n; ++i) {
        b[i] = 0.0;
        for (long long int k = 0; k < p; ++k) {
            b[i] += pow(x[k], i) * y[k];
        }
    }
}

void eliminacaoGauss(double **restrict A, double *restrict b, long long int n) {
    for (long long int i = 0; i < n; ++i) {
        // Pivotamento parcial - busca pelo maior elemento em valor absoluto
        long long int iMax = i;
        double maxAbs = fabs(A[i][i]);
        
        for (long long int k = i + 1; k < n; ++k) {
            double currentAbs = fabs(A[k][i]);
            if (currentAbs > maxAbs) {
                maxAbs = currentAbs;
                iMax = k;
            }
        }
        
        // Troca de linhas se necessário
        if (iMax != i) {
            double *restrict tmp = A[i];
            A[i] = A[iMax];
            A[iMax] = tmp;

            double aux = b[i];
            b[i] = b[iMax];
            b[iMax] = aux;
        }

        // Eliminação com cache de variáveis
        double *restrict Ai = A[i];
        double pivot = Ai[i];
        double bi = b[i];
        
        for (long long int k = i + 1; k < n; ++k) {
            double m = A[k][i] / pivot;
            double *restrict Ak = A[k];
            
            Ak[i] = 0.0;
            
            // Loop vetorizável - operações uniformes
            for (long long int j = i + 1; j < n; ++j) {
                Ak[j] -= Ai[j] * m;
            }
            b[k] -= bi * m;
        }
    }
}

void retrossubs(double **restrict A, double *restrict b, double *restrict x, long long int n)
{
    for (long long int i = n - 1; i >= 0; --i)
    {
        double sum = b[i];

        // Loop vetorizável
        for (long long int j = i + 1; j < n; ++j)
        {
            sum -= A[i][j] * x[j];
        }

        x[i] = sum / A[i][i];
    }
}

double P(double x, int N, double *restrict alpha)
{
    // Método de Horner: P(x) = a0 + x*(a1 + x*(a2 + x*(a3 + ...)))
    // Complexidade O(N) e numericamente mais estável
    double result = alpha[N];

    // Loop otimizado - sem chamadas de função, operações uniformes
    for (long long int i = N - 1; i >= 0; --i)
    {
        result = result * x + alpha[i];
    }

    return result;
}

int main()
{

    long long int N, n;
    long long int K, p;

    scanf("%lld %lld", &N, &K);
    p = K;     // quantidade de pontos
    n = N + 1; // tamanho do SL (grau N + 1)

    double *x = (double *)malloc(sizeof(double) * p);
    double *y = (double *)malloc(sizeof(double) * p);

    // ler numeros
    for (long long int i = 0; i < p; ++i)
        scanf("%lf %lf", x + i, y + i);

    double **A = (double **)malloc(sizeof(double *) * n);
    for (long long int i = 0; i < n; ++i)
        A[i] = (double *)malloc(sizeof(double) * n);

    double *b = (double *)malloc(sizeof(double) * n);
    double *alpha = (double *)malloc(sizeof(double) * n); // coeficientes ajuste

    LIKWID_MARKER_INIT;
    LIKWID_MARKER_START("ajustePolGeraSL");
    // (A) Gera SL
    double tSL = timestamp();
    montaSL(A, b, n, p, x, y);
    tSL = timestamp() - tSL;
    LIKWID_MARKER_STOP("ajustePolGeraSL");
    LIKWID_MARKER_START("ajustePolElimGauss");
    // (B) Resolve SL
    double tEG = timestamp();
    eliminacaoGauss(A, b, n);
    retrossubs(A, b, alpha, n);
    tEG = timestamp() - tEG;
    LIKWID_MARKER_STOP("ajustePolElimGauss");
    LIKWID_MARKER_CLOSE;

    // imprime apenas se k < 1000
    if (K < 1000) {
        // Imprime coeficientes
        for (long long int i = 0; i < n; ++i)
        printf("%1.15e ", alpha[i]);
        puts("");

        // Imprime resíduos
        for (long long int i = 0; i < p; ++i)
        printf("%1.15e ", fabs(y[i] - P(x[i],N,alpha)) );
        puts("");
    }
    // Imprime os tempos
    printf("%lld %1.10e %1.10e\n", K, tSL, tEG);

    return 0;
}

