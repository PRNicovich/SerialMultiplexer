% NicoPlex communication test script

classdef NicoPlex
    
    properties
        
        serialPort = 'COM5'; % Name of serial port
        serialBaud = 250000; % Baud rate of serial port - must match Marlin configuration setting
        
        bufferLines = 1; % Lines to load into Arduino memory at one time. 
                         % Values other than 1 cause issues
        serHand = [];
        gCode = [];
        
        stepperSpeed = 1000;  % Default speed of steppers
        
        servoConn = 0;
        needleDownAngle = 0; % Servo angle for 'down' position of needle carrier 
        needleUpAngle = 145; % Servo angle for 'up' position of needle carrier
        needleDownPause = 5; % Degrees above (below) needleDownAngle to hold for 5 ms to avoid needle overshoot
                               % Will always stop between needleDownAngle
                               % and needleUpAngle, in case of inverted
                               % polarity
        XStepper = 0; % Channel of X axis stepper
        YStepper = 1; % Channel of Y axis stepper
        
        samplePump = 2; % Channel of solution transfer pump stepper
        bufferPump = 3; % Channel of buffer extruder pump
        wastePump = 4; % Channel of waste extruder pump
        
        samplePumpStepsPermL = 1000;
        bufferPumpStepsPermL = 1000;
        wastePumpStepsPermL = 1000;
        
        % Initial maxValues
        % These will be overwritten with values returned from 
        % 'findMaxValues() method.
        maxValue = struct('X', 410, 'Y', 65); % Hard-coded max values. 
                                              % findMaxValues() can make these shorter 
    end
    
    methods
        
        function nP = NicoPlex(serialPort, serialBaud)
            % Initialize class
            
            if nargin == 2
                nP.serialPort = serialPort;
                nP.serialBaud = serialBaud;
            else
                error('Two arguments must be given (obj = NicoPlex(serialPort, serialBaud)');
            end
            
        end
        
        function nP = init(nP)
            
            if nargout == 0
                error('At least one argument must be supplied.')
            end
            
            %% Initialize communication
            fprintf(1, 'Initializing communication with device.\n');
            
            nP.serHand = serial(nP.serialPort, 'BaudRate', nP.serialBaud);
            fopen(nP.serHand);
            
            pause(0.5);
            
            % Echo serial reply to open
            echo = nP.readReply(nP.serHand);
            echoAgain = nP.readReply(nP.serHand);
            
            disp(echo);
            disp(echoAgain);
            
        end
        
        function nP = enableSteppers(nP)
            % Engage steppers to hold position
            
            fprintf(1, 'Engaging steppers.\n');
            fprintf(nP.serHand, 'M17\n');
            echo = nP.readReply(nP.serHand);
            
            disp(echo);
            
            % Set steppers to default speed
            fprintf(nP.serHand, 'G0 F%d\n', nP.stepperSpeed);
            echo = nP.readReply(nP.serHand);
            disp(echo);
            
            %             echo = fread(nP.serHand, nP.serHand.BytesAvailable, 'uchar');
            %             disp(char(echo'));
            
        end
        
        function nP = clearSerial(nP)
            % Clear out serial buffer
            
           if nP.serHand.BytesAvailable > 0
            fread(nP.serHand, nP.serHand.BytesAvailable);
           end
           
        end
        
        function nP = setExtrudersRelative(nP)
            % Set extruders to relative position for ease of dispensing
            
            fprintf(1, 'Setting extruders to relative positioning.\n');
            fprintf(nP.serHand, 'M128\n');
            echo = nP.readReply(nP.serHand);
            
            disp(echo);

            %             echo = fread(nP.serHand, nP.serHand.BytesAvailable, 'uchar');
            %             disp(char(echo'));
            
        end
        
        
        function nP = homeAxes(nP)
            % Use endstop switches to find zero position
            
            fprintf(1, 'Homing axes.\n');
            
            fprintf(nP.serHand, 'G28 XY\n');
            
            echo = '';
            while isempty(strfind(echo, 'ok'))
                echo = [echo, nP.readReply(nP.serHand, 30)];
                
            end
            disp(echo);
            
        end
        
        function nP = findMaxValues(nP)
            % Use far endstop values to find maximum position of axes
            
            fprintf(1, 'Finding max axes positions.\n');
            
            fprintf(nP.serHand, 'G0 X410');
            
            echo = '';
            while isempty(strfind(echo, 'ok'))
                echo = [echo, nP.readReply(nP.serHand, 30)];
                
            end
            disp(echo);

            fprintf(nP.serHand, 'G0 Y65');

            echo = '';
            while isempty(strfind(echo, 'Y'))
                echo = [echo, nP.readReply(nP.serHand, 30)];
                
            end
            disp(echo);
            
            assignin('base', 'echo', echo);
            
            % Parse echo to pull out empirical limits on far ends
            [~, tok] = strtok(echo, 'X');
            xlim = strtok(tok, char(10));
            
            nP.maxValue.X = str2double(xlim(3:end));
            
            [~, tok] = strtok(echo, 'Y');
            ylim = strtok(tok, char(10));
            
            nP.maxValue.Y = str2double(ylim(3:end));
            
        end
        
        function nP = execute(nP)
            % Do what the gCode has programmed
            
            executedCode = '';
            
            gCodeCell = strsplit(nP.gCode, '\n'); % Split gCode array into cells of 1 line each
            lengthToUpload = min([length(gCodeCell) nP.bufferLines]); % see if we have too many to fill buffer
%             lengthToUpload = 1;
            
            initgCodeformat = repmat('%s\n', 1, lengthToUpload);
%             initgCodeformat = strcat(initgCodeformat, '\n');
            uploadStr = sprintf(initgCodeformat, gCodeCell{1:lengthToUpload});
            
            fprintf(nP.serHand, uploadStr); % take initial strings and add to buffer
            
            fprintf(1, uploadStr);
            
            executedCode = strcat(executedCode, uploadStr);
            executedCode = sprintf('%s\n', executedCode);
      
            
            % if buffer didn't cover all of the strings
            if length(gCodeCell) > lengthToUpload
                
                onCell = lengthToUpload+1;
                
                while le(onCell, length(gCodeCell))  % move through remaining lines
                    
                    % wait for 'ok' to be returned from serial port before
                    % uploading the next line
                    echo = '';
                    while isempty(strfind(echo, 'ok'))
                        echo = [echo, nP.readReply(nP.serHand, 30)];
                        findOks = numel(strfind(echo, 'ok'));
%                         disp(numel(findOks));
                    end
%                     fprintf(1, '%s - %s\n', gCodeCell{onCell}, echo);
                    
                    
                    if ~isempty(findOks)
                        %                         disp(echo)
                        nextgCodeformat = repmat('%s\n', 1, numel(findOks));
                        
                        uploadString = sprintf(nextgCodeformat, gCodeCell{onCell:min([onCell + numel(findOks)-1, length(gCodeCell)])});
                        fprintf(nP.serHand, uploadString); % upload next line
                        fprintf(1, uploadString);
%                         disp(length(uploadString));
                        
                        executedCode = [executedCode, uploadString];
                        
                        onCell = onCell + numel(findOks);
                    else
                        %                         pause(0.05);
                    end
                end
                assignin('base', 'executedCode', executedCode);
            end
            
        end
        
        function nP = clearGcode(nP)
            nP.gCode = [];
        end
        
        function nP = servoDown(nP)
            %% Set servo to bottom position
            
            nP.gCode = sprintf('%sM400\n', nP.gCode);
            if nP.needleDownAngle > nP.needleUpAngle
                
                nP.gCode = sprintf('%sM280 P0 S%d \n', nP.gCode, nP.needleDownAngle - nP.needleDownPause);
                nP.gCode = sprintf('%sG4 P%d\n', nP.gCode, 5);
                nP.gCode = sprintf('%sM280 P0 S%d \n', nP.gCode, nP.needleDownAngle);
                
            elseif nP.needleDownAngle < nP.needleUpAngle
                
                nP.gCode = sprintf('%sM280 P0 S%d \n', nP.gCode, nP.needleDownAngle + nP.needleDownPause);
                nP.gCode = sprintf('%sG4 P%d\n', nP.gCode, 5);
                nP.gCode = sprintf('%sM280 P0 S%d \n', nP.gCode, nP.needleDownAngle);
                
            else
                nP.gCode = sprintf('%sM280 P0 S%d \n', nP.gCode, nP.needleDownAngle);
            end
            
            nP.gCode = sprintf('%sM280 P0 S%d \n', nP.gCode, nP.needleDownAngle);
            nP.gCode = sprintf('%sM400\n', nP.gCode);
            
            %             echo = fread(nP.serHand, nP.serHand.BytesAvailable, 'uchar');
            %             disp(char(echo'));
            
        end
        
        function nP = servoUp(nP)
            %% Set servo to top position
            
            nP.gCode = sprintf('%sM400\n', nP.gCode);
            nP.gCode = sprintf('%sM280 P0 S%d \n', nP.gCode, nP.needleUpAngle);
            nP.gCode = sprintf('%sM400\n', nP.gCode);
            %             echo = fread(nP.serHand, nP.serHand.BytesAvailable, 'uchar');
            %             disp(char(echo'));
            
        end
        
        function nP = pauseMillis(nP, varargin)
            % Pause motion for specified time 
            
            if nargin == 2
                pauseTime = varargin{1};
            else
                error('Second argument of milliseconds of pause must be supplied');
            end
            
            nP.gCode = sprintf('%sG4 P%d\n', nP.gCode, pauseTime);
        end
        
        function nP = goto(nP, varargin)
            
            % send to absolute position on x and y
            % Arguments in mm
            
            if nargin == 2
                x = varargin{1};
                y = [];
                z = [];
                f = [];
            elseif nargin == 3
                x = varargin{1};
                y = varargin{2};
                z = [];
                f = [];
            elseif nargin == 4
                x = varargin{1};
                y = varargin{2};
                z = varargin{3};
                f = [];
            elseif nargin == 5
                x = varargin{1};
                y = varargin{2};
                z = varargin{3};
                f = varargin{4};
            else
                error('Up to four arguments are supported. nP = nP.goto(X, Y, Z, F)');
            end
            
            gCodeOut = sprintf('%sG0', nP.gCode);
            
            if ~isempty(x)
                gCodeOut = sprintf('%s X%.2f', gCodeOut, x);
                %                 echo = fread(nP.serHand, nP.serHand.BytesAvailable, 'uchar');
                %                 disp(char(echo'));
            end
            
            if ~isempty(y)
                gCodeOut = sprintf('%s Y%.2f', gCodeOut, y);
                %                 echo = fread(nP.serHand, nP.serHand.BytesAvailable, 'uchar');
                %                 disp(char(echo'));
            end
            
            if ~isempty(z)
                gCodeOut = sprintf('%s Z%.2f', gCodeOut, z);
                %                 echo = fread(nP.serHand, nP.serHand.BytesAvailable, 'uchar');
                %                 disp(char(echo'));
            end
            
            if isempty(f)
                nP.gCode = sprintf('%s\n', gCodeOut);
            else
                nP.gCode = sprintf('%s F%.2f\n', gCodeOut, f);
            end
            
        end
        
        function nP = setTravelSpeed(nP, varargin)
            
            if nargin == 2
                x = varargin{1};
            elseif nargin == 3
                x = varargin{1};
            else
                error('Up to one argument is supported. nP = nP.setTravelSpeed(speed)');
            end
            
            if ~isempty(x)
                fprintf(nP.serHand, 'G1 F%.2f', x);
%                 echo
                %                 echo = fread(nP.serHand, nP.serHand.BytesAvailable, 'uchar');
                %                 disp(char(echo'));
            else
                disp('No speed set. Specify speed as argument');
            end
            
            
        end
        
        
        
        function delete(nP)
            % Terminate communication and delete object
            
            disp('Terminating communication with NicoPlex device');
            
            delete(nP.serHand);
            
        end
        
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Static methods
    methods(Static)
        
        function echo = readReply(serialPort, varargin)
            
%             disp(serialPort)
            
            if nargin == 2
                maxWaits = varargin{1}*100;
            else
                maxWaits = 500;
            end
            
            nWaits = 0;
            while serialPort.BytesAvailable == 0
                if ge(nWaits, maxWaits)
                    break;
                else
                    pause(0.01)
                    nWaits = nWaits + 1;
                end
            end
            
            if nWaits < maxWaits
                echo = char(fread(serialPort, serialPort.BytesAvailable, 'uchar')');
            else
                error('Communication did not return text in 5 seconds');
            end
            
        end
    end
end
