# PROGRAMA
    PROGS = ajustePol gera_entrada
    OBJS = utils.o

# Compilador
    CC     = gcc
    CFLAGS = 
    LFLAGS = -lm

# Lista de arquivos para distribuição.
# LEMBRE-SE DE ACRESCENTAR OS ARQUIVOS ADICIONAIS SOLICITADOS NO ENUNCIADO DO TRABALHO
DISTFILES = *.c *.h LEIAME* Makefile 
DISTDIR = ${USER}

.PHONY: all clean purge dist

%o: %c utils.h
	$(CC) -o $@ $(CFLAGS) $^

all: $(PROGS)

$(PROGS) : % : %.o $(OBJS)
	$(CC) -o $@ $(CFLAGS) $^ $(LFLAGS)

clean:
	@echo "Limpando sujeira ..."
	@rm -f *~ *.bak core 

purge:  clean
	@echo "Limpando tudo ..."
	@rm -f $(PROGS) *.o a.out $(DISTDIR) $(DISTDIR).tar

dist: purge
	@echo "Gerando arquivo de distribuição ($(DISTDIR).tar) ..."
	@ln -s . $(DISTDIR)
	@tar -chvf $(DISTDIR).tar $(addprefix ./$(DISTDIR)/, $(DISTFILES))
	@rm -f $(DISTDIR)
