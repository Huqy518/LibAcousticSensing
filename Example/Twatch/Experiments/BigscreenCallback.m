function BufferCallback_TWatchExperiment ()
    global FillUpBuffer savedLabels FillUpPointers AlreadyProcessed;
    global CorrBuffer XYBuffer DistanceBuffer ConfidenceColorBuffer;
    global SpacePresses;
    global currentExpStep ongoingExperiment;
    global AcceptTaps TapReceived;
    global BN_A BN_B BN_P;
    global c1ego c2ego c3ego;
    global c1window c2window c3window;
    global c1DownPeak c2DownPeak c3UpPeak;
    global initializedSounds doneTraining createdUI;
    
    global recordedBorder referenceBorder; 
    global minX maxX minY maxY;
    
    global NROWS NCOLS;
    global handles;
    
    global currentPoint;
    global PS;
    global CORRSIZE;
    global StartTime;
    global MICDISTANCE MIC1D MIC2D WMD;
    global EgoFromWindow;
    global ReplayMode;
    
    % These are set in the replayer
    global CORRSMOOTHING;
    global CONFTHRESH;
    global DISTSMOOTHING;
    global ALGORITHM;
    
    global FLIP_X FLIP_Y;
    global LASTN;
    
    if any(FillUpPointers <= AlreadyProcessed)
        return;
    end
    
    %fig = findobj('Tag', 'PeakFig');
    
    GREEN = [0 1 0];
    YELLOW = [1 1 0];
    RED = [1 0 0];
    
    if isempty(createdUI)
        StartTime = datevec(now);
        
        FLIP_X =0;
        FLIP_Y =0;
        
        if isempty(ReplayMode)
            EgoFromWindow = 0;
            SpacePresses = zeros(2000);
        end
        
        if isempty(CORRSMOOTHING), CORRSMOOTHING = 10; end
        if isempty(DISTSMOOTHING), DISTSMOOTHING = 4; end
        if isempty(CONFTHRESH), CONFTHRESH = 2; end
        if isempty(ALGORITHM), ALGORITHM = 'conftrack'; end
        
        
        LASTN = 200;
        CORRSIZE = 501;
        initializedSounds = 0;
        doneTraining = 0;
        CorrBuffer = zeros(CORRSIZE, 2000, 4);
        
        NROWS = 4;
        NCOLS = 4;
        XYBuffer = zeros(2000, 2);
        DistanceBuffer = zeros(2000, 2);
        ConfidenceColorBuffer = zeros(2000, 2, 3);
        
        %MICDISTANCE = 0.35;
        %MIC1D = 0.14;
        %MIC2D = 0.46;
        %WMD = 0.01;
        
        MICDISTANCE = 0.37;
        MIC1D = 0.14;
        MIC2D = 0.25;
        WMD = 0.01;
        
        %MIC2D = 0.06;
        %MICDISTANCE = 0.142;
        
        createUI();
        savedLabels = [];
        c1DownPeak = -1;
        c2DownPeak = -1;
        c3UpPeak = -1;
        
        
    else
        AlreadyProcessed = AlreadyProcessed + 1;
        if ReplayMode
            if AlreadyProcessed == EgoFromWindow
                findWindowsAndEgoCallback(0,0,0);
            end
            
            if SpacePresses(AlreadyProcessed)
                event = [];
                event.Modifier = [];
                event.Key = 'space';
                Key_Down(0, event); 
            end
        end
        
        
        NowTime = datevec(now);
        % We should have received this many by now. 
        elapsed = (NowTime - StartTime);
        elapsedSecs = elapsed(5)*60 + elapsed(6);
        perChirp = PS.PERIOD / PS.FS;
        expectedNum = ceil(elapsedSecs / perChirp);
        
        if isempty(ReplayMode)
            title(handles.expAx, sprintf('#%d (out of %d)', AlreadyProcessed, expectedNum));
        end
        %savedLabels{AlreadyProcessed} = groundLabel;
        
        
        if initializedSounds
            lastWindow = FillUpBuffer(:,AlreadyProcessed,:);
            
            c1downcorr = abs(convn(lastWindow(:,1), PS.downchirp_data, 'same'));
            c2downcorr = abs(convn(lastWindow(:,2), PS.downchirp_data, 'same'));
            c3upcorr = abs(convn(lastWindow(:,3), PS.upchirp_data, 'same'));
            
            if CORRSMOOTHING ~= 0
                c1downcorr = smooth(c1downcorr, CORRSMOOTHING);
                c2downcorr = smooth(c2downcorr, CORRSMOOTHING);
                c3upcorr = smooth(c3upcorr, CORRSMOOTHING);
            end
            
            c1downcorr = c1downcorr(c1window(1):c1window(2));
            c2downcorr = c2downcorr(c2window(1):c2window(2));
            c3upcorr = c3upcorr(c3window(1):c3window(2));
            
            CorrBuffer(:, AlreadyProcessed, 1) = c1downcorr;
            CorrBuffer(:, AlreadyProcessed, 2) = c2downcorr;
            CorrBuffer(:, AlreadyProcessed, 3) = c3upcorr;
            
            c1uppeak = c1ego;
            c2uppeak = c2ego;
            c3downpeak = c3ego;
            
            
            % Step 1. Peak detection
            if strcmp(ALGORITHM, 'stateless')
                c1DownPeak = getPeaksForCorr(CorrBuffer(:, AlreadyProcessed, 1));
                c2DownPeak = getPeaksForCorr(CorrBuffer(:, AlreadyProcessed, 2));
                c3UpPeak = getPeaksForCorr(CorrBuffer(:, AlreadyProcessed, 3));
            elseif strcmp(ALGORITHM, 'conftrack')
                if c1DownPeak == -1 % This means we haven't initialized peaks yet
                    c1DownPeak = getPeaksForCorr(CorrBuffer(:, AlreadyProcessed, 1));
                    c2DownPeak = getPeaksForCorr(CorrBuffer(:, AlreadyProcessed, 2));
                    c3UpPeak = getPeaksForCorr(CorrBuffer(:, AlreadyProcessed, 3));
                else % We did initialize and found a peak before this. We're ready to go!
                    [c1Confident, c1DownPeak] = singleconftrack(CorrBuffer(:, AlreadyProcessed-1, 1), CorrBuffer(:, AlreadyProcessed, 1), c1DownPeak - c1window(1) + 1, CONFTHRESH);
                    [c2Confident, c2DownPeak] = singleconftrack(CorrBuffer(:, AlreadyProcessed-1, 2), CorrBuffer(:, AlreadyProcessed, 2), c2DownPeak - c2window(1) + 1, CONFTHRESH);
                    [c3Confident, c3UpPeak] = singleconftrack(CorrBuffer(:, AlreadyProcessed-1, 3), CorrBuffer(:, AlreadyProcessed, 3), c3UpPeak - c3window(1) + 1, CONFTHRESH);


                    if c1Confident && c3Confident
                        ConfidenceColorBuffer(AlreadyProcessed, 1, :) = GREEN;
                    elseif c1Confident || c3Confident
                        ConfidenceColorBuffer(AlreadyProcessed, 1, :) = YELLOW;
                    else
                        ConfidenceColorBuffer(AlreadyProcessed, 1, :) = RED;
                    end


                    if c2Confident && c3Confident
                        ConfidenceColorBuffer(AlreadyProcessed, 2, :) = GREEN;
                    elseif c2Confident || c3Confident
                        ConfidenceColorBuffer(AlreadyProcessed, 2, :) = YELLOW;
                    else
                        ConfidenceColorBuffer(AlreadyProcessed, 2, :) = RED;
                    end
                end
            end
            
           
            c1DownPeak =  c1DownPeak + c1window(1) - 1;
            c2DownPeak = c2DownPeak + c2window(1) - 1;
            c3UpPeak = c3UpPeak + c3window(1) - 1;
            PeakDown = [c1DownPeak c2DownPeak c3downpeak];
            PeakUp = [c1uppeak c2uppeak c3UpPeak];
            
            
            % Step 2. Distance calculation
            d13 = calcDistance(PeakDown, PeakUp, 1, 3, MIC1D, WMD);
            d23 = calcDistance(PeakDown, PeakUp, 2, 3, MIC2D, WMD);
            DistanceBuffer(AlreadyProcessed, :) = [d13 d23];
            
            % Three invariants:
            % 1. Distances shouldnt jump too much
            % 2. Distances should be roughly the same. Give or take ~14 cm.
            % 3. Distances should be bounded.
            
            % If these are violated in one of the two and the phone peaks
            % are very different, then we'll use the "well-behaved" one to
            % narrow search peaks in the "bad" one.
            
            % Or we can re-do peak searching excluding the current peak --
            % IF the peak changed a lot since the last time.
            
            % If they are violated in both, then we will go back to peak
            % detection and find the other most likely peak.
            
            % Step 3. XY calculation
            smoothedD13 = mean(DistanceBuffer(max(1, AlreadyProcessed-DISTSMOOTHING):AlreadyProcessed, 1));
            smoothedD23 = mean(DistanceBuffer(max(1, AlreadyProcessed-DISTSMOOTHING):AlreadyProcessed, 2));
            %[xm1, ym1] = calculateXY(d13, d23, MICDISTANCE);
            [xm1, ym1] = calculateXY(smoothedD13, smoothedD23, MICDISTANCE);
            
            XYBuffer(AlreadyProcessed, :) = [xm1 ym1];
            
            smoothedX = smooth(XYBuffer(max(1, AlreadyProcessed-LASTN):AlreadyProcessed, 1), 4);
            smoothedY = smooth(XYBuffer(max(1, AlreadyProcessed-LASTN):AlreadyProcessed, 2), 4);
            
            
            set(handles.xyplot, 'xdata', smoothedX);
            set(handles.xyplot, 'ydata', smoothedY);            
            set(handles.xycurrent, 'xdata', smoothedX(end));
            set(handles.xycurrent, 'ydata', smoothedY(end));
            
            set(handles.c1CorrPlot, 'ydata', c1downcorr);
            set(handles.c2CorrPlot, 'ydata', c2downcorr);
            set(handles.c3CorrPlot, 'ydata', c3upcorr);
            set(handles.c1CorrPeak, 'xdata', c1DownPeak-c1window(1)+1);
            set(handles.c1CorrPeak, 'ydata', c1downcorr(c1DownPeak-c1window(1)+1));
            set(handles.c2CorrPeak, 'xdata', c2DownPeak-c2window(1)+1);
            set(handles.c2CorrPeak, 'ydata', c2downcorr(c2DownPeak-c2window(1)+1));
            set(handles.c3CorrPeak, 'xdata', c3UpPeak-c3window(1)+1);
            set(handles.c3CorrPeak, 'ydata', c3upcorr(c3UpPeak-c3window(1)+1));
            
            
            Xaxis = max(1, AlreadyProcessed-LASTN):AlreadyProcessed;
            set(handles.d1PlotScatter, 'xdata', Xaxis);
            set(handles.d1PlotLine, 'xdata', Xaxis);
            set(handles.d2PlotScatter, 'xdata', Xaxis);
            set(handles.deltaDistance, 'xdata', Xaxis);
            set(handles.d1Delta, 'xdata', Xaxis);
            set(handles.d2Delta, 'xdata', Xaxis);
            set(handles.d2PlotLine, 'xdata', Xaxis);
            
            
            smoothedD1 = smooth(DistanceBuffer(Xaxis, 1), DISTSMOOTHING);
            smoothedD2 = smooth(DistanceBuffer(Xaxis, 2), DISTSMOOTHING);
            set(handles.d1PlotScatter, 'ydata', smoothedD1);
            set(handles.d1PlotLine, 'ydata', smoothedD1);
            set(handles.d1PlotScatter, 'cdata', reshape(ConfidenceColorBuffer(Xaxis, 1, :), length(Xaxis), 3));
            set(handles.d2PlotScatter, 'ydata', smoothedD2);
            set(handles.d2PlotLine, 'ydata', smoothedD2);
            set(handles.d2PlotScatter, 'cdata', reshape(ConfidenceColorBuffer(Xaxis, 2, :), length(Xaxis), 3));
            set(handles.deltaDistance, 'ydata', smoothedD1-smoothedD2);
            set(handles.d1Delta, 'ydata', [0; diff(smoothedD1)]);
            set(handles.d2Delta, 'ydata', [0; diff(smoothedD2)]);
            
            if doneTraining && isempty(ReplayMode)
                x = smoothedX(end);
                y = smoothedY(end);
                
                if FLIP_X, x = -x; end
                if FLIP_Y, y = -y; end
                
                width = maxX - minX;
                height = maxY - minY;
                x = (x - minX) / width;
                y = (y - minY) / height;
                
                
                % Go through beier neely!
                mappedPoint = bnTransform(recordedBorder, referenceBorder, [x y; x y], BN_A, BN_B, BN_P);
                
                %sprintf('(%f, %f) --> (%f, %f)', x, y, mappedPoint(1, 1), mappedPoint(1, 2))
                
                set(currentPoint, 'xdata', mappedPoint(1, 1));
                set(currentPoint, 'ydata', mappedPoint(1, 2));
                
                set(handles.debugMessage, 'string', sprintf('(%f, %f) --> (%f, %f)', x, y, mappedPoint(1,1), mappedPoint(1,2)));
                
                if TapReceived && AcceptTaps && doneTraining % Not strictly necessary to check the third item
                    highlightButtonAt(mappedPoint(1, 1), mappedPoint(1, 2));
                end
            end
        end
        
        if TapReceived && AcceptTaps && ~doneTraining
            event = [];
            event.Modifier = [];
            event.Key = 'space';
            Key_Down(0, event);
        end
        
        if TapReceived
            set(handles.debugMessage, 'string', 'Tap detected');
            TapReceived = 0;
        end
        
        
        if ongoingExperiment
            savedLabels(AlreadyProcessed) = currentExpStep;
        else
            savedLabels(AlreadyProcessed) = -1;
        end
   end
end


function saveButton (~, ~)
    global FillUpBuffer savedLabels AlreadyProcessed;
    global handles EgoFromWindow PS;
    global SpacePresses;
    
    rawData = FillUpBuffer(:,1:AlreadyProcessed,:);
    prefix = get(handles.editText, 'string');
    if strcmp(prefix, ''), prefix = 'lastExperiment'; end
    saveName = sprintf('experiments/%s', prefix);
    
    save(saveName, 'rawData', 'savedLabels', ...
        'EgoFromWindow', 'PS', 'SpacePresses', 'AlreadyProcessed');
end


function Key_Down(~, event)
    global expSteps currentExpStep AlreadyProcessed ongoingExperiment;
    global recordedBorder referenceBorder doneTraining;
    global currentPoint;
    global minX maxX minY maxY;
    global handles;
    global BN_P BN_A BN_B;
    global FLIP_X FLIP_Y;
    global SpacePresses;
    global ReplayMode;
    
    
    if isempty(event.Modifier) && strcmp(event.Key, 'space')
        SpacePresses(AlreadyProcessed) = 1;
        
        % Space is pressed.
        % If currently doing one experiment, we will stop the label and
        % highlight the next experiment using a light highlight.
        % If we are not currently doing an experiment, start the current
        % experiment and highlight experiment with bold highlight.
        
        INACTIVE_COLOR = [0.6 0.6 0.6];
        PREP_COLOR = [0 0 0];
        CURRENT_COLOR = [1 0 0];
        
        if isempty(ReplayMode)
            experimentObjects = findall(expSteps, 'type', 'line');
            set(experimentObjects, 'color', INACTIVE_COLOR);
            experimentObjects = findall(expSteps, 'type', 'scatter');
            set(experimentObjects, 'markerfacecolor', INACTIVE_COLOR);
            set(experimentObjects, 'markerEdgeColor', INACTIVE_COLOR);
        end
        
        if ongoingExperiment
            ongoingExperiment = 0;
            currentExpStep = currentExpStep + 1;
            if currentExpStep > length(expSteps) 
                if ~doneTraining                    
                    disp('All done!');
                    set(currentPoint, 'visible', 'on');
                    [minX, maxX, minY, maxY, recordedBorder, left, top, right, bottom, middlehoriz, middlevert] = getPoints(FLIP_X, FLIP_Y);
                    
                    axes(handles.xyaxes);
                    hold on;
                    plot(left(:,1), left(:, 2), 'linewidth', 3, 'zdata', zeros(1, size(left, 1))+100);
                    plot(right(:,1), right(:, 2), 'linewidth', 3, 'zdata', zeros(1, size(right, 1))+100);
                    plot(top(:,1), top(:, 2), 'linewidth', 3, 'zdata', zeros(1, size(top, 1))+100);
                    plot(bottom(:,1), bottom(:, 2), 'linewidth', 3, 'zdata', zeros(1, size(bottom, 1))+100);
                    plot(middlehoriz(:,1), middlehoriz(:, 2), 'linewidth', 3, 'zdata', zeros(1, size(middlehoriz, 1))+100);
                    plot(middlevert(:,1), middlevert(:, 2), 'linewidth', 3, 'zdata', zeros(1, size(middlevert, 1))+100);
                    hold off;
                    drawnow;
                    
                    referenceBorder = getReference;
                    
                    
                    if isempty(ReplayMode)
                        set(handles.instructionText, 'string', 'Finding deformation. Please wait.');
                        set(handles.debugMessage, 'string', 'Finding beier neely parameters');
                        drawnow;

                        [BN_A, BN_B, BN_P, ~] = BNSearch(recordedBorder, referenceBorder);
                        set(handles.debugMessage, 'string', 'Done.');
                        set(handles.instructionText, 'visible', 'off');
                        drawnow;
                        drawbuttons;
                    end
                    doneTraining = 1;
                end
                
                return;
            end
            
            
            if isempty(ReplayMode)
                currStep = expSteps(currentExpStep);
                if strcmp(get(currStep, 'type'), 'line')
                    set(currStep, 'color', PREP_COLOR);
                else
                    set(currStep, 'MarkerFaceColor', PREP_COLOR);
                    set(currStep, 'MarkerEdgeColor', PREP_COLOR);
                end
            end
        else
            
            ongoingExperiment = 1;
            if currentExpStep > length(expSteps) 
                return;
            end
            
            if isempty(ReplayMode)
                currStep = expSteps(currentExpStep);
                if strcmp(get(currStep, 'type'), 'line')
                   set(currStep, 'color', CURRENT_COLOR);
                else
                    set(currStep, 'MarkerFaceColor', CURRENT_COLOR);
                    set(currStep, 'MarkerEdgeColor', CURRENT_COLOR);
                end
            end
        end
    end
end


function autotuneCallback (~, ~, ~)
    global phoneSensor watchSensor;
    global FillUpBuffer AlreadyProcessed;
    global PS handles ReplayMode;
    % Take the last correlation 
    % Find the ego sounds in c1-up, c2-up, c3-down
    % Use those to set the windows for c1-down, c2-down and c3-up
    
    
    lastWindow = FillUpBuffer(:, AlreadyProcessed, :);
    c1upcorr = abs(convn(lastWindow(:,1), PS.upchirp_data, 'same'));
    c3downcorr = abs(convn(lastWindow(:,3), PS.downchirp_data, 'same'));
    [~, c1ego] = max(c1upcorr);
    [~, c3ego] = max(c3downcorr);

    
    while 1
        % If they're too close to the border, shift them
        if (c1ego - 100 <= 0 || c1ego + 400 > PS.PERIOD)
            phoneSensor.jss.writeByte(int8(phoneSensor.REACTION_DELAY_SOUND));
            phoneSensor.jss.writeInt(int32(100));
            phoneSensor.jss.writeByte(int8(-1)); % Check
        elseif (c3ego - 100 <= 0 || c3ego + 400 > PS.PERIOD)
            watchSensor.jss.writeByte(int8(watchSensor.REACTION_DELAY_SOUND));
            watchSensor.jss.writeInt(int32(100));
            watchSensor.jss.writeByte(int8(-1)); % Check
        
        % If they're too close together, shift them
        elseif (abs(c1ego - c3ego) < (PS.PERIOD*0.3)) || ...
            (abs(c1ego - c3ego) > (PS.PERIOD*0.6))
            phoneSensor.jss.writeByte(int8(phoneSensor.REACTION_DELAY_SOUND));
            phoneSensor.jss.writeInt(int32(300));
            phoneSensor.jss.writeByte(int8(-1)); % Check
        else
            break
        end
        
        
        pause(0.5);
        
        lastWindow = FillUpBuffer(:, AlreadyProcessed, :);
        c1upcorr = abs(convn(lastWindow(:,1), PS.upchirp_data, 'same'));
        c3downcorr = abs(convn(lastWindow(:,3), PS.downchirp_data, 'same'));
        [~, c1ego] = max(c1upcorr);
        [~, c3ego] = max(c3downcorr);   
        
        
        if isempty(ReplayMode)
            set(handles.debugMessage, 'string', ...
                sprintf('Auto tune with already processed %d. \nc1Ego=%d, c3Ego=%d, Diff=%d\n. We are trying go higher than %d\n', ...
                    AlreadyProcessed, ...
                    c1ego, c3ego, abs(c1ego-c3ego), ...
                    PS.PERIOD*0.3));
        end
    end
    
    
    if isempty(ReplayMode)
        set(handles.debugMessage, 'string', ...
            sprintf('Auto tune done with: c1Ego=%d, c3Ego=%d, Diff=%d\n.\n', ...
                c1ego, c3ego, abs(c1ego-c3ego)));
    end
end



function findWindowsAndEgoCallback(~, ~, ~)
    global initializedSounds;
    global c1ego c2ego c3ego;
    global c1window c2window c3window;
    global FillUpBuffer AlreadyProcessed;
    global PS EgoFromWindow;
    % Take the last correlation 
    % Find the ego sounds in c1-up, c2-up, c3-down
    % Use those to set the windows for c1-down, c2-down and c3-up
    
    lastWindow = FillUpBuffer(:, AlreadyProcessed, :);
    % Ego sounds: 
    c1upcorr = abs(convn(lastWindow(:,1), PS.upchirp_data, 'same'));
    c2upcorr = abs(convn(lastWindow(:,2), PS.upchirp_data, 'same'));
    c3downcorr = abs(convn(lastWindow(:,3), PS.downchirp_data, 'same'));
    
    [~, c1ego] = max(c1upcorr);
    [~, c2ego] = max(c2upcorr);
    [~, c3ego] = max(c3downcorr);
    
    
    c1window = [c3ego-100 c3ego+400];
    c2window = [c3ego-100 c3ego+400];
    c3window = [c1ego-100 c1ego+400];
    initializedSounds = 1;
    
    fprintf('c1ego=%d c2Ego=%d c3Ego=%d, c1Window=[%d, %d], c2Window=[%d, %d] c3Window=[%d, %d]\n', ...
            c1ego, c2ego, c3ego, ...
            c1window(1), c1window(2), ...
            c2window(1), c2window(2), ...
            c3window(1), c3window(2));
    
    EgoFromWindow = AlreadyProcessed;
end

function startTapCallback (~, ~, ~)
    global AcceptTaps TapsReceived;
    AcceptTaps = 1;
    TapsReceived = 0;
end



function pressSpace(~, ~, ~)
    event = [];
    event.Modifier = [];
    event.Key = 'space';
    Key_Down(0, event);
end

function createUI()
    % lineCnts is the number of lines per figure
    global currentPoint;
    global expSteps currentExpStep expFig ongoingExperiment;
    global handles;
    global CORRSIZE LASTN;
    global ReplayMode createdUI;
    currentExpStep = 1;
    ongoingExperiment = 0;
    
    FONTSIZE = 20;
    createdUI = 1;
    
    set(0,'DefaultAxesFontSize',14,'DefaultTextFontSize',16);
    
    
    MonPositions = get(0, 'monitorpositions');
    fullMon = MonPositions(MonPositions(:,3) == 1440, :);
    firstHalf = fullMon;
    firstHalf(3) = firstHalf(3)/2;
    secondHalf = firstHalf;
    secondHalf(1) = firstHalf(3);
    
    fullSecondMon = MonPositions(MonPositions(:,3) == 1920, :);
    if isempty(fullSecondMon)
        fullSecondMon = fullMon;
    end
    
    
    
    if isempty(ReplayMode) 
        figure('Toolbar','none','MenuBar','none','Tag','PeakFig', 'position', firstHalf);
        h_panel = uipanel('Parent', gcf, 'Units', 'normal', 'Position', [0  0 1 0.5]);

        handles.debugMessage = uicontrol(h_panel, ...
        'Style','text',...
        'units', 'normalized', ...
        'Position',[0 0 1 0.9],...
        'FontSize',25 ,...
        'String','Num');


        %% Experiment recording panel
        h_panel2 = uipanel('Parent', gcf, 'Units', 'normal', 'Position', [0  0.5 1 0.5]); 

        handles.editText = uicontrol(h_panel2, ...
            'style','edit',...
            'units','normal',...
            'position',[0.0 0.5 0.5 0.5], ...
            'FontSize', FONTSIZE);

        uicontrol(h_panel2, ...
            'style','pushbutton', ...
            'units','normal', ...
            'position',[0.0 0 0.5 0.5], ...
            'String', 'Done!', ...
            'FontSize', FONTSIZE, ...
            'Callback', @saveButton);


        uicontrol(h_panel2, ...
            'style','pushbutton', ...
            'units','normal', ...
            'position',[0.5 0.75 0.5 0.25], ...
            'String', '1. Autotune', ...
            'FontSize', FONTSIZE, ...
            'Callback', @autotuneCallback);




        uicontrol(h_panel2, ...
            'style','pushbutton', ...
            'units','normal', ...
            'position',[0.5 0.5 0.5 0.25], ...
            'String', '2. Find Windows and Ego', ...
            'FontSize', FONTSIZE, ...
            'Callback', @findWindowsAndEgoCallback);



        uicontrol(h_panel2, ...
            'style','pushbutton', ...
            'units','normal', ...
            'position',[0.5 0.25 0.5 0.25], ...
            'String', '3. Start Tapping', ...
            'FontSize', FONTSIZE, ...
            'Callback', @startTapCallback);



        uicontrol(h_panel2, ...
            'style','pushbutton', ...
            'units','normal', ...
            'position',[0.5 0.0 0.5 0.25], ...
            'String', 'Advance', ...
            'FontSize', FONTSIZE, ...
            'Callback', @pressSpace);


        % Draw experiment window
        expFig = figure('position', fullSecondMon);
        handles.expAx = subplot(1,1,1);
        hold on;
        expSteps = zeros(1, 6);
        expSteps(1) = plot([0 1], [1 1]);
        expSteps(2) = plot([1 1], [1 0]);
        expSteps(3) = plot([0 1], [0 0]);
        expSteps(4) = plot([0 0], [0 1]);
        expSteps(5) = plot([0 1], [0.5 0.5]);
        expSteps(6) = plot([0.5 0.5], [0 1]);

        handles.instructionText = text(0.5, 0.5, 'Please trace the border', ...
                                        'HorizontalAlignment', 'center', ...
                                        'VerticalAlignment', 'middle');

        currentPoint = scatter(0, 0, 150, 'r', 'filled');
        currentPoint.Visible = 'off';
        xlim([-0.1 1.1]);
        ylim([-0.1 1.1]);
        hold off;

        set(expFig, 'KeyPressFcn', @Key_Down);
    else
        % We still ahve to set the "expSteps"
        expSteps = zeros(1, 6);
    end
    
    % Beautiful experiment debug window
    figure('position', secondHalf, 'tag', 'stateFigure');
    NROWS = 6;
    handles.xyaxes = subplot(NROWS,2,[1 3 5]);
    hold on;
    handles.xyplot = plot(0, 0, 'r');
    handles.xycurrent = scatter(0, 0, 50, 'filled');
    hold off;
    
  
    subplot(NROWS,2,2);
    hold on;
    handles.c1CorrPlot = plot(zeros(1, CORRSIZE));
    handles.c1CorrPeak = scatter(0,0);
    hold off;
    
    subplot(NROWS,2,4);
    hold on;
    handles.c2CorrPlot = plot(zeros(1, CORRSIZE));
    handles.c2CorrPeak = scatter(0,0);
    hold off;
    
    subplot(NROWS,2,6);
    hold on;
    handles.c3CorrPlot = plot(zeros(1, CORRSIZE));
    handles.c3CorrPeak = scatter(0,0);
    hold off;
    
    ax(1) = subplot(NROWS,2,[7 8 9 10]);
    hold on;
    handles.d1PlotScatter = scatter(1:LASTN, zeros(1, LASTN), 15, 'filled');
    handles.d2PlotScatter = scatter(1:LASTN, zeros(1, LASTN), 15, 'filled');
    handles.d1PlotLine = plot(zeros(1, LASTN));
    handles.d2PlotLine = plot(zeros(1, LASTN));
    hold off;
    
    
    ax(2) = subplot(NROWS,2,[11 12]);
    hold on;
    handles.deltaDistance = plot(zeros(1, LASTN), 'linewidth', 3);
    handles.d1Delta = plot(zeros(1, LASTN));
    handles.d2Delta = plot(zeros(1, LASTN));
    hold off;
    
    
    %linkaxes(ax,'x');
end





function drawbuttons
%DRAWBU Summary of this function goes here
%   Detailed explanation goes here
    global handles;
    global NCOLS NROWS;

    
    axes(handles.expAx);
    hold on;
    for r=1:NROWS
        for c=1:NCOLS
            x = (c/NCOLS + (c-1)/NCOLS)/2.0;
            y = ((1-r/NROWS) + (1-(r-1)/NROWS)) / 2.0;
            s = scatter(x, y);
            s.ZData = 10;
        end
    end
    
    for r=1:NROWS
        plot([0 1], [1-r/NROWS 1-r/NROWS]);
    end
    
    for c=1:NCOLS
        plot([c/NCOLS c/NCOLS], [0 1]);
    end
    
    handles.highlightedPart = fill(0, 0, 'r');
    hold off;
end


function highlightButtonAt (x, y)
    global NCOLS NROWS;
    x = round(x*100);
    y = round((1-y)*100);
    perCol = round(1/NCOLS*100);
    perRow = round(1/NROWS*100);
    
    col = ceil(x/perCol);
    row = ceil(y/perRow);
    highlightButton(row, col);
end

function highlightButton (r, c)
    global NCOLS NROWS;
    global handles;
    x = [(c-1)/NCOLS c/NCOLS c/NCOLS (c-1)/NCOLS];
    y = [(1-r/NROWS) (1-r/NROWS) (1-(r-1)/NROWS) (1-(r-1)/NROWS)];
    set(handles.highlightedPart, 'xdata', x);
    set(handles.highlightedPart, 'ydata', y);
end
