%% Code to identify bad components from ICA

% This code is executed manually to identify ICA components per block 
% from Step 4 and save the bad ICA components 
% (only eye blinks and eye movements)

% Authors: Vincent Wang, Bijurika Nandi & Ted Zanto (2023)

%% Parameters

clear all; clc; close all;
eeglab;
close all;

load('C:\Users\mbijanzadeh\Documents\Data\emosense\metadata\128chanlocs_eeglab.mat');
% load('/home/vincent/projects/emosense/data-processing/data/metadata/64chanlocs_eeglab.mat');

PID = {'emo001'};
sessions = [3];

for session = sessions
    if session == 3
        % blocks = [1, 2, 3, 4, 5, 6, 7, 8];
        blocks = 8;

    else
        blocks = [4];
        blocks = [1, 2, 3, 4, 5, 6, 7];
    end
    
    % % File path for filtered data 
    InDir1 = sprintf('C:/Users/mbijanzadeh/Documents/Data/emosense/Datasets/%s/Session %d/Preprocessed/step3', PID{1}, session);
    
    % File path for ICA weights
    InDir2 = sprintf('C:/Users/mbijanzadeh/Documents/Data/emosense/Datasets/%s/Session %d/Preprocessed/step4', PID{1}, session);
    
    % % File path for output ICA bad components
    OutDir = sprintf('C:/Users/mbijanzadeh/Documents/Data/emosense/Datasets/%s/Session %d/Preprocessed/step5', PID{1}, session);
    
    if ~exist(OutDir,'dir')
        mkdir(OutDir);
    end
    
    %% Load ICA weights and concatenated data
    
    close all;
    
    for block_number = blocks
        % load data from Step 3
        load(sprintf('%s/%s_session%d_block0%d_allSignals_final_filtered_final.mat', InDir1, PID{1}, session, block_number)); 
        % load ICA weights from Step 4
        load(sprintf('%s/%s_session%d_block0%d_ICAweights_final.mat', InDir2, PID{1}, session, block_number));
        
        % Storing EEG channel locations to be used for component topomaps
        chanlocs = Signal.EEG.chanlocs;
        
        % Arranging EEG and EOG data together
        Data = [Signal.EEG.data; Signal.EOG.data];
        
        % Identifying ICA components
        

        winv = inv(ICA.wts*ICA.sph);
        acts = ICA.wts * ICA.sph * Data;
        % winv = pinv(ICA.wts / ICA.sph); % winv is Hermitian Run this when
        % you have reduced dimensions with PCA 
        
        % Plot EEG data prior to compare blink time stamps with components
        eegplot(Data, 'srate', Signal.EEG.srate, 'winlength', 25, 'dispchans', 32,  'title', sprintf('Data_%s_block0%d', PID{1}, block_number));
        % Plot ICA components
        eegplot(acts, 'srate', Signal.EEG.srate, 'winlength', 25, 'dispchans', 20 ,'title', sprintf('ICA_%s_block0%d', PID{1}, block_number));

        
        % Zica = ICA.Zica;
        % eegplot(Zica, 'srate', Signal.EEG.srate, 'winlength', 25, 'dispchans', 20);


        % Plot topomaps and time series of ICA components
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
        output_file = sprintf('%s/%s_session%d_block0%d_ICAbadcomp_final.mat', OutDir, PID{1}, session, block_number);
        % if exist(output_file, 'file') == 2
        %     load(output_file);
        %     fprintf("Existing bad ICA component file loaded successfully\n")
        % else
        %     ICA.BadComps = [];
        % end
        
        % fprintf("Existing Bad ICA Components: ")
        
        % bad_components = [1,2,3,5,6];  %block 1 , session 4 , removing 3 high frequency noise correlated with eye movement
        % bad_components = [1,2,3,5]; % block 2 , session 4 
        % bad_components = [1,2,3,4]; % block 3 , session 4 
        bad_components = [7,13]; % block 4 , session 4 
        % bad_components = [2,4]; % block 7 , session 4 
        % bad_components = [1,2]; % block 6 , session 4 


        % bad_components = [2,6,8];  %block 4 , session 3 
        % bad_components = [1,2,5];  %block 1, session 3
        % bad_components = [1,2,3,5];  %block 2, session 3 
        % bad_components = [4,10];  %block 3, session 3 
        % bad_components = [1,3,5,6];  %block 5, session 3 
        % bad_components = [2,4,5,6];  %block 6, session 3 
        % bad_components = [1:7];  %block 7, session 3 
        % bad_components = [1,3,4];  %block 8, session 3 

        % bad_components = [1,2,4];  %block 1, session 2
        % bad_components = [1,3,5];  %block 2, session 2
        % bad_components = [1,2,3];  %block 3, session 2
        % bad_components = [1,2,3,5];  %block 4, session 2
        % bad_components = [1,2,3];  %block 5, session 2
        % bad_components = [1,2,3,5];  %block 6, session 2
        % bad_components = [1,2,3];  %block 7, session 2


        % bad_components = [1,2,4];  %block1, session 1
         % bad_components = [1,2,3,5];  %block2, session 1
         % bad_components = [1,4,5];  %block3, session 1
         % bad_components = [2,5];  %block 4, session 1
         % bad_components = [2,6];  %block 5, session 1
         % bad_components = [1,2,3,4];  %block 6, session 1
         % bad_components = [1,2,3,4,7];  %block 7, session 1


        ICA.BadComps = unique([bad_components]);

        for comp = ICA.BadComps
            fprintf("%d ", comp)
        end
        fprintf("\n")
        
        fprintf('\t Saving file: %s/%s_session%d_block0%d_ICAbadcomp.mat\n\n', OutDir, PID{1}, session, block_number);
        
        save(output_file, 'ICA');   
        
        clear Signal Data1 Data2 Data ICA
    end
end


