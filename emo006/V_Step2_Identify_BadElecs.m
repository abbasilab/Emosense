%% Code to identify EEG bad electrodes

%This script will look for bad electrodes in EEG channels and interpolate
%them. It requires 2 step checking. 
% 1. Checking via SD method
% 2. Checking via plotting topo maps

% Authors: Vincent Wang, Bijurika Nandi and Ted Zanto (2023)
% Maryam Bijanzadeh Modified the code for Emosense 005 

%% Parameters

clear all; clc; close all;

eeglab;
close all;

PIDs= {'emo006'};
sessions = 4;
blocks = 2;

for p = 1:length(PIDs)

    % File path for imported data from Step 1
    INDIR = sprintf('C:/Users/Maryam/Documents/Data/emosense/Datasets/%s/Session %d/Preprocessed/step1', PIDs{p}, sessions(1));

    % File path for output bad electrodes file
    OUTDIR = sprintf('C:/Users/Maryam/Documents/Data/emosense/Datasets/%s/Session %d/Preprocessed/step2', PIDs{p}, sessions(1));

    if ~exist(OUTDIR,'dir')
        mkdir(OUTDIR);
    end
end

%% Identify bad electrodes

% load data, identify bad electrodes for each block and save
for s = sessions
    for b = blocks
        % Load imported data from Step 1
        load(sprintf('%s/%s_session%d_block0%d_allSignals_final.mat', INDIR, PIDs{1}, s, b));
    
        fprintf('\t Identifying bad electrodes for session %d block %d...\n', s, b)
        
        % Electrodes which have standard dev > 2 * the avg standard
        % deviation are automatically considered bad
        sd = std(Signal.EEG.data(:,:), [], 2);
        cutoff = 2 * mean(sd);
        indx = find(sd >= cutoff);
        badelecs = {Signal.EEG.chanlocs(indx).labels};
        badelecs_auto_indices = indx;
        % clear sd cutoff indx
    
        % Checking each channel manually
    
        % Plot EEG data to identify bad electrodes
        % eegplot(Signal.EEG.data, 'srate', Signal.EEG.srate, 'eloc_file', Signal.EEG.chanlocs, 'winlength', 25, 'dispchans', 64 ,'title', sprintf('%s_session%d_block%d', PIDs{1}, s, b));

        eegplot(Signal.EEG.data, 'srate', Signal.EEG.srate, 'winlength', 123, 'dispchans', 64 ,'title', sprintf('%s_session%d_block%d', PIDs{1}, s, b));

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

        title(sprintf('%d sec data topoplot', nsec));
    
        % add bad channels
        elecs = input("enter indices of manually chosen bad electrodes in a column vector format");
        badelecs_idx = unique([indx; elecs]);

        badelecs = {Signal.EEG.chanlocs(badelecs_idx).labels};

        fprintf("Saving %s\n", string(badelecs));

        save(sprintf('%s/%s_session%d_block0%d_badelecs_final.mat', OUTDIR, PIDs{1}, s, b), 'badelecs');
        clear Signal badelecs sd indx
    end
end

close all;