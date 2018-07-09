#/bin/bash

# Program to include incidence angle into CPT CSV main result file.
# This program needs the path to the file "param.ang" as well as the csv file and ML used.
# example:
# ./CPT_csv_add_incidence.sh results_file.csv /path/to/param.ang 15x3 (multilook used AZxRG)
# Joaquin Escayo @ 2017 j.escayo@csic.es
# CC LICENSE: Attribution-NonCommercial-ShareAlike 4.0 International

# v1.0 - Initial version
# v1.1 - Fixed name detection, now parses the name of the file correctly.

# ----------------------- CODE START --------------------------------

LC_ALL=C                                                        # to get the locales right. Decimal separator as point.
DEBUG=0                                                         # Debug 0 to don't show debug messages, any other value will show debugging messages.
results_file=$1
incidende_file=$2
output_file=$(basename $results_file | sed 's/\.csv//g' )_inc.csv
AZ_ml=$(echo $3 | cut -d'x' -f1)
RG_ml=$(echo $3 | cut -d'x' -f2)

if [ -z "$1" ] || [ -z $2 ] || [ -z $3 ] ; then
	echo "############# ERROR ##################"	
	echo "One or more input parameters is missing"
	echo "Use CPT_csv_add_incidence.bash results.csv /path/to/param.ang 3x15"
	echo "Where 3x15 is the multilook used in the processing parameters"
	echo "${bold}Do not use special characters in the route (as spaces) ${normal}"
	exit
fi

# check if output file exists
if [ -e $output_file ]; then
    echo "$output_file already exists. exiting"
    exit
fi

if [ ! $DEBUG == 0 ]; then
    echo "Results file: $results_file"
    echo "Incidence angle file: $incidende_file"
    echo "Multilook (Azimuth): $AZ_ml"
    echo "Multilook (Range): $RG_ml"
fi

columns=$(awk -F';' 'NR==1{print NF}' $results_file)
if [ ! $DEBUG == 0 ]; then echo "Number of fields in csv file: $columns"; fi

# RANGE column determination
for i in $(eval echo "{1..$columns}")
do
    if [ $(awk -F';' 'NR==1{print $'$i'}' $results_file ) == 'Range' ]; then
        RANGE=$i        
        if [ ! $DEBUG == 0 ]; then echo "Range is Column: $RANGE"; fi
        break
    fi
done
# AZIMUTH column determination
for i in $(eval echo "{1..$columns}")
do
    if [ $(awk -F';' 'NR==1{print $'$i'}' $results_file ) == 'Azimuth' ]; then
        AZIMUTH=$i        
        if [ ! $DEBUG == 0 ]; then echo "Azimuth is Column: $AZIMUTH"; fi
        break
    fi
done

# Start to process line by line the results file
echo "$(sed '1q;d' $results_file)Incidence_angle;" > $output_file                         # copy first line to $output_file
for i in $(tail -n +2 $results_file); do
PS_ID=$(echo $i | awk -F';' '{print $1}')
AZ_coord=$(echo $i | awk -F';' '{print $'$AZIMUTH'}')
RANGE_coord=$(echo $i | awk -F';' '{print $'$RANGE'}')
AZ_coord_inc=$(echo "scale=2; $AZ_coord*$AZ_ml/10" | bc | awk '{print int($1+0.5)}')
RANGE_coord_inc=$(echo "scale=2; $RANGE_coord*$RG_ml/10" | bc | awk '{print int($1+0.5)}')
inc_angle=$(gdallocationinfo -valonly $incidende_file  $RANGE_coord_inc $AZ_coord_inc)
inc_angle_round=$(printf "%.4f\n" "$inc_angle" | sed -e 's/\./,/g')
if [ ! $DEBUG == 0 ]; then echo "PS_ID: $PS_ID" ; echo "Azimuth coordinate: $AZ_coord"; echo "Azimuth coordinate incidence: $AZ_coord_inc" ; echo "Range coordinate: $RANGE_coord"; echo "Range coordinate incidence: $RANGE_coord_inc"; echo "Incidence angle: $inc_angle"; echo "Incidence angle rounded: $inc_angle_round";fi
echo "$i;$inc_angle_round" >> $output_file


done

exit
