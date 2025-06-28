# EP-03 - Otimização de Ajuste de Curvas

## 🎯 Objetivo

O objetivo deste trabalho é **melhorar e avaliar o desempenho** do programa de ajuste de curvas `ajustePol`. O programa calcula um polinômio de grau N que se ajusta a uma curva descrita por K pontos.

## 📋 Especificações do Programa

### Descrição Geral
O programa `ajustePol` calcula um ajuste de curva polinomial **f(x)** de grau N a partir de uma tabela de K pontos (x,y).

### Método Utilizado
- **Algoritmo**: Método dos Mínimos Quadrados
- **Resolução do Sistema Linear**: Eliminação de Gauss com pivoteamento parcial
- **Função objetivo**: f(x) = a₀ + a₁×x + a₂×x² + ... + aₙ×xⁿ

### Funcionalidades
- Calcula os coeficientes aᵢ do polinômio de ajuste
- Computa os resíduos: rᵢ = |yᵢ - f(xᵢ)|
- Mede tempos de execução dos principais trechos do código

## 📥 Formato de Entrada

**Via stdin:**
```
N                    # Grau do polinômio
K                    # Quantidade de pontos
x₁ y₁               # Coordenadas do ponto 1
x₂ y₂               # Coordenadas do ponto 2
...
xₖ yₖ               # Coordenadas do ponto K
```

### Exemplo:
```
3
5
1.0 2.5
2.0 4.1
3.0 6.8
4.0 8.2
5.0 11.0
```

## 📤 Formato de Saída

**Via stdout:**
```
a₀ a₁ a₂ ... aₙ      # Coeficientes do polinômio
r₀ r₁ r₂ ... rₖ      # Resíduos dos pontos
K tSL tEG            # Quantidade de pontos e tempos (ms)
```

### Legenda dos Tempos:
- **tSL**: Tempo de geração do Sistema Linear (ms)
- **tEG**: Tempo de resolução do Sistema Linear via Eliminação de Gauss (ms)

## ⚡ Melhorias de Desempenho

### Objetivo da Otimização
Transformar o código original (**v1**) em uma versão otimizada (**v2**) com melhor desempenho computacional.

### ⚠️ Restrições Importantes
- As alterações **NÃO devem** modificar o resultado do programa
- Pequenos erros numéricos são aceitáveis devido às otimizações
- O funcionamento correto do programa deve ser preservado

### Áreas de Otimização
As melhorias podem ser aplicadas em:

- 🔧 **Geração do Sistema Linear**
- 🔧 **Resolução do Sistema Linear** 
- 🔧 **Estruturas de Dados**
- 🔧 **Outros pontos relevantes**

### 📝 Documentação das Alterações
Todas as modificações realizadas devem ser:
1. **Explicadas** detalhadamente no README
2. **Justificadas** com as razões técnicas para cada alteração
3. **Documentadas** com impacto esperado no desempenho

---

> **Nota**: Este projeto faz parte da disciplina de Computação Científica e foca na otimização de algoritmos numéricos.