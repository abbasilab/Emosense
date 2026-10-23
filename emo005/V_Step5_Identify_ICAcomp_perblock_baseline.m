%% Code to identify bad components from ICA

% This code is executed manually to identify ICA components per block 
% from Step 4 and save the bad ICA components 
% (only eye blinks and eye movements)

% Authors: Vincent Wang, Bijurika Nandi & Ted Zanto (2023)

%% Parameters

clear all; clc; close all;
eeglab;
close all;

load('C:\Users\Maryam\Documents\Data\emosense\metadata\128chanlocs_eeglab.mat');


PID = {'emo005'};
sessions = [1];

for session = sessions
    if session == 3
        blocks = 7;
    elseif session ==4
        blocks = [7];
    elseif session ==2
        blocks = [7];
  
    elseif session ==1
        blocks = [1];
      
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
        % bad_components = [1,3,83,85]; % block 4 , session 3 
        % bad_components = [1,3,17]; % block 1 , session 3 
        % bad_components = [3,18]; % block 2 , session 3 
        % bad_components = [1,2]; % block 3 , session 3 
        % bad_components = [2,15,44]; % block 5 , session 3 
        % bad_components = [1,4]; % block 6 , session 3 
        % bad_components = [1,2,3]; % block 7 , session 3 


        % bad_components = [4,14]; % block 1 , session 4 
        % bad_components = [1,5]; % block 2 , session 4 
        % bad_components = [1,3,16]; % block 3 , session 4
        % bad_components = [1,2,4]; % block 5 , session 4 
        % bad_components = [1,5]; % block 6 , session 4 
        % bad_components = [1,2,4]; % block 7 , session 4 

        % bad_components = [1,2,3]; % block 3 , session 2
        % bad_components = [1,2]; % block 4, session 2
        % bad_components = [1,2,3,4]; % block 5 , session 2
        % bad_components = [1,5,10]; % block 6 , session 2 
        % bad_components = [1,5]; % block 7 , session 2 

        bad_components = [3,8,22,112]; % block 1 , session 1 
        % bad_components = [1,2,3,4]; % block 2 , session 1
        % bad_components = [1,2,4]; % block 3 , session 1
        % bad_components = [1,2,3]; % block 4 , session 1 
        % bad_components = [1,2,3]; % block 6 , session 1 
        % bad_components = [1,2,4]; % block 7 , session 1 

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


