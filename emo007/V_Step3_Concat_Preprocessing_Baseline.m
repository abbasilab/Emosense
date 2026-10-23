%% Code to preprocess Biosemi and Biopac data

% This script is the 3rd step in the processing pipeline for Emosense 
% study. Here, we import a .mat file containing information for
% bad electrodes, and remove and interpolate those bad electrodes (if there 
% are any). We also highpass the EEG data at 0.5 Hz.
% We then identify artifacts in the data and remove them.
% Finally, we compute the spectral decomposition for EEG, EGG, and HRV (for
% only low freqencies). 


% Authors: Vincent Wang, AJ Simon, Bijurika Nandi, and Ted Zanto (2023)
% modified by Maryam Bijanzadeh for Emo 5 and it just concatenates baseline
% epochs checks wether the block is the first one and has the two_min and
% then concats the rest of the baselines that are saved in the 3rd column of the data_epoched from step 3. for further preprocessing 
% this only concatenates using the data from V3 


%% Parameters 

clear all; clc; close all;

eeglab;
close all;

addpath(genpath('C:\Users\Maryam\Documents\GitHub\emosense-preprocessing\helper_functions'))

sessions = [2:4];
PIDs = {'emo007'};

for session = sessions
    
    close all
 
    if session == 3 
        blocks = [1:7];
    elseif session == 2
        blocks = [1:5 7];
    elseif session == 4
        blocks = [1 3:4 6:7];
    elseif session == 1
        blocks = [1: 7];
        
    end

    % File path for imported data from Step 1
    InDir1 = sprintf('C:/Users/Maryam/Documents/Data/emosense/Datasets/%s/Session %d/Preprocessed/step3', PIDs{1}, session);
    
     
    % File path for output pre-processed data
    OUTDIR = sprintf('C:/Users/Maryam/Documents/Data/emosense/Datasets/%s/Session %d/Preprocessed/step3_baseline', PIDs{1}, session);
    
    % Load EEG electrode template
    % load('/Users/bijurika/Documents/Neuroscape/M&M States/EEG_template.mat');
    
    if ~exist(OUTDIR,'dir')
        mkdir(OUTDIR);
    end
    
    
   
    
    %% Loop through blocks
        
        for block_number = blocks
     
            filename = sprintf('%s_session%d_block0%d_allSignals_final_filtered_final.mat', PIDs{1},session,block_number);
            % filename = sprintf('%s_filtered_eogtest.mat', signals(1).name(1:end-4));
            if ~exist([OUTDIR '/' filename],'file')
                fprintf("Block Number: %d...\n", block_number);
                %load signals file
                % load([signals(block_number).folder '/' signals(block_number).name])
                % load([signals(1).folder '/' signals(1).name])
                load(sprintf('%s/%s_session%d_block0%d_allSignals_final_filtered_final.mat', InDir1, PIDs{1}, session, block_number));

            

                %% 
                               
                % check whether it is block 1 or the twominbaseline is not
                % empty , if it has value concatenate with all other
                % crosshairs 


                %%
                % just concat the crosshair 
                

                fields =  fieldnames(Signal.EEG); 

                for i = 1:length(fields)
                    field = fields{i};

                    match_field = endsWith(field, '_twominbaseline', 'IgnoreCase', true);
                    % if (match_field && ~isempty(Signal.EEG.(field))) % if the field matches with the name if it is empty an empty ,matrix is going to concantenate which is fine! 
                    if match_field % if the field matches with the name if it is empty an empty ,matrix is going to concantenate which is fine! 

                        EEG_two_baseline = Signal.EEG.(field); 
                        break
                    end 
                     
                end


                fields =  fieldnames(Signal.EOG); 

                for i = 1:length(fields)
                    field = fields{i};

                    match_field = endsWith(field, '_twominbaseline', 'IgnoreCase', true);
                    if (match_field)% if the field matches with the name and is not an empty matrix 
                        EOG_two_baseline = Signal.EOG.(field); 
                    
                    break 
                    end
                end

                %%                 
                % for i 
                EEG = concat_epoched_baseline(Signal.EEG, {'data'});
                EOG = concat_epoched_baseline(Signal.EOG, {'data'});

                Signal.EEG.data = [EEG_two_baseline EEG.data]; 
                Signal.EOG.data = [EOG_two_baseline EOG.data]; 


                % if you wanna remove exception trials due to mismatch in
                % the markers run concat_epoched_Emo5
                % 
                % Signal.EEG = concat_epoched_Emo5(Signal.EEG, {'data'},PIDs{1},session,block_number);
                % Signal.EOG = concat_epoched_Emo5(Signal.EOG, {'data'},PIDs{1},session,block_number);

                %%  save primary Signal struct
                save(sprintf('%s/%s_session%d_block0%d_allSignals_filtered_final_baseline.mat', OUTDIR, PIDs{1}, session, block_number), 'Signal');

                    clear Signal
            end
        end
        
    
end
% 
% figure();
% for i = 1:13
%     subplot(3,5,i)
%     plot(squeeze(Signal.EDA.raw(:,:,i)));
%     title(sprintf('Trial %d', i));
% end