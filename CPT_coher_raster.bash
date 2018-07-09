#!/bin/bash
######################################################################################
# CPT_coher_raster.bash
# This program generates a raster file with coordinates for medium coherence.
# Use: CPT_coher_raster subsoftdirectory utm/lat
# you must specify the subsoft directory to work with
# optionally you can set lat/long or UTM coordinate system.
# Joaquin Escayo | j.escayo@csic.es | Rome, June 2018       
######################################################################################

# V 1.0 - Inital version 09/07/2018

# WARNING: CHECK THE CORRECT EPSG FOR THE OUTPUT! # TODO: IMPROVE THIS PART

# Related functions (for benchmarking)
start_measuring_time() {
  read s1 s2 < <(date +'%s %N')
}

stop_measuring_time() {
  read e1 e2 < <(date +'%s %N')
}

show_elapsed_time() {
  echo "$((e1-s1)) seconds, $((e2-s2)) nanoseconds"
}

#  Control for input directory
if [ -z "$1" ]; then
	echo "############# ERROR ##################"	
	echo "No subsfot directory used as input"
	echo "${bold}Do not use special characters in the route (as spaces) ${normal}"
	echo "Use: CPT_coher_raster.bash /path/to/dir [proj]"
	echo "where proj is UTM or LATLONG"
	echo "######################################"
	exit
elif [ ! -f gui_status.xml ]; then
	echo "This directory does not appear to be a subsoft folder"
	exit
elif [ -f gui_status.xml ] && [ ! -d 04_geocoding ]; then
	echo "This directory does not contain geocoding information"
	echo "or it's not a subsoft folder."
	echo "Please run geocoding in CPT and try it again"
	exit
elif [ -f gui_status.xml ] && [ ! -f 02_pixel_selection/mean_coher.dat ]; then
	echo "This directory does not contain coherence files"
	echo "or it's not a subsoft folder."
	echo "Please run geocoding in CPT and try it again"
	exit
elif [ $1 == "." ]; then
    DIR=$(pwd)
#checkign for absolute or relative path
elif [[ $(expr substr $1 1 1) == "/" ]]; then # absolute path as input
    DIR=$1
else # relative path
    DIR=$(pwd)/$1
fi

# Coordinate system output
if [ -z "$2" ]; then
	COORD=UTM
	echo "No coordinate system was specified, using UTM"
elif [ $2 == "LATLONG" ]; then
	COORD=LATLONG
	echo "Using LAT/LONG as coordinate system"
elif [ $2 == "UTM" ]; then
	COORD=UTM
	echo "Using UTM as coordinate system"
else
	echo "Use coordinate system as variable"
	echo "posible uses are UTM or LATLONG"
	exit
fi

# Debug variable, true for debugging
DEBUG=true

# Creating temp dir and removing previous contents
TMP=$DIR/temp
rm -rf $TMP &> /dev/null
mkdir $TMP &> /dev/null


# CODE START

# COHERENCE FILE:
COHER_FILE=$DIR/02_pixel_selection/mean_coher.dat
# LAT LONG FILES:
if [ $COORD == "UTM" ]; then
	LAT_FILE=$DIR/04_geocoding/yutm.dat
	LONG_FILE=$DIR/04_geocoding/xutm.dat
elif [ $COORD == "LATLONG" ]; then
	LAT_FILE=$DIR/04_geocoding/lat.dat	
	LONG_FILE=$DIR/04_geocoding/lon.dat
else
	echo "Error 1"
	exit
fi

# This should never happens because it's checked at the beginning, but who knows.
if [ ! -f $COHER_FILE ] || [ ! -f $LAT_FILE ] || [ ! -f $LONG_FILE ]; then
	echo "Error 2"
	echo "coherence or coordinates files are missing, please check"
	exit
fi

# Getting raster dimensions
samples=$(gdalinfo $COHER_FILE | grep Size | awk '{print $3}' | sed 's/.$//')  # this can be improved
lines=$(gdalinfo $COHER_FILE | grep Size | awk '{print $4}')		       #

if [ $DEBUG ]; then
	echo "Work dir: $DIR"
	echo "COORD: $COORD"
	echo "COHERENCE: $COHER_FILE"
	echo "LAT_FILE: $LAT_FILE"
	echo "LONG_FILE: $LONG_FILE"
	echo "Samples: $samples"
	echo "Lines: $lines"
fi

# First approach, read values of the three files using gdallocationinfo.
# While this method works is very very slow to compute because gdallocationinfo is called so many times.
#for i in $(eval echo "{1..$samples}"); do
#for j in $(eval echo "{1..$lines}"); do
#lat=$(gdallocationinfo -valonly $LAT_FILE  $i $j)
#long=$(gdallocationinfo -valonly $LONG_FILE  $i $j)
#coher=$(gdallocationinfo -valonly $COHER_FILE  $i $j)
#echo "$lat,$long,$coher" >> $TMP/out.txt
#done
#done

# Other solution
# converting files to xyz
gdal_translate -of xyz $COHER_FILE $TMP/coher.txt # TODO: reduce the number of decimals in coherence
gdal_translate -of xyz $LAT_FILE $TMP/lat.txt
gdal_translate -of xyz $LONG_FILE $TMP/lon.txt

# merging the three files together
# GDAL XYZ format uses X,Y,VAL
paste $TMP/lon.txt $TMP/lat.txt $TMP/coher.txt > $TMP/lon_lat_coher.txt
awk '{print $3","$6","$9}' $TMP/lon_lat_coher.txt > $TMP/lon_lat_coher.csv # TODO: check that $1=$4=$7 and $2=$5=$8 before the merging, if not exit.
sed -i '1s/^/lon,lat,coher\n/' $TMP/lon_lat_coher.csv

# Rasterize the result into a geotiff:
# First convert results to SHP file

# vrt file creation

echo "<OGRVRTDataSource>" > $TMP/driver.vrt
echo "  <OGRVRTLayer name=\"coherence\">" >> $TMP/driver.vrt
echo "    <SrcDataSource>temp/lon_lat_coher.csv</SrcDataSource>" >> $TMP/driver.vrt
echo "    <SrcLayer>lon_lat_coher</SrcLayer>" >> $TMP/driver.vrt
echo "    <GeometryType>wkbPoint</GeometryType>" >> $TMP/driver.vrt
echo "    <LayerSRS>EPSG:32630</LayerSRS>" >> $TMP/driver.vrt
echo "    <GeometryField encoding=\"PointFromColumns\" x=\"lon\" y=\"lat\"/>" >> $TMP/driver.vrt
echo "  </OGRVRTLayer>" >> $TMP/driver.vrt
echo "</OGRVRTDataSource>" >> $TMP/driver.vrt

echo "Creating SHP file from CSV data"
ogr2ogr -f "ESRI Shapefile" $TMP/shapefile.dbf $TMP/lon_lat_coher.csv
ogr2ogr -f "ESRI Shapefile" $TMP/shapefile.shp $TMP/driver.vrt
echo "Creating TIFF file from Shapefile"
gdal_rasterize -a coher -tr 60.0 60.0 -l shapefile $TMP/shapefile.shp $(echo $DIR | awk -F/ '{print $(NF-2)}')_coher.tif
echo "done"


