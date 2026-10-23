%% Code to run ICA on epoched data

% This code runs ICA per block, per subject and saves the ICA weights
% Before running ICA, dimensionality is reduced by using PCA

% Authors: Vincent Wang, Bijurika Nandi and Ted Zanto (2023)
% Authors: Maryam Bijanzadeh modified for Emo 5(2024)

%%

clear all; clc; close all;
eeglab;
close all;

% Parameters

PIDs = {'emo007'};
sessions = [4];

 

% for session = sessions
session = sessions;

if session == 3 
blocks = [5:7];
elseif session == 2
blocks = [1:5 7];
elseif session == 4
% blocks = [1 3 4 6 7];
blocks = [ 4 6 7];

elseif session == 1
% blocks = [2:5 7];
blocks = [1:7];

end

tic;

% for p = 1: length(PIDs)
p = 1;
% File path for filtered data from Step 3        
InDir = sprintf('C:/Users/Maryam/Documents/Data/emosense/Datasets/%s/Session %d/Preprocessed/step3', PIDs{1}, session);

% File path for output ICA weights
OutDir = sprintf('C:/Users/Maryam/Documents/Data/emosense/Datasets/%s/Session %d/Preprocessed/step4', PIDs{1}, session);

if ~exist(OutDir,'dir')
    mkdir(OutDir);
end

%dimension: chanXtimesXepochs

% Load and concatenate data across epochs and blocks 

tic;
% poolobj = gcp('nocreate');
% delete(poolobj);
% G= parpool(4);
for block_number = blocks
    fprintf("Block Number: %d", block_number);

    % load data from Step 3
    load(sprintf('%s/%s_session%d_block0%d_allSignals_final_filtered_final.mat', InDir, PIDs{p}, session, block_number));

    %% EEG artifact rejection in 4s chunks
    % time_window = .25;
    % voltage_threshold = 25;
    % bad_electrode_threshold = 1;
    % Signal.EEG = create_continuous_events(Signal.EEG);
    % [EEG, EOG] = art_rej_chunks(Signal.EEG, Signal.EOG, time_window, voltage_threshold, bad_electrode_threshold);
    % 
    % Signal.EEG.data = EEG.data;
    % Signal.EOG.data = EOG.data;
    % Signal.EEG.event_continuous = EEG.event_continuous;
    % clear EEG eog_data
        
    % Arranging EEG and EOG data together
    Data = [Signal.EEG.data; Signal.EOG.data];
    % Data = [Dat.Signal.EEG.data; Dat.Signal.EOG.data];


    fprintf('\tRunning ICA...\n');
    %% RunICA
    %tic; 
    [wts, sph] = runica(Data); 
    %toc;
    ICA.wts = wts;
    ICA.sph = sph;
    ICA.blocks = blocks;


    fprintf('\t Saving file: %s/%s_session%d_block0%d_ICAweights.mat\n\n', OutDir, PIDs{p}, session, block_number);
    save(sprintf('%s/%s_session%d_block0%d_ICAweights_final.mat', OutDir, PIDs{p}, session, block_number), 'ICA');   
    clear Signal Data1 Data2 Data

    %% FastICA
    % [Zica, W, T, mu] = fastICA(Data, size(Signal.EEG.data, 1));
    % 
    % %Sort components
    % winv = T\W';
    % for c = 1:size(Signal.EEG.data, 1) %loop through components and calculate percent variance
    %     z = winv(:,c)*Zica(c,:);
    %     pvaf(c) = 100-100*mean(var(Data-z,[],2),1)./mean(var(Data,[],2),1);
    % end
    % [x indx] = sort(pvaf,2,'descend');
    % 
    % Zica = Zica(indx, :);
    % ICA.Zica = Zica;
    % ICA.winv = winv;
    % ICA.mu = mu;
    
    % fprintf('\t Saving file: %s/%s_session%d_block0%d_ICAweights.mat\n\n', OutDir, PIDs{p}, session, block_number);
    % save(sprintf('%s/%s_session%d_block0%d_ICAweights_fastica_kurtosis_1e8_1000.mat', OutDir, PIDs{p}, session, block_number), 'ICA');   
    % clear Signal Data1 Data2 Data
end

    
    
    toc;


% poolobj = gcp('nocreate');
% delete(poolobj);