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

% 3) EEG filter visualization -- set 'EEGfiltvis' to 1 to visualize thecompute_avg_heartrate
% power spectrum of the EEG data to see if the peak at 60 Hz has been
% removed by the lowpass filter.

% 4) Biopac filter visualization -- set 'Bpacfiltvis' to 1 to visualize the
% power spectrum of the biopac (ECG) data to see if a peak at 60 Hz has
% been removed by the lowpass filter.

% Authors:  Vincent Wang, Bijurika Nandi, Alexander Simon, and Theodore Zanto (2023)

function output = V_Step1_ImportAll()
    clear all; clc; close all; clf;
        
    %cd eeglab14_1_2b/;
    eeglab;
    close all; clc; clear all; clf;

    addpath(genpath('C:\Users\Maryam\Documents\GitHub\emosense-preprocessing'));
    addpath(genpath('C:\Users\Maryam\Documents\GitHub\fieldtrip-20240309')); 

    ft_defaults;
    
    PID = {'emo001'};
    % blocks = [1:7];
    blocks = [1];
    sessions = [1];
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
        
        %import channel locations file
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
        
        % Find index of first trial for each block
        for block_num = 1:size(unique_block_nums,1)
            block_indices(block_num, 1) = find(strcmp(string(unique_block_nums(block_num, 1)), string(behav.Var3)), 1);
        end
        
        [sorted_blocks, ord] = sort(block_indices);
        
        % Populate block_order with sorted blocks from behav
        for block_num = 1:size(unique_block_nums,1)
            block_order{block_num, 1} = behav{sorted_blocks(block_num), 3};
        end
        
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
        plot_bpac_markers = 0;
        
        if length(bdfs) == length(biopac)
            for block_number = blocks
                % for block_number= 2
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
        
                    % Restore bad marker cases
                    marker_exceptions = [
                        isequal(PID{1}, 'emo001') && session == 1 && block_number == 7
                        isequal(PID{1}, 'emo001') && session == 2 && block_number == 7
                    ];
                    
                    if ~any(marker_exceptions)
                        assert(length(EEG.event) == 36, 'Unexpected number of events in Biosemi');
                    end
        
                    if any(marker_exceptions)
                        % emo001, session 1, block 7 had a missing cross start (3 bursts)
                        % marker for the final trial in both biopac and biosemi.
                        if isequal(PID{1}, 'emo001') && session == 1 && block_number == 7
                            response_start_times = EEG.event_coded([EEG.event_coded.type] == 2);
                            assert(EEG.event_coded(end).type == 2, 'Expected emo001, session 1, block 7 to end with marker type 2')
                            response_time = 20.0364;
                            last_marker_idx = length(EEG.event_coded);
                            assert(last_marker_idx == 17, 'Expected emo001, session 1, block 7 to be missing 1 marker')
                            EEG.event_coded(last_marker_idx + 1).type = 3;
                            EEG.event_coded(last_marker_idx + 1).duration = 0;
                            EEG.event_coded(last_marker_idx + 1).latency = EEG.event_coded(last_marker_idx).latency + response_time * EEG.srate;
                            EEG.event_coded(last_marker_idx + 1).urevent = EEG.event_coded(last_marker_idx).urevent + EEG.event_coded(last_marker_idx).type;
                        end
                        
                        % emo001, session 2, block 7 only has markers until
                        % video start of trial 2.
                        if isequal(PID{1}, 'emo001') && session == 2 && block_number == 7
                            assert(length(EEG.event_coded) == 4, 'Expected emo001, session 2, block 7 to only have 4 markers')
                            assert(EEG.event_coded(1).type == 1, 'Unexpected event structure for emo001, session 2, block 7')
                            assert(EEG.event_coded(2).type == 2, 'Unexpected event structure for emo001, session 2, block 7')
                            assert(EEG.event_coded(3).type == 3, 'Unexpected event structure for emo001, session 2, block 7')
                            assert(EEG.event_coded(1).type == 1, 'Unexpected event structure for emo001, session 2, block 7')
                        end
                    end
                    
                    % Check event structure for all blocks except for session
                    % 2, block 7, which is expected to be broken.
                    if ~(isequal(PID{1}, 'emo001') && session == 2 && block_number == 7)
                        assert_event_structure(EEG.event_coded, 'Biosemi');
                    end
    
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
                    end
        
                    % Create an array of biopac channel labels
                    % (Trimming white space from each row and converting to cell
                    % array of strings)
                    bpac_labels = cellstr(strtrim(bpacdata.labels));
        
                    % Get indices of desired signals (varies between sessions)
                    desired_signal_exceptions = [
                        strcmp(PID{1}, 'emo001') && session == 1,
                    ];
                    desired_bpac_labels = {'EDA2004000211', 'Phasic EDA', 'EOG1911000117', 'RSP1911000136', 'Resp Rate', 'BP', 'Systolic BP', 'Diastolic BP', 'TREV1', 'TREV2'};
                    desired_bpac_indices = containers.Map;
                    for i = 1:length(desired_bpac_labels)
                        % emo001, session 1 is missing Phasic EDA and Resp Rate, but EDA was
                        % unuseable anyway
                        if strcmp(PID{1}, 'emo001') && session == 1 
                            if strcmp(desired_bpac_labels{i}, 'Phasic EDA') || strcmp(desired_bpac_labels{i}, 'Resp Rate')
                                continue
                            end
                        end
                        bpac_signal_idx = find(strcmp(bpac_labels, desired_bpac_labels{i}));
                        assert(1 <= bpac_signal_idx && bpac_signal_idx <= length(bpac_labels), 'Biopac signal label not found in the expected format.')
                        desired_bpac_indices(desired_bpac_labels{i}) = bpac_signal_idx;
                    end
                    
                    if ~any(desired_signal_exceptions)
                        assert(length(desired_bpac_indices) == length(desired_bpac_labels), 'Unexpectedly missing bpac signals')
                    end
                    
                    % Both emo001 session 1 and 2 have BP offset by +100
                    if strcmp(PID{1}, 'emo001') && (session == 1 || session == 2)
                       % Only offset for non-zero indices (where there is
                       % already data)
                       non_zero_indices = bpacdata.data(:, desired_bpac_indices('BP')) ~= 0;
                       bpacdata.data(non_zero_indices, desired_bpac_indices('BP')) = bpacdata.data(non_zero_indices, desired_bpac_indices('BP')) - 100;
                       non_zero_indices = bpacdata.data(:, desired_bpac_indices('Systolic BP')) ~= 0;
                       bpacdata.data(non_zero_indices, desired_bpac_indices('Systolic BP')) = bpacdata.data(non_zero_indices, desired_bpac_indices('Systolic BP')) - 100;
                       non_zero_indices = bpacdata.data(:, desired_bpac_indices('Diastolic BP')) ~= 0;
                       bpacdata.data(non_zero_indices, desired_bpac_indices('Diastolic BP')) = bpacdata.data(non_zero_indices, desired_bpac_indices('Diastolic BP')) - 100;
                    end
        
                    % If there are biopac signals expected to be missing, we
                    % will fill their data in as NaNs here
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
    
                    % Identify R peaks to compute avg heart rate
                    [qrspeaks, Signal.ECG.Rpeaklocs] = pan_tompkin(Signal.ECG.data, Signal.ECG.srate, HRVvalidation);
                    Signal = compute_avg_heartrate(Signal, qrspeaks);
    
                    %% Biopac event formatting
    
                    % Set the active diode
                    if strcmp(PID{1}, 'emo001')
                        bpac_active_diode = 'PD 32';
                    else
                        bpac_active_diode = 'PD 16';
                    end
    
                    bpac_event_channel_idx = find(strcmp(bpac_labels, bpac_active_diode));
                    BpacEvts = bpacdata.data(:, bpac_event_channel_idx);
        
                    % Plot Biopac markers
                    if plot_bpac_markers
                        subplot(2, 1, 2)
                        plot(BpacEvts)
                        legend("Biopac Markers")
                    end
                    
                    info = code_raw_bpac_events(info, BpacEvts);
                    
                    if ~any(marker_exceptions)
                        assert(length(info.event) ~= 0, 'There are no event markers in the biopac file')
                        assert(length(info.event) == 36, 'Unexpected number of event markers in Biopac')
                        assert(length(EEG.event) == length(info.event), 'Biopac and Biosemi have a different number of raw event markers')
                    end
                    
                    assert_event_sync_quality(info.event, EEG.event, info.srate, EEG.srate, bp_bs_sync_tolerence, PlotTimeLocking);
                    
                    % Recode Biopac Events for Successive Pulses
                    successive_threshold = 500;  % Maximum gap (samples) allowed to consider pulses as successive
                    info = recode_successive_pulses(info, successive_threshold);
        
                    if any(marker_exceptions)
                        % emo001, session 1, block 7 had a missing cross start (3 bursts)
                        % marker for the final trial in both biopac and biosemi.
                        if isequal(PID{1}, 'emo001') && session == 1 && block_number == 7
                            response_start_times = info.event_coded([info.event_coded.type] == 2);
                            assert(info.event_coded(end).type == 2, 'Expected emo001, session 1, block 7 to end with marker type 2')
                            response_time = 20.0364;
                            last_marker_idx = length(info.event_coded);
                            assert(last_marker_idx == 17, 'Expected emo001, session 1, block 7 to be missing 1 marker')
                            info.event_coded(last_marker_idx + 1).type = 3;
                            info.event_coded(last_marker_idx + 1).duration = 0;
                            info.event_coded(last_marker_idx + 1).latency = info.event_coded(last_marker_idx).latency + response_time * info.srate;
                            info.event_coded(last_marker_idx + 1).urevent = info.event_coded(last_marker_idx).urevent + info.event_coded(last_marker_idx).type;
                        end
    
                        % emo001, session 2, block 7 only has markers until
                        % video start of trial 2.
                        if isequal(PID{1}, 'emo001') && session == 2 && block_number == 7
                            assert(length(info.event_coded) == 4, 'Expected emo001, session 2, block 7 to only have 4 markers')
                            assert(info.event_coded(1).type == 1, 'Unexpected event structure for emo001, session 2, block 7')
                            assert(info.event_coded(2).type == 2, 'Unexpected event structure for emo001, session 2, block 7')
                            assert(info.event_coded(3).type == 3, 'Unexpected event structure for emo001, session 2, block 7')
                            assert(info.event_coded(1).type == 1, 'Unexpected event structure for emo001, session 2, block 7')
                        end
                    end
                    
                    % Check event structure for all blocks except for session
                    % 2, block 7, which is expected to be broken.
                    if ~(isequal(PID{1}, 'emo001') && session == 2 && block_number == 7)
                        assert_event_structure(info.event_coded, 'Biopac');
                    end
    
                    assert(length(EEG.event_coded) == length(info.event_coded), 'Total number of events between Biosemi and Biopac are not equal')
                    assert_event_sync_quality(info.event_coded, EEG.event_coded, info.srate, EEG.srate, bp_bs_sync_tolerence, PlotTimeLocking);
                    
                    Signal = add_bpac_events_to_signal(Signal, info);
                    
                    % Signal = create_continuous_events_for_all(Signal);
    
                    %% Add behavioral data to 'Signal' and format
                    Signal = add_behavioral_to_signal(Signal, behav, sorted_blocks, PID, session, block_number);
                    
                    continue;

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
    Signal.ECG.hrUnits = 'beats per minute'
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
    csv = dir(sprintf('C:/Users/Maryam/Documents/Data/emosense/Datasets/%s/bp_calibration.csv', pid));
    % csv = dir(sprintf('/home/vincent/projects/emosense/data-processing/data/metadata/bp_calibration.csv'));
    bp_calibration_table = readtable([csv.folder '/' csv.name], 'Delimiter', ',');
    session_idx = find(strcmp(bp_calibration_table.PID, pid) & bp_calibration_table.Session == session);
    calibration_blocks = str2double(strsplit(cell2mat(bp_calibration_table.Blocks(session_idx)), ','));
    Signal.BP.calibration = any(calibration_blocks == block_number);
end

function Signal = lowpass_filter_bpac(Signal, srate, locutoff)
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
    Signal.EDA.event = info.event_coded;

    Signal.ECG.event = info.event_coded;
    
    Signal.Resp.event = info.event_coded;

    Signal.BP.event = info.event_coded;

    Signal.TREV.event = info.event_coded;
end

function y = compute_modwt(data)
    wt = modwt(data, 5);   % Use the maximal overlap discrete wavelet transform (MODWT) to enhance the R peaks in the ECG waveform
    wtrec = zeros(size(wt));       % decompose the ECG waveform down to level 5 using the default 'sym4' wavelet.
    wtrec(4:5,:) = wt(4:5,:);      % Then, reconstruct a frequency-localized version of the ECG waveform using only the wavelet coefficients at scales 4 (11.25-22.5 Hz) and 5 (5.625-11.25 Hz)
    y = imodwt(wtrec,'sym4');
    y = abs(y).^2;     %Use the squared absolute values of the signal approximation built from the wavelet coefficients
end

function Signal = compute_avg_heartrate(Signal, qrspeaks)
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

function info = code_raw_bpac_events(info, BpacEvts)
    % Code Biopac Events into Raw EEG Coding Style
    event_idx = 0;
    for i = 1:length(BpacEvts)
        % this finds the onset of a new event -- events come through this
        % channel as '5'
        if BpacEvts(i) == 5 && BpacEvts(i-1) == 0
            event_idx = event_idx + 1;

            info.event(event_idx).type = 16;  %keep it numeric
            info.event(event_idx).value = '';
            info.event(event_idx).latency = i;
            info.event(event_idx).duration = 0;
            info.event(event_idx).urevent = event_idx;
        end
    end
end

function source_struct = recode_successive_pulses(source_struct, successive_threshold)
    i = 1;
    j = 1;
    while i <= length(source_struct.event)
        start_idx = i;
        count = 1;

        % Check for successive pulses
        while (i < length(source_struct.event)) && ((source_struct.event(i + 1).latency - source_struct.event(i).latency) <= successive_threshold)        
            count = count + 1;
            i = i + 1;
        end
        
        % Store new event codes
        source_struct.event_coded(j).type = count;
        source_struct.event_coded(j).duration = source_struct.event(start_idx).duration;
        source_struct.event_coded(j).latency = source_struct.event(start_idx).latency;
        source_struct.event_coded(j).urevent = source_struct.event(start_idx).urevent;
        
        % Move to the next pulse
        i = i + 1;
        j = j + 1;
    end
end

function output = assert_event_structure(events, event_source)
    assert(length(events) == 18, sprintf('Unexpected total number of events in %s', event_source))
    for i = 1:3:(length(events) - 3)
        assert(events(i).type == 1, sprintf('Unexpected video start event in %s', event_source))
        assert(events(i + 1).type == 2, sprintf('Unexpected response start event in %s', event_source))
        assert(events(i + 2).type == 3, sprintf('Unexpected crosshair start event in %s', event_source))
    end
end

function output = assert_event_sync_quality(bpac_events, biosemi_events, bpac_srate, biosemi_srate, bp_bs_sync_tolerence, PlotTimeLocking)
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

function Signal = add_behavioral_to_signal(Signal, behav, sorted_blocks, PID, session, block_number)

    self_reports = table2array(behav(:, 5:end));
    assert(~any(any(isnan(self_reports))), 'There are NaNs in the behavioral data')

    session_id = table2array(behav(:,2));
    block_id = table2array(behav(:,3)); 
    block_id(session~=session_id)= 0; % we just focus on current session 
    block_id(session==session_id)=  block_id(session==session_id)- min(block_id(session==session_id))+1; % convert block number such that they start from 1
    
    trial_indices =  intersect(find(block_id==block_number), find(session_id==session)); 

    % The overall trial number that this block starts at (eg. Block 2 starts at trial 7)
    % block_start_trial_num = sorted_blocks(block_number);
    block_start_trial_num = trial_indices(1);

    % assert( ...
    %     all(behav{block_start_trial_num:block_start_trial_num + 5, 3} == (block_number - 1)), ...
    %     sprintf('Behavioral data in block %d is missing trials', block_number) ...
    % )
    
    assert( ...
        all(block_id(block_start_trial_num:block_start_trial_num + 5) == (block_number)), ...
        sprintf('Behavioral data in block %d is missing trials', block_number) ...
    )
    % Iterate over each trial in this block (eg. for block 2,
    % trials 7 - 12 inclusive).
    for overall_trial_num = block_start_trial_num:(block_start_trial_num + 5)
        within_block_trial_num = overall_trial_num - block_start_trial_num + 1;
        
        % Set trial number in this block
        Signal.behavior.data(within_block_trial_num).trial = overall_trial_num;
        
        % Set the trial id (corresponds to its .mp4 filename)
        trial_path = cell2mat(behav{overall_trial_num, 4});
        backslash_indices = strfind(trial_path, '\');
        trial_name = trial_path(backslash_indices(end) + 1:strfind(trial_path, '.mp4') - 1);
        underscore_idx = strfind(trial_name, '_');
        trial_id = str2double(trial_name(underscore_idx + 1:end));
        
        Signal.behavior.data(within_block_trial_num).trial_id = trial_id;
        
        % Get the video names and timestamps for this trial
        trial_info = getTrialInfo();

        % Set the videos for this trial
        Signal.behavior.data(within_block_trial_num).videos = trial_info(trial_id).videoNames;
        
        % Since emo001, session 2, block 7 doesn't have marker data, don't
        % bother calculating video timestamps, which depend on them.
        % TODO: Fix marker data
        if ~(isequal(PID{1}, 'emo001') && session == 2 && block_number == 7)
            % Get the start and end markers for this trial
            trial_start_rows = Signal.EEG.event([Signal.EEG.event.type] == 1);
            trial_end_rows = Signal.EEG.event([Signal.EEG.event.type] == 2);
            trial_start = trial_start_rows(within_block_trial_num).latency / Signal.EEG.srate;  % convert to seconds
            trial_end = trial_end_rows(within_block_trial_num).latency / Signal.EEG.srate;  % convert to seconds
            
            % Generate timestamps for each video in this trial
            within_block_timestamps = trial_info(trial_id).timestamps;
            for idx = 1:length(trial_info(trial_id).timestamps) % timestamp in seconds
                 timestamp = trial_info(trial_id).timestamps(idx);
                 within_block_timestamps(idx) = timestamp + trial_start;
            end
    
            % Check that marker for trial end matches the video
            % timestamp for trial end
            % assert(within_block_timestamps(end) <= trial_end, 'Video timestamps do not match marker timestamps');
            fprintf("Video timestamp for trial end: %d\n", within_block_timestamps(end))
            fprintf("Marker timestamp for trial end: %d\n", trial_end)
            fprintf("Marker - Video timestamp difference: %d\n", trial_end - within_block_timestamps(end))
            
            % Set the video timestamps for this trial
            Signal.behavior.data(within_block_trial_num).timestamps = within_block_timestamps;
        else
            Signal.behavior.data(within_block_trial_num).timestamps = nan(1, length(trial_info(trial_id).videoNames));
        end
            
        % Set the self report data for this trial
        conditions = {'Calmness', 'Entrancement', 'Confusion', 'Boredom', 'Nostalgia', 'Romance', 'Interest', 'Satisfaction', 'Relief', 'Excitement', 'Awkwardness', 'Amusement', 'Adoration', 'Joy', 'Admiration', 'Craving', 'Awe', 'AestheticAppreciation'};
        for idx = 1:length(conditions)
            Signal.behavior.data(within_block_trial_num).(conditions{idx}) = self_reports(overall_trial_num, idx);
        end

        %% add cowen's rating for each corresponding trial id this is computed in a
        % python notebook 
        Cowen_ratings = struct; 
        co_emotions = dir(sprintf('C:/Users/Maryam/Documents/Data/emosense/metadata/emotion_names_for_trials.csv'));
        co_names= readtable([co_emotions.folder,'/',co_emotions.name] , 'Delimiter', ',');
        co_names = table2array(co_names(2:end,1));

        co_rating_csv = dir(sprintf('C:/Users/Maryam/Documents/Data/emosense/metadata/max_emotions_for_trials.csv')); % This is Cowen ratings 
        co_rate = readtable([co_rating_csv.folder,'/',co_rating_csv.name] , 'Delimiter', ',');
        max_emo_strength = table2array(co_rate(:,3)); 
        co_rate = table2array(co_rate(:,[1:2 4:5])); % 3rd column is the intensity of the emotion with max score. saved in the second column as string 

        idx = find(contains(co_rate(:,1),num2str(trial_id))); 

        if ~isempty(idx)
            if length(idx)>1
                for kk = 1: length(idx)
                    if strmatch(co_rate{idx(kk),1}(7:end), num2str(trial_id))
                       idx =  idx(kk); 
                       break
                    end
                end
            end
    
            Cowen_ratings.max_emo_strength = max_emo_strength(idx); 
            Cowen_ratings.max_emo_name = co_rate(idx,2); 
            Cowen_ratings.avg_emo_vector = str2num(co_rate{idx,3}); 
            Cowen_ratings.max_dimension_vector = str2num(co_rate{idx,4}); 
            Cowen_ratings.names = co_names'; 
            Cowen_ratings.trial_id = trial_id; 
            Signal.behavior.Cowen_data(within_block_trial_num)= Cowen_ratings; 
        else 
            warning("trial id is not in the cowen rating file")
            Cowen_ratings.max_emo_strength = nan; 
            Cowen_ratings.max_emo_name = nan; 
            Cowen_ratings.avg_emo_vector = nan; 
            Cowen_ratings.max_dimension_vector = nan; 
            Cowen_ratings.names = nan; 
            Cowen_ratings.trial_id = nan; 
            Signal.behavior.Cowen_data(within_block_trial_num) = Cowen_ratings; % it will be an empty structure
        end

    end 
    end