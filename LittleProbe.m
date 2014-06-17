function varargout = LittleProbe(varargin)
% LITTLEPROBE M-file for LittleProbe.fig
%      LITTLEPROBE, by itself, creates a new LITTLEPROBE or raises the existing
%      singleton*.
%
%      H = LITTLEPROBE returns the handle to a new LITTLEPROBE or the handle to
%      the existing singleton*.
%
%      LITTLEPROBE('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in LITTLEPROBE.M with the given input arguments.
%
%      LITTLEPROBE('Property','Value',...) creates a new LITTLEPROBE or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before LittleProbe_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to LittleProbe_OpeningFcn via varargin.
%
%      Developed by Tzu-Ming Wang, Kramer Lab, UC Berkeley, 2010.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help LittleProbe

% Last Modified by GUIDE v2.5 10-Feb-2012 15:05:30

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @LittleProbe_OpeningFcn, ...
                   'gui_OutputFcn',  @LittleProbe_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before LittleProbe is made visible.
function LittleProbe_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to LittleProbe (see VARARGIN)

% Choose default command line output for LittleProbe
% try
%     handles.gh = evalin('base','gh');
% catch
%     handles.gh = [];
% end
%assignin('base','gh2',handles.scanimage);
global LP_callback LP_state state
%functions and objects used in auto acquisition
LP_callback(1).name = 'ShutterOff';
LP_callback(1).hobj = handles.ShutterOff;
LP_callback(1).fh = @ShutterOff_Callback; %function handle
LP_callback(2).name = 'P5';
LP_callback(2).hobj = handles.Labelbutton5;
LP_callback(2).fh = @Labelbutton_Callback;
LP_callback(3).name = 'T6';
LP_callback(3).hobj = handles.Labelbutton6;
LP_callback(3).fh = @Labelbutton_Callback;
LP_callback(4).name = 'SwapTTL';
LP_callback(4).hobj = handles.SwapTTL;
LP_callback(4).fh = @SwapTTL_Callback;

LP_state.first = 1; %if it is the first frame in the loop
LP_state.acquiring = 0; %if the Grab or Loop button is pressed
LP_state.pauseacq = 0; %for label button 4 to pause the loop
LP_state.forcetrigger = 0; %for label button 5 to force triggering acquisition before the next trigger event occurs in the loop
LP_state.burst = 0; %not used anymore, but still keep it in LP_acquisitionStartedFcn and LP_mainLoop
LP_state.shutteroff = 0; %if 1, bypass shutter open in LP_openShutter
LP_state.autoacq = 0; %will be used in LP_resumeLoop for auto acquisition
LP_state.protocol = ''; % name of the protocol used by auto acquisition
%LP_state.tempStackPath = 'C:\Program Files\MATLAB\';
LP_state.tempStackPath = pwd;
LP_state.tempStackName = 'LittleProbeStacks.tif';
LP_state.currentpath = pwd; %replace handles.currentpath 1/13/2011
LP_state.starttime = []; %recorded in LP_acquisitionStartedFcn using tic;

LP_state.time = []; %determined in LP_acquisitionStartedFcn using toc;
LP_state.label = {}; %{actual time,associated frame time,label}
LP_state.note = {};
LP_state.xyczt = [];
LP_state.Ft = []; %average frame intensity along Z and t axese (c-z-t matrix). it's done in LP_writeDat
LP_state.Ftclip = {}; %clip index for LP_Ft. String format {low high}

LP_state.ai = []; %for validating/updating the functions in @GrabStatus
LP_state.dio = []; %2 lines, one for shutter the other for LED
LP_state.TTLblue.color = [0.2,0.6,1];
if strcmpi(get(handles.menu_TTLblue1,'Checked'),'On')
    LP_state.TTLblue.value = true; %TTL high turn on LED
else
    LP_state.TTLblue.value = false; %TTL low turn on LED
end
LP_state.TTL5 = LP_state.TTLblue.value;
LP_state.TTL6 = ~LP_state.TTL5;
LP_state.TTLcurrent = LP_state.TTL6;
set(handles.edit_label5,'BackgroundColor',LP_state.TTLblue.color);
LP_state.PMTOpenValue = true; %value to open PMT shutter
LP_state.PMTshouldbe = ~LP_state.PMTOpenValue;

LP_state.powerEq = [];

LP_state.SIM.active = false; %if using SIM or not
LP_state.SIM.gh = []; %graphic handle to the GUI, will be assigned/removed from LP_SIM GUI directly
LP_state.SIM.Callback = []; %function handle to the GUI, will be assigned/removed from LP_SIM GUI directly
LP_state.SIM.type = []; %type of SIM
LP_state.SIM.Nphase = []; %number of phases
LP_state.SIM.Ncycle = []; %spatial frequency
LP_state.SIM.count = 1; %step number
LP_state.SIM.aodata = []; %M-by-frame
LP_state.SIM.loadedpattern = []; %user-defined gray scale pattern (LP_state.SIM.type = 4)
LP_state.SIM.comp2p = []; %2-photon compensation or not
% try
%     LP_state.SIM.eomSR = 8*state.acq.outputRate;
% catch
%     disp(lasterr);
%     disp('LP_state.SIM.eomSR was manually defined in the LittleProbe');
%     LP_state.SIM.eomSR = 800000; %in Hz, must be the integral multiple of state.acq.outputRate
% end


%set(state.internal.roiimage,'CData',uint16(zeros(256,256)));
%LP_state.acqData = zeros(512,512,400);
%LP_state.acqData = []

handles.output = hObject;
%handles.ObjT = timer; %for updating motor position
handles.ObjT2 = timer; %for checking grabing status
% set(handles.ObjT,'ExecutionMode','fixedRate','BusyMode','drop','Period',1);
% set(handles.ObjT,'TimerFcn',{@UpdatePosition,gcf});
set(handles.ObjT2,'ExecutionMode','fixedRate','BusyMode','drop','Period',0.5);
set(handles.ObjT2,'TimerFcn',{@GrabStatus,gcf});
handles.group_motor = [handles.Lensup,handles.Lensdown];
handles.group_active = [handles.Labelbutton1,handles.Labelbutton2,handles.Labelbutton3,...
    handles.Labelbutton4]; %group that is enabled when acquiring
handles.group_inactive = [handles.menu_file,handles.menu_show,handles.show_first1,...
    handles.show_previous2,handles.show_next3,handles.show_last4,...
    handles.menu_AutoAcq,handles.menu_setting,handles.Lensup,...
    handles.Lensdown]; %group that is disabled when acquiring
handles.mountindex = [];
handles.hFt = []; %figure handle of the LP_Ft
handles.hDev3 = []; %figure handles of the LP_Dev3 flash control
handles.hColormap = []; %figure handles of the LP_Colormap
handles.hShowItems = []; %handls of menu items in Show menu
handles.hAutoAcq = []; %handls of menu items in AutoAcq menu

%handles.currentpath = pwd; %independent from ScanImage save path bcz it might not be loaded
%use LP_state.currentpath so it can be synchronized between LittleProbe and
%LP_Navi etc. 1/13/2011
handles.loadedvar = []; %notes of files loaded by menu_load_Callback
handles.loadindex = [0 0]; %[total,current] index to current file to be displayed
handles.saveasked = 1; %has been asked to save or not
if exist('LP_ijpath.mat','file') == 0 %ImageJ path
    handles.ijpath = 'C:\DirNotSpecified';
else
    handles.ijpath = load('LP_ijpath.mat'); %load ImageJ path
    handles.ijpath = handles.ijpath.ijpath; %convert from struc to string
end

%handles.shell = 'LittleProbe';
handles.shell = mfilename;
%handles.powerEq = '261.1*cos(-2.427*X+3.144)+271.9';
%handles.powerEq = []; %use LP_state.powerEq...
set(hObject,'Name',handles.shell);
set(hObject,'Position',[139.6 2.7692 115.4 14.5385]);
set(handles.text_xyczt,'String','x: y: c: z: t:');
set(handles.group_active,'Enable','off');
%evalin('base','global LP_state');

% Update handles structure
guidata(hObject, handles);
try %try creating dio for LED control before pressing Activation button
%     scanimage;
%     addpath('C:\Documents and Settings\All Users\Documents\Data\TMW\LittleProbe','-begin');
    if isempty(LP_state.dio)
        LP_state.dio = digitalio('nidaq',state.shutter.shutterBoardIndex); %usually Dev2
        %assignin('base','dio',LP_state.dio);
        addline(LP_state.dio,state.shutter.shutterLineIndex,'out','Shutter_Laser'); %usually P0.0
        addline(LP_state.dio,state.shutter.shutterLineIndex+1,'out','Shutter_LED'); %usually P0.1
        addline(LP_state.dio,state.shutter.shutterLineIndex+2,'out','Shutter_PMT'); %usually P0.2
        menu_powerLUT_Callback(handles.menu_powerLUT, [], handles); %propmt to load power LUT
    end
catch ME
    assignin('base','ME',ME);
    disp('ScanImage is probably not loaded.');
    ME
end
%handles.mountindex = 1; %somehow it won't be saved if called from the OpeningFcn...
guidata(hObject, handles);
pause(0.1);
context_mount_Callback(handles.context_mount1, [], guidata(handles.context_mount1)); %set default to Ch1
%try activating the LittleProbe
set(handles.Activation,'Value',1);
Activation_Callback(handles.Activation, [], guidata(handles.Activation));
%evalin('base','global LP_first');
%disp('entered');
% UIWAIT makes LittleProbe wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = LittleProbe_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in Activation.
function Activation_Callback(hObject, eventdata, handles)
% hObject    handle to Activation (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global gh state LP_state;
if get(hObject,'Value') %Activate
    if isempty(daqfind)
        beep;
        disp(lasterr);
        disp('ScanImage is probably not loaded!!');
        set(hObject,'Value',0);
        return;
    end
    
    if isempty(LP_state.dio)
        LP_state.dio = digitalio('nidaq',state.shutter.shutterBoardIndex); %usually Dev2
        %assignin('base','dio',LP_state.dio);
        addline(LP_state.dio,state.shutter.shutterLineIndex,'out','Shutter_Laser'); %usually P0.0
        addline(LP_state.dio,state.shutter.shutterLineIndex+1,'out','Shutter_LED'); %usually P0.1
        addline(LP_state.dio,state.shutter.shutterLineIndex+2,'out','Shutter_PMT'); %usually P0.2
    end
    guidata(hObject,handles);
    LP_state.ai = state.init.ai;
    set(gh.mainControls.focusButton,'Callback',{'LP_executeFocusCallback'});
    set(gh.mainControls.grabOneButton,'Callback',{'LP_executeGrabOneCallback'});
    set(gh.mainControls.startLoopButton,'Callback',{'LP_executeStartLoopCallback'});
    set(gh.powerBox.etBoxPowerOff,'Callback',{'LP_etBoxPowerOff_Callback'}); %to correct the bug
    set(gh.powerBox.cbLockBoxOffToMin,'Callback',{'LP_cbLockBoxOffToMin_Callback'});
    set(state.init.ai,'SamplesAcquiredFcn',{'LP_makeFrameByStripes'});
    set(state.init.ai,'TriggerFcn',{'LP_acquisitionStartedFcn'});
    set(hObject,'String','Active','ForegroundColor','green');
    if LP_state.acquiring %not sure why it's here... 10/13/2010
        set(handles.group_inactive,'Enable','Off');
        set(handles.group_active,'Enable','On');
        %set(handles.group_show,'Enable','Off');
    end
    if isempty(eventdata) %not empty if called from @GrabStatus
        putvalue(state.init.triggerLine,1); %prepare for triggering
        putvalue(LP_state.dio,[state.shutter.closed  ~LP_state.TTLblue.value ~LP_state.PMTOpenValue]); %update LED status
    end
    start(handles.ObjT2);
else %Inactivate
    try
        set(state.init.ai,'SamplesAcquiredFcn',{'makeFrameByStripes'});
        set(state.init.ai,'TriggerFcn',{'acquisitionStartedFcn'});
        set(gh.mainControls.focusButton,'Callback',@(hObject,eventdata)mainControls...
            ('focusButton_Callback',hObject,eventdata,guidata(hObject)));
        set(gh.mainControls.grabOneButton,'Callback',@(hObject,eventdata)mainControls...
            ('grabOneButton_Callback',hObject,eventdata,guidata(hObject)));
        set(gh.mainControls.startLoopButton,'Callback',@(hObject,eventdata)mainControls...
            ('startLoopButton_Callback',hObject,eventdata,guidata(hObject)));
        set(gh.powerBox.etBoxPowerOff,'Callback',@(hObject,eventdata)powerBox...
            ('etBoxPowerOff_Callback',hObject,eventdata,guidata(hObject)));
        set(gh.powerBox.cbLockBoxOffToMin,'Callback',@(hObject,eventdata)powerBox...
            ('cbLockBoxOffToMin_Callback',hObject,eventdata,guidata(hObject)));
    catch ME
        beep;
        disp('The target AI is gone!!');
        assignin('base','ME',ME);
        ME
    end
    set(hObject,'String','Inactive','ForegroundColor','red');
    stop(handles.ObjT2);
    set(handles.group_inactive,'Enable','On');
    set(handles.group_active,'Enable','Off');
    %set(handles.group_show,'Enable','On');
end


% Hint: get(hObject,'Value') returns toggle state of Activation

% --- Executes on button press in ShutterOff.
function ShutterOff_Callback(hObject, eventdata, handles)
% hObject    handle to ShutterOff (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global LP_state
if get(hObject,'Value') %make offline
%     if strcmpi(get(handles.ObjT,'Running'),'off')
%         start(handles.ObjT);
%     end
%     set(hObject,'BackgroundColor',[1,0.6,0]);
    LP_state.shutteroff = 1;
    set(hObject,'BackgroundColor','red');
    disp('Laser shutter is offline now.'); 
else
%     if strcmpi(get(handles.ObjT,'Running'),'on')
%         stop(handles.ObjT);
%     end
%     set(hObject,'BackgroundColor',[0.6,0.6,0.6]);
    LP_state.shutteroff = 0;
    set(hObject,'BackgroundColor',[0,0.8,0.2]);
    disp('Laser shutter is online again.');
end
if LP_state.acquiring %automatically put note when acquiring
    if isempty(LP_state.time)
        if LP_state.shutteroff
            LP_state.label = cat(1,LP_state.label,{toc(LP_state.starttime),0,...
                'Laser out'});
        else
            LP_state.label = cat(1,LP_state.label,{toc(LP_state.starttime),0,...
                'Laser in'});
        end
    else
        if LP_state.shutteroff
            LP_state.label = cat(1,LP_state.label,{toc(LP_state.starttime),LP_state.time(end),...
                'Laser out'});
        else
            LP_state.label = cat(1,LP_state.label,{toc(LP_state.starttime),LP_state.time(end),...
                'Laser in'});
        end
    end
end
% Hint: get(hObject,'Value') returns toggle state of ShutterOff

% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global LP_state;
%stop(handles.ObjT);
% stop(handles.ObjT2);
% try
%     set(state.init.ai,'SamplesAcquiredFcn',{'makeFrameByStripes'});
%     set(state.init.ai,'TriggerFcn',{'acquisitionStartedFcn'});
%     set(gh.mainControls.startLoopButton,'Callback',@(hObject,eventdata)mainControls...
%         ('startLoopButton_Callback',hObject,eventdata,guidata(hObject)));
% catch
%     %do nothing
% end
%reset the related DAQ functions to its default
set(handles.Activation,'Value',0);
Activation_Callback(handles.Activation, [], handles);
if ~isempty(LP_state.dio)
    delete(LP_state.dio);
end
try
    %in case the LP_Ft is launched
    close(handles.hFt);
    %Use close() instead of delete(). In this case the CloseRequestFcn of
    %LP_Ft will handle the request, which includes obj cleanup
catch
    %do nothing
end
try
    close(handles.hDev3);
catch
    %do nothing
end
try
    close(handles.hColormap);
catch
    %do nothing
end
if ~isempty(LP_state.SIM.gh)
    close(LP_state.SIM.gh);
end
%delete(handles.ObjT);
delete(handles.ObjT2);
%delete(timerfind);
%get(hObject,'Position')

% Hint: delete(hObject) closes the figure
delete(hObject);

% --- Executes on button press in Lensup.
function Lensup_Callback(hObject, eventdata, handles)
% hObject    handle to Lensup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global gh;
% stopped = 0;
% if get(handles.ShutterOff,'Value')
%     stop(handles.ObjT);
%     stopped = 1;
% end
%turnOffMotorButtons;
try
    if strcmpi(get(gh.motorGUI.readPosition,'Enable'),'on')
        set(handles.group_motor,'Enable','off');
        currentPos = MP285GetPos;
        if ~isempty(currentPos)
            newZ = currentPos(1,3)-abs(str2double(get(handles.Zstep,'String')));
            setMotorPosition([currentPos(1,1),currentPos(1,2),newZ]);
        end
    end
catch ME
    beep;
    disp('Lensup_Callback action cancelled, check motor GUI - by LittleProbe');
    assignin('base','ME',ME);
    ME
end
set(handles.group_motor,'Enable','on');
% if get(handles.ShutterOff,'Value') && stopped
%     start(handles.ObjT);
% end
%turnOnMotorButtons;

% --- Executes on button press in Lensdown.
function Lensdown_Callback(hObject, eventdata, handles)
% hObject    handle to Lensdown (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global gh;
% stopped = 0;
% if get(handles.ShutterOff,'Value')
%     stop(handles.ObjT);
%     stopped = 1;
% end
%turnOffMotorButtons;
try
    if strcmpi(get(gh.motorGUI.readPosition,'Enable'),'on')
        set(handles.group_motor,'Enable','off');
        currentPos = MP285GetPos;
        if ~isempty(currentPos)
            newZ = currentPos(1,3)+abs(str2double(get(handles.Zstep,'String')));
            setMotorPosition([currentPos(1,1),currentPos(1,2),newZ]);
        end
    end
catch ME
    beep;
    disp('Lensdown_Callback action cancelled, check motor GUI - by LittleProbe');
    assignin('base','ME',ME);
    ME
end
set(handles.group_motor,'Enable','on');
% if get(handles.ShutterOff,'Value') && stopped
%     start(handles.ObjT);
% end
%turnOnMotorButtons;

%--------------------------------------------------------------------------
% function UpdatePosition(hObject, eventdata, FH)
% global gh state;
% handles = guidata(FH);
% try
%     if strcmpi(get(gh.motorGUI.readPosition,'Enable'),'on')
%         %turnOffMotorButtons;
%         updateMotorPosition;
%         set(handles.currentZ,'String',num2str(state.motor.relZPosition));
%         %turnOnMotorButtons;
%     end
% catch
%     beep;
%     disp('TimerFcn action cancelled, check motor GUI - by LittleProbe');
% end

function GrabStatus(hObject, eventdata, FH)
global gh state LP_state;
handles = guidata(FH);
%get(handles.ai,'SamplesAcquiredFcn'); %to probe if the ai channel cfg has been changed or not
%if ~isvalid(LP_state.ai) %sometimes this doesn't work... i.e. obj is not updated...
if LP_state.ai ~= state.init.ai
    stop(handles.ObjT2);
    %pause(1); %in case ScanImage is busy creating the object
    Activation_Callback(handles.Activation,'GrabStatus',handles);
    disp('AI object has been updated in LittleProbe');
    beep; %so that the user knows that it's updated without checking the command window
end
LoopButton = strcmpi(get(gh.mainControls.startLoopButton,'Visible'),'On');
GrabButton = strcmpi(get(gh.mainControls.grabOneButton,'Visible'),'On');
if LP_state.acquiring && LoopButton && GrabButton %just stopped acqusition
    LP_state.first = 1;
    LP_state.acquiring = 0;
    LP_state.pauseacq = 0;
    LP_state.forcetrigger = 0;
    LP_state.PMTshouldbe = ~LP_state.PMTOpenValue;
    set(handles.group_inactive,'Enable','On');
    set(handles.group_active,'Enable','Off');
    %set(handles.group_show,'Enable','On');
    putvalue(LP_state.dio,[state.shutter.closed LP_state.TTLcurrent LP_state.PMTshouldbe]); %close PMT shutter
elseif ~LP_state.acquiring && (~LoopButton || ~GrabButton) % just started acquisition
    LP_state.acquiring = 1;
    LP_state.time = []; %determined in LP_acquisitionStartedFcn using toc;
    LP_state.label = {}; %{actual time,associated frame time,label}
    LP_state.xyczt = [state.acq.pixelsPerLine,state.acq.linesPerFrame,length(state.init.ai.Channel),state.acq.numberOfZSlices,0];
    LP_state.PMTshouldbe = LP_state.PMTOpenValue; %so PMT shutter won't be closed between stacks
    %LP_state.Ft = []; %average frame intensity along Z and t axese (c-z-t matrix), determined in LP_writeData
%     if strcmpi(get(handles.ObjT,'Running'),'on') %disable auto position update
%         stop(handles.ObjT);
%     end
    handles.saveasked = 0;
    guidata(FH,handles);
    set(handles.figure1,'Name',handles.shell);
%     set(handles.ShutterOff,'BackgroundColor',[0.6,0.6,0.6]);
%     set(handles.ShutterOff,'Value',0);
    set(handles.group_inactive,'Enable','Off');
    set(handles.group_active,'Enable','On');
    %set(handles.group_show,'Enable','Off');
    set(handles.figure1,'Name',handles.shell);
    %assignin('base','LP_state',LP_state);
end
%disp('triggered');

% --- Executes on button press in Labelbutton1.
function Labelbutton_Callback(hObject, eventdata, handles)
% hObject    handle to Labelbutton1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global LP_state state;
index = char(get(hObject,'Tag'));
try
    switch index(end)
        case '5' %output TTL and pause acquisition if the context menu option is checked
%             if state.shutter.shutterOpen %if still acquiring
%                 beep;
%                 disp('still acquiring image!!');
%                 return;
%             end
            if LP_state.acquiring && strcmpi(get(handles.context_pause,'Checked'),'on') %pause acquisition only when it's checked
                LP_state.pauseacq = 1;
            end
            %putvalue(LP_state.dio,[state.shutter.closed false]);
            %pause(0.035); %make sure the PMT shutter is closed first. close time for DSS25 shutter is ~35ms
            %if xor(LP_state.TTLcurrent,LP_state.TTL5) %if the values are different from each other
                LP_state.TTLcurrent = LP_state.TTL5;
                if LP_state.TTLcurrent == LP_state.TTLblue.value %going to turn on LED
                    LP_state.PMTshouldbe = ~LP_state.PMTOpenValue; %close PMT shutter
                else %going to turn off LED
                    LP_state.PMTshouldbe = LP_state.PMTOpenValue; %open PMT shutter
                end
                if LP_state.acquiring
                    putvalue(LP_state.dio,[state.shutter.closed LP_state.TTLcurrent LP_state.PMTshouldbe]);
                else
                    putvalue(LP_state.dio,[state.shutter.closed LP_state.TTLcurrent ~LP_state.PMTOpenValue]); %keep PMT closed if not acquiring
                end
                %state.shutter.close is 1, not 0!!
                %guidata(hObject,handles);
            %end
        case '6' %output TTL and trigger acquisition
            if state.shutter.shutterOpen %if still acquiring
                beep;
                disp('still acquiring image->cannot trigger->action cancelled');
                return;
            end
            if LP_state.acquiring
                LP_state.pauseacq = 0;
                LP_state.forcetrigger = 1;
            end
%             if LP_state.forcetrigger
%                 %turn off LED in LP_openShutter to minimize the delay
%                 LP_state.TTLcurrent = LP_state.TTL6;
%             else
                %if xor(LP_state.TTLcurrent,LP_state.TTL6)
                    %disp('entered');
                    LP_state.TTLcurrent = LP_state.TTL6;
                    if LP_state.TTLcurrent == LP_state.TTLblue.value %going to turn on LED
                        LP_state.PMTshouldbe = ~LP_state.PMTOpenValue; %close PMT shutter
                    else %going to turn off LED
                        LP_state.PMTshouldbe = LP_state.PMTOpenValue; %open PMT shutter
                    end
                    if LP_state.acquiring
                        putvalue(LP_state.dio,[state.shutter.closed LP_state.TTLcurrent LP_state.PMTshouldbe]);
                    else
                        putvalue(LP_state.dio,[state.shutter.closed LP_state.TTLcurrent ~LP_state.PMTOpenValue]); %keep PMT closed if not acquiring
                    end
                    %guidata(hObject,handles);
                %end
%             end
    end
catch ME
    beep;
    disp('ScanImage not loaded?');
    assignin('base','ME',ME);
    ME
end
% if strcmpi(index(end),'5') %force triggering acquisition
%     LP_state.forcetrigger = 1;
% end
try
    %use findall instead of findobj so that the label can be found during
    %auto acquisition
    if isempty(LP_state.time)
%         LP_state.label = cat(1,LP_state.label,{toc(LP_state.starttime),0,...
%             get(findobj('Tag',['edit_label',index(end)]),'String')});
        LP_state.label = cat(1,LP_state.label,{toc(LP_state.starttime),0,...
            get(findall(0,'Tag',['edit_label',index(end)]),'String')});
    else
%         LP_state.label = cat(1,LP_state.label,{toc(LP_state.starttime),LP_state.time(end),...
%             get(findobj('Tag',['edit_label',index(end)]),'String')});
        LP_state.label = cat(1,LP_state.label,{toc(LP_state.starttime),LP_state.time(end),...
            get(findall(0,'Tag',['edit_label',index(end)]),'String')});
    end
catch
    %this only happens when P5 or T6 is pressed and the LittleProbe is
    %still Inactive
end
%disp('entered');

%--------------------------------------------------------------------------


% --- Executes during object creation, after setting all properties.
function edit_label_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_label1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function edit_note_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_note (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function edit_burst_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_burst (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



% --- Executes on button press in ROI_mount.
function ROI_mount_Callback(hObject, eventdata, handles)
% hObject    handle to ROI_mount (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%state.internal.roiimage
%state.internal.GraphFigure(i)
global state;
figure(state.internal.roifigure); %bring the figure up in case it is closed
% CData = get(state.internal.imagehandle(1),'CData');
% assignin('base','CData',CData);
% assignin('base','CData_uint8',uint8(CData));
if handles.mountindex ~= 0
    set(state.internal.roiimage,'CData',get(state.internal.imagehandle(handles.mountindex),'CData'));
    set(state.internal.roiaxis,'CLim',get(state.internal.maxaxis(handles.mountindex),'CLim'));
else
    set(state.internal.roiimage,'CData',zeros(256,256));
end

% Hint: get(hObject,'Value') returns toggle state of ROI_mount


% --------------------------------------------------------------------
function context_mount_Callback(hObject, eventdata, handles)
% hObject    handle to context_mount1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
index = char(get(hObject,'Tag'));
handles.mountindex = str2num(index(end));
guidata(hObject,handles);
set(get(handles.context_mount,'Children'),'Checked','off');
switch index(end)
    case '0'
        set(handles.context_mount0,'Checked','on');
        %set(handles.context_mount1,'Checked','off');
        %set(handles.context_mount2,'Checked','off');
    case '1'
        %set(handles.context_mount0,'Checked','off');
        set(handles.context_mount1,'Checked','on');
        %set(handles.context_mount2,'Checked','off');
    case '2'
        %set(handles.context_mount0,'Checked','off');
        %set(handles.context_mount1,'Checked','off');
        set(handles.context_mount2,'Checked','on');
end
%assignin('base','index',handles.mountindex);

% ----------------------------------------------------------------------
% function DAQrefresh(FH)
% handles = guidata(FH);
% handles.daq = daqfind; %get ScanImage DAQ objects
% for n=1:length(handles.daq)
%     try
%         temp = get(handles.daq(n),'SamplesAcquiredFcn');
%         if isa(temp,'function_handle')
%             temp = func2str(temp);
%         end
%         if strcmpi(temp,'makeFrameByStripes')
%             handles.aiindex = n;
%             %disp('entered');
%             break;
%         end
%     catch
%         %not an AI object
%         if n == length(handles.daq)
%             beep;
%             disp('Please load ScanImage first!!');
%             set(handles.Activation,'Value',0,'String','Inactive','ForegroundColor','red');
%             handles.ai = [];
%             guidata(FH,handles);
%             return;
%         end
%     end
% end
% handles.ai = handles.daq(handles.aiindex); %target AI for Grab,Loop
% guidata(FH,handles);


% --- Executes on button press in show_first1.
function show_Callback(hObject, eventdata, handles)
% hObject    handle to show_first1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global LP_state;
index = char(get(hObject,'Tag'));
if handles.loadindex(1,1) < 1
    return
elseif ~handles.saveasked %if the acquired data is not saved yet
    menu_save_Callback(handles.menu_save, eventdata, handles);
    %return %this return is essential... or somehow the handles.saveasked won't be updated...
    %the above description is not always the case...
    %disp('entered');
end
switch index(end)
    case '1' %first
        handles.loadindex(1,2) = 1;
    case '2' %previous
        handles.loadindex(1,2) = handles.loadindex(1,2)-1;
    case '3' %next
        handles.loadindex(1,2) = handles.loadindex(1,2)+1;
    case '4' %last
        handles.loadindex(1,2) = handles.loadindex(1,1);
end
if handles.loadindex(1,2) < 1
    %handles.loadindex(1,2) = handles.loadindex(1,1); %wrap to the last one
    handles.loadindex(1,2) = 1;
elseif handles.loadindex(1,2) > handles.loadindex(1,1)
    %handles.loadindex(1,2) = 1; %wrap to the first one
    handles.loadindex(1,2) = handles.loadindex(1,1);
end
guidata(hObject,handles);
set(handles.figure1,'Name',[handles.shell,'  ',handles.loadedvar(handles.loadindex(1,2)).filename]);
set(handles.edit_note,'String',handles.loadedvar(handles.loadindex(1,2)).var.note);
set(handles.text_xyczt,'String',[num2str(handles.loadindex(1,2)),'/',num2str(handles.loadindex(1,1)),...
    ' x:',num2str(handles.loadedvar(handles.loadindex(1,2)).var.xyczt(1)),...
    ' y:',num2str(handles.loadedvar(handles.loadindex(1,2)).var.xyczt(2)),...
    ' c:',num2str(handles.loadedvar(handles.loadindex(1,2)).var.xyczt(3)),...
    ' z:',num2str(handles.loadedvar(handles.loadindex(1,2)).var.xyczt(4)),...
    ' t:',num2str(handles.loadedvar(handles.loadindex(1,2)).var.xyczt(5))]);
%This is for LP_Ft to plot the time series fig
LP_state.time = handles.loadedvar(handles.loadindex(1,2)).var.time;
LP_state.Ft = handles.loadedvar(handles.loadindex(1,2)).var.Ft;
LP_state.label = handles.loadedvar(handles.loadindex(1,2)).var.label;
LP_state.xyczt = handles.loadedvar(handles.loadindex(1,2)).var.xyczt;


% --------------------------------------------------------------------
function menu_show_Callback(hObject, eventdata, handles)
% hObject    handle to menu_show (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
delete(handles.hShowItems);
if handles.loadindex(1,1) < 1 %no loaded data
    handles.hShowItems = uimenu(handles.menu_show,'Label','(Empty)');
else
    handles.hShowItems = [];
    for n = 1:handles.loadindex(1,1)
        handles.hShowItems(end+1) = uimenu(handles.menu_show,'Label',handles.loadedvar(n).filename,...
            'Callback',{@menu_show_jumpto,handles.figure1},'Checked','off');
    end
    handles.hShowItems(end+1) = uimenu(handles.menu_show,'Label','Open in ImageJ',...
        'Callback',{@menu_show_imagej,handles.figure1},'Checked','off',...
        'Separator','on','Accelerator','J');
    handles.hShowItems(end+1) = uimenu(handles.menu_show,'Label','Assign var to Workspace',...
        'Callback',{@menu_show_assignin,handles.figure1},'Checked','off',...
        'Separator','off');
    set(handles.hShowItems(handles.loadindex(1,2)),'Checked','on');
end
guidata(hObject,handles);
%assignin('base','hShowItems',handles.hShowItems);

% --------------------------------------------------------------------
function menu_show_jumpto(hObject, eventdata, FH)
handles = guidata(FH);
%assignin('base','hShowItems',handles.hShowItems);
%assignin('base','hObject',hObject);
index = find(handles.hShowItems == hObject);
%index = find(get(handles.menu_show,'Children') == hObject); %menu order is different from loaded var
if index == 1
    %use the show_first1 button to locate the data
    handles.loadindex(1,2) = 1;
    guidata(FH,handles);
    show_Callback(handles.show_first1,[],handles);
else
    %use the show_next3 button to locate the data
    handles.loadindex(1,2) = index-1;
    guidata(FH,handles);
    show_Callback(handles.show_next3,[],handles);
end

% --------------------------------------------------------------------
function menu_show_imagej(hObject, eventdata, FH)
handles = guidata(FH);
%disp('entered');
global LP_state
if exist(handles.ijpath,'file') == 0
    %disp('path does not exist');
    %path = uigetdir('C:\','Specify ImageJ path');
    [file, path] = uigetfile('*.mat','Specify ImageJ EXE file',fullfile(pwd,'*.exe'),'MultiSelect','off');
    % If 'Cancel' was selected then return
    if isequal([file,path],[0,0])
        return;
    else
        %handles.ijpath = path;
        handles.ijpath = fullfile(path,file);
        guidata(FH,handles);
        path = uigetdir(pwd,'Specify where LittleProbe is:');
        save(fullfile(path,'LP_ijpath.mat'),'-struct','handles','ijpath');
    end
end
[pathstr, name, ext, versn] = fileparts(handles.loadedvar(handles.loadindex(1,2)).filename);
% system(['"',fullfile(handles.ijpath,'ImageJ.exe'),'" "',fullfile(LP_state.currentpath,...
%     [name,'.tif']),'"']);
system(['"',handles.ijpath,'" "',fullfile(LP_state.currentpath,[name,'.tif']),'"']);

% --------------------------------------------------------------------
function menu_show_assignin(hObject, eventdata, FH)
handles = guidata(FH);
assignin('base','time',handles.loadedvar(handles.loadindex(1,2)).var.time);
assignin('base','label',handles.loadedvar(handles.loadindex(1,2)).var.label);
assignin('base','note',handles.loadedvar(handles.loadindex(1,2)).var.note);
assignin('base','xyczt',handles.loadedvar(handles.loadindex(1,2)).var.xyczt);
assignin('base','Ft',handles.loadedvar(handles.loadindex(1,2)).var.Ft);
commandwindow;

% --------------------------------------------------------------------
function menu_save_Callback(hObject, eventdata, handles)
% hObject    handle to menu_save (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%disp('entered');
global state LP_state hNavi;
if strcmpi(handles.shell,get(handles.figure1,'Name')) %save images and notes
    try
        %if isempty(state.files.savePath)
            %[filename, pathname] = uiputfile(fullfile(LP_state.tempStackPath,'*.tif'),'Save');
            [filename, pathname] = uiputfile(fullfile(LP_state.currentpath,'*.tif'),'Save');
        %else
            %[filename, pathname] = uiputfile(fullfile(state.files.savePath,'*.tif'),'Save');
        %end
        if isequal([filename,pathname],[0,0])
            handles.saveasked = 1;
            guidata(hObject,handles);
            %disp('entered 600');
            return;
        end
    catch %should not happen 5/26/10
        %ScanImage is probably not loaded, and the user probably wants to save
        %the modified notes
        %disp('entered line ~606');
        %     handles.saveasked = 1;
        %     guidata(hObject,handles);
        %     show_Callback(handles.show_first1, eventdata, handles); %update file name and xyczt
        %     return;
    end
    try %save images and notes
        %disp('entered');
        %move and rename instead of saving again
        LP_state.note = deblank(cellstr(get(handles.edit_note,'String')));
        %LP_state.note = get(handles.edit_note,'String');
        LP_state.xyczt(1,5) = length(LP_state.time); %get number of time points
        %movefile(fullfile(LP_state.tempStackPath,LP_state.tempStackName),fullfile(pathname,filename));
        %pause(2);
        while strcmpi(get(handles.figure1,'Name'),handles.shell)
            set(handles.figure1,'Name',[handles.shell,'  ',filename]);
            [pathstr, name, ext, versn] = fileparts(filename);
            save(fullfile(pathname,[name,'.mat']),'-struct','LP_state','time','label','note','xyczt','Ft');
            handles.loadedvar(end+1).var.note = LP_state.note;
            handles.loadedvar(end).var.xyczt = LP_state.xyczt;
            handles.loadedvar(end).var.time = LP_state.time;
            handles.loadedvar(end).var.label = LP_state.label;
            handles.loadedvar(end).var.Ft = LP_state.Ft;
            handles.loadedvar(end).filename = filename;
            handles.loadindex(1,1) = handles.loadindex(1,1)+1;
            handles.saveasked = 1;
            LP_state.currentpath = pathname;
            movefile(fullfile(LP_state.tempStackPath,LP_state.tempStackName),fullfile(pathname,filename));
            guidata(hObject,handles);
            pause(0.1);
        end %try it until it's saved...... even though, it's still skipped once in a while...
        show_Callback(handles.show_last4, eventdata, handles); %update file name and xyczt
        state.files.savePath = pathname;
        try
            if strcmpi(get(hNavi(2).hobj,'Checked'),'On') %if Sync context menu is checked in LP_Navi
                set(hNavi(1).hobj,'String',filename); %edit_label box in LP_Navi
            end
        catch
            %do nothing. LP_Navi is not loaded
        end
    catch
        beep;
        disp('File saving error... Nothing to save??');
    end
else %it is a saved file -> wanna save modified notes
    handles.loadedvar(handles.loadindex(1,2)).var.note = deblank(cellstr(get(handles.edit_note,'String')));
    %handles.loadedvar(handles.loadindex(1,2)).var.note = get(handles.edit_note,'String');
    guidata(hObject,handles);
    time = handles.loadedvar(handles.loadindex(1,2)).var.time;
    label = handles.loadedvar(handles.loadindex(1,2)).var.label;
    note = handles.loadedvar(handles.loadindex(1,2)).var.note;
    xyczt = handles.loadedvar(handles.loadindex(1,2)).var.xyczt;
    Ft = handles.loadedvar(handles.loadindex(1,2)).var.Ft;
    %assignin('base','filename',handles.loadedvar(handles.loadindex(1,2)).filename);
    %occasionally the extension becomes .tif although the saved one is .mat......
    [pathstr, name, ext, versn] = fileparts(handles.loadedvar(handles.loadindex(1,2)).filename);
%     save(fullfile(LP_state.currentpath,[name,'.mat']),'-struct','LP_state','time','label','note','xyczt','Ft'); %this won't work, either...
%     save([LP_state.currentpath,handles.loadedvar(handles.loadindex(1,2)).filename],'time','label','note','xyczt','Ft');
    recycle('off');
    delete([LP_state.currentpath,name,'.mat']);
    recycle('on');
    save([LP_state.currentpath,'fkfkfk.mat'],'time','label','note','xyczt','Ft');
    movefile([LP_state.currentpath,'fkfkfk.mat'],[LP_state.currentpath,name,'.mat']);
    %The above code is necessary... It's not because I'm stupid... it's
    %because MATLAB is always doing something funny. Try save the acquired
    %file first and then modify the note and save again. The note won't be
    %saved anyway unless the above method is used......
    %save([LP_state.currentpath,handles.loadedvar(handles.loadindex(1,2)).filen
    %ame],'note','-append'); %this won't work
    %disp('entered 679');
end


function menu_load_Callback(hObject, eventdata, handles)
% hObject    handle to menu_load (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global LP_state

[filename, pathname] = uigetfile('*.mat','Select Files',fullfile(LP_state.currentpath,'*.mat'),'MultiSelect','on');
% If 'Cancel' was selected then return
if isequal([filename,pathname],[0,0])
    return;
else
    handles.loadedvar = [];
    %assignin('base','filenames',filename);
    %filename = filename';
    if ischar(filename) %only one file is selected
        try
            handles.loadedvar(end+1).var = load([pathname,filename],'note','xyczt','time','label','Ft');
            handles.loadedvar(end).filename = filename;
            if ~isfield(handles.loadedvar(end).var,'note')
                beep;
                disp(['Cannot load ',char(filename),'...']);
                handles.loadedvar(end) = []; %delete it
            end
        catch
            beep;
            disp(['Cannot load ',char(filename),'...']);
        end
    else
        filename = sort(filename);
        for n = 1:length(filename)
            try
                %disp('entered');
                %assignin('base','fullfile',[pathname,char(filename(n))]);
                handles.loadedvar(end+1).var = load([pathname,char(filename(n))],'note','xyczt','time','label','Ft');
                handles.loadedvar(end).filename = char(filename(n));
                if ~isfield(handles.loadedvar(end).var,'note')
                    beep;
                    disp(['Cannot load ',char(filename(n)),'...']);
                    handles.loadedvar(end) = []; %delete it
                    %disp('entered 636');
                end
                %assignin('base',['loaded',num2str(n)],[pathname,filename{n}]);
            catch %invalid file, could be MAT or others
                beep;
                disp(['Cannot load ',char(filename(n)),'...']);
                %disp('entered 642');
            end
        end
    end
end
handles.loadindex(1,1) = length(handles.loadedvar);
if handles.loadindex(1,1) > 0
    handles.loadindex(1,2) = 1; %show first file
    %disp('loadindex = [n,1]');
else
    handles.loadindex(1,2) = 0; %no file loaded
    %disp('loadindex = [0,0]');
end
LP_state.currentpath = pathname;
handles.saveasked = 1;
guidata(hObject,handles);
%assignin('base','loadpath',LP_state.currentpath);
if handles.loadindex(1,2) ~= 0
    show_Callback(handles.show_first1, eventdata, handles); %update the note
else
    return
end

% assignin('base','loadindex',handles.loadindex);

% --------------------------------------------------------------------
function menu_clear_Callback(hObject, eventdata, handles)
% hObject    handle to menu_clear (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.loadedvar = []; %notes of files loaded by menu_browse_Callback
handles.loadindex = [0 0]; %[total,current] index to current file to be displayed
guidata(hObject,handles);
set(handles.figure1,'Name',handles.shell);
set(handles.edit_note,'String',[]);
set(handles.text_xyczt,'String','x: y: c: z: t:');

% --------------------------------------------------------------------
function menu_duplicate_Callback(hObject, eventdata, handles)
% hObject    handle to menu_duplicate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%duplicate the .mat file. It's for making processing notes of processed
%images.
global LP_state
[filename, pathname] = uiputfile(fullfile(LP_state.currentpath,'*.mat'),'Save the Duplicated Notes As...');
if isequal([filename,pathname],[0,0])
    return;
end
time = handles.loadedvar(handles.loadindex(1,2)).var.time;
label = handles.loadedvar(handles.loadindex(1,2)).var.label;
note = get(handles.edit_note,'String');
xyczt = [handles.loadedvar(handles.loadindex(1,2)).var.xyczt(1:2),NaN,NaN,NaN]; %NaN indicates it's a duplicated note
Ft = handles.loadedvar(handles.loadindex(1,2)).var.Ft;
[pathstr, name, ext, versn] = fileparts(filename);
save(fullfile(pathname,[name,'.mat']),'time','label','note','xyczt','Ft');

handles.loadedvar(end+1) = handles.loadedvar(handles.loadindex(1,2));
handles.loadedvar(end).var.note = note;
handles.loadedvar(end).var.xyczt = xyczt;
handles.loadedvar(end).filename = filename;
handles.loadindex(1,1) = handles.loadindex(1,1)+1;
%handles.loadindex(1,2) = handles.loadindex(1,1);
handles.saveasked = 1;
%LP_state.currentpath = pathname;
guidata(hObject,handles);
show_Callback(handles.show_last4, eventdata, handles); %update file name and xyczt

% --------------------------------------------------------------------
function menu_powerGraph_Callback(hObject, eventdata, handles)
% hObject    handle to menu_powerGraph (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global state LP_state
try
    if isempty(LP_state.powerEq)
        beep;
        disp('Equation for power conversion has not been specified.');
        return
    end
    f = inline(LP_state.powerEq);
    figure;
    h=plot(f(state.init.eom.lut),'Color','blue');
    title(['Power conversion: ',LP_state.powerEq]);
    xlabel('Power Controls value (%)');
    ylabel('Expected power (mW)');
    grid on
    set(gcf,'Name','Laser Power Graph');
catch
    beep;
    disp('Faild to locate state.init.eom.lut');
end
% --------------------------------------------------------------------
function menu_powerLUT_Callback(hObject, eventdata, handles)
% hObject    handle to menu_powerLUT (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global state LP_state
try
[filename, pathname] = uigetfile('*.mat','Laser Power LUT',fullfile(state.iniPath,'*.mat'),'MultiSelect','off');	
%[filename, pathname] = uigetfile('*.mat','Laser Power LUT',fullfile(pwd,'*.mat'),'MultiSelect','off'); %for debug
% If 'Cancel' was selected then return
if isequal([filename,pathname],[0,0])
    return;
else
    temp = load([pathname,filename]);
%     field = fieldnames(temp);
%     temp = temp.(field{1});
    if isfield(temp,'powerEq')
        LP_state.powerEq = temp.powerEq;
        %guidata(gcf,handles);
    end
    temp = temp.LUT;
    %assignin('base','powerEq',LP_state.powerEq);
    if length(temp) == 100
        menu_powerGraph_Callback(handles.menu_powerGraph, eventdata, handles);
        set(get(gca,'Children'),'Color','red');
        f = inline(LP_state.powerEq);
        state.init.eom.lut = temp;
        hold on
        plot(f(state.init.eom.lut),'Color','blue');
        hold off
        legend('Previous','Current');
    else
        beep;
        disp('not a valid LUT file');
        return;
    end
end
catch ME
    beep;
    disp('Scanimage is probably not loaded...');
    assignin('base','ME',ME);
    ME
end


% --------------------------------------------------------------------
function context_pause_Callback(hObject, eventdata, handles)
% hObject    handle to context_pause (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if strcmpi(get(handles.context_pause,'Checked'),'on')
    set(handles.context_pause,'Checked','off');
else
    set(handles.context_pause,'Checked','on');
end
        


% --- Executes on button press in SwapTTL.
function SwapTTL_Callback(hObject, eventdata, handles)
% hObject    handle to SwapTTL (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global LP_state;
%swap labels
temp = get(handles.edit_label5,'String');
set(handles.edit_label5,'String',get(handles.edit_label6,'String'));
set(handles.edit_label6,'String',temp);
%swap TTL
LP_state.TTL5 = LP_state.TTL6;
LP_state.TTL6 = ~LP_state.TTL5;
%set TTL blue background
if LP_state.TTL5 == LP_state.TTLblue.value
    %set(handles.edit_label5,'BackgroundColor',get(handles.edit_label6,'BackgroundColor'));
    set(handles.edit_label5,'BackgroundColor',LP_state.TTLblue.color);
    set(handles.edit_label6,'BackgroundColor','white');
else
    %set(handles.edit_label6,'BackgroundColor',get(handles.edit_label5,'BackgroundColor'));
    set(handles.edit_label6,'BackgroundColor',LP_state.TTLblue.color);
    set(handles.edit_label5,'BackgroundColor','white');
end

% --------------------------------------------------------------------
function TTLsetting_Callback(hObject, eventdata, handles)
global LP_state
index = get(hObject,'Tag');
if strcmp(index(end),'1')
    set(handles.menu_TTLblue1,'Checked','On');
    set(handles.menu_TTLblue0,'Checked','Off');
    LP_state.TTLblue.value = true;
else
    set(handles.menu_TTLblue1,'Checked','Off');
    set(handles.menu_TTLblue0,'Checked','On');
    LP_state.TTLblue.value = false;
end
%set TTL blue background
if LP_state.TTL5 == LP_state.TTLblue.value
    %disp('TTL5 is blue');
    set(handles.edit_label5,'BackgroundColor',LP_state.TTLblue.color);
    set(handles.edit_label6,'BackgroundColor','white');
else
    %disp('TTL5 is white');
    set(handles.edit_label6,'BackgroundColor',LP_state.TTLblue.color);
    set(handles.edit_label5,'BackgroundColor','white');
end
%assignin('base','tag',index(end));


% --------------------------------------------------------------------
function menu_Ft_Callback(hObject, eventdata, handles)
% hObject    handle to menu_Ft (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global LP_state
handles.hFt = LP_Ft(LP_state.Ftclip);
guidata(hObject,handles);
% if isempty(handles.hFt)
%     handles.hFt = LP_Ft;
%     guidata(hObject,handles);
% else
%     figure(handles.hFt); %This doesn't work
% end

% --------------------------------------------------------------------
function menu_ShowAll_Callback(hObject, eventdata, handles)
% hObject    handle to menu_ShowAll (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

%use findall to locate GUIs
h = findall(0,'Tag','figure1','Visible','on'); %0 is the handle of the root object
for n = 1:length(h)
    figure(h(n)); %bring figures to the front
end
%use get(0) to find figures: e.g. Ch1,Ch2,ROI etc.
h = get(0);
index = find(strcmpi(get(h.Children,'Visible'),'on'));
for n = 1:length(index)
    figure(h.Children(index(n)));
end

% % --- Executes on button press in Burst.
% function Burst_Callback(hObject, eventdata, handles)
% % hObject    handle to Burst (see GCBO)
% % eventdata  reserved - to be defined in a future version of MATLAB
% % handles    structure with handles and user data (see GUIDATA)
% 
% % Hint: get(hObject,'Value') returns toggle state of Burst
% global LP_state;
% if get(hObject,'Value') %Burst mode
%     %LP_state.pauseacq = 1;
%     set(hObject,'String','Ready','ForegroundColor','green');
%     LP_state.burst = 1;
% else
%     LP_state.burst = 0;
%     set(hObject,'String','Burst','ForegroundColor','red');
% end

% --------------------------------------------------------------------

function edit_burst_Callback(hObject, eventdata, handles)
% hObject    handle to edit_burst (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%disp('entered');
global gh state
T = str2double(get(hObject,'String'));
if T == 0
    return
else
    try
        %frames = ceil(T*get(state.init.ao2,'SampleRate')/length(state.acq.mirrorDataOutput)); %calculate number of frames
        frames = ceil(T*state.acq.frameRate);
        set(gh.standardModeGUI.numberOfFrames,'String',num2str(frames)); %update frames
        Cloned_numberOfFrames_Callback(gh.standardModeGUI.numberOfFrames, [], []);
        if state.acq.averaging
            set(gh.standardModeGUI.averageFrames,'Value',0); %uncheck averaging
            Cloned_averaging_Callback(gh.standardModeGUI.averageFrames, [], []);
        end
    catch ME
        assignin('base','ME',ME);
        ME
    end
end


% Hints: get(hObject,'String') returns contents of edit_burst as text
%        str2double(get(hObject,'String')) returns contents of edit_burst as a double


% --------------------------------------------------------------------
function menu_AutoAcq_Callback(hObject, eventdata, handles)
% hObject    handle to menu_AutoAcq (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global LP_state
[filename, pathname] = uigetfile('*.m','Load Protocol(s)','MultiSelect','on');
% If 'Cancel' was selected then return
if isequal([filename,pathname],[0,0])
    return;
else
    addpath(pathname);
    if ischar(filename) %only one file is selected
        [pathstr, name, ext, versn] = fileparts(filename);
        handles.hAutoAcq(end+1) = uimenu(handles.menu_tools,'Label',name,...
            'Callback',{@menu_AutoAcq_selected},'Checked','off');
    else
        for n = 1:length(filename)
            [pathstr, name, ext, versn] = fileparts(char(filename(n)));
            handles.hAutoAcq(end+1) = uimenu(handles.menu_tools,'Label',name,...
            'Callback',{@menu_AutoAcq_selected},'Checked','off');
        end
    end
    guidata(hObject,handles);
    set(handles.hAutoAcq(1),'Separator','On');
    set(handles.toggle_autoacq,'Enable','On');
    menu_AutoAcq_selected(handles.hAutoAcq(end),[]); %select the last one
    toggle_autoacq_Callback(handles.toggle_autoacq, eventdata, handles); %make sure LP_state.autoacq and the tooltip string is current
end

% if strcmpi(get(hObject,'Checked'),'on') %disable
%     set(hObject,'Checked','off');
%     set(handles.toggle_autoacq,'Enable','Off');
%     LP_state.autoacq = 0;
% else %enable
%     [filename, pathname] = uigetfile('*.m','Specify the Protocol','MultiSelect','off');
%     % If 'Cancel' was selected then return
%     if isequal([filename,pathname],[0,0])
%         return;
%     else
%         addpath(pathname);
%         [pathstr, name, ext, versn] = fileparts(filename);
%         LP_state.protocol = name;
%         set(hObject,'Label',LP_state.protocol);
%         set(hObject,'Checked','on');
%         set(handles.toggle_autoacq,'Enable','On');
%         toggle_autoacq_Callback(handles.toggle_autoacq, eventdata, handles); %make sure the value of LP_state.autoacq
%         %LP_state.autoacq = 1;
%     end
% end

% --------------------------------------------------------------------
function menu_AutoAcq_selected(hObject, eventdata)
global LP_state
set(get(get(hObject,'Parent'),'Children'),'Checked','off'); %uncheck all
set(hObject,'Checked','On');
LP_state.protocol = get(hObject,'Label');

% --- Executes on button press in toggle_autoacq.
function toggle_autoacq_Callback(hObject, eventdata, handles)
% hObject    handle to toggle_autoacq (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global LP_state
if get(hObject,'Value') %disable autoacq
    set(hObject,'BackgroundColor','red');
    set(hObject,'TooltipString','AutoAcq is disabled');
    LP_state.autoacq = 0;
else %enable autoacq
    set(hObject,'BackgroundColor',[0,0.8,0.2]);
    set(hObject,'TooltipString','AutoAcq is enabled');
    %set(hObject,'TooltipString',[LP_state.protocol,' is launched']);
    LP_state.autoacq = 1;
end
% Hint: get(hObject,'Value') returns toggle state of toggle_autoacq


% --------------------------------------------------------------------
function menu_Navi_Callback(hObject, eventdata, handles)
% hObject    handle to menu_Navi (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%LP_Navi([],handles.currentpath);
LP_Navi([],1); %flag indicating it's called from the LittleProbe
%the first input is a Callback in LP_Navi. Refer to Lines 9 and 36 in
%LP_Navi.m


% --------------------------------------------------------------------
function menu_flash_Callback(hObject, eventdata, handles)
% hObject    handle to menu_flash (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if ~get(handles.Activation,'Value') %if the LittleProbe is not activated
    disp('Please activate the LittleProbe first.');
    return
end
handles.hDev3 = LP_Dev3;
guidata(hObject,handles);

% --------------------------------------------------------------------
function menu_colormap_Callback(hObject, eventdata, handles)
% hObject    handle to menu_colormap (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hColormap = LP_Colormap(get(handles.figure1,'Position'));
guidata(hObject,handles);

% --------------------------------------------------------------------
function menu_SIM_Callback(hObject, eventdata, handles)
% hObject    handle to menu_SIM (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if ~get(handles.Activation,'Value') %if the LittleProbe is not activated
    disp('Please activate the LittleProbe first.');
    return
end
LP_SIM;


% --------------------------------------------------------------------
function varargout = Cloned_numberOfFrames_Callback(h, eventdata, handles, varargin)
%copied form standardModeGUI.m
genericCallback(h); 
updateAcquisitionSize(h);
% --------------------------------------------------------------------
function varargout = Cloned_averaging_Callback(h, eventdata, handles, varargin)
%copied form standardModeGUI.m
% Stub for Callback of most uicontrol handles
genericCallback(h);
global state
state.acq.averaging=state.standardMode.averaging;
updateHeaderString('state.acq.averaging');
reconcileStandardModeSettings;
preallocateMemory;
% --------------------------------------------------------------------




