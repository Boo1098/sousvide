import processing.serial.*; // add the serial library
import java.util.Arrays;
import java.util.Collections;
Serial myPort; // define a serial port object to monitor

// Global colors
color background=color(0,0,0);
color foreground=color(255,255,255);
color accent=color(255,0,255);

// Displayed objects
Graph graph;
Pot pot;
Timer timer;
Dial dial;

void setup() {
  size(1200, 612); // set the window size
  myPort = new Serial(this, Serial.list()[0], 115200); // define input port
  

  // Create drawn objects
  graph=new Graph(50, 50, 750, 350, background, foreground, accent);
  pot=new Pot(1200-350,50,450,300,background,foreground, accent);
  timer=new Timer(175,450,500,132,background,foreground,accent);
  dial=new Dial(875,375,200,200,background,foreground,accent);
  
  // Initialize timer to convienient number
  timer.setTimer(1,30,0);
  
  myPort.clear(); // clear the port of any initial junk
}
boolean flag = false;
void draw () {
  // Read in data and process
  while (myPort.available () > 0) { // make sure port is open
    String inString = myPort.readStringUntil('\n'); // read input string
        
      if (inString != null) { // ignore null strings
      inString = trim(inString); // trim off any whitespace
      String[] xyzaRaw = splitTokens(inString, "\t"); // extract x & y into an array
      // proceed only if correct # of values extracted from the string:
      if (xyzaRaw.length == 3) {
        float a0 = float(xyzaRaw[0]);
        float a1 = float(xyzaRaw[1]);
        float a2 = float(xyzaRaw[2]);
        if(a0<5||flag){
          graph.addPoint(a0,a1);
          flag = true;
        }
        pot.setHeat((int)a2*4/270);
      } else {
        println(inString);
      }  
    }
  }
   
  
  // Draw all objects
  // Reset Background
  background(background);
  // Update graph points
  graph.updateGraph();
  // Update Pot heating
  pot.drawPot();
  // Update timer
  timer.drawTimer();
  dial.drawDial();
}

void mousePressed(){
  timer.mouse(mouseX,mouseY);
}

class Dial{
  color fg, bg, a;
  int x, y, w, h;
  int heat;
  long startTime;
  boolean started;
  long timeTotal, timeLeft;
  float theta, temp;
  PImage outsideDial, insideDial;
  
  // Setup pot
  Dial(int topLeftX, int topLeftY, int xSize, int ySize, color background, color foreground, color accent) {
    x=topLeftX;
    y=topLeftY;
    w=xSize;
    h=ySize;
    bg=background;
    fg=foreground;
    a=accent;
    outsideDial=loadImage("dialOutside.png");
    insideDial=loadImage("dialInside.png");
    temp=25;
    theta=radians(240);
    drawDial();
  }
  
  void drawDial(){
    imageMode(CENTER);
    fill(fg);
    tint(fg);
    image(outsideDial,x+w/2,y+h/2,w,h);
    stroke(fg);
    fill(bg);
    if(mousePressed){
      if(mouseX>x&&mouseX<x+w&&mouseY>y&&mouseY<y+h){
        // Generate angle dial needs to point in
        theta=atan2(mouseY-(y+h/2),mouseX-(x+w/2))+PI/2;
        // Don't allow pointing down
        if(theta>radians(120)&&theta<radians(180)){
          theta=radians(120);
        }
        if(theta>=radians(180)&&theta<radians(240)){
          theta=radians(240);
        }
      }
      // Generate temperature corresponding to angle
      temp=(theta>PI?(theta-PI-radians(60)):theta+PI/2+radians(30))*(75)/radians(180+60)+25;
      writeTemp();
    }
    pushMatrix();
    translate(x+w/2,y+h/2);
    rotate(theta);
    tint(a);
    image(insideDial,0,0,w,h);
    popMatrix();
    imageMode(CORNER);
    textAlign(CENTER);
    textSize(25);
    fill(fg);
    text((int)temp+"°C",x+w/2,y+h+25);
    textSize(12);
  }
  
  // Update arduino setpoint
  void writeTemp(){
     myPort.write("temp\t");
     myPort.write(temp+"\n"); 
  }
}

class Timer{
  color fg, bg, a;
  int x, y, w, h;
  int heat;
  long startTime;
  boolean started;
  long timeTotal, timeLeft;
  PImage pot;
  
  // Setup pot
  Timer(int topLeftX, int topLeftY, int xSize, int ySize, color background, color foreground, color accent) {
    x=topLeftX;
    y=topLeftY;
    w=xSize;
    h=ySize;
    bg=background;
    fg=foreground;
    a=accent;
    drawTimer();
  }
  
  // Draw timer
  void drawTimer(){
    // Set big text size for timer
    textSize(h-20);
    textAlign(LEFT,TOP);
    // Make sure time is up to date before drawing it
    updateTime();
    // Draw in accent color if time is started
    fill(started?a:fg);
    // Draw time left
    text(nf((int)(timeLeft/60.0/60.0),2)+":"+nf((int)(timeLeft/60.0%60),2)+":"+nf((int)(timeLeft%60),2),x,y);
    
    // Draw +/- buttons
    rectMode(CENTER);
    textAlign(CENTER,CENTER);
    textSize(12);
    fill(bg);
    stroke(fg);
    rect(x+w/6,y+h-10,w/6,20);
    rect(x+w/3+w/6,y+h-10,w/6,20);
    rect(x+2*w/3+w/6,y+h-10,w/6,20);
    rect(x+w/6,y+10,w/6,20);
    rect(x+w/3+w/6,y+10,w/6,20);
    rect(x+2*w/3+w/6,y+10,w/6,20);
    // Draw +/- button text
    fill(fg);
    text("+Hour",x+w/6,y+10);
    text("+Minute",x+w/3+w/6,y+10);
    text("+Second",x+2*w/3+w/6,y+10);
    text("-Hour",x+w/6,y+h-10);
    text("-Minute",x+w/3+w/6,y+h-10);
    text("-Second",x+2*w/3+w/6,y+h-10);
  }
  
  // Updates time left on timer
  void updateTime(){
    if(started){
      timeLeft=timeTotal-(millis()-startTime)/1000;
      if(timeLeft<=0){
        endTimer();
      }
    }
  }
  
  // Overwrite timer
  void setTimer(int hour, int minute, int second){
    timeTotal=hour*60*60+minute*60+second;
    timeLeft=timeTotal;
    drawTimer();
  }
  
  // Increment timer
  void incrementTimer(int hour, int minute, int second){
    timeTotal+=hour*60*60+minute*60+second;
    timeLeft+=hour*60*60+minute*60+second;
    drawTimer();
  }
  
  // Ends timer countdown
  void endTimer(){
    timeTotal=timeLeft;
    started=false;
    // Stop arduino
    turnOffHeat();
  }
  
  // Send off signal to arduino
  void turnOffHeat(){
    myPort.write("off\n");
  }
  
  // Starts timer countdown
  void startTimer(){
    startTime=millis();
    started=true;
    // Ensure arduino has a setpoint
    dial.writeTemp();
  }
  
  // Ran every time a mouse is clicked. Used to update buttons
  void mouse(int mx, int my){
    println(mx+" "+my);
    // Check if timer itself is pressed
    if(mx>x && mx<x+w && my>y+20 && my<y+h-20){
      if(!started)
      startTimer();
      else
      endTimer();
    }
    // Check if +/- buttons pressed
    // Hours
    if(mx>x+w/6-w/12&&mx<x+w/6+w/12){
      // + Hour
      if(my>y&&my<y+20){
        incrementTimer(1,0,0);
      // - Hour
      } else if (my>y+h-20&&my<y+h){
        incrementTimer(-1,0,0);
      }
    }
    // Minutes
    if(mx>x+w/3+w/6-w/12&&mx<x+w/3+w/6+w/12){
      // + Minute
      if(my>y&&my<y+20){
        incrementTimer(0,1,0);
      // - Minute
      } else if (my>y+h-20&&my<y+h){
        incrementTimer(0,-1,0);
      }
    }
    // Second
    if(mx>x+2*w/3+w/6-w/12&&mx<x+2*w/3+w/6+w/12){
      // + Second
      if(my>y&&my<y+20){
        incrementTimer(0,0,1);
      // - Second
      } else if (my>y+h-20&&my<y+h){
        incrementTimer(0,0,-1);
      }
    }
  }
}

// Displays a pot with current heating level underneat it
class Pot {
  color fg, bg, a;
  int x, y, w, h;
  int heat;
  PImage pot;
  
  // Setup pot
  Pot(int topLeftX, int topLeftY, int xSize, int ySize, color background, color foreground, color accent) {
    x=topLeftX;
    y=topLeftY;
    w=xSize;
    h=ySize;
    bg=background;
    fg=foreground;
    heat=0;
    // Source: https://www.pinclipart.com/downpngs/iTRRTii_sauce-pan-boiling-pot-icon-clipart/
    pot = loadImage("pot.png");
    drawPot();
  }
  
  void drawPot(){
    tint(fg);
    image(pot,x,y,w,h-50);
    stroke(heat>=3?accent:fg);
    line(x,y+h-40,x+w/1.7,y+h-40);
    stroke(heat>=2?accent:fg);
    line(x,y+h-25,x+w/1.7,y+h-25);
    stroke(heat>=1?accent:fg);
    line(x,y+h-10,x+w/1.7,y+h-10);
  }
  
  void setHeat(int heatLevel){
    heat=heatLevel;
  }
}

class Graph {
  color fg, bg, a;
  int x, y, w, h;
  ArrayList<Float> times=new ArrayList<Float>();
  ArrayList<Float> temps= new ArrayList<Float>();

  // Initialize new graph with dimensions and colors
  Graph(int topLeftX, int topLeftY, int xSize, int ySize, color background, color foreground, color accent) {
    x=topLeftX;
    y=topLeftY;
    w=xSize;
    h=ySize;
    bg=background;
    fg=foreground;
    a=accent;
    setupGraph();
  }

  // Draw graph backdrop
  void setupGraph() {
    noStroke();
    fill(bg);
    rect(x, y, w, h);
    fill(fg);
    textAlign(CENTER, CENTER);
    textSize(12);
    text("Time (s)", x+(w/2), y+h-12);
    pushMatrix();
    translate(x+6, y+h/2);
    rotate(radians(-90));
    text("Temp (°C)", 0, 0);
    popMatrix();
    stroke(fg);
    line(x+48, y+h-48, x+48, y+12);
    line(x+48, y+h-48, x+w-12, y+h-48);
  }

  // Add point to graph data
  void addPoint(float time, float temp) {
    // Add new value to array
    times.add(time);
    temps.add(temp);
    // Update plot
    if(times.size()>10000){
      times.remove(0);
      temps.remove(0);
    }
    
  }

  void drawPoints() {
    // Don't draw until at least 2 data points exist
    if (times!=null && times.size()>=2) {
      // Calculate mins and maxes for graph
      float minTemp=Float.MAX_VALUE;
      float maxTemp=Float.MIN_VALUE;
      for (float t : temps) { 
        if(t<minTemp)
        minTemp=t;
        if(t>maxTemp)
        maxTemp=t;
      }
      // Assuming time is in order
      float minTime=times.get(0);
      float maxTime=times.get(times.size()-1);
      
      // Draw points
      fill(a);
      stroke(a);
      float graphWidth=w-48-12;
      float graphHeight=h-48-12;
      float lastxloc=-1;
      float lastyloc=-1;
      for(int i=0; i<times.size(); i++){
        float xloc=x+48+(times.get(i)-minTime)*graphWidth/(maxTime-minTime);
        float yloc=y+h-48-(temps.get(i)-minTemp)*graphHeight/(maxTemp-minTemp);
        ellipse(xloc,yloc,5,5);
        // Draw line between points
        if(lastxloc!=-1){
          line(lastxloc,lastyloc,xloc,yloc);
        }
        lastxloc=xloc;
        lastyloc=yloc;
      }
      
      // Plot tick marks
      int ticks=5;
      stroke(fg);
      fill(fg);
      textSize(12);
      for(int i= 0; i<ticks+1; i++){  
        line(x+48-5,y+h-48-i*graphHeight/ticks,x+48+5,y+h-48-i*graphHeight/ticks);
        line(x+48+i*graphWidth/ticks,y+h-48-5,x+48+i*graphWidth/ticks,y+h-48+5);
        text(round(i*(maxTemp-minTemp)/ticks+minTemp),x+48-18,y+h-48-i*graphHeight/ticks);
        text(round(i*(maxTime-minTime)/ticks+minTime),x+48+i*graphWidth/ticks,y+h-48+12);
      }
    }
  }

  void updateGraph() {
    setupGraph();
    drawPoints();
  }
}
