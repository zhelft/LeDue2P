function ScanImage(defFile,iniFileName)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function that starts the ScanImage software.
% 
% defFile is the default file name of a .usr file if called as a function.
%
% Software Description:
%
% ScanImage controls a laser-scanning microscope (Figure 1A). It is written 
% entirely in MATLAB and makes use of standard multifunction boards 
% (e.g. National Instruments, Austin, TX) for data acquisition and 
% control of scanning. The software generates the analog voltage 
% waveforms to drive the scan mirrors, acquires the raw data from 
% the photomultiplier tubes (PMTs), and processes these signals to 
% produce images. ScanImage controls three input channels 
% (12-bits each) simultaneously, and the software is written to be 
% easily expandable to the maximum number of channels the data acquisition 
% (DAQ) board supports and that the CPU can process efficiently. 
% The computer bus speed dictates the number of samples that can be 
% acquired before an overflow of the input buffer occurs, while the 
% CPU speed and bus speed combine to determine the rate of data 
% processing and ultimately the refresh rate of images on the screen. 
% Virtually no customized data acquisition hardware is required for 
% either scan mirror motion or data acquisition.
%
% Reference: Pologruto, T.A., Sabatini, B.L., and Svoboda, K. (2003)
%            ScanImage: Flexible software for operating laser scanning microscopes.
%            Biomedical Engineering Online, 2:13.
%            Link: www.biomedical-engineering-online.com/content/2/1/13
%
% Copyright 2003 Cold Spring harbor Laboratory
%
%% MODFIFICATIONS
%   11/24/03 Tim O'Connor - Start using the daqmanager object.
%   12/18/03 Tim O'Connor - Initialize the uncagingPulseImporter tool.
%   TPMOD_1: Modified 12/30/03 Tom Pologruto - Handles defFile Input correctly now
%   TPMOD_2: Modified 12/31/03 Tom Pologruto - Sets the GUI for power control
%            to the scan laser beam by default.
%   TPMOD_3: Modified 1/12/04 Tom Pologruto - Allows passing in of INI file also now.
%   TO051704a Tim O'Connor 5/17/04 - Public release formatting.
%   VI021808A Vijay Iyer 2/18/08 - Make global vars (state,gh) available in base workspace--needed (for now) for GUI callback dispatches (e.g. via updateGUIByGlobal())
%   VI030408A Vijay Iyer 3/4/08 - Prompt for .ini file location if no .usr file specified
%   VI042108A Vijay Iyer 4/21/08 - Initialize file writing function handle
%   VI050608A Vijay Iyer 5/6/08 - Use installation 'standard_model.ini' file when no user-created file was identified
%   VI081308A Vijay Iyer 8/13/08 - Do PowerControl figure hiding stuff /after/ opening user file, because that action can re-open the GUI
%   VI091608A Vijay Iyer 9/16/08 - Include updateSaveDuringAcq in startup tasks 
%   VI092408A Vijay Iyer 9/24/08 - Handle unified configuration GUI -- Vijay Iyer 9/24/08
%   VI101708A Vijay Iyer 10/17/08 - Eliminate the use of scanLaserBeam variable
%   VI103108A Vijay Iyer 10/31/08 - Handle pockels calibration via openusr() or calibrateBeams(), depending on whether USR file is selected
%   VI110208A Vijay Iyer 11/02/08 - Handle state.init.eom.started flag here now, after first chance to calibrate any beams the user is employing
%   VI110708A Vijay Iyer 11/07/08 - Verify that DAQmx drivers are present and exclusively installed
%   VI111708A Vijay Iyer 11/17/08 - Allow bidirectional scanning to be enabled via an INI file setting
%   VI111708B Vijay Iyer 11/17/08 - Ensure ChannelGUI is in consistent state following all INI/USR loading
%   VI112208A Vijay Iyer 11/22/08 - Create state.userSettingsPath here now, since it's not done in INI file anymore
%   VI121208A Vijay Iyer 12/12/08 - Call setPockelsAcqParameters() rather than Configuration GUI callback
%   VI010209A Vijay Iyer 1/02/09 - Remove call to setPockelsAcqParameters()
%   VI011609A Vijay Iyer 1/16/09 - Changed state.init.pockelsOn to state.init.eom.pockelsOn
%   VI011709A Vijay Iyer 1/17/09 - Add PowerBox GUI to list of figures
%   VI012709A Vijay Iyer 1/27/09 - Load configurationGUI, rather than basicConfigurationGUI
%   VI012909A Vijay Iyer 1/29/09 - Create section to initialize cell array variables (as these can not be initialized within the INI file, with current INI parser)
%   VI020709A Vijay Iyer 2/7/09 - Store version information immediately following INI file loading 
%   VI021309A Vijay Iyer 2/13/09 - Add Align GUI to list of figures
%   VI022709A Vijay Iyer 2/27/09 - Revert VI110708A
%   VI111109A Vijay Iyer 11/11/09 - Remove code referencing now-deprecated 'specialty' EOM features
%   VI112309A Vijay Iyer 11/23/09 - Revert VI020709A: No longer place version information here -- do this in internal.ini instead
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% 

 
%Create waitbar to track process of application.
h = waitbar(0, 'Starting ScanImage...', 'Name', 'ScanImage Software Initialization', 'WindowStyle', 'modal', 'Pointer', 'watch');            

% Global declaration: all variables used by ScanImage are contained in the structure
% state, while all the handles to the grpahics objects (GUIs) are contained in
% the structure gh
global state gh
evalin('base','global state gh;'); %VI021808A

%User File Manipulations from outside the function....
if nargin==0
    defFile='';
    iniFileName='';
elseif nargin==1
    iniFileName='';
end

if isempty(defFile) % start TPMOD_1 12/31/03
    % Select user file if one exists....
    % Remembers the path to the last one loaded from the last session if possible....
    scanimagepath=fileparts(which('scanimage'));
    if isdir(scanimagepath) & exist(fullfile(scanimagepath,'lastUserPath.mat'))==2
        temp=load(fullfile(scanimagepath,'lastUserPath.mat'));
        userpath=getfield(temp,char(fieldnames(temp)));
%         if isdir(userpath) %VI030408A
%             cd(userpath);
%         end
    else
        userpath = cd; %VI030408A -- use current path if no lastUserPath exists
    end
    
    [fname, pname]=uigetfile('*.usr', 'Choose user file (cancel if none)',userpath);
    if isnumeric(fname)
        fname='';
        pname='';
        full=[];
        selectIni=true;
    else
        %Use 'standard.ini' if found in .usr directory, otherwise prompt to select
        if exist(fullfile(pname,'standard.ini'),'file') %VI030408A 
            iniFileName = fullfile(pname,'standard.ini'); 
            selectIni=false;
        else
            selectIni= true;            
        end           
        %cd(pname); %VI030408A -- removed
        full=fullfile(pname, fname);
        defFile = full;
    end
        
    if selectIni %VI030408A -- prompt for .ini 
        [ini_f ini_p] = uigetfile('*.ini', 'Select .ini file (usually ''standard.ini''; cancel to use installation standard.ini file)',userpath); %VI030408A
        if isnumeric(ini_f)
            iniFileName = '';
        else
            iniFileName = fullfile(ini_p, ini_f);
        end
    end    
            
end % end TPMOD_1 12/31/03

%%%VI112309A%%%%%%%
% %VI020709A: Store version information 
% state.software.version = 3.6;
% state.software.minorRev = 0;
% state.software.beta = 1;
% state.software.betaNum = [];
%%%%%%%%%%%%%%%%%%%%

%Build GUIs 
state.internal.guinames={'roiCycleGUI','imageGUI','channelGUI','configurationGUI', 'alignGUI', 'motorGUI',... %VI092408A, VI011709A, VI012709A, VI021309A
        'mainControls','standardModeGUI','userFcnGUI','cycleControls','userPreferenceGUI','powerControl', 'powerTransitions', ...
        'powerBox','uncagingPulseImporter', 'powerBoxStepper', 'uncagingMapper', 'laserFunctionPanel'};

for guicounter=1:length(state.internal.guinames)
    gh=setfield(gh,state.internal.guinames{guicounter},eval(['guidata(' state.internal.guinames{guicounter} ')']));
end

set(gh.uncagingMapper.figure1, 'Visible', 'Off');
set(gh.laserFunctionPanel.figure1, 'Visible', 'Off');
set(gh.powerBox.figure1, 'Visible', 'Off'); %VI011709A

% Open the waitbar for loading
waitbar(.1,h, 'Reading Initialization File...');

%%%VI012909A%%%%%%%%
state.internal.executeButtonFlags = {};
%%%%%%%%%%%%%%%%%%%%

% start TPMOD_3 1/12/04
if isempty(iniFileName)
    openini('standard_model.ini'); %VI050608A
else
    openini(iniFileName);
end
% end TPMOD_3 1/12/04

setStatusString('Initializing...');
waitbar(.2,h, 'Configuring the MP285 Motor...');

MP285Config; % Configure Motor Driver

waitbar(.25,h, 'Creating Figures for Imaging');
makeImageFigures;	% config independent...relies only on the .ini file for maxNumberOfChannles.

setStatusString('Initializing...');
waitbar(.4,h, 'Setting Up Data Acquisition Devices...');
setupDAQDevices_Common;				% config independent
makeAndPutDataPark;					% config independent
setStatusString('Initializing...');

setStatusString('Initializing...');

%%%SECTION OF INI-FILE DEPENDENT ACTIONS%%%%%%%%%%%%%%%%%%%%%
if state.video.videoOn
    waitbar(.6,h, 'Starting Video Controls...');
    videoSetup;
end

%Activate Pockels Cell.
if state.init.eom.pockelsOn %VI011609A
    startEomGui;
    % start TPMOD_2 12/31/03
    %state.init.eom.beamMenu=state.init.eom.scanLaserBeam; %VI101708A
    state.init.eom.beamMenu=1; %VI101708A    
    updateGUIByGlobal('state.init.eom.beamMenu');
    powerControl('beamMenu_Callback',gh.powerControl.beamMenu);
     % end TPMOD_2 12/31/03
    powerControl('usePowerArray_Callback',gh.powerControl.usePowerArray);
    initializeUncagingPulseImporter;
    set(gh.uncagingMapper.figure1, 'Visible', 'Off');
end

%%%%VI103008: Prepare shutter state
state.shutter.open = logical(state.shutter.open);
state.shutter.epiShutterOpen = logical(state.shutter.epiShutterOpen);
state.shutter.closed = ~state.shutter.open;
state.shutter.epiShutterClosed = ~state.shutter.epiShutterOpen;

%%%VI121308: Removed %%%%%%%%%%%%
%%%VI121108: Adjust MotorGUI controls if there are adjusted calibrations
% if state.motor.motorOn
%     dimensions = {'X' 'Y' 'Z'};
%     for i=1:length(dimensions)
%         if state.motor.(['calibrationAdjust' dimensions{i}]) ~= 1
%             set(gh.motorGUI.([lower(dimensions{i}) 'Pos']), 'BackgroundColor', [1 1 .5],'TooltipString', 'WARNING: This display value does not match the value on the MP-285 controller! If this is not desired, adjust your INI file.');
%         end
%     end
% end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%END INI FILE DEPENDENT ACTIONS%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

parkLaserCloseShutter;				% config independent

if length(defFile)==0
    waitbar(.7,h, 'No user settings file chosen.');
    state.userSettingsPath = ''; %VI112208A
    calibrateBeams(true); %VI103108A: Calibrate beams according to default beam selection settings (beam 1 on, others off)
    applyModeCycleAndConfigSettings;
    updateAutoSaveCheckMark;	% BSMOD
    updateSaveDuringAcq; %VI091608A
    updateKeepAllSlicesCheckMark; % BSMOD
    updateAutoOverwriteCheckMark;
else
    waitbar(.7,h, 'Reading User Settings...');
    openusr(defFile,true); %VI103108A: Signal that this is on startup
end

if ~state.init.eom.pockelsOn %VI081308A, VI011609A
    set(gh.powerControl.figure1,'Visible','off');
    set(get(gh.powerControl.figure1,'Children'),'Enable','off');
    set(gh.uncagingMapper.figure1, 'Visible', 'Off');
    
    %VI111109A: Removed%%%
    %     children = get(gh.mainControls.Settings, 'Children');
    %     index = getPullDownMenuIndex(gh.mainControls.Settings, 'Power Controls');
    %     set(children(index), 'Enable', 'Off');
    %%%%%%%%%%%%%%%%%%%%%%%
else %VI110208A
    state.init.eom.started = 1; %VI110208A
end

if state.init.roiManagerOn==1
    startROIManager('off');
end

setStatusString('Initializing...');
waitbar(.8,h, 'Updating motor position...');

updateMotorPosition;

setStatusString('Initializing...');
state.internal.startupTime=clock;
state.internal.startupTimeString=clockToString(state.internal.startupTime);
updateHeaderString('state.internal.startupTimeString');
state.internal.imageWriter = getfield(imformats('tif'),'write'); %VI042108A 
state.internal.niDriver = whichNIDriver;

waitbar(.9,h, 'Initialization Done');

setStatusString('Ready to use');
state.initializing=0;
setStatusString('Ready to use');
waitbar(1,h, 'Ready To Use');

%Ugly...call several callbacks to ensure/initialize various states. These could be handled by updateGuiByGlobal as well.
%basicConfigurationGUI('pockelsClosedOnFlyback_Callback',gh.basic.pockelsClosedOnFlyback); %VI092408A, VI121208A
%setPockelsAcqParameters(); %VI121208A, VI010209A
roiCycleGUI('roiCyclePosition_Callback',gh.roiCycleGUI.roiCyclePosition);   %setup initial cycle....
updateGUIByGlobal('state.acq.channelMerge','Callback',1); %VI111708B
hideGUI('gh.channelGUI.figure1'); %VI111708B

close(h);

if state.init.releaseVersion
    %TO051704a
    configureForRelease;
end

return;

%-------------------------------------------------------------------------
%TO051704a
function configureForRelease
global state gh;

%Don't let any errors go.
try
    %Only disable stuff for "official" releases.
    if ~state.init.releaseVersion
        return;
    end
    
    %Only 1 beam is supported as of now.
    state.init.eom.numberOfBeams = 1;
    set(gh.powerControl.beamMenu, 'String', 'Beam 1');
    set(gh.powerTransitions.beamMenu, 'String', 'Beam 1');
    
    %No synchronizing to Physiology, anywhere.
    updateGUIByGlobal('state.init.eom.powerTransitions.syncToPhysiology', 'Value', 0);
    updateGUIByGlobal('state.init.eom.uncagingPulseImporter.syncToPhysiology', 'Value', 0);
    updateGUIByGlobal('state.init.eom.uncagingMapper.syncToPhysiology', 'Value', 0);
    updateGUIByGlobal('state.init.syncToPhysiology', 'Value', 0);

    %Get rid of all the menu items that go to unsupported/in-development/non-working stuff.
    menu = findobj(get(gh.mainControls.Settings, 'Children'), 'Label', 'Power Controls');
    submenu = get(menu, 'Children');

    %For some reason, non-handle objects have shown up here.
    f = findobj(submenu(find(ishandle(submenu) == 1)), 'Label', 'Powerbox Stepper');
    if ishandle(f) & f ~= 0
        delete(f);
    end

    f = findobj(submenu(find(ishandle(submenu) == 1)), 'Label', 'Uncaging Importer');
    if ishandle(f) & f ~= 0
        delete(f);
    end

    %Do the same for the powerControl menu.
    f = findobj(gh.powerControl.Settings, 'Label', 'Uncaging Pulse Importer');
    if ishandle(f) & f ~= 0
        delete(f);
    end

    f = findobj(gh.powerControl.Settings, 'Label', 'Power Box Stepper');
    if ishandle(f) & f ~= 0
        delete(f);
    end
    
    f = findobj(gh.powerControl.Settings, 'Label', 'Uncaging Mapper');
    if ishandle(f) & f ~= 0
        delete(f);
    end
    
    %Do the same for the powerTransitions menu.
    f = findobj(gh.powerTransitions.Options, 'Label', 'SyncToPhysiology');
    if ishandle(f) & f ~= 0
        delete(f);
    end
    
    %Hide preferences that are meaningless.
    set(gh.userPreferenceGUI.syncToPhysiology, 'Visible', 'Off');
    set(gh.userPreferenceGUI.syncToPhysiology, 'Enable', 'Off');
    
    set(gh.userPreferenceGUI.roiCalibrationFactor, 'Visible', 'Off');
    set(gh.userPreferenceGUI.roiCalibrationFactor, 'Enable', 'Off');
    set(gh.userPreferenceGUI.text2, 'Visible', 'Off');
    
    set(gh.userPreferenceGUI.roiPhaseCorrection, 'Visible', 'Off');
    set(gh.userPreferenceGUI.roiPhaseCorrection, 'Enable', 'Off');
    set(gh.userPreferenceGUI.text3, 'Visible', 'Off');
    
    feval(state.init.eom.laserFunctionPanelUpdateFunction);
    
    %Resize arrays
    state.init.eom.lut = state.init.eom.lut(1, :);
    state.init.eom.min = state.init.eom.min(1);
    state.init.eom.maxPower = state.init.eom.maxPower(1);
    state.init.eom.boxPowerArray = state.init.eom.boxPowerArray(1);
    state.init.eom.startFrameArray = state.init.eom.startFrameArray(1);
    state.init.eom.endFrameArray = state.init.eom.endFrameArray(1);
    name = state.init.eom.pockelsCellNames{1};
    state.init.eom.pockelsCellNames = {};
    state.init.eom.pockelsCellNames{1} = name;
    state.init.eom.maxLimit = state.init.eom.maxLimit(1);
    state.init.eom.changed = 1;
    state.init.eom.maxPhotodiodeVoltage = state.init.eom.maxPhotodiodeVoltage(1);
catch
    %Do nothing.
end

return;
