# score

from sklearn.metrics import jaccard_score
from skimage.io import imread
import glob, os, sys, json

def score_for_image(tif_path, geo_path):
	return { 
		'score': jaccard_score(imread(tif_path).flatten(), imread(geo_path).flatten(), average='micro')
	}


def get_id(path):
	return path.split('/')[-1].split('.')[0]


def score_for_all(tif_dir, mask_dir, extension='.png'):
	images = []
	for root, dirs, files in os.walk(tif_dir):
	    for file in files:
	        if file.endswith(extension):
	             images.append(os.path.join(root, file))

	images = sorted(images, key=lambda p: (os.path.sep not in p, p))

	masks = []
	for root, dirs, files in os.walk(mask_dir):
	    for file in files:
	        if file.endswith(extension):
	             masks.append(os.path.join(root, file))

	images = sorted(images, key=lambda p: (os.path.sep not in p, p))
	masks = sorted(masks, key=lambda p: (os.path.sep not in p, p))

	total_samples = len(images)
	good_examples = 0
	score = 0.0

	print('getting score for total image: ', total_samples)

	for img, mask in zip(images, masks):
		try:
			if get_id(img) != get_id(mask):
				raise ValueError(f"file name mismatch {tif} and {mask}")
			score += score_for_image(img, mask)['score']
			good_examples += 1
		except ValueError:
			pass
			# print(f'ValueError for image: {img}, maks: {mask}')


	out = {
		'total_images': total_samples,
		'good_images': good_examples,
		'bad_images': total_samples - good_examples,
		'average': score/good_examples
	}

	print(out)

if __name__ == '__main__':
	tif = sys.argv[1]
	mask = sys.argv[2]
	score_for_all(tif, mask)
