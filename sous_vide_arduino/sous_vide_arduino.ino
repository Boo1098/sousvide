// Pin to read thermistor from
#define THERMISTOR_PIN A0
// Resistance of thermistor at nominal temp
#define THERMISTOR_NOMINAL 10000 // ohms
// Nominal temperature
#define TEMPERATURE_NOMINAL 298.15 // K
// Resistor that thermistor is in series with
#define SERIES_RESISTOR 1000 // ohms
// Beta for thermistor in operating range (25-100C for this application)
// See https://www.powerandsignal.com/images/pdfs/AASTemperatureResistanceCurves.pdf page 69
#define BETA 3984
// Pin servo control is connected to
#define SERVO_PIN 3
#define LEFT_US 568 // Pulse time in us for all the way CCW
#define RIGHT_US 2400 // Pulse time in us for all the way CW
#define PERIOD 20000 // Period between leading edge of each pulse

// Stepper motor setup
#define PINK 10
#define ORANGE 9
#define BLUE 12
#define YELLOW 11
#define CCW_BUTTON 2
#define CW_BUTTON 3

// Global temperature setpoint value
int setPoint = 0; //degC

// PID bootstrap
float lastError,output,integral;
long lastTime;

// PID constants
float P = 20; // Found from testing
float I = 0.001; // A little I just in case
float D = 0;  // Didn't find that I needed D
float F = .12; // constant based on setpoint (F*setPoint). A little heat is necessary to hold steady state temperature since it bleeds into environment.

// Save stepper position
int currentSteps = 0;


void setup() {
  // put your setup code here, to run once:
  Serial.begin(115200);

  // Setup inputs and outputs for stepper motor
  pinMode(PINK, OUTPUT);
  pinMode(ORANGE, OUTPUT);
  pinMode(YELLOW, OUTPUT);
  pinMode(BLUE, OUTPUT);
  pinMode(CCW_BUTTON,INPUT_PULLUP);
  pinMode(CW_BUTTON,INPUT_PULLUP);

//  currentSteps=EEPROM.read(0);
}

void loop() {
  // Save loop start time
  long startTime=millis();
  
  // Write temperature to serial
  Serial.print((float)millis()/1000.0);
  Serial.print('\t');
  Serial.print(getTemp(1));
  Serial.print('\t');
  Serial.println(output);
  
  Serial.print(currentSteps);
  Serial.print('\t');
  Serial.println(integral);

  // Get input data
  if(Serial.available()>0){
    String stringIn=Serial.readStringUntil('\n');
    Serial.println(stringIn);
    // New setpoint
    if(stringIn.startsWith("temp")){
      Serial.println(stringIn.substring(5));
      setPoint=stringIn.substring(5).toInt();
    }
    // Command
    if(stringIn.equals("off")){
      setPoint = 0;
    }
  }

  // Make sure output is off if no pid set
  if(setPoint!=0){
    updatePID();
  } else {
    setStepperAngle(0);
  }

  // Edit starting stepper position with button (does not change saved steps)
  while(digitalRead(CCW_BUTTON)==LOW){
    twoStepsCCW();
  }
  while(digitalRead(CW_BUTTON)==LOW){
    twoStepsCW();
  }

  // Loop must take at least 100ms
  while(millis()-startTime<10);
}

// Run and update PID loop
void updatePID(){
  long startTime=millis();
  float error = setPoint-getTemp(1);
  float derivative = (error-lastError)/(startTime-lastTime);
  
  // Ensure integral is taking a huge area that it may never recover from
  if(startTime-lastTime<1000){
    integral+=error*(startTime-lastTime)/1000.0;
  }

  // Calculate PID
  output = P*error+I*integral+D*derivative+F*setPoint;

  // Ensure don't go out of range of stove
  if(output<0){
    output=0;
  } else if (output>270){
    output=270;
  }

  // Write output
  setStepperAngle(output);
  lastTime=startTime;
}

// Returns temperature in C from thermistor
// parameter numberOfSamples is how many samples to average for measurement
// Modified from https://learn.adafruit.com/thermistor/using-a-thermistor
float getTemp(int numberOfSamples){
  int samples[numberOfSamples];
  float average;
 
  // Take numberOfSamples samples of thermistor voltage
  if(numberOfSamples>1){
    for (int i=0; i< numberOfSamples; i++) {
     samples[i] = analogRead(THERMISTOR_PIN);
     delay(10); // Reasonable delay
    }
  
    // Get average of samples
    average = 0;
    for (int i=0; i< numberOfSamples; i++) {
       average += samples[i];
    }
    average /= numberOfSamples;
  } else {
    average = analogRead(THERMISTOR_PIN);
  }
  
  // Convert reading to resistance
  average = average*5.0/1023.0; // Voltage
  average = (5.0-average)*SERIES_RESISTOR/average; // ohms (based on voltage divider equation solved for R)

  // Get temperature using thermistor equation
  // 1/T = 1/T_nominal+(1/beta)*ln(R/R_nominal)
  average = 1.0/(1.0/(float)TEMPERATURE_NOMINAL+(1.0/(float)BETA)*log(average/(float)THERMISTOR_NOMINAL)); //K
  average -=273.15;// Celsius
  return average-2.0; // Found off by ~2C consistently
}

// Set stepper motor based on angle
void setStepperAngle(int angle){
  // 2*p*N_poles*GR=2*4*2*64=1024 steps/rev
  int steps = (map(angle,0,360,0,1024)*75)/12;
  setStepperSteps(steps);
}

// Set stepper motor based on total steps from starting position
// Will only move towards target, does not wait until move is complete
// Must be run every loop to actually get to target
void setStepperSteps(int steps){
  // Since incrementing by 2 steps at a time, allow for error of 1 so motor doesn't bounce back and forth
  if(steps-1>currentSteps){
      twoStepsCW();
      currentSteps+=2;
  } else if (steps+1<currentSteps){
      twoStepsCCW();
      currentSteps-=2;
  }
}

// Go two steps CCW on stepper motor
void twoStepsCCW(){
  // Based on https://components101.com/motors/28byj-48-stepper-motor
  // Provides much higher torque
  digitalWrite(PINK, HIGH);
  digitalWrite(ORANGE, LOW);
  digitalWrite(BLUE, HIGH);
  digitalWrite(YELLOW, HIGH);
  delay(5); // Found that 1 was broken, and 5 works well.
  digitalWrite(PINK, HIGH);
  digitalWrite(ORANGE, LOW);
  digitalWrite(BLUE, HIGH);
  digitalWrite(YELLOW, LOW);
  delay(5);
  digitalWrite(PINK, HIGH);
  digitalWrite(ORANGE, HIGH);
  digitalWrite(BLUE, HIGH);
  digitalWrite(YELLOW, LOW);
  delay(5);
  digitalWrite(PINK, LOW);
  digitalWrite(ORANGE, HIGH);
  digitalWrite(BLUE, HIGH);
  digitalWrite(YELLOW, LOW);
  delay(5);
  digitalWrite(PINK, LOW);
  digitalWrite(ORANGE, HIGH);
  digitalWrite(BLUE, HIGH);
  digitalWrite(YELLOW, HIGH);
  delay(5); 
  digitalWrite(PINK, LOW);
  digitalWrite(ORANGE, HIGH);
  digitalWrite(BLUE, LOW);
  digitalWrite(YELLOW, HIGH);
  delay(5);
  digitalWrite(PINK, HIGH);
  digitalWrite(ORANGE, HIGH);
  digitalWrite(BLUE, LOW);
  digitalWrite(YELLOW, HIGH);
  delay(5);
  digitalWrite(PINK, HIGH);
  digitalWrite(ORANGE, LOW);
  digitalWrite(BLUE, LOW);
  digitalWrite(YELLOW, HIGH);
  delay(5);
}

// Go two steps CW on stepper motor
void twoStepsCW(){
  // Based on https://components101.com/motors/28byj-48-stepper-motor
  // Provides much higher torque
  digitalWrite(PINK, HIGH);
  digitalWrite(ORANGE, LOW);
  digitalWrite(BLUE, LOW);
  digitalWrite(YELLOW, HIGH);
  delay(5);
  digitalWrite(PINK, HIGH);
  digitalWrite(ORANGE, HIGH);
  digitalWrite(BLUE, LOW);
  digitalWrite(YELLOW, HIGH);
  delay(5);
  digitalWrite(PINK, LOW);
  digitalWrite(ORANGE, HIGH);
  digitalWrite(BLUE, LOW);
  digitalWrite(YELLOW, HIGH);
  delay(5);
  digitalWrite(PINK, LOW);
  digitalWrite(ORANGE, HIGH);
  digitalWrite(BLUE, HIGH);
  digitalWrite(YELLOW, HIGH);
  delay(5); 
  digitalWrite(PINK, LOW);
  digitalWrite(ORANGE, HIGH);
  digitalWrite(BLUE, HIGH);
  digitalWrite(YELLOW, LOW);
  delay(5);
  digitalWrite(PINK, HIGH);
  digitalWrite(ORANGE, HIGH);
  digitalWrite(BLUE, HIGH);
  digitalWrite(YELLOW, LOW);
  delay(5);
  digitalWrite(PINK, HIGH);
  digitalWrite(ORANGE, LOW);
  digitalWrite(BLUE, HIGH);
  digitalWrite(YELLOW, LOW);
  delay(5);
  digitalWrite(PINK, HIGH);
  digitalWrite(ORANGE, LOW);
  digitalWrite(BLUE, HIGH);
  digitalWrite(YELLOW, HIGH);
  delay(5); 
}
