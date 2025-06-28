# Relatório de Desempenho: Ajuste Polinomial com Mínimos Quadrados e Eliminação de Gauss

Este projeto tem como objetivo comparar o desempenho de duas versões do código de ajuste de curvas polinomiais (versões `v1` e `v2`), considerando dois aspectos principais:

- **(A)** Geração do Sistema Linear (SL) pelo **Método dos Mínimos Quadrados**
- **(B)** Solução do SL pelo **Método da Eliminação de Gauss**

## Condições Obrigatórias

Para garantir uma comparação justa e válida, devem ser respeitadas as seguintes condições:

- Ambos os códigos devem ser compilados com:
  ```bash
  gcc -O3 -mavx -march=native
  ```
- Os códigos devem ser compilados e executados **na mesma máquina**.
- Os testes devem utilizar **os mesmos parâmetros**, em igualdade de condições.
- Todos os testes devem ser instrumentados com a **biblioteca LIKWID**, utilizando a opção `-C 3` para garantir que a execução ocorra na core mais superior (no caso do DINF, a core 3).
- **Não utilizar máquinas virtuais ou servidores com uso compartilhado.**
- Apresente a **arquitetura do processador** no relatório com:
  ```bash
  likwid-topology -g -c
  ```

---

## Execução dos Testes

Utilize o programa `gera_entrada` para gerar dados de entrada no pipeline com o programa `ajustePol`. Por exemplo:

```bash
./gera_entrada 100 5 | ./ajustePol       # Sem LIKWID
./gera_entrada 100 5 | likwid-perfctr -C 3 -g <grupo> -m ./ajustePol   # Com LIKWID
```

**Atenção:** Para valores grandes de `K`, é obrigatório o uso do tipo `long long int` em ambas versões.

---

## Parâmetros de Teste

- **Graus do polinômio (N):**
  - `N1 = 10`
  - `N2 = 1000`

- **Número de pontos (K):**

  ```
  64, 128, 200, 256, 512, 600, 800, 1024,
  2000, 3000, 4096, 6000, 7000, 10000, 50000, 100000
  ```

  Para `N1`, acrescente também:
  ```
  10^6, 10^7, 10^8
  ```

---

## Coleta de Métricas com LIKWID

Execute os testes coletando as seguintes métricas com os grupos abaixo:

| Métrica                  | Grupo LIKWID | Métrica Específica             |
|--------------------------|--------------|---------------------------------|
| Tempo de execução        | -            | Medido via `timestamp()`       |
| Cache Miss de L3         | `L3CACHE`    | `Cache Miss Ratio`             |
| Consumo de energia       | `ENERGY`     | `Energy [J]`                   |
| Operações aritméticas    | `FLOPS_DP`   | `FLOPS DP` e `FLOPS AVX DP`    |

---

## Representação dos Resultados

- Os dados coletados devem ser convertidos em **gráficos de linha**.
- Cada gráfico deve conter **4 linhas** representando:
  - `N1 + v1`
  - `N1 + v2`
  - `N2 + v1`
  - `N2 + v2`

### Eixos:
- **X (abcissas):** Número de pontos `K` (em escala logarítmica)
- **Y (ordenadas):**
  - Tempo de execução (em log)
  - Cache miss ratio
  - Energia (Joules)
  - MFLOP/s

---

## Produto Final a Ser Entregue

Um pacote compactado contendo:

- Códigos-fonte em C:
- `ajustePolv1.c`, `ajustePolv2.c`, `utils.c`, `utils.h`
- `gera_entrada.c`
- `Makefile`
- Scripts de automação de testes
- Tabelas com resultados do LIKWID (formato `.csv` ou `.txt`)
- Gráficos gerados (em `.pdf` ou `.png`)
- Este arquivo `README.md` (ou `LEIAME`)
  - Com explicações dos resultados e observações sobre:
    - FLOPS AVX DP
    - Diferenças de desempenho observadas
    - Interpretação dos gráficos

---

## Observações Finais

- Certifique-se de realizar os testes em **modo isolado**, sem interferência de outros processos.
- Documente claramente no LEIAME:
  - A arquitetura da máquina utilizada
  - Quais variáveis foram alteradas para `long long int`
  - Comportamentos inesperados, se houver