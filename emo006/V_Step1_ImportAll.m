%% Code to Import Biosemi and Biopac data
 
% This script will load BioSemi, Biopac, and beavioral data and integrate
% all signals. Some very basic preprocessing is done here, such as
% detrending, applying a lowpass filter @ 55 Hz to remove 60 Hz line noise,
% and downsampling the data. EEG channel location info is also added here,
% as well as ECG R-peak detection. Marker diodes from Biopac and Biosemi
% are additionally encoded and formatted to be used in epoching in later
% steps.

% Run this script from the directory it is stored in.

% There are 4 stages of manual quality assurance that can be done here:

% 1) Check time locking -- ensure that the biosemi and biopac event markers
% are timelocked well. Set 'CheckTimelocking' to 1 to visualize the event
% marker timing differences.

% 2) HRV validation -- in order to compute HRV in later steps, the timing
% of the R-peaks must be accurately detected. These parameters for
% detection are set in the variables 'pk_height' and 'pk_dist'. Set
% 'HRVvalidation' to 1 to check that R-peaks are being accurately detected.

% 3) EEG filter visualization -- set 'EEGfiltvis' to 1 to visualize the
% power spectrum of the EEG data to see if the peak at 60 Hz has been
% removed by the lowpass filter.

% 4) Biopac filter visualization -- set 'Bpacfiltvis' to 1 to visualize the
% power spectrum of the biopac (ECG) data to see if a peak at 60 Hz has
% been removed by the lowpass filter.

% Authors:  Vincent Wang, Bijurika Nandi, Alexander Simon, and Theodore Zanto (2023)

function output = V_Step1_ImportAll()
    clear all; clc; close all; clf;
        
    eeglab;
    close all; clc; clear all; clf;
    PID = {'emo006'};


    addpath(genpath(sprintf('C:\Users\Maryam\Documents\GitHub\emosense-preprocessing\%s',PID{1})));
    addpath(genpath('C:\Users\Maryam\Documents\GitHub\fieldtrip-20240309')); 
    addpath(genpath('C:\Users\Maryam\Documents\GitHub\emosense-preprocessing\helper_functions'))
    ft_defaults;
    
    sessions = [4];
    blocks = [6:7];


    % Set the active diode used in the biopac markers. This can be found in
    % the plot of biopac markers. This can vary between
    % participants/sessions.
    bpac_active_diode_first = 'PD 16';
    bpac_active_diode_second = 'PD 32';

    for session = sessions
        fprintf("Session %d\n", session);
        % File path for raw data
        InDir = sprintf('C:/Users/Maryam/Documents/Data/emosense/Datasets/%s/Session %d/Raw', PID{1}, session);
        
        % File path for output imported data
        OUTDIR = sprintf('C:/Users/Maryam/Documents/Data/emosense/Datasets/%s/Session %d/Preprocessed/step1', PID{1}, session);
        
        if ~exist(OUTDIR,'dir')
            mkdir(OUTDIR);
        end
        
        % biosemi specific params
        sfreq = 512 ;   %indicate down-sampling frequency
        downsample = 4;   %downsample biosemi data by a factor of 4
        locutoff = 55;   %lowpass filter cutoff
        Chantype = {'EEG 128', 'EMG (EX1 EX5 EX6)', 'EOG vertical(EX2) EOG horizontal(EX3 EX4)', 'EGG (EX7 EX8)' };
        nsec = 20; % num of secs averaged for topo plot for manually checking electrodes
        FP1 = {'C29'};   %this electrode in our configuration is the same as FP1
        
        % import channel locations file
        load('C:\Users\Maryam\Documents\Data\emosense\metadata\128chanlocs_eeglab.mat');
        
        % biopac specific parameters
        bp_dsample = 2;    %downsample biopac data by a factor of 2
        
        % ECG R peak detection parameters -- adjust these if HRV visualization
        % shows that the algorithm isn't properly detecting R peaks
        pk_height = 0.02; % in mV
        pk_dist = 0.5; % in seconds
        
        %% Load behav files and setup physio file lists
        
        % if ~exist(OUTDIR,'dir') mkdir(OUTDIR); end
        % list and sort bdfs
        % bdfs = dir(sprintf('%s/%s/*.bdf',InDir,PID{1}));
        
        bdfs = dir(sprintf('%s/Biosemi/%s_s%02d/*.bdf',InDir,PID{1},session));
        bdffiles = {bdfs.name};
        [~,bdfidx] = sort(bdffiles);
        bdfs = bdfs(bdfidx);
        
        % list and sort biopac files
        biopac = dir(sprintf('%s/Biopac/%s_s%02d/*.mat',InDir,PID{1},session));
        bpacfiles = {biopac.name};
        [~,bpacidx] = sort(bpacfiles);
        biopac = biopac(bpacidx);
        
        % load in behavioral data
        % csv = dir(sprintf('%s/%s/*.csv',InDir,PID{1}));
        csv = dir(sprintf('C:/Users/Maryam/Documents/Data/emosense/Datasets/%s/complete/*.csv',PID{1}));
        
        % the script wants all of the behavioral data in a single file (the last one the task generates)
        if length(csv) > 1
            error('Too many behavioral files in the path. Make sure the only file in the path is the one containing data from ALL blocks of the task');
        end
        
        behav = readtable([csv.folder '\' csv.name], 'Delimiter', ',');
        % create a block order list for behavioral files
        unique_block_nums = table2array(unique(behav(:,3)));
        unique_block_nums = unique_block_nums(~isnan(unique_block_nums));
        
        % % Find index of first trial for each block
        % for block_num = 1:size(unique_block_nums,1)
        %     block_indices(block_num, 1) = find(strcmp(string(unique_block_nums(block_num, 1)), string(behav.Var3)), 1);
        % end
        % 
        % [sorted_blocks, ord] = sort(block_indices);
        % 
        % % Populate block_order with sorted blocks from behav
        % for block_num = 1:size(unique_block_nums,1)
        %     block_order{block_num, 1} = behav{sorted_blocks(block_num), 3};
        % end
        
        %% Quality control visualization parameters
        
        %select if you want to visualize the ISI differences between biopac and biosemi event markers
        PlotTimeLocking = 1; 
        
        % Tolerence for syncing between biopac and biosemi markers in seconds
        bp_bs_sync_tolerence = 0.0025;
        
        %select if you want to visualize a portion of the ECG signal with R peaks
        %detected by the peak detection algorithm circled
        HRVvalidation = 1;
        
        % Visualize the power spectrum of filtered EEG data? This is for checking
        % if there was 60 Hz line noise that made it through the filter
        % Also check BP noise
        EEGfiltvis = 1;
        
        % Visualize the power spectrum of filtered biopac (ECG as example) data? This is for checking
        % if there was 60 Hz line noise that made it through the filter
        Bpacfiltvis = 1;
    
        plot_biosemi_markers = 1;
        plot_bpac_markers = 1;
        
        if length(bdfs) == length(biopac)
            for block_number = blocks

            % for block_number = 1:length(biopac)
                filename = sprintf('%s_session%d_block0%d_allSignals_final.mat', PID{1}, session, block_number);
                if ~exist([OUTDIR filename],'file')
                    fprintf("Block %d", block_number)
                    fprintf('\tLoading Data...\n')

                    EEG = pop_fileio([bdfs(block_number).folder '/' bdfs(block_number).name]);
                    EEG.data = double(EEG.data);
                    EEG = fPD2numeric(EEG);  % convert diodes from 5 or 6 to 2 or 3 digit numbers
                    
                    % Plot EEG markers
                    if plot_biosemi_markers
                        figure(1);
                        plot(EEG.data(144, :));
                        title("Biosemi Markers");
                    end
                    
                    % Remove unused channels from EEG
                    fprintf('\tDeleting unused EEG channels...\n')
        
                    DeleteChans = [137:144];
        
                    EEG.data(DeleteChans,:) = [];
                    EEG.nbchan = size(EEG.data,1);
                    EEG.chanlocs(DeleteChans) = [];
        
                    %% Downsampling
                    fprintf('\tDownsampling EEG data...\n')
                    EEG.data = EEG.data(:,1:downsample:end);
                    EEG.srate = EEG.srate/downsample;
                    EEG.times = EEG.times(1:downsample:end);
                    EEG.pnts = length(EEG.times);
                    for i = 1:length(EEG.event)
                        EEG.event(i).latency =  EEG.event(i).latency/downsample;
                    end
        
                    % Detrend all biosemi channels
                    fprintf('\tDetrending all biosemi channels...\n')
                    EEG.data = detrend(EEG.data')';
        
                    % lowpass filtering
                    order = 20*(fix(EEG.srate/locutoff));
                    b = fir1(order, locutoff/(EEG.srate/2));
        
                    % notch filtering 28hz for BP machine
                    wo = 28/(EEG.srate/2);
                    bw = wo/20;
                    [bn,an] = iirnotch(wo,bw);
                    %           fvtool(b,a);

                    % notch filtering for unknown 50Hz noise
                    wf = 48.5/(EEG.srate/2);
                    bf = wf/20;
                    [bf,af] = iirnotch(wf,bf);
                    %           fvtool(b,a);
        
        
                    fprintf('\tApplying lowpass filter...\n')
                    for e = 1:size(EEG.data,1)
                        if EEGfiltvis == 1
                            figure(2);
                            if e == 1   % we only really need to check this on one channel
                                % code for checking how well the filter worked
                                y2 = fft(EEG.data(e,:));
                                p2 = abs(y2/length(EEG.data(e,:)));
                                p1 = p2(1:length(EEG.data(e,:))/2);
                                p1(1) = [];
                                freq = (EEG.srate*(0:(length(EEG.data)/2)-1))/length(EEG.data);
                                freq(1) = [];
                                %                         freq = 0:0.05:60;
                                %                       [Pxx, F] = pwelch(EEG.data(e,:),5*EEG.srate, EEG.srate,freq);
                                subplot(2, 1, 1); 
                                plot(freq,p1);
                                %                       figure(); plot(freq,Pxx);
                                eval(sprintf('title(''%s Unfiltered EEG power spectrum'')',filename))
                                xlabel('Frequency (Hz)')
                                ylabel('Power (µV^2)')
                                xlim([0 100]);
                                ylim([0 1]);
        
                                clear y2 p2 pq freq
                            end
                        end
        
                        EEG.data(e,:) = filtfilt(bn, an, EEG.data(e,:));
                        EEG.data(e,:) = filtfilt(bf, af, EEG.data(e,:));

                        EEG.data(e,:) = filtfilt(b, 1, EEG.data(e,:));
        
                        if EEGfiltvis == 1
                            if e == 1   % we only really need to check this on one channel
                                % code for checking how well the filter worked
                                y2 = fft(EEG.data(e,:));
                                p2 = abs(y2/length(EEG.data(e,:)));
                                p1 = p2(1:length(EEG.data(e,:))/2);
                                p1(1) = [];
                                freq = (EEG.srate*(0:(length(EEG.data)/2)-1))/length(EEG.data);
                                freq(1) = [];
                                %                         freq = 0:0.05:60;
                                %                       [Pxx, F] = pwelch(EEG.data(e,:),5*EEG.srate, EEG.srate,freq);
                                subplot(2, 1, 2); 
                                plot(freq,p1);
                                %                       figure(); plot(freq,Pxx);
                                eval(sprintf('title(''%s filtered EEG power spectrum'')',filename))
                                xlabel('Frequency (Hz)')
                                ylabel('Power (µV^2)')
                                xlim([0 100]);
                                ylim([0 1]);
        
                                clear y2 p2 pq freq
                            end
                        end
                    end
        
                    EEG = reformat_biosemi_chanlocs(EEG, chanlocs);
                    
                    eegplot(EEG.data(1:128,:), 'srate', EEG.srate, 'winlength', 25, 'dispchans', 32, 'title', sprintf('%s_session%d_block0%d', PID{1}, session, block_number));   
                    
                    %% Format EEG Events
        
                    % Remove 0 and NaN events in Biosemi
                    events = [EEG.event.type];
                    valid_indices = ~isnan(events) & events ~= 0;
                    EEG.event = EEG.event(valid_indices);
                   
                    successive_threshold = 200; % Maximum gap (samples) allowed to consider pulses as successive
                    EEG = recode_successive_pulses(EEG, successive_threshold);


                    if isequal(PID{1}, 'emo005') && session == 2 && block_number == 7
                              EEG.event_coded(end-2:end) = []; % second trial has more pulses than expected and is an exception, just fixing this marker type here
                    end
                    EEG = fix_twopulse_issue(EEG); 
        
                    % Enumerate special cases of marker problems in
                    % specific blocks or sessions.
                    marker_exceptions = [
                        isequal(PID{1}, 'emo005') && session == 2 && block_number == 1
                        isequal(PID{1}, 'emo005') && session == 2 && block_number == 2
                        isequal(PID{1}, 'emo005') && session == 2 && block_number == 7
                        isequal(PID{1}, 'emo005') && session == 1 && block_number == 5
                        isequal(PID{1}, 'emo005') && session == 1 && block_number == 7
                        isequal(PID{1}, 'emo005') && session == 4 && block_number == 2 % last trial needs to be removed 
                        isequal(PID{1}, 'emo005') && session == 4 && block_number == 4


                        % isequal(PID{1}, 'emo005') && session == 2 && block_number == 2
                    ];


                    if any(marker_exceptions)
                        % emo001, session 1, block 7 had a missing cross start (3 bursts)
                        % marker for the final trial in both biopac and biosemi.
                        if isequal(PID{1}, 'emo005') && session == 1 && block_number == 5
                             sprintf('skipping this block for %s session %d block %d', PID{1},session, block_number),
                            continue

                        elseif isequal(PID{1}, 'emo005') && session == 2 && block_number == 2
                            sprintf('skipping this block for %s session %d block %d', PID{1},session, block_number),
                            continue    
                        % elseif isequal(PID{1}, 'emo005') && session == 1 && block_number == 7
                        %     EEG.event_coded(38:48)= []; % remove trial 5 since it doesn't match with number of video clips in the excel sheet 
                        % 
                        elseif isequal(PID{1}, 'emo005') && session == 4 && block_number == 4
                             sprintf('skipping this block for %s session %d block %d', PID{1},session, block_number),

                            continue 
                       % 
                       % elseif isequal(PID{1}, 'emo005') && session == 2 && block_number == 7
                       %        EEG.event_coded(end-3:end).type = []; % second trial has more pulses than expected and is an exception, just fixing this marker type here
                       % 
                       %  % 
                        % % emo001, session 2, block 7 only has markers until
                        % % video start of trial 2.
                        % if isequal(PID{1}, 'emo001') && session == 2 && block_number == 7
                        %     assert(length(EEG.event_coded) == 4, 'Expected emo001, session 2, block 7 to only have 4 markers')
                        %     assert(EEG.event_coded(1).type == 1, 'Unexpected event structure for emo001, session 2, block 7')
                        %     assert(EEG.event_coded(2).type == 2, 'Unexpected event structure for emo001, session 2, block 7')
                        %     assert(EEG.event_coded(3).type == 3, 'Unexpected event structure for emo001, session 2, block 7')
                        %     assert(EEG.event_coded(1).type == 1, 'Unexpected event structure for emo001, session 2, block 7')
                        end
                    end
                      

                    % if ~any(marker_exceptions)
                        assert_event_structure(EEG.event_coded, 'Biosemi', block_number);
                    % end

                    % if ~(isequal(PID{1}, 'emo001') && session == 2 && block_number == 7)
                    %     assert_event_structure(EEG.event_coded, 'Biosemi');
                    % end
    
                    % Add Biosemi to Signal
                    Signal = add_biosemi_to_signal(EEG, FP1);
    
                    % Remove EMG, EOG, EGG and misc channels from EEG struct for interpolation
                    Signal.EEG.data = EEG.data(1:128,:);
                    Signal.EEG.chanlocs(129:end) = [];
                        
                    %%  Biopac importing, formatting, and preprocessing
                    bpacdata = load([biopac(block_number).folder '/' biopac(block_number).name]);
                    bpac_sampUnits = strmatch(bpacdata.isi_units, 'ms');
                    
                    assert(~isempty(bpac_sampUnits) && bpacdata.isi == 1, 'The biopac is sampled in an unexpected sampling rate (not @1000 Hz)')
                                
                    %downsample to 500 Hz
                    fprintf('\tDownsampling biopac data...\n')
                    bpacdata.data = bpacdata.data(1:bp_dsample:end, :);
                    bpacdata.isi = bpacdata.isi*bp_dsample;
                    info.srate = 1000/bp_dsample;
                    info.times = 1000*(1:length(bpacdata.data))/info.srate; %time in ms
                    
                    if plot_bpac_markers
                        figure(3);
                        for i = 1:size(bpacdata.data, 2)
                            subplot(size(bpacdata.data, 2), 1, i)
                            plot(bpacdata.data(:, i))
                            legend(bpacdata.labels(i, :))
                        end
                        title("biopac markers")
                    end
        
                    % Create an array of biopac channel labels
                    % (Trimming white space from each row and converting to cell
                    % array of strings)
                    bpac_labels = cellstr(strtrim(bpacdata.labels));
        
                    % Raw biopac data contains more signal channels than we
                    % need. Enumerate the labels of signal channels which
                    % we actually want. These are decided by manual
                    % inspection of the earlier biopac data plot.
                    desired_bpac_labels = {'EDA2004000211', 'Phasic EDA', 'EOG1911000117', 'RSP1911000136', 'Resp Rate', 'BP', 'Systolic BP', 'Diastolic BP', 'TREV1', 'TREV2'};
                    
                    % Sometimes the signal channels we want varies across
                    % blocks. Enumerate these special cases.
                    desired_signal_exceptions = [
                    ];
                    
                    % Get the index of the biopac labels we want.
                    desired_bpac_indices = containers.Map;
                    for i = 1:length(desired_bpac_labels)
                        bpac_signal_idx = find(strcmp(bpac_labels, desired_bpac_labels{i}));
                        assert(1 <= bpac_signal_idx && bpac_signal_idx <= length(bpac_labels), 'Biopac signal label not found in the expected format.')
                        desired_bpac_indices(desired_bpac_labels{i}) = bpac_signal_idx;
                    end
                    
                    if ~any(desired_signal_exceptions)
                        assert(length(desired_bpac_indices) == length(desired_bpac_labels), 'Unexpectedly missing bpac signals')
                    end
        
                    % Add the biopac signals to the Signal struct. If there are biopac signals expected to be missing based on the experiment notes, we
                    % will fill their data in as NaNs.
                    Signal = add_bpac_to_signal(Signal, info, bpacdata, desired_bpac_indices);
                    Signal = lowpass_filter_bpac(Signal, info.srate, locutoff);
                    Signal = add_bp_calibration_metadata(Signal, PID{1}, session, block_number);
    
                    % Check quality of filtering
                    if Bpacfiltvis == 1
                        y2 = fft(Signal.ECG.data(1,:));
                        p2 = abs(y2/length(Signal.ECG.data(1,:)));
                        p1 = p2(1:floor(length(Signal.ECG.data(1,:))/2));
                        p1(1) = [];
                        freq = (info.srate*(0:(length(Signal.ECG.data)/2)-1))/length(Signal.ECG.data);
                        freq(1) = [];
                        figure(4); 
                        plot(freq,p1);
                        eval(sprintf('title(''%s filtered ECG power spectrum'')',filename))
                        xlabel('Frequency (Hz)')
                        ylabel('Power (mV^2)')
                        clear y2 p2 pq freq
                    end
        
                    %% ECG R peak analysis
                    % % Use the maximal overlap discrete wavelet transform (MODWT) to enhance the R peaks in the ECG waveform
                    % y = compute_modwt(Signal.ECG.data);
                    % 
                    % % Identify R peaks -- minpeak height might need some tweaking on a personalized
                    % % basis
                    % [qrspeaks, Signal.ECG.Rpeaklocs] = findpeaks(y, info.times, 'MinPeakHeight', pk_height, ...
                    %     'MinPeakDistance', info.srate * pk_dist);
                    % 
                    % % plotting -- for validation
                    % if HRVvalidation == 1
                    %     figure(5);
                    %     plot(info.times, y)
                    %     hold on;
                    %     plot(Signal.ECG.Rpeaklocs, qrspeaks, 'ro')
                    %     xlabel('msec')
                    %     eval(sprintf('title(''Heartrate Validation %s'',''Interpreter'',''none'')', filename))
                    % end
    
                    % Identify R peaks to compute avg heart rate.
                    % pan_tompkin() is an R peak identification algorithm.
                    [qrspeaks, Signal.ECG.Rpeaklocs] = pan_tompkin(Signal.ECG.data, Signal.ECG.srate, HRVvalidation);
                    Signal = compute_avg_heartrate(Signal, qrspeaks);
    
                    %% Biopac event formatting
    
                    bpac_event_channel_idx_first = find(strcmp(bpac_labels, bpac_active_diode_first));
                    bpac_event_channel_idx_second = find(strcmp(bpac_labels, bpac_active_diode_second));
                    BpacEvts_first = bpacdata.data(:, bpac_event_channel_idx_first);
                    BpacEvts_second = bpacdata.data(:, bpac_event_channel_idx_second);
        
                    % Plot Biopac markers
                    if plot_bpac_markers
                        figure(5)
                        subplot(2, 1, 1)
                        plot(BpacEvts_first)

                        subplot(2, 1, 2)
                        plot(BpacEvts_second)
                        legend("Biopac Markers")
                    end
                    
                    info = code_raw_bpac_events(info, BpacEvts_first, BpacEvts_second);
                    
                    if ~any(marker_exceptions)
                        assert(length(info.event) ~= 0, 'There are no event markers in the biopac file')
                        assert(length(EEG.event) == length(info.event), 'Biopac and Biosemi have a different number of raw event markers')
                    end
                    
                    if isequal(PID{1}, 'emo005') && session == 2 && block_number == 7

                        sprintf('skipping assert_event_sync_quality for raw data')
                    else 
                    assert_event_sync_quality(info.event, EEG.event, info.srate, EEG.srate, bp_bs_sync_tolerence, PlotTimeLocking);
                    end
                    
                    % Recode Biopac Events for Successive Pulses
                    info = recode_successive_pulses(info, successive_threshold);
                    if isequal(PID{1}, 'emo005') && session == 2 && block_number == 7
                          info.event_coded(end-2:end) = []; % second trial has more pulses than expected and is an exception, just fixing this marker type here
                    end
                    info = fix_twopulse_issue(info);
                    
                    if any(marker_exceptions)
                        % if isequal(PID{1}, 'emo005') && session == 1 && block_number == 7
                        %     info.event_coded(38:48)= []; % remove trial 5 since it doesn't match with number of video clips in the excel sheet 
                        % end
                    end
                    assert(length(EEG.event_coded) == length(info.event_coded), 'Total number of events between Biosemi and Biopac are not equal')
        
                    assert_event_structure(info.event_coded, 'Biopac', block_number);
                    assert_event_sync_quality(info.event_coded, EEG.event_coded, info.srate, EEG.srate, bp_bs_sync_tolerence, PlotTimeLocking);
                    
                    Signal = add_bpac_events_to_signal(Signal, info);

                    %% Add behavioral data to 'Signal' and format
                    Signal = add_behavioral_to_signal(Signal, behav, PID, session, block_number);
            
                    %save each block as a different file
                    save(sprintf('%s/%s', OUTDIR, filename), 'Signal');
        
                    clear Signal BpacEvts ISI info qrspeaks RR EEG isMT isMW
                end
            end
        else
            error('There are not the same number of .bdf files as biopac files for this participant');
        end
    end
end

function EEG = reformat_biosemi_chanlocs(EEG, chanlocs)
    % =======================================================
    % Adds and formats chanlocs data to the EEG struct
    %% Inputs:
    % EEG (Struct): The main EEG struct as specified in the documentation.
    % chanlocs (Cell Array): A cell array containing the labels and spatial data for
    % each EEG electrode
    %% Outputs:
    % The same EEG struct with EEG.chanlocs populated.
    % ========================================================

    EEG.chanlocs = [];   %clear this to start from scratch (for formatting purposes)
    
    % add channel location info from channel locations file to 'EEG.chanlocs'
    for ch = 1:length(chanlocs)
        EEG.chanlocs(ch).labels = chanlocs{ch, 1};   % will replace with the actual channel label (eg, 'A1')
        EEG.chanlocs(ch).type = [];   % we don't use this but it's important formatting for EEGLAB functions
        EEG.chanlocs(ch).theta = chanlocs{ch, 2};   %theta
        EEG.chanlocs(ch).radius = chanlocs{ch, 3};  %radius -- we don't use this but it's important formatting for EEGLAB functions
        EEG.chanlocs(ch).X = chanlocs{ch, 4};   % x coordinates
        EEG.chanlocs(ch).Y = chanlocs{ch, 5};   % y coordinates
        EEG.chanlocs(ch).Z = chanlocs{ch, 6};   % z coordinates
        EEG.chanlocs(ch).sph_theta = chanlocs{ch, 7};   %spherical theta
        EEG.chanlocs(ch).sph_phi = chanlocs{ch, 8};   %spherical phi
        EEG.chanlocs(ch).sph_radius = 87.535;  %was 85
        EEG.chanlocs(ch).urchan = ch;
        EEG.chanlocs(ch).ref = [];
    end
end

function Signal = add_biosemi_to_signal(EEG, FP1)
    % =======================================================
    %% Inputs:
    % EEG (Struct): The main EEG struct as specified in the documentation.
    % FP1 (String): The electrode name (eg. 'C29') used as reference for EMG and EOG bipolar signals.
    %% Outputs:
    % Signal struct with each biosemi modality populated (as per the documentation)
    % ========================================================

    % Add EOG, EMG, and EGG data to 'Signal'. Channels are bipolar
    % Find FP1 for referencing EOG and EMG electrodes - C29
    eindx = strmatch(upper(FP1), upper({EEG.chanlocs.labels}), 'exact');
    
    % Bipolar referencing of EMG, EOG, and EGG channels
    Signal.EMG.data = [EEG.data(129,:)-EEG.data(eindx,:); EEG.data(133,:)-EEG.data(134,:)];
    Signal.EOG.data = [EEG.data(130,:)-EEG.data(eindx,:); EEG.data(131,:)-EEG.data(132,:)]; % 4 electrodes (2 on the sides, 1 below, 1 above) converted to 2 bipolar
    % Signal.EOG.data = [EEG.data(130,:); EEG.data(131,:); EEG.data(132,:)];
    Signal.EGG.data = EEG.data(135,:)-EEG.data(136,:) ; % 2 electrodes converted to 1 bipolar
    
    %EMG
    Signal.EMG.chanlocs(1).labels = 'Corrugator';
    Signal.EMG.chanlocs(2).labels = 'Zygomaticus';
    Signal.EMG.event = EEG.event_coded;
    Signal.EMG.times = EEG.times;
    Signal.EMG.srate = EEG.srate;
    Signal.EMG.xmin = EEG.xmin;
    Signal.EMG.xmax = EEG.xmax;
    Signal.EMG.units = 'µV';
    
    %EOG
    Signal.EOG.chanlocs(1).labels = 'VEOG';
    Signal.EOG.chanlocs(2).labels = 'LEOG';
    Signal.EOG.event = EEG.event_coded;
    Signal.EOG.times = EEG.times;
    Signal.EOG.srate = EEG.srate;
    Signal.EOG.xmin = EEG.xmin;
    Signal.EOG.xmax = EEG.xmax;
    Signal.EOG.units = 'µV';
    
    %EGG
    Signal.EGG.event = EEG.event_coded;
    Signal.EGG.times = EEG.times;
    Signal.EGG.srate = EEG.srate;
    Signal.EGG.xmin = EEG.xmin;
    Signal.EGG.xmax = EEG.xmax;
    Signal.EGG.units = 'µV';
    
    %Organizing EEG data
    Signal.EEG.data = EEG.data;
    Signal.EEG.event = EEG.event_coded;
    Signal.EEG.srate = EEG.srate;
    Signal.EEG.chanlocs = EEG.chanlocs;
    Signal.EEG.times = EEG.times;
    Signal.EEG.xmin = EEG.xmin;
    Signal.EEG.xmax = EEG.xmax;
    Signal.EEG.units = 'µV';  
end

function Signal = add_bpac_to_signal(Signal, info, bpacdata, desired_bpac_indices)
    % =======================================================
    %% Inputs:
    % Signal (Struct): The main Signal struct containing all structs from
    % each modality (eg. Signal.EDA, Signal.EEG, etc.). See documentation
    % for more info.
    % info (Struct): A temporary struct containing metadata about the
    % biopac struct. 
    %   Fields: 
    %       info.srate: The bpac sample rate
    %       info.times: The time vector for the biopac signals
    %       info.event: Biopac events. May not be present at in this
    %       particular function call, it is populated later.
    % bpacdata (cxn matrix): A matrix containing all of the biopac data. c
    % is the number of channels and n is the timepoints.
    % desired_bpac_indices: An experimenter-defined list of the biopac channels relevant to us.
    %% Outputs:
    % Signal struct with each bpac modality populated as per the docs.
    % ========================================================

    % EDA
    Signal.EDA.units = 'microsiemens';   % the unit for both variables
    if isKey(desired_bpac_indices, 'EDA2004000211')
        Signal.EDA.raw = bpacdata.data(:, desired_bpac_indices('EDA2004000211'))';
    else
        Signal.EDA.raw = nan(1, length(bpacdata.data));
    end

    if isKey(desired_bpac_indices, 'Phasic EDA')
        Signal.EDA.phasic = bpacdata.data(:, desired_bpac_indices('Phasic EDA'))';
    else
        Signal.EDA.phasic = nan(1, length(bpacdata.data));
    end
    Signal.EDA.srate = info.srate;
    
    % ECG
    Signal.ECG.units = 'mV';
    Signal.ECG.hrUnits = 'beats per minute';
    if isKey(desired_bpac_indices, 'EOG1911000117') % ECG is named EOG
        Signal.ECG.data = bpacdata.data(:, desired_bpac_indices('EOG1911000117'))';
    else
        Signal.ECG.data = nan(1, length(bpacdata.data));
    end
    Signal.ECG.srate = info.srate;      

    % Respiratory
    Signal.Resp.units = 'volts';   % this seems weird that this is the unit
    if isKey(desired_bpac_indices, 'RSP1911000136')
        Signal.Resp.raw = bpacdata.data(:, desired_bpac_indices('RSP1911000136'))';
    else
        Signal.Resp.raw = nan(1, length(bpacdata.data));
    end
    
    Signal.Resp.rateUnits = 'breaths per min';
    if isKey(desired_bpac_indices, 'Resp Rate')
        Signal.Resp.rate = bpacdata.data(:, desired_bpac_indices('Resp Rate'))';
    else
        Signal.Resp.rate = nan(1, length(bpacdata.data));
    end
    Signal.Resp.srate = info.srate;
    
    % Blood pressure
    Signal.BP.units = 'mmHg'; % the unit for all 3 variables
    if isKey(desired_bpac_indices, 'BP')
        Signal.BP.raw = bpacdata.data(:, desired_bpac_indices('BP'))';
    else
        Signal.BP.raw = nan(1, length(bpacdata.data));
    end

    if isKey(desired_bpac_indices, 'Systolic BP')
        Signal.BP.systolic = bpacdata.data(:, desired_bpac_indices('Systolic BP'))';
    else
        Signal.BP.systolic = nan(1, length(bpacdata.data));
    end

    if isKey(desired_bpac_indices, 'Diastolic BP')
        Signal.BP.diastolic = bpacdata.data(:, desired_bpac_indices('Diastolic BP'))';
    else
        Signal.BP.diastolic = nan(1, length(bpacdata.data));
    end
    Signal.BP.srate = info.srate;
    
    % TREV
    Signal.TREV.data1_units = 'ohms';
    if isKey(desired_bpac_indices, 'TREV1')
        Signal.TREV.data1 = bpacdata.data(:, desired_bpac_indices('TREV1'))'; % Raw TREV, 4 electrodes, 2 time series
    else
        Signal.TREV.data1 = nan(1, length(bpacdata.data));
    end

    Signal.TREV.data2_units = 'ohms/sec';
    if isKey(desired_bpac_indices, 'TREV2')
        Signal.TREV.data2 = bpacdata.data(:, desired_bpac_indices('TREV2'))'; % Derivative measure to be analyzed
    else
        Signal.TREV.data2 = nan(1, length(bpacdata.data));
    end
    Signal.TREV.srate = info.srate;
end

function Signal = add_bp_calibration_metadata(Signal, pid, session, block_number)
    % =======================================================
    % The BP cuff calibrates during random blocks (listed in the experiment
    % notes). Those notes are converted manually into a CSV named bp_calibration.csv
    % which indicates for which blocks the BP cuff calibrated. The CSV is
    % expected to have 3 columns: PID, Session, Blocks. Each row lists the
    % participant (string, eg. 'emo001'), session number (int), and the block numbers (1xn array) for which the BP
    % calibrated during that session.
    % This function puts that metadata into the Signal.BP struct.
    %% Inputs:
    % Signal (struct): The main Signal struct.
    % pid (string): Participant ID
    % session (int)
    % block_number (int)
    %% Outputs:
    % Signal.BP.calibration populated.
    % ========================================================
    csv = dir(sprintf('C:/Users/Maryam/Documents/Data/emosense/Datasets/%s/bp_calibration.csv', pid));
    bp_calibration_table = readtable([csv.folder '/' csv.name], 'Delimiter', ',');
    session_idx = find(strcmp(bp_calibration_table.PID, pid) & bp_calibration_table.Session == session);
    calibration_blocks = str2double(strsplit(cell2mat(bp_calibration_table.Blocks(session_idx)), ','));
    Signal.BP.calibration = any(calibration_blocks == block_number);
end

function Signal = lowpass_filter_bpac(Signal, srate, locutoff)
    % =======================================================
    %% Inputs:
    % Signal (struct): The main Signal struct.
    % srate (int): The sample rate of biopac
    % locutoff (int): The frequency of the lowpass cutoff
    %% Outputs
    % Signal struct with bpac data lowpass filtered.
    % ========================================================
    fprintf('\tApplying lowpass filter to Biopac data...\n')    
    bporder = 20*(fix(srate/locutoff));
    c = fir1(bporder, locutoff/(srate/2));
    
    if ~all(isnan(Signal.EDA.raw(1, :)))
        Signal.EDA.raw = filtfilt(c, 1, Signal.EDA.raw(1, :));
    end
    
    if ~all(isnan(Signal.EDA.phasic(1, :)))
        Signal.EDA.phasic = filtfilt(c, 1, Signal.EDA.phasic(1, :));
    end

    if ~all(isnan(Signal.ECG.data(1, :)))
        Signal.ECG.data = filtfilt(c, 1, Signal.ECG.data(1, :));
    end

    if ~all(isnan(Signal.Resp.raw(1, :)))
        Signal.Resp.raw = filtfilt(c, 1, Signal.Resp.raw(1, :));
    end
    
    if ~all(isnan(Signal.Resp.rate(1, :)))
        Signal.Resp.rate = filtfilt(c, 1, Signal.Resp.rate(1, :));
    end
    
    if ~all(isnan(Signal.BP.raw(1, :)))
        Signal.BP.raw = filtfilt(c, 1, Signal.BP.raw(1, :));
    end

    if ~all(isnan(Signal.BP.systolic(1, :)))
        Signal.BP.systolic = filtfilt(c, 1, Signal.BP.systolic(1, :));
    end
    
    if ~all(isnan(Signal.BP.diastolic(1, :)))
        Signal.BP.diastolic = filtfilt(c, 1, Signal.BP.diastolic(1, :));
    end
    
    if ~all(isnan(Signal.TREV.data1(1, :)))
        Signal.TREV.data1 = filtfilt(c, 1, Signal.TREV.data1(1, :));
    end

    if ~all(isnan(Signal.TREV.data2(1, :)))
        Signal.TREV.data2 = filtfilt(c, 1, Signal.TREV.data2(1, :));
    end
end

function Signal = add_bpac_events_to_signal(Signal, info)
    % =======================================================
    %% Inputs:
    % Signal (struct)
    % info (Struct): As documented in other functions).
    %% Outputs:
    % Signal struct with bpac modalities containing .event fields.
    % ========================================================
    Signal.EDA.event = info.event_coded;

    Signal.ECG.event = info.event_coded;
    
    Signal.Resp.event = info.event_coded;

    Signal.BP.event = info.event_coded;

    Signal.TREV.event = info.event_coded;
end

function y = compute_modwt(data)
    % =======================================================
    % Compute maximal overlap discrete wavelet transform (MODWT)
    %% Inputs:
    % data (cxn matrix): The data matrix of the ECG (from ECG.data).
    % ========================================================
    wt = modwt(data, 5);   % Use the maximal overlap discrete wavelet transform (MODWT) to enhance the R peaks in the ECG waveform
    wtrec = zeros(size(wt));       % decompose the ECG waveform down to level 5 using the default 'sym4' wavelet.
    wtrec(4:5,:) = wt(4:5,:);      % Then, reconstruct a frequency-localized version of the ECG waveform using only the wavelet coefficients at scales 4 (11.25-22.5 Hz) and 5 (5.625-11.25 Hz)
    y = imodwt(wtrec,'sym4');
    y = abs(y).^2;     %Use the squared absolute values of the signal approximation built from the wavelet coefficients
end

function Signal = compute_avg_heartrate(Signal, qrspeaks)
    % =======================================================
    %% Inputs:
    % Signal (struct)
    % qrspeaks (1xn array): An array containing the amplitudes of the n QRS peaks of the ECG.
    %% Outputs:
    % Signal struct with Signal.ECG.avgHR and Signal.ECG.RRIntervals
    % populated
    % ========================================================
     assert(length(Signal.ECG.Rpeaklocs) == length(qrspeaks), 'Rpeaklocs and QRS peaks have a different length.')

    nSamples = length(Signal.ECG.data);
    avgHR = nan(1, nSamples);

    for s = 1:nSamples
        % Find the two R-peaks that surround the current sample
        laterRpeakIdx = find(Signal.ECG.Rpeaklocs > s, 1);
        if isempty(laterRpeakIdx) || laterRpeakIdx == 1
            % If 's' is before the first R-peak or after the last R-peak, the heart rate is undefined (leave as NaN)
            continue;
        end
        earlierRpeakIdx = laterRpeakIdx - 1;
        
        % Calculate the R-R interval in seconds
        RRInterval = (Signal.ECG.Rpeaklocs(laterRpeakIdx) - Signal.ECG.Rpeaklocs(earlierRpeakIdx)) / Signal.ECG.srate;
        
        candidate_heartrate = 60 / RRInterval;

        % If there was noise detected as an Rpeak
        if candidate_heartrate > 160
            % Find the index of smaller Rpeak (assumed to be noise)
            [~, smaller_idx] = min([qrspeaks(earlierRpeakIdx), qrspeaks(laterRpeakIdx)]);
            smallerRpeakIdx = earlierRpeakIdx * (smaller_idx == 1) + laterRpeakIdx * (smaller_idx == 2);

            % Delete the noisy Rpeak
            Signal.ECG.Rpeaklocs(smallerRpeakIdx) = [];

            % Recalculate the RpeakIdx after deletion
            laterRpeakIdx = find(Signal.ECG.Rpeaklocs > s, 1);
            earlierRpeakIdx = laterRpeakIdx - 1;

            % Re-calculate the RRInterval using the next peak
            RRInterval = (Signal.ECG.Rpeaklocs(laterRpeakIdx) - Signal.ECG.Rpeaklocs(earlierRpeakIdx)) / Signal.ECG.srate;
        end

        % Calculate the instantaneous heart rate (in beats per minute) at the current sample
        avgHR(s) = 60 / RRInterval;
    end

    for peak_idx = 2:length(Signal.ECG.Rpeaklocs)
        RRIntervals(1, peak_idx-1) = (Signal.ECG.Rpeaklocs(1,peak_idx) - Signal.ECG.Rpeaklocs(1,peak_idx-1)) / Signal.ECG.srate;
    end

    not_nan_indices = find(~isnan(avgHR));
    % assert(all(40 < avgHR(not_nan_indices) & avgHR(not_nan_indices) < 120), 'Average heart rate outside of the expected range')
    Signal.ECG.avgHR = avgHR;
    Signal.ECG.RRIntervals = RRIntervals * 1000; % RRIntervals need to be in ms for further processing
end

    
function info = code_raw_bpac_events(info, BpacEvts_first, BpacEvts_second)
    % =======================================================
    % Takes the raw biopac event timeseries and codes them into the info
    % struct so that each event has an index, type (the code for the event), and a latency (the sample number at which the event occurred).
    %% Inputs:
    % info (Struct): A struct containing the fields info.srate and
    % info.times.
    % BpacEvts (1xn array): The timeseries of biopac events.
    %% Outputs:
    % info struct with info.event populated.
    % ========================================================

    % Code Biopac Events into Raw EEG Coding Style
    event_idx = 0;
    assert(length(BpacEvts_first) == length(BpacEvts_second), "Biopac diodes have different time lengths.")
    for i = 1:length(BpacEvts_first)
        % this finds the onset of a new event -- events come through this
        % channel as '5'
        if BpacEvts_first(i) == 5 && BpacEvts_first(i-1) == 0
            event_idx = event_idx + 1;

            info.event(event_idx).type = 16;  %keep it numeric
            info.event(event_idx).value = '';
            info.event(event_idx).latency = i;
            info.event(event_idx).duration = 0;
            info.event(event_idx).urevent = event_idx;
        end

        if BpacEvts_second(i) == 5 && BpacEvts_second(i-1) == 0
            event_idx = event_idx + 1;

            info.event(event_idx).type = 32;  %keep it numeric
            info.event(event_idx).value = '';
            info.event(event_idx).latency = i;
            info.event(event_idx).duration = 0;
            info.event(event_idx).urevent = event_idx;
        end
    end
end

function source_struct = recode_successive_pulses(source_struct, successive_threshold)
    % =======================================================
    % Codes markers based on detected successive number of pulses. The
    % first video of each clip is coded as "1', the following clips are
    % coded as "4", response start is coded as 2, and crosshair start is
    % coded as 3.
    %% Inputs:
    % source_struct (struct): The struct for the given modality (eg. the EEG struct
    % or EDA struct containing EEG.data and EDA.data respectively).
    % successive_threshold (int): The minimum number of samples between 2 event
    %                       pulses that is used to create a code (eg. if successive_threshold ==
    %                       200 then 2 successive samples <200 samples apart are considered to be
    %                       an event code of '2'. 
    %% Outputs:
    % source_struct with .event_coded populated. .event_coded should mirror
    % the structure of source_struct.event, except with new codes in
    % source_struct.event_coded(idx).type.
    % ========================================================
    i = 1;
    j = 1;
    first_clip = true;
    while i <= length(source_struct.event)
        start_idx = i;
        count = 1;

        % Check for successive pulses
        while (i < length(source_struct.event)) && ((source_struct.event(i + 1).latency - source_struct.event(i).latency) <= successive_threshold)        
            count = count + 1;
            i = i + 1;
        end
        
        % Store new event codes 
        if count == 1
            if first_clip
                source_struct.event_coded(j).type = 1;
                first_clip = false;
            else
                source_struct.event_coded(j).type = 4;
            end
        else
            source_struct.event_coded(j).type = count;
            first_clip = true;
        end

        source_struct.event_coded(j).duration = source_struct.event(start_idx).duration;
        source_struct.event_coded(j).latency = source_struct.event(start_idx).latency;
        source_struct.event_coded(j).urevent = source_struct.event(start_idx).urevent;
        
        % Move to the next pulse
        i = i + 1;
        j = j + 1;
    end
end


function source_struct = fix_twopulse_issue(source_struct)
    % =======================================================
    % Codes markers based on detected successive number of pulses. The
    % first video of each clip is coded as "1', the following clips are
    % coded as "4", response start is coded as 2, and crosshair start is
    % coded as 3. 
    % This function fixes the double/triple pulses for any trials that are
    % supposed to be type = 1, i.e., they are start of the video 

    %% Inputs:
    % source_struct (struct): The struct for the given modality (eg. the EEG struct
    % or EDA struct containing EEG.data and EDA.data respectively). The
    % input to this function is the output of the recode_successive_pulses
   
    %% Outputs:
    % source_struct with .event_coded populated. .event_coded should mirror
    % the structure of source_struct.event, except with new codes in
    % source_struct.event_coded(idx).type.
    % ========================================================
    
    ev_type = [source_struct.event_coded(:).type]; 

    if ev_type(1)== 2 && ev_type(2)==1 % this is just for the beginning of blocks which is usually all except B1 

        ev_type(1) = 1 ; ev_type(2) = 4; 

    end
    idx = find(ev_type==3); 
    j = 1;  
    while idx(j) < length(ev_type)% iterate over crosshair, the next pulse after cross hair should be 1, i.e., start of video, find those instances that are coded as 2 or 3 instead of 1

        if ev_type(idx(j)+1) == 2 && ev_type(idx(j)+2) == 1 
            ev_type(idx(j)+1) = 1 ; ev_type(idx(j)+2) = 4; 

        elseif ev_type(idx(j)+1) == 3 && ev_type(idx(j)+2) == 1 
             ev_type(idx(j)+1) = 1 ; ev_type(idx(j)+2) = 4; 

        end
        j = j+1; 
    end

    for i = 1: length(source_struct.event_coded)
        source_struct.event_coded(i).type = ev_type(i); 
    end

end

function output = assert_event_structure(events, event_source, block_number)
    % =======================================================
    % Events should be of the form "1", "2", "3", "4", indicating video start,
    % response start, and crosshair start respectively.
    %% Inputs:
    % events (Struct): An event struct with fields .type and .latency
    % event_source (String): Either "Biopac" or "Biosemi".
    % ========================================================
    
    num_video_start = 0;
    num_response_start = 0;
    num_crosshair_start = 0;

    i = 1;
    while i < length(events)
        if block_number == 1
            if i == 1
                assert(events(i).type == 3, sprintf("Block 1 expected to start with 2min crosshair marker."))
                i = i + 1;
            end
        end
        
        if block_number == 7

            % if i < (length(events) - 2)
                
            assert(events(i).type == 1, sprintf('Expected video start event in %s', event_source))
            i = i + 1;
            num_video_start = num_video_start + 1;
            
            assert(events(i).type == 4, sprintf('Expected clip start event in %s', event_source))
            j = i + 1;
            while events(j).type == 4 && j <= length(events)
                j = j + 1;
            end
            i = j;
        
            if num_video_start ==6 % this is the last trial of B7    

                assert(events(i).type == 2, sprintf("Block 7 expected to have emotional response marker in last trial."))
                assert(events(i + 1).type == 2, sprintf("Block 7 expected to have global response marker in last trial."))
                assert(events(i + 2).type == 3, sprintf("Block 7 expected to end with 2min crosshair marker."))

                num_response_start = num_response_start + 1;
                num_crosshair_start = num_crosshair_start + 1;
                i = length(events); % this means break! 
            else 

                assert(events(i).type == 2, sprintf('Expected response start event in %s', event_source))
                i = i + 1;
                num_response_start = num_response_start + 1;
        
                assert(events(i).type == 3, sprintf('Expected crosshair start event in %s', event_source))
                i = i + 1;
                num_crosshair_start = num_crosshair_start + 1;
                  
                
            % elseif   i == (length(events) - 2)
            %     assert(events(i).type == 2, sprintf("Block 7 expected to have emotional response marker in last trial."))
            %     assert(events(i + 1).type == 2, sprintf("Block 7 expected to have global response marker in last trial."))
            %     assert(events(i + 2).type == 3, sprintf("Block 7 expected to end with 2min crosshair marker."))
            % 
            %     num_response_start = num_response_start + 1;
            %     num_crosshair_start = num_crosshair_start + 1;
            % break
                % return
            end 
                
        else

            assert(events(i).type == 1, sprintf('Expected video start event in %s', event_source))
            i = i + 1;
            num_video_start = num_video_start + 1;
            
            assert(events(i).type == 4, sprintf('Expected clip start event in %s', event_source))
            j = i + 1;
            while events(j).type == 4 && j <= length(events)
                j = j + 1;
            end
            i = j;
    
            assert(events(i).type == 2, sprintf('Expected response start event in %s', event_source))
            i = i + 1;
            num_response_start = num_response_start + 1;
    
            assert(events(i).type == 3, sprintf('Expected crosshair start event in %s', event_source))
            i = i + 1;
            num_crosshair_start = num_crosshair_start + 1;
            
        end
    end

    assert(num_video_start == 6 && num_response_start == 6 && num_crosshair_start == 6, "Expected 6 markers each for video start, response start, and crosshair start.")
end

function output = assert_event_sync_quality(bpac_events, biosemi_events, bpac_srate, biosemi_srate, bp_bs_sync_tolerence, PlotTimeLocking)
    % =======================================================
    % Biopac and Biosemi events should by synchronized to a common clock
    % within a certain tolerence level. This function asserts this.
    %% Inputs:
    % bpac_events (nx1 Struct):A struct where each row contains an event for biopac. The two relevant columns are 'latency'
    % (the sample at which the event occurred) and 'type', the code for the
    % event.
    % biosemi_events (nx1 Struct): Same structure as bpac_events
    % bpac_srate (int)
    % biosemi_srate (int)
    % bp_bs_sync_tolerence (int): The number of ms tolerence within which
    % bpac and biosemi markers should be synced.
    % PlotTimeLocking (bool): A decision to plot the sync quality.
    % ========================================================
    assert(length(bpac_events) == length(biosemi_events), 'Biosemi and Biopac have different numbers of events')

    % Check the quality of the synchronization between biopac and biosemi event timing
    for i = 2:length(bpac_events)
        biopacISI(i-1) = (bpac_events(i).latency - bpac_events(i-1).latency)/bpac_srate;
        biosemiISI(i-1) = (biosemi_events(i).latency - biosemi_events(i-1).latency)/biosemi_srate;
    end
    
    tdiffs = biopacISI - biosemiISI;
    bp_bs_isi_tolerence = bp_bs_sync_tolerence * 4; % multiply by 4 to account for +- on both sides of interval
    assert(all(tdiffs < bp_bs_isi_tolerence), 'Raw Biopac and Biosemi events are not accurately synced.')

    % Plot event timing synchronization quality between raw biopac and biosemi events
    if PlotTimeLocking
        figure;
        plot(tdiffs);

        xlabel('Event marker number')
        ylabel('Timing difference (Sec) between systems (biopac - biosemi)')
    end
end

function Signal = create_continuous_events_for_all(Signal)
    % =======================================================
    %% No longer needed.
    % Converts event structs into timeseries of event state (eg. video
    % presentation, response period, etc.) 
    % ========================================================
    Signal.EEG = create_continuous_events(Signal.EEG, size(Signal.EEG.data, 2));
    Signal.EOG = create_continuous_events(Signal.EOG, size(Signal.EOG.data, 2));
    Signal.EMG = create_continuous_events(Signal.EMG, size(Signal.EMG.data, 2));
    Signal.EGG = create_continuous_events(Signal.EGG, size(Signal.EGG.data, 2));
    Signal.EDA = create_continuous_events(Signal.EDA, size(Signal.EDA.raw, 2));
    Signal.ECG = create_continuous_events(Signal.ECG, size(Signal.ECG.data, 2));
    Signal.Resp = create_continuous_events(Signal.Resp, size(Signal.Resp.raw, 2));
    Signal.BP = create_continuous_events(Signal.BP, size(Signal.BP.raw, 2));
    Signal.TREV = create_continuous_events(Signal.TREV, size(Signal.TREV.data1, 2));
end

function Signal = add_behavioral_to_signal(Signal, behav, PID, session, block_number)
    % =======================================================
    %% Inputs:
    % Signal (Struct)
    % behav (table): The imported behavioral CSV as a table. Dimensions
    % vary across experiments.
    % sorted_blocks (1x7 array): A sorted array of block numbers.
    % PID (string)
    % session (int)
    % block_number (int)
    %% Outputs:
    % Signal struct with Signal.behavioral populated.
    % Signal.behavioral: TBD for participant 5
    % ========================================================
    self_reports = table2array(behav(:, 6:end));
    %% TO CHECK:
    % There are NaNs in emo005 behavioral files. Assume NaNs in self report
    % represent those lines.
    % Maryam : Nans are regarding the global ratings so no worries!! 
    % not_nan = ~isnan(self_reports);
    % good_rows = [];
    % for idx = 1:size(not_nan, 1)
    %     if all(not_nan(idx, :))
    %         good_rows = [good_rows, idx];
    %     end
    % end
    % behav = behav(good_rows, :);

    % Get rows for this session
    logical_table = behav(:, 2) == session;
    behav = behav(find(logical_table.Var2), :);
    Signal.behavior.global_ratings = behav(end, 4:width(behav(end, :)) - 2);
    
    % There should be 6 trials per block, 7 blocks per session + a Global Ratings row.
    assert(height(behav(:, 3)) == 43, "Unexpected number of trials in the behavioral data for this session.");

    % Get the rows for this block number
    start_row = 1 + (block_number - 1) * 6;
    end_row = start_row + 5;
    behav = behav(start_row:end_row, :);

    self_reports = self_reports(find(logical_table.Var2), :); 

    self_reports = self_reports(start_row:end_row, :);

    for idx = 1:height(behav)
        % start_row is the trial num for the entire session.
        Signal.behavior.data(idx).trial = start_row + idx - 1;

        Signal.behavior.data(idx).trial_id = table2array(behav(idx, 4));
        Signal.behavior.data(idx).videos = table2array(behav(idx, 5));
        Signal.behavior.data(idx).timestamp = table2array(behav(idx, 1));

        % Set the self report data for this trial
        conditions = {'Calmness', 'Entrancement', 'Confusion', 'Boredom', 'Nostalgia', 'Romance', 'Interest', 'Satisfaction', 'Relief', 'Excitement', 'Awkwardness', 'Amusement', 'Adoration', 'Joy', 'Admiration', 'Craving', 'Awe', 'AestheticAppreciation'};
        for jdx = 1:length(conditions)
            Signal.behavior.data(idx).(conditions{jdx}) = self_reports(idx, jdx);
        end
    end


     % add cowen's rating for each corresponding trial id this is computed in a
        % python notebook 
    Cowen_ratings = struct; 
    co_emotions = dir(sprintf('C:/Users/Maryam/Documents/Data/emosense/metadata/emotion_names_for_trials.csv'));
    co_names= readtable([co_emotions.folder,'/',co_emotions.name] , 'Delimiter', ',');
    co_names = table2array(co_names(2:end,1));

    co_rating_csv = dir(sprintf('C:/Users/Maryam/Documents/Data/emosense/metadata/max_emotions_for_trials.csv')); % This is Cowen ratings 
    co_rate = readtable([co_rating_csv.folder,'/',co_rating_csv.name] , 'Delimiter', ',');
    max_emo_strength = table2array(co_rate(:,3)); 
    co_rate = table2array(co_rate(:,[1:2 4:5])); % 3rd column is the intensity of the emotion with max score. saved in the second column as string 
    clear idx

    co_trial_id = co_rate(:,1);

    trial_idx = table2array(behav(:,4)); 
    trial_idx = cellfun(@(v)v(1:end-4),trial_idx,'UniformOutput',false); 
    trial_idx = strrep(trial_idx,'_',' ' );
    idx = find(cell2mat(cellfun(@(c)ismember(co_trial_id,c),{trial_idx},'UniformOutput',false)));
  

    for ww = 1:length(idx)
        if ~isempty(idx)
            % if length(idx)>1
            %     for kk = 1: length(idx)
            %         if strmatch(co_rate{idx(kk),1}(7:end), num2str(trial_id))
            %            idx =  idx(kk); 
            %            break
            %         end
            %     end
            % end
    
            Cowen_ratings.max_emo_strength = max_emo_strength(idx(ww)); 
            Cowen_ratings.max_emo_name = co_rate(idx(ww),2); 
            Cowen_ratings.avg_emo_vector = str2num(co_rate{idx(ww),3}); 
            Cowen_ratings.max_dimension_vector = str2num(co_rate{idx(ww),4}); 
            Cowen_ratings.names = co_names'; 
            Cowen_ratings.trial_id = trial_idx(ww); 
            Signal.behavior.Cowen_data(ww)= Cowen_ratings; 
        else 
            warning("trial id is not in the cowen rating file")
            Cowen_ratings.max_emo_strength = nan; 
            Cowen_ratings.max_emo_name = nan; 
            Cowen_ratings.avg_emo_vector = nan; 
            Cowen_ratings.max_dimension_vector = nan; 
            Cowen_ratings.names = nan; 
            Cowen_ratings.trial_id = nan; 
            Signal.behavior.Cowen_data(ww)= Cowen_ratings; % it will be an empty structure
        end
    end

    
end


