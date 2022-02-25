#!/bin/bash

#***************************************************************
# Scopo:           estrazione campo TP da cosmo 2I e creazione
#                  matrici per sistemi idro di Pciv Lombardia
# Autore:          EP
#
# Data creazione:  17/01/2020
# Versione:        1.0
# Revisioni:       -
#
# Uso:             cosmo_2I_pciv <data (aaaammgg)> <run (00-12)>
# Note:            se manca la data usa quella odierna; se man-
#                  ca il run utilizza quello ragionevolmente
#                  disponibile al momento del lancio.
# Dipendenze:      cURL, cdo, perl, python, grib2ctl, gribmap,
#                  GrADS, ncftpput
#***************************************************************

#-----------------------------------------------------------------------------------------
# 1. utilizzo dello script
#-----------------------------------------------------------------------------------------
usage="Utilizzo: `basename $0` <data(aaaammgg)> <run>"
usage1="Se non si specifica la data, viene usata quella odierna"
usage2="Se non si specifica il run, viene usato quello più prossimo"
usage3=" all'orario di esecuzione dello script"

if [ "$1" == "-h" ] || [ "$1" == "--help" ]
then
        echo
        echo $usage
        echo $usage1
        echo $usage2 && echo $usage3
        echo
        exit
fi

if [ ! $1 ]
then
        dataplot=$(date +%Y%m%d)
else
        dataplot=$1
fi

ora1=$(date +%H); if [ "${ora1:0:1}" == "0" ]; then ora=$[${ora1:1:${#ora1}} + 0]; else ora=$[$ora1 + 0]; fi
min=$(date +%M)
echo -e "\n ORA: $ora:$min" && echo
if [ ! $2 ]
then
        if [ $ora -gt 16 ]; then run=12; else run=00; fi
else
        run=$2
fi


#-----------------------------------------------------------------------------------------
# 2. variabili ambiente ed altre variabili
#-----------------------------------------------------------------------------------------
# definiscono l'ambiente di esecuzione
. /home/meteo/cosmo2i_tp_2pciv/conf/variabili_ambiente

# nome del dataset in Arkiweb e nome modello nella procedura
dataset=cosmo_2I_fcast
fieldset=cosmo2i

# definisce il nome del file di controllo che conterrà il numero di campi presenti su Arkiweb
gribcheck=$tmp_dir/gribcheck.txt

# definisce il nome del file di controllo dell'esecuzione e quello di log dello script
nomescript=`basename $0 .sh`
control_file=$log_dir/$nomescript.${dataplot}"_"${run}".ctrl" && echo -e "\ncontrol file: $control_file"

# Arkiweb vuole la data nel formato aaaa-mm-gg:
dataxarki=${dataplot:0:4}"-"${dataplot:4:2}"-"${dataplot:6:2}

# definisco i campi che mi interessano, il numero di scadenze e le strighe di interrogazione di Arkiweb
grib="GRIB1,80,2,61"
n_scad=49
stringaquery="reftime:="$dataxarki" "$run":00; product:"$grib
accessofields="https://"${usr}":"${pwd}"@"${arkiweb}"/fields"
accessodata="https://"$usr":"$pwd"@"$arkiweb"/data"
echo $stringaquery

#-----------------------------------------------------------------------------------------
# 3. controllo esecuzioni concorrenti
#-----------------------------------------------------------------------------------------
export LOCKDIR=$tmp_dir/$nomescript-$dataplot-$run.lock && echo "lockdir -----> $LOCKDIR"
T_MAX=5400

if mkdir "$LOCKDIR" 2>/dev/null
then
        echo $$ > $LOCKDIR/PID
else
        echo -e "\nScript \"$nomescript.sh\" già in esecuzione alle ore `date +%H%M` con PID: $(<$LOCKDIR/PID)"
        echo "  => controllo durata esecuzione script:"
        ps --no-heading -o etime,pid,lstart -p $(<$LOCKDIR/PID)| while read PROC_TIME PROC_PID PROC_LSTART
        do
                SECONDS=$[$(date +%s) - $(date -d"$PROC_LSTART" +%s)]
                echo "  Script \"$nomescript.sh\" con PID $(<$LOCKDIR/PID) in esecuzione da $SECONDS secondi"
                if [ $SECONDS -gt $T_MAX ]
                then
                        echo "     => $PROC_PID in esecuzione da più di $T_MAX secondi, lo killo" && echo
                        pkill -15 -g $PROC_PID
                fi
        done
        echo "*********************************************************"
        exit
fi

trap "rm -fvr "$LOCKDIR";
rm -fv $tmp_dir/$$"_"*;
echo;
echo \"** fine script $nomescript: `date` ***************************************\";
echo;
exit" EXIT HUP INT QUIT TERM


#-----------------------------------------------------------------------------------------
# 4. controllo se la procedura e' gia' stata eseguita
#-----------------------------------------------------------------------------------------
if [ -f $control_file ]
then
        echo -e "\nDati $dataset, data $aaaammgg corsa $run gia' elaborati. Esco dalla procedura" && echo
        exit
fi


#-----------------------------------------------------------------------------------------
# 5. controllo se sono presenti le scadenze dei campi di tp e scarico il grib
#-----------------------------------------------------------------------------------------
echo -e "\nVerifico che il grib sia presente e che contenga le scadenze necessarie"
curl -sgG --data-urlencode "datasets[]=$dataset" --data-urlencode "query=$stringaquery" \
    $accessofields | python -c 'import json, sys; print(json.load(sys.stdin)["stats"]["c"])' > $gribcheck
if [ "$?" -ne "0" ]
then
        echo "   => Corsa del modello non ancora presente. Fine procedura" && echo
        exit
fi

# se il numero di scadenze non e' corretto controllo il run di backup; se neanche quello
# le contiene, esco dalla procedura
n_elem=$(head -1 $gribcheck)
if [ "$n_elem" -ne "$n_scad" ]
then
      echo "   Scadenze non ancora tutte presenti. Provo con la corsa di backup"
      rm $gribcheck
      dataset="cosmo_2I_fcast_backup"
      curl -sgG --data-urlencode "datasets[]=$dataset" --data-urlencode "query=$stringaquery" \
          $accessofields | python -c 'import json, sys; print(json.load(sys.stdin)["stats"]["c"])' > $gribcheck
      if [ "$?" -ne "0" ];
      then
              echo "     => Corsa di backup non ancora presente. Fine procedura"
                          echo
              exit
      fi
      echo -e "\n  => Verifico che il grib di backup sia presente e che contenga le scadenze necessarie"
      n_elem=$(head -1 $gribcheck)
      if [ "$n_elem" -ne "$n_scad" ]
      then
              echo "   Scadenze della corsa di backup non ancora tutte presenti. Fine procedura"
              echo
              rm $gribcheck
              exit
      fi
fi

echo "   => sono presenti $n_elem campi del parametro $grib: proseguo con l'estrazione"
rm $gribcheck
curl -sgG --data-urlencode "datasets[]=$dataset" --data-urlencode "query=$stringaquery" \
    $accessodata > $grb_dir/tp_${dataplot}${run}.grib


#-----------------------------------------------------------------------------------------
# 6. estraggo le tp e genero la matrice per PC
#-----------------------------------------------------------------------------------------
# primo step: antiruoto la griglia e ritaglio il dominio di interesse:
/usr/local/bin/cdo -remapbil,$conf_dir/grid_cosmo2i_antirot $grb_dir/tp_${dataplot}${run}.grib $grb_dir/tp_${dataplot}${run}.anti.grib

# secondo step: uso grib2ctl e gribmap per creare i file di controllo e di indice per grads
$fun_dir/grib2ctl.pl -verf $grb_dir/tp_${dataplot}${run}.anti.grib > $grb_dir/tp3h_cosmo2i.ctl
if [ "$?" -ne "0" ]
then
       echo -e "\nErrore nella creazione del file di controllo per grads. Esco dalla procedura" && echo
       #logger -is -p user.err "$nomescript: codice uscita grib2ctl diverso da 0" -t "PREVISORE"
       exit 1
fi

$GRIBMAP -q -i $grb_dir/tp3h_cosmo2i.ctl
if [ "$?" -ne "0" ]
then
        echo -e "\nErrore nella creazione del file di indice per grads. Esco dalla procedura" && echo
        #logger -is -p user.err "$nomescript: codice uscita gribmap diverso da 0" -t "PREVISORE"
        exit 1
fi

# terzo step: genero le matrici con grads
$GRADS -blc "estrazione_tp3_pc.gs $dataplot $run"
if [ $? -ne 0 ]
then
       echo -e "\nErrore nella creazione dei file da parte di grads. Esco dalla procedura" && echo
       #logger -is -p user.err "$nomescript: errore di grads" -t "PREVISORE"
       exit 1
fi


#-----------------------------------------------------------------------------------------
# 7. disseminazione su ftp PC Lombardia
#-----------------------------------------------------------------------------------------
# devo mantanere la vecchia nomclatura dei file per la compatibilità con gli
# applicativi software di protezione civile
echo -e "\ncopio i file forecast $fieldset $run su ftp protezione civile"
/usr/bin/ncftpput -t 300 -r 2 -u $ftpusr -p $ftppwd $FTPSITE cosmoi2/ $dat_dir/"cosmoi2_estra_tp3_"$dataplot$run*.dat
if [ $? -ne 0 ]
then
       echo -e "\nErrore nella copia dei file su ftp di protezione civile. Esco dalla procedura" && echo
       #logger -is -p user.err "$nomescript: errore nella copia su ftp" -t "PREVISORE"
       exit 1
fi
touch $control_file


#-----------------------------------------------------------------------------------------
# 8. pulizie: rimuove i file più vecchi di 10 giorni
#-----------------------------------------------------------------------------------------
echo -e "\nrimozione file più vecchi di 10 giorni forecast $fieldset $run"
find $grb_dir -maxdepth 1 -type f -name "*.grib" -mtime +10 -exec rm -vr {} \;
find $grb_dir -maxdepth 1 -type f -name "*.idx" -mtime +10 -exec rm -vr {} \;
find $grb_dir -maxdepth 1 -type f -name "*.ctl" -mtime +10 -exec rm -vr {} \;
find $dat_dir -maxdepth 1 -type f -name "*.dat" -mtime +10 -exec rm -vr {} \;


#-----------------------------------------------------------------------------------------
# 9. goodbye
#-----------------------------------------------------------------------------------------
echo -e "\n******FINE script: $nomescript alle ore: `date` ************************\n"
