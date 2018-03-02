#!/bin/bash
# Joaquín Escayo 2016 (j.escayo@csic.es)
# V 1.0 - Initial version, lot to re-do but works as intended. Not fool-proof, be careful with the inputs. (22/11/2017)
# V 1.1 - Some bugfixes. Added the option to remove VH polarization. (1/3/2018)
# TO-DO:
# Option to keep only one polarization

#########################
# SOME USEFUL FUNCTIONS #
#########################

containsElement () { for e in "${@:2}"; do [[ "$e" = "$1" ]] && return 0; done; return 1;} # Function to check if an element is part of an array
sentinel_unzip () {                                                                # Function to decompress Sentinel Image, uses 2 arguments (input file and output folder)
if [[ -z $1 ]] || [[ -z $2 ]]; then echo "You must specify file and output folder"; exit; fi
unzip -qq -d $2 $1 &> /dev/null                                                          # redirect to /dev/null to hide output messages
mv $2/*SAFE/* $2/
}

#########################
# DIRECTORIES CHECK     #
#########################
# Check of the input variable (directory)
if [ -z "$1" ]; then
	echo "############# ERROR ###################################"	
	echo "No SLC directory used as input"
	echo "Use slc_image_renamer.sh slc_directory"
	echo "If you want to use current directory as input:"
	echo "slc_image_renamer.sh ."
	echo "Do not use special characters in the route (as spaces)"
	echo "#######################################################"	
	exit
elif [ $1 == "." ]; then
    DIR=$(pwd)
#checkign for absolute or relative path
elif [[ $(expr substr $1 1 1) == "/" ]]; then # absolute path as input
    DIR=$1
else # relative path
    DIR=$(pwd)/$1
fi

############################
# Variables initialization #
############################
totalno=0
totalsi=0
REPORT=$DIR/files
rm $REPORT &> /dev/null  # TODO: check if report exists and delete if exists or ask user
MSLICES=()                                                                        # Array to index multiple slices dates

echo "Generating list of files"
for i in $(find $DIR \( -name "S1A_*.zip" -or -name "S1B_*.zip" \)); do
SAT=$(basename $i | cut -d'_' -f1)
MODE=$(basename $i | cut -d'_' -f2)
TYPE=$(basename $i | cut -d'_' -f3)
POL=$(basename $i | cut -d'_' -f5)
DATE_TIME=$(basename $i | cut -d'_' -f6)
DATE=$(basename $i | cut -d'_' -f6 | cut -c1-8)
TIME=$(basename $i | cut -d'_' -f6 | cut -c10-15)
ID=$(basename $i | cut -d'_' -f10 | cut -d'.' -f1)
echo "$i,$SAT,$MODE,$TYPE,$POL,$DATE_TIME,$DATE,$TIME,$ID" >> $REPORT
done
NIMAGES=$(cat $REPORT | wc -l)
if [ $(cat $REPORT | wc -l) == 0 ]; then                                         # Check that at least one image is found
    echo "No images found, please make sure that the"
    echo "directory contains at least one SLC image"
    exit
fi

sort --field-separator=',' --key=6 $REPORT -o $REPORT                             # sort file list by time and date and save in the same file
echo "The following files has been found:"
awk -F',' '{print $1}' $REPORT
echo "Found $NIMAGES Sentinel-1 files in the input directory"
read -n1 -r -p "Press any key to continue..." key

#############################
# Start to processing images#
#############################


for i in $(cat "files"); do
DATE=$(echo $i | awk -F',' '{print $7}')
DATE_TIME=$(echo $i | awk -F',' '{print $6}')
N_IMAGES=$(grep $DATE $REPORT | wc -l)

if [[ $(containsElement $DATE ${MSLICES[@]}; echo $?) == 1 ]];then                # Check if it is a multiple slice image if it is a multiple slice file, skip it
echo "Satellite image: $(basename $(echo $i | awk -F',' '{print $1}'))"

########################
# Checking polarization#
########################
POL=$(echo $i | awk -F',' '{print $5}' | cut -c3-4)
if [ $POL == "SV" ] || [ $POL == "SH" ]; then
            CPTDIR=$DIR/$DATE.sen1
elif [ $POL == "DV" ] || [ $POL == "DH" ]; then
            CPTDIR=$DIR/$DATE.sen1.dp
fi

########################
# SINGLE IMAGE FOUND   #
########################
if [ $N_IMAGES == 1 ]; then
    FILE=$(echo $i | awk -F',' '{print $1}')
	echo "Processing image $(echo $totalsi+1 | bc) of $NIMAGES"
    echo "One image found for $DATE"
    echo "Ouput folder: $CPTDIR"
    mkdir $CPTDIR
    sentinel_unzip $FILE $CPTDIR
    totalsi=$((totalsi+1))
echo "-------------------------------------------------------------------------"

########################
#MULTIPLE IMAGES FOUND #
########################
else
	echo "Processing images $(echo $totalsi+1 | bc) to $(echo $totalsi+$N_IMAGES | bc) of the total $NIMAGES images"
    echo "$DATE appears to have more than one slices"
    MSLICES+=($DATE)
    counter=1
    mkdir $CPTDIR
    for i in $(grep $DATE $REPORT);do
        FILE=$(echo $i | awk -F',' '{print $1}')
        DATE_TIME=$(echo $i | awk -F',' '{print $6}')
        echo "Processing $DATE_TIME slice #$counter"
        echo "Output folder: $CPTDIR/slice$counter"
        mkdir $CPTDIR/slice$counter
        sentinel_unzip $FILE $CPTDIR/slice$counter
        counter=$((counter+1))
        totalsi=$((totalsi+1))
    done
    echo "-------------------------------------------------------------------------"

fi
fi
done

echo "A total of $totalsi SLC images has been processed"
if [ $totalsi == $(cat $REPORT | wc -l) ]; then
    echo "All images has been processed"
else
    echo "Some images has been not processed, please check"
fi

#########################
# Polarization removal  #
#########################
echo "########################################################"
echo "Do you want to remove VH polarization?"
echo "This is only valid if you have 1SDV files"
read -r -p "Only VV polarization will be preserved. Enter [y/N] " response

if [[ $response =~ ^([yY][eE][sS]|[yY])+$ ]]
then
    echo "Removing VH Polarization"
        for i in $(find $DIR/ | grep vh); do
            rm $i
        done
    echo "Renaming directories"
    for i in $(ls -d $DIR/*/); do
        NAME=$(echo $i | sed 's/.dp//')
        mv $i $NAME
    done
else
    echo "No polarizations were removed"
fi



########################
#   Clean temp files   #
########################
rm $REPORT












