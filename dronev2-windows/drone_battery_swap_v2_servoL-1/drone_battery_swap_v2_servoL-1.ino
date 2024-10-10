#include <ezButton.h>
#include <Servo.h>
// initialize pins
int generic_dir = 6;
int leftBat = 5;
int rightBat = 8;
int farArm1 = 11; 
int nearArm1 = 7;
int water = 12;
int arm2 = 9;
int relaunch = 10;
int relaunchL = 4;
int demo = 0;
int demoButton = 3; int demoButtonState = 0;
Servo lBatSpin;
//Servo rBatSpin;
//ezButton landing2_limit(13); //history

// the setup function runs once when you press reset or power the board
void setup() 
{
  pinMode(generic_dir, OUTPUT); 
  pinMode(leftBat, OUTPUT); 
  pinMode(rightBat, OUTPUT);
  pinMode(farArm1, OUTPUT); 
  pinMode(nearArm1, OUTPUT);
  pinMode(water, OUTPUT);
  pinMode(arm2, OUTPUT);
  pinMode(relaunch, OUTPUT);
  pinMode(relaunchL, OUTPUT); 
  pinMode(demoButton, INPUT);
  pinMode(LED_BUILTIN, OUTPUT);
  lBatSpin.attach(A1);
  //rBatSpin.attach(A0);
  //landing2_limit.setDebounceTime(10); //history
  Serial.begin(9600);
}

// the loop function runs over and over again forever
void loop() 
{ 
  //2. spin servos to correct orientation - call correct script from autoit. push with riht or left arm also from autoit. 
  if (demo == 1){waitForPress();}//wait for demo button to be pushed if demo is active
  int pos = 90; 
  lBatSpin.write(pos+4); 
  //push with left or right battery arm  estimate 3 mins
  moveMotor(generic_dir, leftBat, 255, 85000, 1); //left push charged battery into drone, spent battery into empty bay on other side
  //moveMotor(generic_dir, rightBat, 255, 85000, 1); //right push charged battery into drone, spent battery into empty bay on other side
  moveMotor(generic_dir, leftBat, 255, 90000, 0); //left pull back batteyr arm to neutral
  //moveMotor(generic_dir, rightBat, 255, 90000, 0); //right pull back batteyr arm to neutral
  exit(0);
}

void waitForPress(){
  //waits for button to be pressed in demo mode
  Serial.print("waiting for button push");
  demoButtonState = digitalRead(demoButton);
  while(demoButtonState == LOW) {
    demoButtonState = digitalRead(demoButton);
    digitalWrite(LED_BUILTIN, HIGH);
    delay(300);
    digitalWrite(LED_BUILTIN, LOW);
    delay(300);
  }
}

int moveMotor(int dir_pin, int pwm_pin, int speed, long milliseconds, int dir){
  //move a single motor for a given time
  //set motor direction
  if (dir == 1) {
    digitalWrite(dir_pin, HIGH);
  }
  else {
    digitalWrite(dir_pin, LOW);
  }
  analogWrite(pwm_pin, speed); //start motor movin
  delay(milliseconds); //delay for duration desired
  analogWrite(pwm_pin, 0); //stop motor movin
  delay(1000); // let the power supply and motors sit idle for a moment
  return 1;
}

int moveMotor2(int dir_pin, int pwm1_pin, int pwm1_speed, int pwm2_pin, int pwm2_speed, long milliseconds, int dir){
  //start and stop moving 2 motors at the same time, run them for a given time
  //set motor direction
  if (dir == 1) {
    digitalWrite(dir_pin, HIGH);
  }
  else {
    digitalWrite(dir_pin, LOW);
  }
  analogWrite(pwm1_pin, pwm1_speed); //start motor1 moving
  analogWrite(pwm2_pin, pwm2_speed); //start motor2 moving
  delay(milliseconds); //delay for duration desired
  analogWrite(pwm1_pin, 0); //stop motor1 moving
  analogWrite(pwm2_pin, 0); //stop motor2 moving
  delay(1000); // let the power supply and motors sit idle for a moment
  return 1;
}

int moveMotor2Start(int dir_pin, int pwm1_pin, int pwm1_speed, int pwm2_pin, int pwm2_speed, long milliseconds, int dir){
  //start moving 2 motors at the same time, no stop time set
  //set motor direction
  if (dir == 1) {
    digitalWrite(dir_pin, HIGH);
  }
  else {
    digitalWrite(dir_pin, LOW);
  }
  analogWrite(pwm1_pin, pwm1_speed); //start motor1 moving
  analogWrite(pwm2_pin, pwm2_speed); //start motor2 moving
  delay(1000); // let the power supply and motors sit idle for a moment
  return 1;
}

int moveMotor2Stop(int pwm1_pin, int pwm2_pin){
  //stop moving 2 motors at the same time
  analogWrite(pwm1_pin, 0); //stop motor1 moving
  analogWrite(pwm2_pin, 0); //stop motor2 moving
  delay(1000); // let the power supply and motors sit idle for a moment
  return 1;
}

int moveMotorLimit(int dir_pin, int pwm_pin, long milliseconds, int dir, ezButton limitSwitch){
  //move motor to a limit switch. 
  //set motor direction
  if (dir == 1) {
    digitalWrite(dir_pin, HIGH);
  }
  else {
    digitalWrite(dir_pin, LOW);
  }
  long startMillis = millis(); //get initial time
  long currentMillis = millis();
  limitSwitch.loop();
  int initState = limitSwitch.getState(); //get initial state
  int curState = limitSwitch.getState(); 
  analogWrite(pwm_pin, 255); //start motor moving
  //turn on motor until the milliseconds are pass OR the limit switch is hit
  while((currentMillis - startMillis <= milliseconds) && (initState == curState)) {
    limitSwitch.loop();
    curState = limitSwitch.getState();
    currentMillis = millis();
  }
  analogWrite(pwm_pin, 0); //stop motor moving
  delay(1000); // let the power supply and motors sit idle for a moment
  return 1;
}

int moveMotorLimit2(int dir_pin, int pwm1_pin, int pwm1_speed, int pwm2_pin, int pwm2_speed, long milliseconds, int dir, ezButton limitSwitch1, ezButton limitSwitch2){
  //move 2 motors to a limit switch, each will turn off when its limit is hit, but the other can continue running to limit even if the first is already there and stopped
  //set motor direction
  if (dir == 1) {
    digitalWrite(dir_pin, HIGH);
  }
  else {
    digitalWrite(dir_pin, LOW);
  }
  long startMillis = millis(); //get initial time
  long currentMillis = millis();
  limitSwitch1.loop();
  limitSwitch2.loop();
  int initState1 = limitSwitch1.getState(); //get initial state 1
  int curState1 = limitSwitch1.getState(); //get cur state 1
  int initState2 = limitSwitch2.getState(); //get initial state 2
  int curState2 = limitSwitch2.getState(); //get cur state 2
  analogWrite(pwm1_pin, pwm1_speed); //start motor1 moving
  analogWrite(pwm2_pin, pwm2_speed); //start motor2 moving
  //turn on motors until the milliseconds are passed OR the limit switches are hit
  int counterLimit1 = 0;
  int counterLimit2 = 0;
  while((currentMillis - startMillis <= milliseconds) && ((counterLimit1 == 0) || (counterLimit2 == 0))) {
    limitSwitch1.loop();
    limitSwitch2.loop();
    curState1 = limitSwitch1.getState();
    curState2 = limitSwitch2.getState();
    if(initState1 != curState1){
      analogWrite(pwm1_pin, 0); //limit reached, stop motor1 moving
      counterLimit1 = 1;
    }
    if(initState2 != curState2){
      analogWrite(pwm2_pin, 0); //limit reached, stop motor2 moving
      counterLimit2 = 1;
    }
    currentMillis = millis();
  }
  analogWrite(pwm1_pin, 0); //stop motor1 moving
  analogWrite(pwm2_pin, 0); //stop motor2 moving
  delay(1000); // let the power supply and motors sit idle for a moment
  return 1;
}
