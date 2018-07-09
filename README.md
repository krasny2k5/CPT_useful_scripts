# CPT useful scripts
Several bash scripts to use with CPT InSAR processor. I wrote this scripts for my personal use so don't expect very detailed outputs.

# slc_image_renamer
This script is intended for use with ERS, ENVI and TSX satellites. It also has support for Sentinel-1 files, but it is better to use sentinel_slc_renamer.bash instead this one.

# sentinel_slc_renamer.bash
This one is intended to rename Sentinel-1 images. Is able to detect different frames of the same track and order in slice1,slice2... subdirectories. This way CPT is able to recognize the images and process it.

# CPT_csv_add_incidence.bash
This routine is intended to add incidence angles to the output csv from subsoft. Since Subsidence GUI doesn't allow to retrieve this information I created this small program. It uses gdallocationinfo which is very very slow (can be improved by generating a text file of the param.ang file).

# CPT_coher_raster.bash
This one allows to obtain georeferenced tifs of mean coherence from a subsoft processing. Did because I needed to obtain this info for other purpouses. It can be extended to plot georeferenced interferograms and many other things.
