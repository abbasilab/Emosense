function [epochs] = fEpochMMBS(sigstruct, datafields)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% epochs = fEpochMMBS(sigstruct,datafields,lim,event)
% 
% Epoch the integrated multimodal biosensing data into windows of a user
% defined length. 
% 
% Inputs: 
%       sigstruct = struct containing, at minimum, a field with an M x N 
%           matrix (M = channels, N = timepoints), a field with event info,
%           and a field indicating the sampling rate. The 'event' field 
%           should contain fields 'type' and 'latency'. The 'event.type' 
%           field indicates the marker number, and 'latency' indicates the 
%           sample when the event occurred.
%       datafields = a cell array containing the names of the fields within
%           the 'sigstruct' that contain sensor data.
%       lim = [startwindow stopwindow] to epoch relative stimulus latency
%           (in seconds)
%       etype = the event marker that serves as a reference for epoching
%           (e.g., '16')
%
%  Outputs: 
%       epochs = struct containing a field with an M x N x P matrix
%           (M = channels, N = timepoints, P = epochs) and a vector of 
%           timepoints within the epoch. All other fields in the data input
%           are retained. 
%
% Author: Vincent Wang, adapted from AJ Simon's version.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%
    % for TREV -- 2 channels, 2 diff units
    try
        epochs.units = sigstruct.units;
    end
    
    try   %for anything with channel location or label info
        epochs.chanlocs = sigstruct.chanlocs;
    end
    
    try
        epochs.hrUnits = sigstruct.hrUnits;
    end
    
    try   %for respiratory 
        epochs.rateUnits = sigstruct.rateUnits;
    end
    
    try   %for TREV
        epochs.data1Units = sigstruct.data1Units;
        epochs.data2Units = sigstruct.data2Units;
    end
    
    try   %for EEG
        epochs.EEG_freqs = sigstruct.EEG_freqs;
    end
    
    num_epochs = 6; % num trials
    
    % epochs.times(1:winsize) = (0:winsize-1)/(sigstruct.srate/1000);
    epochs.srate = sigstruct.srate;
    
    for datafield_idx = 1:length(datafields)
        datafield = datafields{datafield_idx};

        if ~isfield(epochs, datafield)
            % Initialize a cell of (num_epochs X trial/response/crosshair).
            % Each cell will store a matrix of num_channels X trial_length
            epochs.(datafield) = cell(num_epochs, 3);
        end
        
        [~, time_axis] = max(size(sigstruct.(datafield)));
        assert(time_axis == 2, 'Expected time axis to be in dimension 2');
        
        epoch_number = 1;
        for curr_event_idx = 2:length(sigstruct.event)
            curr_event_code = sigstruct.event(curr_event_idx).type;
            curr_event_latency = sigstruct.event(curr_event_idx).latency;

            prev_event_idx = curr_event_idx - 1;
            prev_event_code = sigstruct.event(prev_event_idx).type;
            prev_event_latency = sigstruct.event(prev_event_idx).latency;
            
            segment_data = sigstruct.(datafield)(:, prev_event_latency : curr_event_latency);
            if prev_event_code == 1 && curr_event_code == 2
                epochs.(datafield){epoch_number, 1} = segment_data;
            elseif prev_event_code == 2 && curr_event_code == 3
                epochs.(datafield){epoch_number, 2} = segment_data;
            else prev_event_code == 3 && curr_event_code == 1
                epochs.(datafield){epoch_number, 3} = segment_data;
                epoch_number = epoch_number + 1;
            end
        end
    end
end
