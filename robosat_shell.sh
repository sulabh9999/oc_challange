# !/bin/bash

top_n=1

PRE="data"
MODEL="model"
TRAIN="train"
TEST="test"
PREDICT="predict"
WORKERS=100
EPOCHS=5
zoom=20
batch=3



function config() {
	echo "----- config -----"
	wget -nc -nv https://raw.githubusercontent.com/sulabh9999/toml/master/tanzania.toml
}


# remove previous data
function clean() {
	echo "----- cleaning -----"
	rm -rf $PRE/tif $PRE/geojson $PRE/train $PRE/images
	mkdir -p $PRE/tif $PRE/geojson $PRE/urls $PRE/train
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
	neo tile --zoom=$zoom --ts 1024,1024 --nodata_threshold 25 --rasters $PRE/tif/*.tif --out $PRE/images --workers=$WORKERS
	neo cover --dir $PRE/images --out $PRE/images/cover.csv
	echo "--------- resterise -------------"
	neo rasterize --config=tanzania.toml --ts 1024,1024 --geojson $PRE/geojson/*.geojson --type Building --cover $PRE/images/cover.csv --out $PRE/labels --workers=$WORKERS
	# neo tile --zoom 19 --bands 1,2,3 --nodata_threshold 25 --rasters train/*/*[^-]/*tif --out train/images
}



# function train_set() {
# 	echo "----- training set -------"
# 	# Create Training DataSet
# 	awk '$2 > 0 { print $1 }' $PRE/labels/building_cover.csv > $PRE/buildings_cover.csv
# 	awk '$2 == 0 { print $1 }' $PRE/labels/building_cover.csv > $PRE/no_building_cover.csv
# 	sort -R $PRE/no_building_cover.csv | head -n 5000 > $PRE/no_building_subset_cover.csv
# 	cat $PRE/buildings_cover.csv $PRE/no_building_subset_cover.csv > $PRE/cover.csv

# 	neo cover --cover $PRE/cover.csv --splits 90/10 --out $PRE/train/cover.csv $PRE/eval/cover.csv
# 	neo subset --dir $PRE/images --cover $PRE/train/cover.csv --out $PRE/train/images
# 	neo subset --dir $PRE/labels --cover $PRE/train/cover.csv --out $PRE/train/labels
# 	neo subset --dir $PRE/images --cover $PRE/eval/cover.csv --out $PRE/eval/images
# 	neo subset --dir $PRE/labels --cover $PRE/eval/cover.csv --out $PRE/eval/labels
# }



function preprocessing() {
	# config
	# clean
	train_download_tif_geojson $1 $2
	train_tile
	# train_set 
}


# get_last_checkpoint() {
# 	if [ "$(ls -A $MODEL/*.pth)" ] 
# 	then
# 		echo "---last checkpoint ------"
# 	    return `ls $MODEL/*.pth | sort | tail -n -1`images
# 	else
# 		echo "----- no checkpoints found ------------" 
# 		return ""   
# 	fi
# }

##-------------------------------------------- train ----------------------------------------------------

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
      	neo train --config=tanzania.toml  --ts 1024,1024 --resume --checkpoint="${latest_checkpoint}" --dataset $PRE --epochs $epochs --out "${MODEL}" --bs=$batch --workers=$WORKERS
		# neo eval --config=tanzania.toml --checkpoint "${latest_checkpoint}" --dataset $PRE
	else
      	echo "----- new checkpoints ------------"
	    neo train --config=tanzania.toml --ts 1024,1024 --dataset $PRE  --epochs $EPOCHS --out "${MODEL}" --bs=$batch --workers=$WORKERS
	    latest_checkpoint=`ls "${MODEL}"/*.pth | sort | tail -n -1`
	    # neo eval --config=tanzania.toml --checkpoint "${latest_checkpoint}" --dataset $PRE
	fi
}





## -------------------------------------------- test ---------------------------------------------------
# test_occ_images() {

# }
# band: 1,2,3 = webp
# band: 1,2 = jpg
# band: 1 = png
# band: none = tif

test_download() {
	echo "--------- test downloafing ------------------"

	mkdir -p $TEST/images
	rm -rf $TEST/geojson, $TEST/tif $TEST/masks $TEST/images

	wget -nc -nv --show-progress -P $TEST/tif/ $1
	wget -nc -nv --show-progress -P $TEST/geojson/ $2
}

test_tile() {
	echo "-----------test split tiles ----------------"
	neo tile --zoom $zoom --ts 1024,1024 --nodata_threshold 25 --rasters $TEST/tif/*.tif --out $TEST/images --workers=$WORKERS
	neo cover --dir $TEST/images --out $TEST/images/cover.csv
}

test_rester() {
	echo "--------- resterise -------------"
	neo rasterize --config=tanzania.toml --ts 1024,1024 --geojson $TEST/geojson/*.geojson --type Building --cover $TEST/images/cover.csv --out $TEST/labels --workers=$WORKERS
}


predict() {
	model="${1}"
	cp "${model}" "."
	neo predict --config=tanzania.toml --checkpoint "${model}" --dataset test --out test/masks
}

function test() {
	config
	test_download $1 $2 
	test_tile 
	test_rester
	# predict "${3}"
}



# ---------------------------------- SUBMITION -----------------------------
submission_download() {
	echo "--------- test downloafing ------------------"
	rm -rf $TEST/tif $TEST/json $TEST/images $TEST/labels
	wget -nc -nv --show-progress -P $TEST/tif/ $1
	wget -nc -nv --show-progress -P $TEST/json/ $2
}

submission_tile() {
	echo "-----------test split tiles ----------------"
	neo tile --zoom $zoom  --ts 1024,1024  --nodata_threshold 25 --rasters $TEST/tif/*tif --out $TEST/images
	neo cover --dir $TEST/images --out $TEST/images/cover.csv
}

submission_rester() {
	echo "--------- resterise -------------"
	neo rasterize --config=tanzania.toml --ts 1024,1024 --geojson $TEST/json/*.json --type Building --cover $TEST/images/cover.csv --out $TEST/labels
	# neo tile --zoom 19 --bands 1,2,3 --nodata_threshold 25 --rasters train/*/*[^-]/*tif --out train/images
}

submission() {
	submission_download $1 $2
	submission_tile
	# submission_rester
}

"$@"
