#! /bin/bash
#Script to automate the download of NMME seasonal rainfall deterministic hindcasts and observations, 
#and to execute CPT to assess associated raw skill
#Author: Á.G. Muñoz (agmunoz@iri.columbia.edu)
#
#Output:
# + Several skill maps for assessment of deterministic forecast, in the output folder.
# + CPT scripts used to assess skill, in the scripts folder.
# + Downloaded input files, in the input folder.
#Notes:
#1. Old data in the input folder is deleted at the beginning of the process!
#2. Right now there's no spatial subsetting (it uses the domain prescribed by the DL). This could be easily fixed.
#4. Rainfall observations are CPC Unified (Chen et al 2008).

####START OF USER-MODIFIABLE SECTION######

#Initialization month(s) -modify as needed:
#declare -a mon=('Jan' 'Feb' 'Mar' 'Apr' 'May' 'Jun' 'Jul' 'Aug' 'Sep' 'Oct' 'Nov' 'Dec')
declare -a mon=('Jan')  #if just a particular month is desired
#Target months
declare -a tgti=('1.5')   #S: start for the DL
declare -a tgtf=('3.5')   #S: end for the DL 
declare -a tgt=('Feb-Apr')#for now, just write the period corresponding a tgti to tgtf (for DL)
#Initial and final years
iyear=1982
fyear=2010
#Spatial domain for predictor
nla1=29 # Nothernmost latitude
sla1=23 # Southernmost latitude
wlo1=82 # Westernmost longitude
elo1=90 # Easternmost longitude
#Spatial domain for predictand
nla2=29 # Nothernmost latitude
sla2=23 # Southernmost latitude
wlo2=82 # Westernmost longitude
elo2=90 # Easternmost longitude
#PATH to CPT root directory
cptdir='/Users/agmunoz/Documents/Angel/CPT/CPT/15.7.3/'

####END OF USER-MODIFIABLE SECTION######
####DO NOT CHANGE ANYTHING BELOW THIS LINE####

clear
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo Script to automate the download of NMME seasonal rainfall deterministic hindcasts and observations,
echo and to execute CPT to assess associated raw skill
echo Author: Á.G. Muñoz - agmunoz@iri.columbia.edu
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo
echo
#Prepare folders
echo Creating working folders, if not already there...
mkdir -p input
mkdir -p output
mkdir -p scripts
rm -Rf input/model_*.tsv input/obs_*.tsv  #comment if deletion of old input files is not desired.
rm -Rf scripts/*

cd input
#Set up some parameters
export CPT_BIN_DIR=${cptdir}

#Start loop
for mo in "${mon[@]}"
do
#Download hindcasts
url='http://iridl.ldeo.columbia.edu/SOURCES/.Models/.NMME/.CMC1-CanCM3/.HINDCAST/.MONTHLY/.prec/S/%280000%201%20'${mo}'%20'${iyear}'-'${fyear}'%29/VALUES/L/%28'${tgti}'%29/%28'${tgtf}'%29/RANGEEDGES/%5BL%5D//keepgrids/average/%5BM%5D/average/Y/%2823N%29/%2829N%29/RANGEEDGES/X/%2882E%29/%2890E%29/RANGEEDGES/-999/setmissing_value/%5BX/Y%5D%5BL/S/add%5D/cptv10.tsv'
echo $url
echo ---------------------------------------------------
echo Downloading hindcasts and observations for $tgt initialized in $mo ...
curl -k ''$url'' > model_precip_${tgt}_ini${mon}.tsv

#Download observations
url='http://iridl.ldeo.columbia.edu/SOURCES/.Models/.NMME/.CPC-CMAP-URD/prate/T/%28Jan%20'${iyear}'%29/%28Dec%20'${fyear}'%29/RANGE/T/3/runningAverage/T/%28'${tgt}'%29/VALUES/Y/%2824N%29/%2827N%29/RANGEEDGES/X/%2883E%29/%2888E%29/RANGEEDGES/-999/setmissing_value/%5BX/Y%5D%5BT%5Dcptv10.tsv'
curl -k ''$url'' > obs_precip_${tgt}.tsv


#Create CPT script
cd ../scripts
echo ---------------------------------------------------
echo Producing CPT scripts for $tgt initialized in $mo ...

  
cat  <<< '#!/bin/bash 
'${cptdir}'CPT.x <<- END
614 # Opens GCM validation
1 # Opens X input file
../input/model_precip_'${tgt}'_ini'${mon}'.tsv
'${nla1}' # Nothernmost latitude
'${sla1}' # Southernmost latitude
'${wlo1}' # Westernmost longitude
'${elo1}' # Easternmost longitude

2 # Opens Y input file
../input/obs_precip_'${tgt}'.tsv
'${nla2}' # Nothernmost latitude
'${sla2}' # Southernmost latitude
'${wlo2}' # Westernmost longitude
'${elo2}' # Easternmost longitude

4 # X training period
1982 # First year of X training period
5 # Y training period
1982 # First year of Y training period

531 # Goodness index
3 # Kendalls tau

7 # Option: Lenght of training period
29 # Lenght of training period 
8 # Option: Length of cross-validation window
3 # Enter length

#542 # Turn ON zero bound for Y data
545 # Turn ON synchronous predictors
#561 # Turn ON p-values for skill maps

544 # Missing value options
-999 # Missing value X flag:
10 # Maximum % of missing values
10 # Maximum % of missing gridpoints
1 # Number of near-neighbours
4 # Missing value replacement : best-near-neighbours
-999 # Y missing value flag
10 # Maximum % of missing values
10 # Maximum % of missing stations
1 # Number of near-neighours
4 # Best near neighbour


# Cross-validation
112 # save goodness index
../output/PRCP_Kendallstau_raw_'${tgt}'_ini'${mon}'.txt

#######BUILD MODEL  !!!!!
311 # Cross-validation

#131 # select output format
#3 # GrADS format
# Save forecast results
#111 # output results
# save as GrADS

413 # cross-validated skill maps
2 # save Spearmans Correlation
../output/PRCP_Spearman_raw_'${tgt}'_ini'${mon}'.txt

413 # cross-validated skill maps
3 # save 2AFC score
../output/PRCP_2AFC_raw_'${tgt}'_ini'${mon}'.txt

413 # cross-validated skill maps
10 # save 2AFC score
../output/PRCP_RocBelow_raw_'${tgt}'_ini'${mon}'.txt

413 # cross-validated skill maps
11 # save 2AFC score
../output/PRCP_RocAbove_raw_'${tgt}'_ini'${mon}'.txt

#0 # Stop saving  (not needed in newest version of CPT)

0 # Exit
END
' > RawSkill_precip_${tgt}_ini${mon}.cpt 

#Execute CPT and produce skill maps
echo ---------------------------------------------------
echo Executing CPT and producing skill maps for $mo ...
chmod 755 RawSkill_precip_${tgt}_ini${mon}.cpt  
./RawSkill_precip_${tgt}_ini${mon}.cpt 

cd ../input

echo Done with $tgt initialized in $mo !! Check output folder for results.
echo
echo
done