%% Code to identify bad components from ICA

% This code is executed manually to identify ICA components per block 
% from Step 4 and save the bad ICA components 
% (only eye blinks and eye movements)

% Authors: Vincent Wang, Bijurika Nandi & Ted Zanto (2023)

%% Parameters

clear all; clc; close all;
addpath('C:\Users\Maryam\Documents\GitHub\eeglab2024.0');

eeglab;
close all;

load('C:\Users\Maryam\Documents\Data\emosense\metadata\128chanlocs_eeglab.mat');


PID = {'emo007'};
sessions = [4];

for session = sessions

     if session == 3 
        % blocks = [1:7];
        blocks = 7;
    elseif session == 2
        % blocks = [1:5 7];
        blocks= 7; 
    elseif session == 4
    % blocks = [1 3 4 6 7];
        blocks = [7];
    
    elseif session == 1
        blocks = [1:7];
        % blocks = 7;
    end
    
     % % File path for filtered data 
    InDir1 = sprintf('C:/Users/Maryam/Documents/Data/emosense/Datasets/%s/Session %d/Preprocessed/step3_baseline', PID{1}, session);
    
    % File path for ICA weights
    InDir2 = sprintf('C:/Users/Maryam/Documents/Data/emosense/Datasets/%s/Session %d/Preprocessed/step4_baseline', PID{1}, session);
    
    % % File path for output ICA bad components
    OutDir = sprintf('C:/Users/Maryam/Documents/Data/emosense/Datasets/%s/Session %d/Preprocessed/step5_baseline', PID{1}, session);
    
    if ~exist(OutDir,'dir')
        mkdir(OutDir);
    end
    
    %% Load ICA weights and concatenated data
    
    close all;
    
    for block_number = blocks
        % load data from Step 3
        load(sprintf('%s/%s_session%d_block0%d_allSignals_filtered_final_baseline.mat', InDir1, PID{1}, session, block_number)); 
        % load ICA weights from Step 4
        load(sprintf('%s/%s_session%d_block0%d_ICAweights_final_baseline.mat', InDir2, PID{1}, session, block_number));

        % load(sprintf('%s/%s_session%d_block0%d_ICAweights_fastica_kurtosis_1e8_1000.mat', InDir2, PID{1}, session, block_number));

        
        % Storing EEG channel locations to be used for component topomaps
        chanlocs = Signal.EEG.chanlocs;
        
        % Arranging EEG and EOG data together
        Data = [Signal.EEG.data; Signal.EOG.data];
        
        % Identifying ICA components
        
        %% RunICA
        winv = inv(ICA.wts*ICA.sph);
        acts = ICA.wts * ICA.sph * Data;
        % winv = pinv(ICA.wts / ICA.sph);

        % Plot EEG data prior to compare blink time stamps with components
        eegplot(Data, 'srate', Signal.EEG.srate, 'winlength', 25, 'dispchans', 32,  'title', sprintf('%s_block0%d', PID{1}, block_number));
        % Plot ICA components
        eegplot(acts, 'srate', Signal.EEG.srate, 'winlength', 25, 'dispchans', 20 ,'title', sprintf('%s_block0%d_ICA_weights', PID{1}, block_number));

        figure();
        for i = 1:2
            for j = 1:20
                subplot(4, 5, j)
                topoplot(ICA.wts(j,1:128), chanlocs); %chanlocs for 128 channel ICA
                title(sprintf('128 ch weight %d', j));
            end
        end

        figure();
        for i = 1:2
            for j = 21:40
                subplot(4, 5, j-20)
                topoplot(ICA.wts(j,1:128), chanlocs); %chanlocs for 128 channel ICA
                title(sprintf('128 ch weight %d', j));
            end
        end
        

        %% FastICA
        % Zica = ICA.Zica;
        % 
        % eegplot(Data, 'srate', Signal.EEG.srate, 'eloc_file', Signal.EEG.chanlocs, 'winlength', 25, 'dispchans', 32,'title', sprintf('%s_block0%d', PID{1}, block_number));
        % eegplot(Zica, 'srate', Signal.EEG.srate, 'winlength', 25, 'dispchans', 20,'title', sprintf('%s_block0%d', PID{1}, block_number));
        % 
        % % Plot topomaps and time series of ICA components
        % figure();
        % for i = 1:2
        %     for j = 1:20
        %         subplot(4, 5, j)
        %         topoplot(ICA.winv(j,1:128), chanlocs); %chanlocs for 128 channel ICA
        %         title(sprintf('128 ch weight %d', j));
        %     end
        % end
        % 
        % figure();
        % for i = 1:2
        %     for j = 21:40
        %         subplot(4, 5, j-20)
        %         topoplot(ICA.winv(j,1:128), chanlocs); %chanlocs for 128 channel ICA
        %         title(sprintf('128 ch weight %d', j));
        %     end
        % end
        
        % figure();
        % for i = 1:2
        %     for j = 1:20
        %         subplot(4, 5, j)
        %         topoplot(mean(acts(1:128,round(382*512):round(392*512)),2)', chanlocs); %chanlocs for 128 channel ICA
        %         title(sprintf('128 ch weight %d', j));
        %     end
        % end

        % figure();
        % for i = 1:2
        %     for j = 1:20
        %         subplot(4, 5, j)
        %         topoplot(ICA.wts(j,:), locs); %chanlocs for 64 channel ICA
        %         title(sprintf('64 ch weight %d', j));
        %     end
        % end


        % manually enter components
        % Reject only eye movements and blinks
        % output_file = sprintf('%s/%s_session%d_block0%d_ICAbadcomp_fastica_negentropy.mat', OutDir, PID{1}, session, block_number);
        % if exist(output_file, 'file') == 2
        %     load(output_file);
        %     fprintf("Existing bad ICA component file loaded successfully\n")
        % else
        %     ICA.BadComps = [];
        % end
        % bad_components = [3,6]; % block 4 , session 3 
        % bad_components = [1,22]; % block 1 , session 3 
        % bad_components = [2,8,21]; % block 3 , session 3 
        % bad_components = [2,9]; % block 5 , session 3 
        % bad_components = [1,4]; % block 6 , session 3 --> Noisy 
        % bad_components = [1,8]; % block 7 , session 3 


        % bad_components = [2,3,5]; % block 1 , session 4 
        % bad_components = [1,2,7]; % block 2 , session 4 
        % bad_components = [3,6]; % block 3 , session 4
        % bad_components = [2,3,9]; % block 4 , session 4 
        % bad_components = [1,2, 4,114]; % block 5 , session 4 
        % bad_components = [2,3,4]; % block 6 , session 4 --> 4 is noise 

        % bad_components = [1,10]; % block 1 , session 2
        % bad_components = [2,6]; % block 2, session 2
        % bad_components = [2]; % block 3 , session 2
        % bad_components = [3]; % block 4 , session 2 
        % bad_components = [2]; % block 5 , session 2 
        % bad_components = [1,5]; % block 6 , session 2 
        % bad_components = [1,6]; % block 7 , session 2 

        % bad_components = [1,8]; % block 1 , session 1 
        % bad_components = [1]; % block 2 , session 1
        % bad_components = [3]; % block 3 , session 1
        % bad_components = [1,3]; % block 4 , session 1 don't see eye blinks in the ICA 
        % bad_components = [4]; % block 5 , session 1 
        % bad_components = [1,3,24]; % block 7 , session 1 
% 
        
        bad_components = input("enter indices of ICA [ 3, 7, 10] ");

        ICA.BadComps = unique([bad_components]);

        for comp = ICA.BadComps
            fprintf("%d ", comp)
        end
        fprintf("\n")
        
        fprintf('\t Saving file: %s/%s_session%d_block0%d_ICAbadcomp.mat\n\n', OutDir, PID{1}, session, block_number);
        save(sprintf('%s/%s_session%d_block0%d_ICAbadcomp_final_baseline.mat', OutDir, PID{1}, session, block_number), 'ICA');   


        % save(output_file, 'ICA');   
        
        clear Signal Data1 Data2 Data ICA
    end
end
