# !/bin/bash

top_n=1

PRE="data"
MODEL="model"
TRAIN="train"
TEST="test"
PREDICT="predict"
EPOCHS=5


function config() {
	echo "----- config -----"
	wget -nc -nv https://raw.githubusercontent.com/sulabh9999/toml/master/tanzania.toml
}


# remove previous data
function clean() {
	echo "----- cleaning -----"
	rm -rf $PRE
	mkdir -p $PRE/tif $PRE/geojson $PRE/urls 
}



# donwload tiff 
# function download_dataset() {
# 	for i in `cat $PRE/urls/images.txt| head -$top_n`
# 	do
# 	  wget -nc -nv --show-progress -P $PRE/tif/ $i
# 	done

# 	for i in `cat $PRE/urls/label.txt| head -$top_n`
# 	do
# 	   wget -nc -nv --show-progress -P $PRE/geojson/ $i
# 	done
# }



function train_download_tif_geojson() {
	echo "----- downloading -----"
	tif=`echo $1 | tr -d '\r'`
	json=`echo $2 | tr -d '\r'`
	wget -nc -nv --show-progress -P $PRE/tif/ $tif
	wget -nc -nv --show-progress -P $PRE/geojson/ $json
}



# tif image to tiles
function train_tile() {
	echo "----- training tile to image -------"
	neo tile --zoom 20 --ts 1024,1024 --nodata_threshold 25 --rasters $PRE/tif/*.tif --out $PRE/images
	neo cover --dir $PRE/images --out $PRE/images/cover.csv

	for geoJson in `ls $PRE/geojson/*.geojson | head -$top_n`
	do
	  ogr2ogr -f SQLite $PRE/tanzania_labels.sqlite  $geoJson -dsco SPATIALITE=YES -t_srs EPSG:32630 -nlt PROMOTE_TO_MULTI -nln building -lco GEOMETRY_NAME=geom -append 
	done

	ogr2ogr -f GeoJSON $PRE/building.json $PRE/tanzania_labels.sqlite -dialect sqlite -sql "SELECT Buffer(geom, -0.25) AS geom FROM building" 
	neo rasterize --ts 1024,1024 --geojson $PRE/building.json --config=tanzania.toml --type Building --cover $PRE/images/cover.csv --out $PRE/labels
}



function train_set() {
	echo "----- training set -------"
	# Create Training DataSet
	awk '$2 > 0 { print $1 }' $PRE/labels/building_cover.csv > $PRE/buildings_cover.csv
	awk '$2 == 0 { print $1 }' $PRE/labels/building_cover.csv > $PRE/no_building_cover.csv
	sort -R $PRE/no_building_cover.csv | head -n 5000 > $PRE/no_building_subset_cover.csv
	cat $PRE/buildings_cover.csv $PRE/no_building_subset_cover.csv > $PRE/cover.csv

	neo cover --cover $PRE/cover.csv --splits 90/10 --out $PRE/train/cover.csv $PRE/eval/cover.csv
	neo subset --dir $PRE/images --cover $PRE/train/cover.csv --out $PRE/train/images
	neo subset --dir $PRE/labels --cover $PRE/train/cover.csv --out $PRE/train/labels
	neo subset --dir $PRE/images --cover $PRE/eval/cover.csv --out $PRE/eval/images
	neo subset --dir $PRE/labels --cover $PRE/eval/cover.csv --out $PRE/eval/labels
}



function preprocessing() {
	# config
	# clean
	train_download_tif_geojson $1 $2
	train_tile
	train_set 
}


# get_last_checkpoint() {
# 	if [ "$(ls -A $MODEL/*.pth)" ] 
# 	then
# 		echo "---last checkpoint ------"
# 	    return `ls $MODEL/*.pth | sort | tail -n -1`
# 	else
# 		echo "----- no checkpoints found ------------" 
# 		return ""   
# 	fi
# }

##-------------------------------------------- train ----------------------------------------------------

# !bash robosat_shell.sh train /content/drive/My\ Drive/occ_model
# !ls "/content/drive/My Drive"

function train() {
	echo "------------ train ----------------------"
	MODEL="${1}"  #"${1// /\ }"
	echo "---train model path: $MODEL------"
	# echo $MODEL
	mkdir -p "${MODEL}"

	if [ "$(ls -A "${MODEL}"/*.pth)" ] 
	then
		echo "---fetching checkpoint ------"
		# remove old models, remains only last updated 5 models
	    ls "${MODEL}"/*.pth | sort | head -n -5 | xargs rm -rf 
	    latest_checkpoint=`ls "${MODEL}"/*.pth | sort | tail -n -1`
    
	    count=`ls "${MODEL}"/*.pth | sort | wc -l`
		epochs=${latest_checkpoint//[!0-9]/}    #extract numver from string
      	epochs=$((10#$epochs +EPOCHS))      # add other new epochs
      	neo train --config=tanzania.toml --resume --checkpoint="${latest_checkpoint}" --dataset $PRE/train --epochs $epochs --out "${MODEL}" --bs=1
		neo eval --checkpoint "${latest_checkpoint}" --dataset $PRE/train
	else
      	echo "----- new checkpoints ------------"
	    neo train --config=tanzania.toml --dataset $PRE/train  --epochs 5 --out "${MODEL}" --bs=1
	    neo eval --checkpoint `ls "${MODEL}"/*.pth | sort | tail -n -1` --dataset $PRE/train
	fi
}





## -------------------------------------------- test ---------------------------------------------------
test_download() {
	echo "--------- test downloafing ------------------"
	wget -nc -nv --show-progress -P $TEST/tif/ $1
	wget -nc -nv --show-progress -P $TEST/geojson/ $2
}

test_tile() {
	echo "-----------test split tiles ----------------"
	neo tile --zoom 20  --nodata_threshold 25 --rasters $TEST/tif/*tif --out $PREDICT/images
	neo cover --dir $PREDICT/images --out $PREDICT/images/cover.csv
}

predict() {
	# MODEL="${3}"
	echo "-----------test predict ---------------"
	echo "--model: $MODEL..1: ${1}...2: ${2}..3: ${3}"
	echo "${MODEL}"/*.pth
	echo "--------------------------"
	neo predict --config=tanzania.toml  --checkpoint `ls "${MODEL}"/*.pth | sort | tail -n -1` --dataset $PREDICT --out $PREDICT/masks
}

function test() {
	test_download $1 $2 
	test_tile 
	# predict
}

"$@"