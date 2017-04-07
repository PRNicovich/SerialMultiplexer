% Test script using NicoPlexComms class

% Initialization communication parameters
serialPort = 'COM5';
serialBaud = 250000;

%% Initalize

nP = NicoPlex(serialPort, serialBaud);
nP = nP.init();

%% Start-up code

nP.enableSteppers();
nP = nP.clearGcode();
nP = nP.servoUp();
nP.execute();

nP = nP.clearGcode();
nP.homeAxes();
nP = nP.findMaxValues();
nP.setTravelSpeed(5000);
nP.homeAxes();
nP.setExtrudersRelative();
nP.needleDownAngle = 73;
nP.needleUpAngle = 140;

%%  Start test motion

startPositionX = 300; % Target position X
startPositionY = 2; % Target position Y

nP.homeAxes();
nP = nP.clearGcode();

nP = nP.goto(startPositionX, startPositionY);
nP = nP.servoUp();

nP.execute();

%% Move in loop around 96 well plate

nP = nP.clearGcode();

% [xVect, yVect] = meshgrid(startPositionX:27:(startPositionX+99), startPositionY:18:(startPositionY+63));
[xVect, yVect] = meshgrid(startPositionX + [0 99], startPositionY + [0 63]);
yVect(:, 2:2:end) = flipud(yVect(:, 2:2:end));

nP.homeAxes();
nP.setTravelSpeed(10000);

for m = 1:3
    for k = 1:numel(xVect)

            nP = nP.goto(xVect(k), yVect(k));

            nP = nP.servoDown();
            nP = nP.pauseMillis(50);
            nP = nP.servoUp();

    end
    
    nP = nP.goto(250, 10);
    nP = nP.servoDown();
    nP = nP.pauseMillis(50);
    nP = nP.servoUp();
    
end

nP = nP.goto(startPositionX, startPositionY);

nP.execute();


%% Fluid transfer test
% Move liquid between wells 

startPositionX = 32;
startPositionY = 2;
startPositionZ = 100;

xStepSize = 9; % Distance to move in mm
yStepSize = 9;
zExtractDist = 65; % 'Distance' to move z axis to correspond to fluid motion
zClearDist = 10; % Blow out amount

moveSpeed = 8000;
extractSpeed = 300;


nP = nP.clearGcode();
nP.clearSerial();

nP.homeAxes();
nP = nP.servoUp();

nP = nP.goto(startPositionX, startPositionY, startPositionZ, moveSpeed);
nP = nP.goto(startPositionX+50, startPositionY+10, startPositionZ+10, moveSpeed);
nP = nP.goto(startPositionX, startPositionY, startPositionZ, moveSpeed);
nP = nP.pauseMillis(100);

for k = 1:1

    nP = nP.goto(startPositionX, (startPositionY + (k-1)*yStepSize), [], moveSpeed);
    nP = nP.servoDown();
    nP = nP.pauseMillis(100);
    nP = nP.goto([], [], startPositionZ-zExtractDist, extractSpeed);
    nP = nP.servoUp();
    nP = nP.goto(startPositionX + xStepSize, startPositionY + (k-1)*yStepSize, [], moveSpeed);
%     nP = nP.servoDown();
    nP = nP.pauseMillis(100);
    nP = nP.goto([], [], startPositionZ + zClearDist, extractSpeed);
    
%     nP = nP.servoUp();
    
    nP = nP.goto([], [], startPositionZ + zClearDist + zClearDist, moveSpeed);
    nP = nP.goto([], [], startPositionZ, moveSpeed);
    
end

nP = nP.goto(startPositionX, startPositionY, startPositionZ, moveSpeed);

nP.execute();




%% End communication

delete(nP);
