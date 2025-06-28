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
