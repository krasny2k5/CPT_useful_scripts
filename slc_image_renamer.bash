#!/bin/bash

# Joaquín Escayo 2016 (j.escayo@csic.es)
# This program creates a directory structure valid to use with Subsidence (CPT) software
# by creating directories with the date and sensor (YYYYMMDD.sensor).
# To use execute with the following command:
# slc_image_renamer.sh directory_of_slc
# If you wanna use the current directory you can use . as directory input.
# --------------------------------------------------------------------
# TO-DO:
# More satellites formats to implement (rst2, cskd, alos, sen1)
# Detectar cuando $f es un directorio y mostrarlo en pantalla
# Permitir directorio output (como $2 por ejemplo)
# Corregir errores producidos por caracteres especiales en la ruta de la carpeta.
# ---------------------------------------------------------------------
# Log
# v 1.0 - Rename of the command and major update to support new acquisition TSX images (19/09/2016).
# v 1.1 - Support for new acquisitions from TDX. (28/09/2016)
# v 2.0 - Inital support for Sentinel-1 acquisitions (06/10/2016)
# v 2.1 - Check for Sentinel-1 same date products. (07/10/2016)
# v 2.2 - Check unzip output to detect corrupted files. (10/10/2016)
# v 3.0 - Check if the image is already present in CPT format (sen1)
# v 3.1 - Added detection of dual polarization images on sentinel-1 (13/10/2016)
# Set DEBUG to 1 if you wanna see debug output.

DEBUG=0

# bold and normal expressions
bold=$(tput bold)
normal=$(tput sgr0)

# Check of the input variable (directory)
if [ -z "$1" ]; then
	echo "############# ERROR ##################"	
	echo "No SLC directory used as input"
	echo "Use slc_image_renamer.sh slc_directory"
	echo "If you want to use current directory as input:"
	echo "slc_image_renamer.bash ."
	echo "${bold}Do not use special characters in the route (as spaces) ${normal}"
	exit
elif [ $1 == "." ]; then
    DIR=$(pwd)
#checkign for absolute or relative path
elif [[ $(expr substr $1 1 1) == "/" ]]; then # absolute path as input
    DIR=$1
else # relative path
    DIR=$(pwd)/$1
fi

FILES=$DIR/*

if [ $DEBUG == 1 ]; then
	echo "Files to process"	
	echo $FILES
	echo "DIRECTORY: $DIR"
	read -p "Press [Enter] to continue"
fi

# Variable initialization

totalno=0
totalsi=0
unset multiple_files

for f in $FILES
do
	# Getting filename and extension. .tar.gz files will get as .gz extension
	file=$(basename $f)
	extension=${f##*.}	
	# Variables clean
	unset year
	unset month
	unset day
    unset fecha

	# Archivos ERS: Son directorios cuya nombre empieza por ER01/02, o archivos cuyo nombre empieza por SAR y termina por .E1/2.
	# Buscaremos estos patrones en el nombre de archivo/directorio
	# ERS1 files with CEOS format (directory)
	if [ $(echo $file | cut -c1-4) == ER01 ] ; then
		echo "${bold}ERS1 image (CEOS format)${normal}: $file"
        date=$(echo $file | cut -c17-24)		
		CPTDIR=$date.ers1
        if [ -d "$DIR/$CPTDIR" ] ; then
            multiple_files=("${multiple_files[@]}" $CPTDIR)
            totalno=$((totalno+1))
            echo "Error on $file there is another image with same date (not supported for CEOS format)"
        else
            mv $f "$DIR/$CPTDIR"
		    totalsi=$((totalsi+1))
        fi
	# ERS2 files with CEOS format (directory)
	elif [ $(echo $file | cut -c1-4) == ER02 ]; then
		echo "${bold}ERS2 image (CEOS format)${normal}: $file"
		date=$(echo $file | cut -c17-24)
		CPTDIR=$date.ers2
        if [ -d "$DIR/$CPTDIR" ] ; then
            multiple_files=("${multiple_files[@]}" $CPTDIR)
            totalno=$((totalno+1))
            echo "Error on $file there is another image with same date (not supported for CEOS format)"
        else
            mv $f "$DIR/$CPTDIR"
		    totalsi=$((totalsi+1))
        fi
      	
	# ERS1 files with ENVISAT format (.E1)
	elif [ $(echo $file | cut -c1-7) == SAR_IMS ] && [ $extension == E1 ] ; then
		echo "${bold}ERS1 image (ENVISAT format):${normal} $file"
		date=$(echo $file | cut -c15-22)
		CPTDIR=$date.ers1
        if [ -d "$DIR/$CPTDIR" ] ; then
            multiple_files=("${multiple_files[@]}" $CPTDIR)
        else
            mkdir "$DIR/$CPTDIR"        
        fi
		mv $f "$DIR/$CPTDIR"
		totalsi=$((totalsi+1))

	# ERS2 files with ENVISAT format (.E2)
	elif [ $(echo $file | cut -c1-7) == SAR_IMS ] && [ $extension == E2 ] ; then
		echo "${bold}ERS2 image (ENVISAT format):${normal} $file"
		date=$(echo $file | cut -c15-22)
		CPTDIR=$date.ers2
        if [ -d "$DIR/$CPTDIR" ] ; then
            multiple_files=("${multiple_files[@]}" $CPTDIR)
        else
            mkdir "$DIR/$CPTDIR"        
        fi
		mv $f "$DIR/$CPTDIR"
		totalsi=$((totalsi+1))
		
	# ENVISAT FILES
	elif [ $extension == "N1" ]; then
		echo "${bold}ENVISAT image${normal}: $file"
		#Me quedo con el año día y sensor y lo almaceno en dia
		date=$(echo $file | cut -c15-22 )
        CPTDIR=$date.envi
		if [ -d "$DIR/$CPTDIR" ] ; then
            multiple_files=("${multiple_files[@]}" $CPTDIR)
        fi
        mkdir "$DIR/$CPTDIR"
		mv "$DIR/$file" "$DIR/$CPTDIR"
		totalsi=$((totalsi+1))

	# Routine for new acquisition TSX files. Since it is not possible to decompress one file the complete archive will be extracted before check the date and orbit. http://superuser.com/questions/655739/extract-single-file-from-huge-tgz-file
    elif [ $(echo $file | cut -c1-15) == dims_op_oc_dfd2 ] && [ $extension == gz ]; then
        echo "${bold}TerraSAR-X image: ${normal} $file"
        tar xzf $f -C $DIR
        directorio=$(echo $file | cut -d'.' -f1)
	#check for satellite (TDX or TSX)
	    if [ -d $directorio/TSX-1.SAR.L1B/TSX* ]; then
    		type=TSX
	    else
    		type=TDX
	    fi
	    if [ $type == TSX ]; then         
		    date=$(cat $DIR/$directorio/TSX-1.SAR.L1B/*/TSX1* | grep filename | grep TSX1 | cut -d'>' -f2 | cut -c29-36)
        	geometria=$(cat $DIR/$directorio/TSX-1.SAR.L1B/*/TSX1* | sed -n '/orbitDirection/{s/.*<orbitDirection>//;s/<\/orbitDirection.*//;p;}')
	    else
	    	date=$(cat $DIR/$directorio/TSX-1.SAR.L1B/*/TDX1* | grep filename | grep TDX1 | cut -d'>' -f2 | cut -c29-36)
        	geometria=$(cat $DIR/$directorio/TSX-1.SAR.L1B/*/TDX1* | sed -n '/orbitDirection/{s/.*<orbitDirection>//;s/<\/orbitDirection.*//;p;}')
	    fi
        if [ $geometria == ASCENDING ]; then
            #echo "ASCENDING orbit"
            touch $DIR/$directorio/ASCENDING
        elif [ $geometria == DESCENDING ]; then
            #echo "DESCENDING orbit"
            touch $DIR/$directorio/DESCENDING
        else
            echo "Error reading orbit geometry"
        fi
        mv "$DIR/$directorio" "$DIR/$date.tsx1"
        totalsi=$((totalsi+1))
    

    # Sentinel-1 image detection (ZIP format)
    elif [ $(echo $file | cut -c1-3) == S1A  ] || [ $(echo $file | cut -c1-3) == S1B ] && [ $extension == zip ]; then
        if [ $(echo $file | cut -c1-3) == S1A ]; then
            echo "${bold}Sentinel-1A Image (compressed):${normal} $file"
        else
            echo "${bold}Sentinel-1B Image (compressed):${normal} $file"
        fi
        date=$(echo $file | cut -c18-25)
        # Polarization:
        # Single_POL SH, SV | Dual_POL DV,DH (S1A_IW_SLC__1SDV_20160416T070210_20160416T070237_010843_01039F_B6EC.zip)
        POL=$(echo $file | cut -c15-16)
        if [ $POL == "SV" ] || [ $POL == "SH" ]; then
            CPTDIR=$date.sen1
        elif [ $POL == "DV" ] || [ $POL == "DH" ]; then
            CPTDIR=$date.sen1.dp
        else
            echo "ERROR READING POLARIZATION OF THE FILE"
        fi
        directorio=$(echo $file | cut -d'.' -f1)
        #check for another directory with same date
        if [ -d "$DIR/$CPTDIR" ] ; then
            echo "${bold}There are two products with same date or duplicate product, please check $file${normal}"
            totalno=$((totalno+1))
        else
            unzip -qq $f &> /dev/null # redirect to /dev/null to hide output messages
            # Check for zip file integrity (based on output of unzip command)
            if [ "$?" == "0" ]; then
                mv "$DIR/$directorio.SAFE" "$DIR/$CPTDIR"
                totalsi=$((totalsi+1))
            else
                echo "${bold}ERROR, ZIP file appears to be corrupted, please check:${normal} $file"
                totalno=$((totalno+1))
            fi
        fi

    # Sentinel-1 image detection (uncompressed format)
    elif [ $(echo $file | cut -c1-3) == S1A  ] || [ $(echo $file | cut -c1-3) == S1B ] && [ $extension == SAFE ]; then
        if [ $(echo $file | cut -c1-3) == S1A ]; then
            echo "${bold}Sentinel-1A Image (uncompressed):${normal} $file"
        else
            echo "${bold}Sentinel-1B Image (uncompressed):${normal} $file"
        fi        
        date=$(echo $file | cut -c18-25)
        # Polarization:
        # Single_POL SH, SV | Dual_POL DV,DH (S1A_IW_SLC__1SDV_20160416T070210_20160416T070237_010843_01039F_B6EC.zip)
        POL=$(echo $file | cut -c15-16)
        if [ $POL == "SV" ] || [ $POL == "SH" ]; then
            CPTDIR=$date.sen1
        elif [ $POL == "DV" ] || [ $POL == "DH" ]; then
            CPTDIR=$date.sen1.dp
        else
            echo "ERROR READING POLARIZATION OF THE FILE"
        fi
        if [ -d "$DIR/$CPTDIR" ] ; then
            echo "${bold}There are two products with same date or duplicate products, please check $file${normal}"
            totalno=$((totalno+1))
        else
           mv "$DIR/$file" "$DIR/$CPTDIR"
           totalsi=$((totalsi+1))
        fi

     else
		echo "${bold}Unknow SAR image:${normal} $file "
		totalno=$((totalno+1))
	fi

	if [ $DEBUG == 1 ]; then
		echo "F variable (path+file): $f"
        echo "DIR VAR: $DIR"		
        echo "File: $file"
		echo "Extension: $extension"
		echo "Acquisition date: $date"
		echo "CPTDIR: $CPTDIR"
        echo "------------------------------"
	fi
done

echo "${bold} A total of $totalsi images has been processed, $totalno files NOT processed ${normal}"

if [ $DEBUG == 1 ]; then
    echo "Variable multiple_files: $multiple_files"
fi

if [ ! -z $multiple_files ] ; then
    echo "${bold} WARNING: The following directories contains more than one image (please check):${normal}"
    for i in "${multiple_files[@]}"
    do    
        echo $i
    done
fi
