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

void montaSL(double **restrict A, double *restrict b, int n, long long int p,
             double *restrict x, double *restrict y)
{
    // Pré-computar todas as potências necessárias
    // Máxima potência necessária é 2*(n-1) para A[i][j] = sum(x^(i+j))
    long long int max_power = 2 * (n - 1);

    // Matriz para armazenar potências: powers[k][i] = x[k]^i
    double **powers = (double **)malloc(sizeof(double *) * p);
    for (long long int k = 0; k < p; ++k)
    {
        powers[k] = (double *)malloc(sizeof(double) * (max_power + 1));
        powers[k][0] = 1.0; // x^0 = 1
        // Calcular potências iterativamente: x^i = x^(i-1) * x
        for (long long int i = 1; i <= max_power; ++i)
        {
            powers[k][i] = powers[k][i - 1] * x[k];
        }
    }

    // Montar matriz A
    for (long long int i = 0; i < n; ++i)
    {
        for (long long int j = 0; j < n; ++j)
        {
            double sum = 0.0;
            long long int power = i + j;
            // Loop vetorizável - sem condicionais, sem chamadas de função
            for (long long int k = 0; k < p; ++k)
            {
                sum += powers[k][power];
            }
            A[i][j] = sum;
        }
    }

    // Montar vetor b
    for (long long int i = 0; i < n; ++i)
    {
        double sum = 0.0;
        // Loop vetorizável - sem condicionais, sem chamadas de função
        for (long long int k = 0; k < p; ++k)
        {
            sum += powers[k][i] * y[k];
        }
        b[i] = sum;
    }

    // Liberar memória das potências
    for (long long int k = 0; k < p; ++k)
    {
        free(powers[k]);
    }
    free(powers);
}

void eliminacaoGauss(double **restrict A, double *restrict b, long long int n)
{
    for (long long int i = 0; i < n; ++i)
    {
        // Pivoteamento parcial otimizado
        long long int iMax = i;
        double maxVal = fabs(A[i][i]);

        // Loop otimizado para encontrar pivot
        for (long long int k = i + 1; k < n; ++k)
        {
            double absVal = fabs(A[k][i]);
            if (absVal > maxVal)
            {
                maxVal = absVal;
                iMax = k;
            }
        }

        // Troca de linhas se necessário
        if (iMax != i)
        {
            // Troca ponteiros das linhas (mais eficiente)
            double *tmp = A[i];
            A[i] = A[iMax];
            A[iMax] = tmp;

            // Troca elementos do vetor b
            double aux = b[i];
            b[i] = b[iMax];
            b[iMax] = aux;
        }

        // Pré-calcular 1/A[i][i] para evitar divisões repetidas
        double inv_pivot = 1.0 / A[i][i];

        // Eliminação - loops otimizados para SIMD
        for (long long int k = i + 1; k < n; ++k)
        {
            double m = A[k][i] * inv_pivot;
            A[k][i] = 0.0;

            // Loop vetorizável - operações uniformes
            for (long long int j = i + 1; j < n; ++j)
            {
                A[k][j] -= A[i][j] * m;
            }
            b[k] -= b[i] * m;
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

    for (long long int i = 0; i < n; ++i)
        printf("%1.15e ", alpha[i]);
    puts("");

    // Imprime resíduos
    for (long long int i = 0; i < p; ++i)
        printf("%1.15e ", fabs(y[i] - P(x[i], N, alpha)));
    puts("");

    // Imprime os tempos
    printf("%lld %1.10e %1.10e\n", K, tSL, tEG);

    return 0;
}
