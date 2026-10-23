%% Code to clean bad ICA components, re-epoch, re-reference data and reject artifacts

% This code is used to clean bad ICA ciomponents from Step 5
% Then EEG data is re-referenced against average
% A final round of artifact rejection is done and clean data is saved

% Authors: Vincent Wang, Bijurika Nandi, AJ Simon & Ted Zanto (2023)

%% Parameters

clear all; clc; close all;
eeglab;
close all

addpath(genpath('C:\Users\Maryam\Documents\GitHub\emosense-preprocessing\helper_functions'))

PIDs = {'emo005'};
sessions = [2:4];

for session = sessions
    close all; 
   if session == 3 
        blocks = [1:7];
    elseif session == 2
        blocks = [3 4 5 6 7];
    elseif session == 4
        blocks = [1:3 5:7];
    elseif session == 1
        blocks = [1:4 6:7];

   end

    % File path for ICA bad components
    InDir1 = sprintf('C:/Users/Maryam/Documents/Data/emosense/Datasets/%s/Session %d/Preprocessed/step5', PIDs{1}, session);
    
    % % File path for pre ICA filtered data 
    InDir2 = sprintf('C:/Users/Maryam/Documents/Data/emosense/Datasets/%s/Session %d/Preprocessed/step3', PIDs{1}, session);
    
    % % File path for output clean epoched data
    OutDir = sprintf('C:/Users/Maryam/Documents/Data/emosense/Datasets/%s/Session %d/Preprocessed/step6', PIDs{1}, session);
    
    if ~exist(OutDir,'dir')
        mkdir(OutDir);
    end
    
    % Original: 150, 100, 100
    
    EEGrejthresh = 200;   %when the EEG exceeds +/- this voltage , label as an artifact
    EEGlowthresh = 150;    %when a segment of artifactual EEG data returns back to this threshold, it is no longer an artifact
    minartlen = 100;    %the number of samples during the period before and after an artifact that the signals must remain at the 'clean' threshold for it to be considered clean
    
    CleanDataPlot = 1; % Plot ICA component cleaned data
    ArtDataPlot = 1;  % Plot artifact rejected data
    
    %% Loading datadataflds_ecg
    
    fprintf('\t Loading data...\n');
    
    for block_number = blocks
        fprintf("Session %d, Block %d", session, block_number);
        % load preprocessed data from Step 3
        load(sprintf('%s/%s_session%d_block0%d_allSignals_final_filtered_final.mat', InDir2, PIDs{1}, session, block_number)); 
        % load bad ICA components from Step 5
        % load(sprintf('%s/%s_session%d_block0%d_ICAbadcomp_fastica.mat',InDir1, PIDs{1}, session, block_number)); 
        load(sprintf('%s/%s_session%d_block0%d_ICAbadcomp_final.mat',InDir1, PIDs{1}, session, block_number)); 

        % Arranging EEG and EOG data together
        Data = [Signal.EEG.data; Signal.EOG.data];
    
        %% Cleaning bad ccomponents
    
        fprintf('\t Cleaning bad ICA components...\n');
        % 
        % %% RunICA
        winv = inv(ICA.wts*ICA.sph);
        % winv = pinv(ICA.wts / ICA.sph);
        acts = ICA.wts * ICA.sph * Data;
        winv(:, ICA.BadComps) = [];
        acts(ICA.BadComps, :) = [];
        Cleandata = winv * acts;

        %% FastICA
        % winv = ICA.winv;
        % Zica = ICA.Zica;
        % mu = ICA.mu;
        % 
        % winv(:,ICA.BadComps)=[];
        % Zica(ICA.BadComps,:)=[];
        % z = winv*Zica+repmat(mu,1,size(Signal.EEG.data,2));
        % Cleandata = reshape(z,size(Data));
        EEG_clean = Cleandata(1:128, :);

        % Plot ICA component cleaned data
        if CleanDataPlot == 1 
            eegplot(Cleandata(1:128, :), 'srate', Signal.EEG.srate, 'winlength', 100, 'dispchans', 32, 'title', sprintf('%s_session%d_block0%d_ICA cleaned', PIDs{1}, session, block_number));   
        end
    
        %% Changed this for rerunning step 6 without the need to enter bad elecs 
        % elecs = input("enter indices of manually chosen bad electrodes in a column vector format");
        % badelecs_idx =  elecs;

        Sig6 = load(sprintf('%s/%s_block0%d_allSignals_cleaned_final.mat', OutDir, PIDs{1}, block_number)); 
        badelecs_idx = Sig6.Signal.EEG.final_bad_elecs; 
        clear Sig6


        %%
        if ~isempty(badelecs_idx)
            clean_idx = setdiff([1:128]',badelecs_idx);
        else 
            clean_idx = [1:128]';
        end

        % Deleting last 2 EOG channels
    
        %% Re-referencing the data
        fprintf('\tRe-referencing data...\n');
        EEG_clean(clean_idx,:) = EEG_clean(clean_idx,:) - repmat(mean(EEG_clean(clean_idx,:)), size(clean_idx,1), 1);
    
        eegplot(EEG_clean(clean_idx,:), 'srate', Signal.EEG.srate, 'eloc_file', Signal.EEG.chanlocs(clean_idx), 'winlength',100,'title',sprintf('%s_%s_Common averaged referrenced',PIDs{1}, block_number));
    
        %% Rejecting artifacts and Saving Data
        fprintf('\tRejecting artifacts and Saving data...\n');
    
        Signal.EEG.data = [];                
        Signal.EEG.data = EEG_clean;
    
        % Reject artifacts
        %These fields are required for the interpolation function to work, since it's eeglab-based
            
        EEG = Signal.EEG;
        EEG.nbchan = size(Signal.EEG.data,1);   
        EEG.etc.eeglabvers = '14.1.2';  
        EEG.trials = 1;  % artifact rejection will go through each epoch separately
        EEG.icaact = [];
        EEG.icawinv = [];
        EEG.icasphere = [];
        EEG.icaweights = [];
        EEG.icachansind = [];
        EEG.epoch = [];
        EEG.specdata = [];
        EEG.specicaact = [];
        EEG.setname = []; 
        EEG.chaninfo.plotrad = [];
        EEG.chaninfo.shrink = [];
        EEG.chaninfo.nosedir = '+X';
        EEG.chaninfo.nodatchans = [];
        EEG.chaninfo.icachansind = 1:128;
        EEG.chaninfo.filename = [];
        EEG.reject = [];
        EEG.event = [];
        EEG.dipfit = [];
    
        temp_EEG = EEG;
        % [artsegs, uncorrsegs, temp_EEG] = fArt_rejEEG(temp_EEG, EEGrejthresh, EEGlowthresh, minartlen);
        % EEG.data = temp_EEG.data;
        % clear temp_EEG      
    
        Signal.EEG.data = EEG.data;
        % Signal.EEG.artsegs = artsegs; %TODO: Check compare with Emo 6

        % --------removed the last artifact rejection and just save the
        % artifact segments 
        % Signal.EEG.temp_EEG = temp_EEG
        % Signal.EEG.uncorrsegs = uncorrsegs;
        % ArtData = Signal.EEG.data;
        
        % % Plot artifact rejected data
        % if ArtDataPlot == 1;    
        %     eegplot(ArtData, 'srate', Signal.EEG.srate, 'eloc_file', Signal.EEG.chanlocs, 'winlength',100,'title',sprintf('%s_%s_artifact rejected',PIDs{1}, block_number));
        % end
        
       
        % Re-epoch EEG and EOG after ICA
        Signal.EEG = re_epoch_edited(Signal.EEG, {'data'},PIDs{1});
        Signal.EOG = re_epoch_edited(Signal.EOG, {'data'},PIDs{1});
        Signal.EEG.final_bad_elecs= badelecs_idx; % these electrodes are not use in the CAR 
        plot_all_signals(Signal,PIDs{1}); % re-epoch is run on other peripheral physiology similar to EEG and EOG and onlyconcatenated visual part is plotted 
        fprintf("Saving data...\n")
        save(sprintf('%s/%s_block0%d_allSignals_cleaned_final.mat', OutDir, PIDs{1}, block_number), 'Signal'); 

        clear EEG uncorrsegs artsegs Data1 ArtData Data
        clear Signal
        
    end
end