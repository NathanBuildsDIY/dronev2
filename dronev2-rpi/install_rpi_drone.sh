#Use Legacy 64 bit lite OS - bullseye, comes with python 3.9.2 native. That's important because google only compiled and made avaialble tflite-support and runtime for python <3.10
#So go with older OS/python because we can't run make or wheel to build tflite support/runtime on the zero 2 w without running out of memory
#If you try new OS and Installing old python on new OS works for tf-lite but picamera (installed with apt-get) doesn't work. If we use pip to install that, then libcamera fails, and I don't have a way to install that on old python on new OS. apt-get seems to default to the 3.11 (newer default) python instead of the old one :(


echo "get up to date packages with apt-get"
sudo apt-get update
sudo apt-get -y upgrade

echo "install new packages - basic setup"
sudo apt-get -y install pip
sudo apt-get -y install python3-pyqt5 #needed for picamera2 to work
sudo apt-get -y install build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev wget
sudo apt-get -y install libreadline-gplv2-dev libncursesw5-dev libssl-dev libsqlite3-dev tk-dev libgdbm-dev libc6-dev libbz2-dev

echo "install comuter vision and image classification libs"
pip3 install opencv-python
pip3 install --upgrade tflite-support==0.4.2
pip3 install --upgrade tflite-runtime==2.11.0
pip install --upgrade numpy==1.26.4 #downgraDe to avoid errors wtih 2+ versions
pip3 install imutils

echo "create entry in crontab to always run drone app on startup"
line="@reboot python3 ~/dronev2-rpi/droneSprayer_v2.py >> ~/dronev2-rpi/log.out" 2>&1
(crontab -u $(whoami) -l; echo "$line" ) | crontab -u $(whoami) -
