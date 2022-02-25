#####################################################################
## estrazione pioggia trioraria (ex cosmoi2, ora cosmo 2i)
## 
## UP, 2012
## adattamento cosmo 2i: EP, 2020
## funzioni necessarie: month2number, ccolors_tp (eliminabile), cbarn, 
##   print_data, province, nazioni1, fiumi_laghi
## eseguibili necessari: GXYAT
#####################################################################

*** inizializzazione
function main(args)
'reinit'
rc = gsfallow("on")
'q config'


*** lettura parametri riga comando e restituzioni direttorio
say ''
say 'GRADS: ---- ARGOMENTI PASSATI a estrazione_tp3_pc.gs: 'args' -------'
say ''

dataplot = subwrd(args,1)
run = subwrd(args,2)
say 'data e run: 'dataplot' 'run
say 'directory archivio grib: '
'printenv $grb_dir'
dir_archivio = sublin(result,1)
say 'directory estrazioni: '
'printenv $dat_dir'
dir_dati = sublin(result,1)
say 'directory immagini: '
'printenv $png_dir'
dir_immagini = sublin(result,1)
say 'directory grafica: '
'printenv $graf_dir'
dir_graf = sublin(result,1)
say 'directory cartografia: '
'printenv $car_dir'
dir_car = sublin(result,1)
say 'directory griglie: '
'printenv $conf_dir'
dir_conf = sublin(result,1)


*** apertura dati
'open 'dir_archivio'/tp3h_cosmo2i.ctl'


*** impostazioni generali e legenda scala colori
'clear'
'set undef -99.9'
'run 'dir_graf'/colors_tp.gs'


*** dimensioni temporali e spaziali (griglia ritagliata)
* dimensioni del file e num. scadenze
'set t 1'
'q file'
dimension = sublin(result,5)
x_siz = subwrd(dimension,3)
y_siz = subwrd(dimension,6)
t_siz = subwrd(dimension,12) ; say 'numero istanti temporali: ' t_siz

* imposto area di ritaglio lombardia
'set lat 44.6 46.8'
'set lon 8.4 11.6'

'q dims'
a = sublin(result,1)
b = sublin(result,2)
c = sublin(result,3)
d = sublin(result,4)

x_from = subwrd(b,11);xi_from= math_int(x_from)
x_to = subwrd(b,13); xi_to= math_int(x_to)
say 'x varia tra 'xi_from' a 'xi_to

y_from = subwrd(c,11);yi_from= math_int(y_from)
y_to = subwrd(c,13);yi_to= math_int(y_to)
say 'y varia tra 'yi_from' a 'yi_to

number_x = xi_to - xi_from +1 ; say 'numero di punti in x: 'number_x
number_y = yi_to - yi_from +1 ; say 'numero di punti in y: 'number_y

* reimposto area con x ed y per arrotondamento
'set x 'xi_from' 'xi_to
'set y 'yi_from' 'yi_to


*** impostazione parametri per ciclo
* t=scadenza di inizio
t=4
* intervallo di integrazione
intv=3
* num. di ore di previsione
fh=3


*** ciclo
while (t<=t_siz)
 'set t 't
 say 't= 't
 'q time'

 data_fore=subwrd(result,3)
 year_fore=substr(data_fore,9,4)
 mon_fore=substr(data_fore,6,3)
 day_fore=substr(data_fore,4,2)
 hour_fore=substr(data_fore,1,2)
 monn_fore = month2number(mon_fore)

 say 'data completa: 'data_fore' 'year_fore' 'monn_fore' 'day_fore' 'hour_fore

* definisco variabile tp3 
 'define tp3h=(APCPsfc-APCPsfc(t-'intv'))'

* produzione del file testuale: mantengo la vecchia nomenclatura per questioni di compatibilità
* del software utilizzato in p.civile
 file_out = dir_dati'/cosmoi2_estra_tp3_'dataplot run'_'year_fore monn_fore day_fore'-'hour_fore'.dat'
 say 'nome file output: 'file_out
 'run print_data.gs tp3h 'file_out' %.1f 'number_x

* plottaggio tp3h: impostazione pagina
 'set grads off'
 'set gxout shade2b'

* plottaggio tp3h: impostazione livelli - colori
 'set clevs 0.1 0.5 1 3 5 7 10 15 20 30 40 50 60 70 80 100 120 150'
 'set ccols 0 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38'

* plottaggio tp3h: plottaggio delle precipitazioni
 'd tp3h'
 'run 'dir_graf'/cbarn.gs 0.9 1'

* definizione del titolo
 'set string 3 l 6 0'
 'set strsiz 0.15'
 'draw string 2.0 8.3 COSMO 2i'
 'set string 1 l 6 0'
 'draw string 3.6 8.3 'dataplot' 'run' forecast for: 'data_fore' [+'fh'h]'

* corografia della mappa: shapefiles
 'run 'dir_car'/province.gs'
 'run 'dir_car'/nazioni1.gs'
 'run 'dir_car'/fiumi_laghi.gs'

* plottaggio tp3h: stampa della mappa
 'enable print 'dir_immagini'/cosmo2i_tp3.'t-1'.gx'
 'print'
 'disable print'
 '!$GXYAT 'dir_immagini'/cosmo2i_tp3.'t-1'.gx'
 '!rm -v 'dir_immagini'/cosmo2i_tp3.'t-1'.gx'
 'clear'

* incrementatori e chiusura del ciclo
 t=t+intv
 fh=fh+intv
endwhile

*** chiusura della procedura
'quit'
