1. Log into your new raspberry pi zero 2 w
2. sudo apt-get -y install git #<-- install git
3. git clone https://github.com/NathanBuildsDIY/dronev2 #<-- pull down this git to the rpi
4. mv dronev2/dronev2-rpi . #<-- pull out the dronev2-rpi directyory from this repo to its own directory 
5. bash install_rpi_drone.sh #<-- run the setup script. It will install all libraries and set up the pi to auto-run the script that takes photos and (if the tflite model is present) classify those photos and turn on the sprayer
