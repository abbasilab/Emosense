function Signal = epoch_by_trial(Signal, PID, session, plot)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Epoch the integrated multimodal biosensing data into windows based on the
% diode markers for the biopac and biosemi systems.
% 
% Inputs: 
%       Signal (struct) = Signal struct that is the output of Step 1 with
%       .data fields for each modality unepoched (eg. Signal.EEG.data would
%       be a 128xn matrix).
%       session (int) = Session number
%       plot (bool) = Decision to plot the epoched data
%
%  Outputs: 
%       Signal (struct) = Signal struct where each modality is epoched into
%       a 6x3 cell array where each cell contains a cxn matrix (where c is
%       number of channels, n is number of timepoints). The row number is the trial number
%       for the epoch and column 1 corresponds to video presentation
%       period, column 2 to response period, and column 3 to crosshair
%       period. eg. Signal.EEG.data would be a 6x3 cell array where cell (2, 3) would be
%       a 128xm matrix where m is the number of samples for the crosshair
%       period of trial 2.
%
% Author: Vincent Wang
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%
    %% Epoch Cleaned Data
    if nargin < 5
        plot = false
    end
    
    %% Parameters
    eeglab;
    
    %% Epoching
    datafields = containers.Map();

    datafields('EEG') = {'data'}
    Signal.EEG = V_fEpochMMBS(Signal.EEG, datafields('EEG'));
    
    datafields('EMG') = {'data'};
    Signal.EMG = V_fEpochMMBS(Signal.EMG, datafields('EMG'));
    
    datafields('EOG') = {'data'};
    Signal.EOG = V_fEpochMMBS(Signal.EOG, datafields('EMG'));
    
    % datafields('EGG') = {'data'};   
    % Signal.EGG = V_fEpochMMBS(Signal.EGG, datafields('EGG'));

    if isempty(Signal.EGG.artifact) == 1
        datafields('EGG') = {'data', 'phase', 'amplitude', 'filtered', 'phase_degrees'};
        Signal.EGG = V_fEpochMMBS(Signal.EGG, datafields('EGG'));
        Signal.EGG.warning = {'artifact not found'};
    else
        datafields('EGG') = {'data', 'phase', 'amplitude', 'filtered', 'phase_degrees', 'artifact'};
        Signal.EGG = V_fEpochMMBS(Signal.EGG, datafields('EGG'));
    end
    
    datafields('EDA') = {'raw', 'phasic','tonic'};
    Signal.EDA = V_fEpochMMBS(Signal.EDA, datafields('EDA'));
    
    datafields('ECG') = {'data','avgHR','LF','HF','LFHFratio'};
    % datafields('ECG') = {'data','avgHR'};
    Signal.ECG = V_fEpochMMBS(Signal.ECG, datafields('ECG'));
    
    datafields('Resp') = {'raw', 'rate'};
    Signal.Resp = V_fEpochMMBS(Signal.Resp, datafields('Resp'));
    
    datafields('TREV') = {'data1','data2'};
    Signal.TREV = V_fEpochMMBS(Signal.TREV, datafields('TREV'));
    
    datafields('BP') = {'raw', 'systolic', 'diastolic'};
    Signal.BP = V_fEpochMMBS(Signal.BP, datafields('BP'));
    
    if plot
        modalities = {'EMG', 'EOG', 'EGG', 'EDA', 'ECG', 'Resp', 'TREV', 'BP'};
        num_modalities = length(modalities);

        keys = datafields.keys();
        num_channels = 0;
        for k = 1:length(keys)
            currentCell = datafields(keys{k});
            num_channels = num_channels + length(currentCell{1});
        end
    
        % Final plot of epoched data
        for trial_num = 1:size(Signal.EEG.data, 1)
            for segment_identity = 1:size(Signal.EEG.data, 2)
                if ~(trial_num == 6 && segment_identity == 3)
                    title_string = sprintf('%s_session%d_block0%d_trial0%d_segment0%d', PIDs{1}, session, block_number, trial_num, segment_identity);
                    % Plot the preprocessed EEG
                    eegplot(Signal.EEG.data{trial_num, segment_identity}, 'srate', Signal.EEG.srate, 'eloc_file', Signal.EEG.chanlocs, 'winlength', 25, 'title', sprintf('EEG %s', title_string));
                    freq_window = [0.5 55];
                    % Plot the PSD of EEG
                    plot_avg_psd(Signal.EEG.data{trial_num, segment_identity}, Signal.EEG.srate, freq_window, sprintf('Average PSD of EEG %s', title_string), false);             
                    plot_avg_psd(Signal.EEG.data{trial_num, segment_identity}, Signal.EEG.srate, freq_window, sprintf('Average PSD of EEG %s', title_string), true);             
                end
            end
        end
    end
end