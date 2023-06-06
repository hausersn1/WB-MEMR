%% Plays clicks and noise, records response
% Initializing TDT
fig_num=99;
GB_ch=1;
FS_tag = 3;
Fs = 48828.125;
[f1RZ,RZ,~]=load_play_circuit_Nel2(FS_tag,fig_num,GB_ch);


subj = input('Please subject ID:', 's');
earflag = 1;
while earflag == 1
    ear = input('Please enter which year (L or R):', 's');
    switch ear
        case {'L', 'R', 'l', 'r', 'Left', 'Right', 'left', 'right',...
                'LEFT', 'RIGHT'}
            earname = strcat(ear, 'Ear');
            earflag = 0;
        otherwise
            fprintf(2, 'Unrecognized ear type! Try again!');
    end
end
uiwait(warndlg('Set ER-10B+ GAIN to 40 dB','SET ER-10B+ GAIN WARNING','modal'));

% Make directory to save results
paraDir = 'C:\Documents and Settings\Heinz Lab\Desktop\WBMEMRipsi-master\';
% whichScreen = 1;
addpath(genpath(paraDir));
if(~exist(strcat(paraDir,'\',subj),'dir'))
    mkdir(strcat(paraDir,'\',subj));
end
respDir = strcat(paraDir,'\',subj,'\');

%% DO FULL BAND FIRST
stim = makeMEMRstim_500to8500Hz;
stim.subj = subj;
stim.ear = ear;

pause(3);


%Set the delay of the sound
invoke(RZ, 'SetTagVal', 'onsetdel',0); % onset delay is in ms
playrecTrigger = 1;


%% Set attenuation and play

button = input('Do you want the subject to press a button to proceed? (Y or N):', 's');
switch button
    case {'Y', 'y', 'yes', 'Yes', 'YES'}
        %         getResponse(RZ);
        %         fprintf(1, '\nSubject pressed a button...\nStarting Stimulation...\n');
        DELAY_sec=30;
        fprintf(1, '\n%.f seconds until START...\n',DELAY_sec);
        pause(DELAY_sec)
        fprintf(1, '\nSubject waited %.f seconds ...\nStarting Stimulation...\n',DELAY_sec);
    otherwise
        fprintf(1, '\nStarting Stimulation...\n');
end




resplength = numel(stim.t);
stim.resp = zeros(stim.nLevels, stim.Averages, stim.nreps, resplength);
%% Jun 6 2018: MH and HG
% *re-order data collection (all levels for each rep)
% set to allow break out with data saving

continueDATA=1;
h=figure('KeyPressFcn','continueDATA=0');
disp('Press any key in FIG to STOP data collection')


for nTRIALS = 1: (stim.Averages + stim.ThrowAway)
    for L = 1:stim.nLevels
        
        % Set attenuation on PA5 using Nel 2.0's PAset
        rc = PAset([0, 0, stim.clickatt, stim.noiseatt(L)]);
        %     invoke(RZ, 'SetTagVal', 'attA', stim.clickatt);
        %     invoke(RZ, 'SetTagVal', 'attB', stim.noiseatt(L));
        invoke(RZ, 'SetTagVal', 'nsamps', resplength);
               
        buffdataL = stim.click;
        buffdataR = squeeze(stim.noise(L, nTRIALS, :))';
        % Check for clipping and load to buffer
        if(any(abs(buffdataL(:)) > 1) || any(abs(buffdataR(:)) > 1))
            error('What did you do!? Sound is clipping!! Cannot Continue!!\n');
        end
        %Load the 2ch variable data into the RZ6:
        %invoke(RZ, 'WriteTagVEX', 'datain', 0, 'I16', (buffdata*2^15));
        invoke(RZ, 'WriteTagVEX', 'datainL', 0, 'F32', buffdataL);
        invoke(RZ, 'WriteTagVEX', 'datainR', 0, 'F32', buffdataR);
        pause(1.5);
        for k = 1:stim.nreps
            %Start playing from the buffer:
            invoke(RZ, 'SoftTrg', playrecTrigger);
            currindex = invoke(RZ, 'GetTagVal', 'indexin');
            while(currindex < resplength)
                currindex=invoke(RZ, 'GetTagVal', 'indexin');
            end
            
            vin = invoke(RZ, 'ReadTagVex', 'dataout', 0, resplength,...
                'F32','F64',1);
            %Accumluate the time waveform - no artifact rejection
            if (nTRIALS > stim.ThrowAway)
                stim.resp(L, nTRIALS-stim.ThrowAway, k, :) = vin;
            end
            
            % Get ready for next trial
            invoke(RZ, 'SoftTrg', 8); % Reset OAE buffer

            fprintf(1, 'Done with Level #%d, Trial # %d \n', L, nTRIALS);
        end 
      
        if ~continueDATA
            break
        end
                
    end  % levels
    pause(2);
    if ~continueDATA
        break
    end
    
    if ~rem((nTRIALS-stim.ThrowAway),3)&(nTRIALS>stim.ThrowAway)
        stimTEMP=stim;
        stimTEMP.resp=stim.resp(:,1:nTRIALS-stim.ThrowAway,:,:);
        stimTEMP.Averages=nTRIALS-stim.ThrowAway;
        analyzeMEM_Fn(stimTEMP) %Calls function, builds two plots
    end
        
end  % Trials


%% TO DO
% *1) re-order stim presentation
% *2) way to exit data collection (Fig: KeyPressfnc)
% *3) plot at end of each 3rd rep (after throw away)





%% Info for conversion.. no averaging or conversion done online

mic_sens = 0.05; % V / Pa-RMS
mic_gain = db2mag(40);
P_ref = 20e-6; % Pa-RMS

DR_onesided = 1;

stim.mat2Pa = 1 / (DR_onesided * mic_gain * mic_sens * P_ref);


%% Save results
datetag = datestr(clock);
stim.date = datetag;
datetag(strfind(datetag,' ')) = '_';
datetag(strfind(datetag,':')) = '_';
fname = strcat(respDir,'MEMR_', stim.subj, '_', stim.ear, '_', ...
    datetag, '.mat');
save(fname,'stim');



%% Close and clean up
close_play_circuit(f1RZ, RZ);
