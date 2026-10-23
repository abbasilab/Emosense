%% Code to preprocess Biosemi and Biopac data

% This script is the 3rd step in the processing pipeline for the Music and
% Meditation study. Here, we import a .mat file containing information for
% bad electrodes, and remove and interpolate those bad electrodes (if there 
% are any). We also highpass the EEG data at 0.5 Hz.
% We then identify artifacts in the data and remove them.
% Finally, we compute the spectral decomposition for EEG, EGG, and HRV (for
% only low freqencies). 


% Authors: Vincent Wang, AJ Simon, Bijurika Nandi, and Ted Zanto (2023)
% modified by Maryam Bijanzadeh for Emo 5


%% Parameters 

clear all; clc; close all;

eeglab;
close all;

addpath(genpath('C:\Users\Maryam\Documents\GitHub\emosense-preprocessing\helper_functions'))

sessions = [1:4];
PIDs = {'emo005'};

for session = sessions
    
    close all
    if session == 3 
        blocks = [1:7];
    elseif session == 2
        blocks = [3 4 5 6 7];
    elseif session == 4
        blocks = [1:3 5:7];
    elseif session == 1
        blocks = [1:4 6:7];

    end



    % File path for imported data from Step 1
    InDir1 = sprintf('C:/Users/Maryam/Documents/Data/emosense/Datasets/%s/Session %d/Preprocessed/step1', PIDs{1}, session);
    
    % File path for bad electrodes from Step 2
    InDir2 = sprintf('C:/Users/Maryam/Documents/Data/emosense/Datasets/%s/Session %d/Preprocessed/step2', PIDs{1}, session);
    
    % File path for output pre-processed data
    OUTDIR = sprintf('C:/Users/Maryam/Documents/Data/emosense/Datasets/%s/Session %d/Preprocessed/step3', PIDs{1}, session);
    
    % Load EEG electrode template
    % load('/Users/bijurika/Documents/Neuroscape/M&M States/EEG_template.mat');
    
    if ~exist(OUTDIR,'dir')
        mkdir(OUTDIR);
    end
    
    % list and sort the .mat files containing all signals
    signals = dir(sprintf('%s/*_allSignals_final.mat', InDir1));
    sigfiles = {signals.name};
    [~,sigidx] = sort(sigfiles);
    signals = signals(sigidx);
    
    % list and sort the .mat files containing bad electrode info
    bad_electrodes = dir(sprintf('%s/*_badelecs_final.mat', InDir2));
    elecfiles = {bad_electrodes.name};
    [~,eidx] = sort(elecfiles);
    bad_electrodes = bad_electrodes(eidx);
    
    hicutoff = 0.5;   %highpass cutoff for EEG
    
    % low frequencies to resolve for EEG, EGG, and HRV
    EEG_freqs = [0.05:0.1:0.35];
    EGG_freqs = [0.033:0.001:0.067];
    ECG_freqs = [0.04:0.01:0.4];
    
    %plot EGG?
    EGG_plot = 1;
    
    %artifact rejection (EEG) criteria -- use loose threshold at first, then
    %remove ocular artifacts with ICA, then do another artifact rejection with
    %stricter threshold
    EEGrejthresh = 500;   %when the EEG exceeds +/- this voltage , label as an artifact
    EEGlowthresh = 100;    %when a segment of artifactual EEG data returns back to this threshold, it is no longer an artifact
    minartlen = 50;    %the number of samples during the period before and after an artifact that the signals must remain at the 'clean' threshold for it to be considered clean
    
    % lim = [0 24];
    % etype = 16;
    
    % Visualize the power spectrum of filtered EEG data? This is for checking
    % if there was 60 Hz line noise that made it through the filter
    % Also check BP noise
    EEGfiltvis = 1;
    
    %% Loop through blocks
    if length(signals) == length(bad_electrodes)   %if this condition isnt met then there arent the same number of signal files as bad electrode files
        
        for block_number = blocks
            figure();
     
            filename = sprintf('%s_session%d_block0%d_filtered_final.mat', PIDs{1},session,block_number);
            % filename = sprintf('%s_filtered_eogtest.mat', signals(1).name(1:end-4));
            if ~exist([OUTDIR '/' filename],'file')
                fprintf("Block Number: %d...\n", block_number);
                %load signals file
                % load([signals(block_number).folder '/' signals(block_number).name])
                % load([signals(1).folder '/' signals(1).name])
                load(sprintf('%s/%s_session%d_block0%d_allSignals_final.mat', InDir1, PIDs{1}, session, block_number));

                %load file with list of bad electrodes (if it's empty, there
                %are no bad electrodes)
                % load([bad_electrodes(block_number).folder '/' bad_electrodes(block_number).name])
                load(sprintf('%s/%s_session%d_block0%d_badelecs_final.mat', InDir2, PIDs{1}, session, block_number));

                % load([bad_electrodes(1).folder '/' bad_electrodes(1).name])
                
                EEG = Signal.EEG;
                
                %these fields are required for the interpolation function to
                %work, since it's eeglab-based
                EEG.nbchan = size(Signal.EEG.data,1);   
                EEG.etc.eeglabvers = '14.1.2';  
                EEG.trials = 1;
                EEG.icaact = [];
                EEG.icawinv = [];
                EEG.icasphere = [];
                EEG.icaweights = [];
                EEG.icachansind = [];
                EEG.epoch = [];
                EEG.specdata = [];
                EEG.specicaact = [];
                EEG.setname = [];
                EEG.chaninfo = []; % EEGtemplate.chaninfo;
                EEG.reject = []; % EEGtemplate.reject;
                EEG.dipfit = [];
                
                % remove and interpolate bad electrodes 
                if length(badelecs) == 0
                    fprintf('There are no bad electrodes for block %d \n',block_number);
                else             
                    for e = 1:length(badelecs)
                        bad_electrode_indices(e) = strmatch(upper(badelecs{e}), upper({EEG.chanlocs.labels}), 'exact');
                    end
    
                    if ~isempty(bad_electrode_indices)
                        EEG = pop_interp(EEG, bad_electrode_indices, 'spherical');
                    end
    
                    EEG.FixedElecs = {EEG.chanlocs(bad_electrode_indices).labels};
                end
    
                Signal.EEG.data = EEG.data;
                
                % Check interpolated signal looks good
                % eegplot(Signal.EEG.data, 'srate', Signal.EEG.srate, 'winlength', 25, 'dispchans', 20 ,'title', sprintf('%s_block0%d', PIDs{1}, block_number));
                eegplot(Signal.EEG.data, 'srate', Signal.EEG.srate, 'eloc_file', Signal.EEG.chanlocs,'winlength', 123, 'dispchans', 20,'title', sprintf('%s_block0%d', PIDs{1}, block_number));



                % Plotting topomaps in 3 sections - first, mid and last part of
                % time series
                npartitions = 5;
                nsec = (length(Signal.EEG.data) / Signal.EEG.srate) / npartitions; % num of secs averaged for topo plot for manually checking electrodes
                mid = fix(length(Signal.EEG.data) / 2); % finding the mid of the time series
        
                figure();
                for i = 1:npartitions
                    subplot(1, npartitions, i)
                    topoplot(mean(Signal.EEG.data(:, fix((i - 1) * nsec * Signal.EEG.srate + 1):fix(i * nsec * Signal.EEG.srate)), 2), Signal.EEG.chanlocs);
                end

                title(sprintf('%d sec data topoplot, before artifact rejection', round(nsec)));

                %% compute EEG low frequencies 
    
                % the low frequencies will be stored in a separate variable
                % from 'Signal' struct. At the end of the script, they will be 
                % integrated with the rest of the signals, but saved as a
                % separate 'Signal' struct than the cleaned/highpass filtered
                % EEG
    
                % for c = 1:length(EEG_freqs)
                %     EEG_cycles(1,c) = (length(Signal.EEG.data)/Signal.EEG.srate)*EEG_freqs(1,c);
                % end
                % 
                % fprintf('Computing EEG time-frequency decomposition \n');
                % fprintf('Computing low frequencies for electrode ');
                % tic
                % for el = 1:size(Signal.EEG.data,1)
                %     fprintf('%d ',el);
                %     EEG_tf(el,:,:) = fMorletWavelet(Signal.EEG.data(el,:), Signal.EEG.srate, EEG_freqs, EEG_cycles);
                % end
                % fprintf('\n');
                % toc
                % 
                % %extract the magnitude from the complex numbers
                % fprintf('Extracting and storing power and phase info \n');
                % 
                % tic
                % EEGLowFreqs.pow(:,:,:) = abs(EEG_tf(:,:,:));
                % EEGLowFreqs.phase(:,:,:) = rad2deg(angle(EEG_tf(:,:,:)));
                % 
                % EEGLowFreqs.freqs = EEG_freqs;
                % toc
                
                %% highpass filter the EEG
                 
                Signal.EEG.data = double(Signal.EEG.data);
                
                tic
                horder = 3*(fix(Signal.EEG.srate/hicutoff));
                c = fir1(horder,hicutoff/(Signal.EEG.srate/2),'high');
                
                fprintf('\tApplying highpass filter... \n')
                for e = 1:size(EEG.data,1)
                    Signal.EEG.data(e,:) = filtfilt(c,1,Signal.EEG.data(e,:)); fprintf('.');
                    
    
                    if EEGfiltvis == 1
                      
                      if e == 1   % we only really need to check this on one channel
                          % code for checking how well the filter worked
                          y2 = fft(Signal.EEG.data(e,:));
                          p2 = abs(y2/length(Signal.EEG.data(e,:)));
                          p1 = p2(1:length(Signal.EEG.data(e,:))/2);
                          p1(1) = [];
                          freq = (Signal.EEG.srate*(0:(length(Signal.EEG.data)/2)-1))/length(Signal.EEG.data);
                          freq(1) = [];
    %                         freq = 0:0.05:60;
    %                       [Pxx, F] = pwelch(EEG.data(e,:),5*EEG.srate, EEG.srate,freq);
                          figure()
                          subplot(2,5,block_number); plot(freq,p1); 
    %                       figure(); plot(freq,Pxx);
                          eval(sprintf('title(''session %d block %d filtered EEG power spectrum'')',session,block_number))
                          xlabel('Frequency (Hz)')
                          ylabel('Power (µV^2)')
                          xlim([0 100]);
                          ylim([0 1]);
                         
                          clear y2 p2 pq freq
                      end
                  end
                end
                fprintf('\n');
                toc
                
                EEG.data = Signal.EEG.data;
                
                %% EEG artifact rejection    
                [artsegs, uncorrsegs, EEG] = fArt_rejEEG(EEG, EEGrejthresh, EEGlowthresh, minartlen);
                Signal.EEG.data = EEG.data;

                eegplot(Signal.EEG.data, 'srate', Signal.EEG.srate, 'eloc_file', Signal.EEG.chanlocs,'winlength', 123, 'dispchans', 32 ,'title', sprintf('%s_block0%d', PIDs{1}, block_number));

                clear EEG
                
                %% EEG artifact rejection -- low frequencies only
                     
                % use the EGG approach for low freq EEG artifact rejection -- epoch, save and
                % then delete (probably downsample everything reallllllly low
                % after)
                
                % Do we even want to do this? Who's to say that a non-monotonic
                % phase shift in EEG means its an artifact? That criteria for
                % EGG is based on what is known about the peristaltic
                % contractions of the stomach... we don't know shit about 0.05
                % Hz EEG
                
                
                %% Compute low frequencies - EGG and ECG
                %EGG
                for c = 1:length(EGG_freqs)
                    EGG_cycles(1,c) = (length(Signal.EGG.data)/Signal.EGG.srate)*EGG_freqs(1,c);
                end
                
                fprintf('Computing EGG time-frequency decomposition \n');
                tic
                EGG_tf = fMorletWavelet(Signal.EGG.data, Signal.EGG.srate, EGG_freqs, EGG_cycles);
                
                %extract the magnitude from the complex numbers
                for fr = 1:size(EGG_tf, 2)
                    for sm = 1:size(EGG_tf)
                        EGG_tf_pow(sm, fr) = abs(EGG_tf(sm, fr));
                    end
                end
                toc
                
                EGGpowspec.pow = mean(EGG_tf_pow,1);
                EGGpowspec.freq = EGG_freqs;
                
                peakFreq = find(EGGpowspec.pow == max(EGGpowspec.pow));
                
                EGGpowspec.peakfreq = EGG_freqs(1, peakFreq);
                
                tic
                Signal.EGG = fcompute_filter_EGG(Signal.EGG, EGGpowspec);
                toc
    
                try
                    if EGG_plot == 1
                        [Signal.EGG, figure_EGG_artifacts] = fdetect_EGG_artifacts(Signal.EGG, EGG_plot);
                    else
                        [Signal.EGG] = fdetect_EGG_artifacts(Signal.EGG, EGG_plot);
                    end
                catch
                    Signal.EGG.warning = {'artifact not found'};
                    Signal.EGG.artifact = [];
                end
                Signal.EGG.peakfreq = EGG_freqs(1, peakFreq);
                
                %ECG
                [Signal.ECG.LF, Signal.ECG.HF, Signal.ECG.LFHFratio] = fHRV_compute(Signal.ECG.RRIntervals, Signal.ECG.srate, 'spline', ECG_freqs, length(Signal.ECG.data));
                
                clear EGG_tf EGG_tf_pow avg_pows EEG_tf

                % Epoch data but temporarily concatenate epochs for EEG and EOG for use in
                % ICA.
                times_temp = Signal.EEG.times;

                %% reanalyze EDA 
                EDA = Signal.EDA.raw; 
                %         fs = Sig.Signal.EDA.srate; 
                %         newfs = fs; % no downsampling 
                % 
                [phasic,tonic,TimeVec,zEDAdata,Trigger_Ds,EDA_Ds]= physio_Functions.extract_EDA(Signal.EDA.srate,Signal.EDA.srate,EDA,[]);
                Signal.EDA.raw = EDA_Ds; 
                Signal.EDA.phasic = phasic; 
                Signal.EDA.tonic = tonic; 
                Signal.EDA.zED = zEDAdata; 
                Signal.EDA.timevec= TimeVec; 

                %% 
                Signal = epoch_by_trial(Signal, PIDs{1}, session, false);

                Signal.EEG.times = times_temp;                    
                %
                Signal.EEG = concat_epoched(Signal.EEG, {'data'});
                Signal.EOG = concat_epoched(Signal.EOG, {'data'});

                % if you wanna remove exception trials due to mismatch in
                % the markers run concat_epoched_Emo5
                % 
                % Signal.EEG = concat_epoched_Emo5(Signal.EEG, {'data'},PIDs{1},session,block_number);
                % Signal.EOG = concat_epoched_Emo5(Signal.EOG, {'data'},PIDs{1},session,block_number);

                %%  save primary Signal struct
                save(sprintf('%s/%s_session%d_block0%d_allSignals_final_filtered_final.mat', OUTDIR, PIDs{1}, session, block_number), 'Signal');

                % save(sprintf('%s/%s', OUTDIR, filename),'Signal');
    
    %             %% Prepare low freq EEG for epoching
    %             EEGLowFreqs.event = Signal.EEG.event;
    %             EEGLowFreqs.chanlocs = Signal.EEG.chanlocs;
    %             EEGLowFreqs.srate = Signal.EEG.srate;
    %             EEGLowFreqs.times = Signal.EEG.times;
    %             EEGLowFreqs.xmin = Signal.EEG.xmin;
    %             EEGLowFreqs.xmax = Signal.EEG.xmax;
    %             EEGLowFreqs.units = Signal.EEG.units;
    % 
    %             % Only epoch and save lowfreqs, epoch the rest in last step.
    %             dataflds_lfeeg = {'pow','phase'};
    %             EEGLowFreqs = V_fEpochMMBS(EEGLowFreqs, dataflds_lfeeg);
    % 
    %             Signal = rmfield(Signal, 'EEG');
    %             Signal.EEGLowFreqs = EEGLowFreqs;
    % 
    %             % save Signal struct with low frequency EEG
    %             Signal.EEGLowFreqs.freqs = EEG_freqs;
    %             filename2 = sprintf('%s%s', filename(1:end - 4), 'LowFreqEEG.mat');
    %             save(sprintf('%s/%s', OUTDIR, filename2), 'Signal');
    % %             save([OUTDIR filename(1:end-4) 'LowFreqEEG'],'Signal','-v7.3')
                clear Signal
            end
        end
        
    else
        fprintf('Error: the number of bad electrode files is unequal to the number of signal files \n');
    end
end
% 
% figure();
% for i = 1:13
%     subplot(3,5,i)
%     plot(squeeze(Signal.EDA.raw(:,:,i)));
%     title(sprintf('Trial %d', i));
% end