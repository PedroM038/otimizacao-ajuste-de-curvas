# PROGRAMA
PROGS = ajustePolv1 ajustePolv2 gera_entrada
OBJS = utils.o

# Compilador
CC     = gcc -g
CFLAGS = -O3 -mavx2 -march=native
LFLAGS = -L${LIKWID_LIB} -llikwid -lm

# Lista de arquivos para distribuição.
# LEMBRE-SE DE ACRESCENTAR OS ARQUIVOS ADICIONAIS SOLICITADOS NO ENUNCIADO DO TRABALHO
DISTFILES = *.c *.h LEIAME* Makefile
DISTDIR ?= pacote

.PHONY: all clean purge dist v1 v2

# Regra padrão para compilar objetos
%.o: %.c utils.h
	$(CC) -c -o $@ $(CFLAGS) $<

# Regra para compilar todas as versões
all: $(PROGS)

# Regra para compilar apenas a versão 1 (original)
v1: ajustePolv1 gera_entrada

# Regra para compilar apenas a versão 2 (otimizada)
v2: ajustePolv2 gera_entrada

# Regras específicas para cada programa
ajustePolv1: ajustePolv1.o $(OBJS)
	$(CC) -o $@ $(CFLAGS) $^ $(LFLAGS)

ajustePolv2: ajustePolv2.o $(OBJS)
	$(CC) -o $@ $(CFLAGS) $^ $(LFLAGS)

gera_entrada: gera_entrada.o $(OBJS)
	$(CC) -o $@ $(CFLAGS) $^ $(LFLAGS)

clean:
	@echo "Limpando sujeira ..."
	@rm -f *~ *.bak core

purge: clean
	@echo "Limpando tudo ..."
	@rm -f $(PROGS) *.o a.out $(DISTDIR) $(DISTDIR).tar

dist: purge
	@echo "Gerando arquivo de distribuição ($(DISTDIR).tar) ..."
	@mkdir -p $(DISTDIR)
	@cp -a $(DISTFILES) $(DISTDIR)
	@tar -chvf $(DISTDIR).tar $(DISTDIR)
	@rm -rf $(DISTDIR)
