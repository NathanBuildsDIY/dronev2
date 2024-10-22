import os
import time
from picamera2 import Picamera2, Preview
from datetime import datetime
from tflite_support.task import core
from tflite_support.task import processor
from tflite_support.task import vision
import cv2
import os
import os.path
import imutils
from gpiozero import LED

#set up camera
camera = Picamera2() #declare camera
config = camera.create_preview_configuration()
#camwidth = 1440 
#camheight = 1080
#config = picam.create_preview_configuration(main={"size": (camwidth, camheight)})
camera.configure(config)
camera.start()

#create run directory to save photos and go there
dronedir = os.path.expanduser("~/dronev2-rpi/")
date = datetime.now().strftime("%m_%d_%I_%M_%S_%p_%f")
rundir = dronedir+date
os.makedirs(rundir)
os.chdir(rundir)

#define sprayer pin
sprayer = LED(14)
sprayer.off()

#decide if there is an image classification model
imageModelPresent = False
if os.path.isfile(dronedir + "model_int8.tflite"):
  imageModelPresent = True
  print("Image Classification Model Exists, load it")
  # Initialize the image classification model. This is the custom trained model based on mobilenet
  base_options = core.BaseOptions(
    file_name=os.path.expanduser('~/dronev2-rpi/model_int8.tflite'), use_coral=False, num_threads=4)
  # Enable Coral by this setting
  classification_options = processor.ClassificationOptions(
    max_results=2, score_threshold=0.0)
  options = vision.ImageClassifierOptions(
    base_options=base_options, classification_options=classification_options)
  classifier = vision.ImageClassifier.create_from_options(options) 

while True:
  #take a photo
  date = datetime.now().strftime("%m_%d_%I_%M_%S_%p_%f") #note: keep it short and don't allow : in filename - error
  photo_name = date + ".jpg"
  camera.capture_file(photo_name)

  if imageModelPresent == True: 
    #Load the image
    image = cv2.imread(photo_name) #pull up image and get shape

    # Convert the image from BGR to RGB as required by the TFLite model.
    rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    re_size = (224,224)
    rgb_image=cv2.resize(rgb_image,re_size)

    # Create TensorImage from the RGB image
    tensor_image = vision.TensorImage.create_from_array(rgb_image)
    # List classification results
    categories = classifier.classify(tensor_image)
    category = categories.classifications[0].categories[0]

    #Label Image
    category_name = category.category_name
    score = round(category.score, 2)
    result_text = category_name + ' (' + str(score) + ')'

    #If Weed, turn on sprayer
    if category_name.startswith("weed") and score > 0.6:
      print("Found weed, turning on sprayer")
      sprayer.on()
      cv2.putText(image,category_name,(10,200),cv2.FONT_HERSHEY_PLAIN, 4, (0,0,255), 8) #image, text, (x,y), fontname, fontsize, color, thickness)
      cv2.putText(image,str(score),(10,400),cv2.FONT_HERSHEY_PLAIN, 4, (0,0,255), 8) #image, text, (x,y), fontname, fontsize, color, thickness)
    else:
      sprayer.off()
      cv2.putText(image,category_name,(10,200),cv2.FONT_HERSHEY_PLAIN, 4, (0,255,0), 8) #image, text, (x,y), fontname, fontsize, color, thickness)
      cv2.putText(image,str(score),(10,400),cv2.FONT_HERSHEY_PLAIN, 4, (0,255,0), 8) #image, text, (x,y), fontname, fontsize, color, thickness)
 
    #write out labelled image
    cv2.imwrite(result_text+photo_name,image)
      
camera.close()
