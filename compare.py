from PIL import Image
import matplotlib.image as mpimg      
from matplotlib.pyplot import figure, imshow, axis
import glob
from skimage.io import imread
import matplotlib.pyplot as plt


def webp_to_png(img):
  im = Image.open(img).convert('RGB')
  im = im.resize((1024,1024),Image.ANTIALIAS)
  img_name = img.split('.')[:-1][0] + ".png"
  im.save(img_name, 'png', optimize=True,quality=50)
  return img_name

def show(num, tif_path, masked_path):
  images = sorted(glob.glob(tif_path, recursive=True))
  masks = sorted(glob.glob(masked_path, recursive=True))
  
  number_of_images = min(num, len(images))
  images = images[:number_of_images]
  masks = masks[:number_of_images]
  
  fig = figure(num=None, dpi=80, figsize=(10, number_of_images*5), facecolor='w', edgecolor='k')
  rows = number_of_images
  cols = 2

  for i in range(0, rows):
      img = images[i]
      mask = masks[i]

      if 'webp' in img:
        img = webp_to_png(img)
      a=fig.add_subplot(rows, cols, 2*i+1)
      image = imread(img)
      imshow(image)
  
      b=fig.add_subplot(rows, cols, 2*i+2)
      image = imread(masks[i])
      imshow(image)


def show_rester(num):
  show(num, 'test/images/20/*/*.tiff', 'test/labels/20/*/*.png')

def show_prediction(num):
  # show(num, 'test/images/20/*/*.tiff', 'test/masks/20/*/*.png')
  show(num, 'test/labels/20/*/*.png', 'test/masks/20/*/*.png')

if __name__ == '__main__':
  import sys
  num = int(sys.argv[1])
  tiff = sys.argv[2]
  geo = sys.argv[3]
  show(num, tiff, geo)
