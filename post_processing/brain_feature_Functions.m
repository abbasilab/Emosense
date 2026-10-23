classdef brain_feature_Functions
     %% ----------Author : Maryam Bijanzadeh 10/22/24------------------------------

    methods(Static)

        %% -------------------------------------get EEG frequency powers using PSD  --------------------------------

        function [spectra,frequencies,rel_spectra] = get_spectra_all_segments(sampling_frequency, signal, max_freq, segment_flag)
            % signal is the timeseries 
           rmpath('C:\Users\Maryam\Documents\GitHub\fieldtrip-20240309\realtime\src\buffer\matlab')

           if segment_flag % that means the passed signal is in segment format  
           
           % %% setting defaults 
           %  if isempty(window_length)
           %      window_length = 10; % seconds
           %  end
           %  if isempty(sampling_frequency)
           %      sampling_frequency = 512; % Hz
           %  end
           %  if isempty(overlap_percent)
           %      overlap_percent = 50; % percent
           %  end
           % 
           % 
           % 
           %  % Calculate derived parameters
           %  samples_per_window = window_length * sampling_frequency;
           %  overlap_samples = round(samples_per_window * (overlap_percent / 100));
           % 
           % 
           %  % Extract segments for spectral analysis
           %  segments = buffer(signal, samples_per_window, overlap_samples, 'nodelay');
           %  segments(:,size(segments,2))=[];  % last column is zeros 
           % 
           % 
            
            % Pre-allocate matrix to store spectra
                [num_segments, ~] = size(signal');
                % spectra = zeros(num_segments, samples_per_window/2 + 1);
                
                % Calculate the power spectral density for each segment
                for i = 1:num_segments
                    [spectra(i, :), frequencies] = pwelch(signal(:, i), [], 0, [], sampling_frequency);
                end

           else 

               [spectra, frequencies] = pwelch(signal, [], 0, [], sampling_frequency);

           end


            if ~isempty(max_freq)

                max_freq_idx = max(find(frequencies<max_freq)); 
            else 
        
                max_freq_idx = max(find(frequencies<51));
            end
        
            spectra = 10*log10(spectra(:,1:max_freq_idx)); % return spectra in DB  
            rel_spectra = spectra./sum(spectra); 
            frequencies = frequencies(1:max_freq_idx); 

        end 


        function [freq_feature, freq_feature_rel,freq_feature_log]= get_brain_freqfeatures(spectra, F,rel_spectra, log_flag)
            % spectra is a single vector
            % spectra could be computed by any method, F has to be in hertz
            % if spectra is computed by pwelch and the code above no need
            % for log 
             
           
            d_freq = [1 4]; 
            t_freq = [4 8]; 
        
            a_l_freq = [8 10]; 
            a_freq = [10 12]; 
            b_freq = [13 30]; 
            g_freq = [30 50]; 
        
            freq_range = horzcat([d_freq; t_freq;a_l_freq; a_freq; b_freq; g_freq]);
            freq_idx = zeros(6,2); 
            for i = 1: size(freq_range,1)
                freq_idx(i,:) = [min(find(F>=freq_range(i,1) & F<=freq_range(i,2))) max(find(F>=freq_range(i,1) & F<=freq_range(i,2)))];
            end
        
            freq_feature = zeros(1,6); % average  power for all frequencies are on columns 
            freq_feature_rel = zeros(1,6); % average relative power for all frequencies are on columns 
            freq_feature_log = zeros(1,6); % average log10 power for all frequencies are on columns 

            for i = 1: size(freq_range,1)
    
                freq_feature(:,i) = nanmean(spectra(freq_idx(i,1):freq_idx(i,2))); 
    
            end

            if ~isempty(rel_spectra)
                 for i = 1: size(freq_range,1)

                     freq_feature_rel(:,i) = nanmean(rel_spectra(freq_idx(i,1):freq_idx(i,2))); 
                 end

            end

            if ~isempty(log_flag)
                 for i = 1: size(freq_range,1)

                     freq_feature_log(:,i) =  10*log10(nanmean(spectra(freq_idx(i,1):freq_idx(i,2)))); 
                 end
            end
           
        end

        function [h]= plot_spectra_segment_surf(spectra,num_segments,frequencies)
            % pass like this for a given channel: [h]= brain_feature_Functions.plot_spectra_segment_surf(squeeze(spectra{i,1}(1,:,:)),11,frequencies)

            h = figure;
            % surf(frequencies, 1:num_segments, 10*log10(spectra), 'EdgeColor', 'none');
            surf(frequencies, 1:num_segments,(spectra), 'EdgeColor', 'none');

            xlabel('Frequency (Hz)');
            ylabel('Segment Number');
            zlabel('Power Spectral Density (dB/Hz)');
            title('Spectrograms of 10-second Segments');
        end




        % function [spectra,frequencies,rel_spectra] = get_time_freq_multitape(sampling_frequency, signal, window_length, overlap_percent,max_freq)
        %     % this uses the fieldtrip multitaper method 
        %    rmpath('C:\Users\Maryam\Documents\GitHub\fieldtrip-20240309\realtime\src\buffer\matlab')
        % 
        %     % signal is the timeseries 
        % 
        %     %% setting defaults 
        %     if isempty(window_length)
        %         window_length = 10; % seconds
        %     end
        %     if isempty(sampling_frequency)
        %         sampling_frequency = 512; % Hz
        %     end
        %     if isempty(overlap_percent)
        %         overlap_percent = 50; % percent
        %     end
        % 
        % 
        % 
        %     % Calculate derived parameters
        %     samples_per_window = window_length * sampling_frequency;
        %     overlap_samples = round(samples_per_window * (overlap_percent / 100));
        % 
        % 
        %     % Extract segments for spectral analysis
        %     segments = buffer(signal, samples_per_window, overlap_samples, 'nodelay');
        %     segments(:,size(segments,2))=[];  % last column is zeros 
        % 
        % 
        % 
        %     % Pre-allocate matrix to store spectra
        %     [num_segments, ~] = size(segments');
        %     % spectra = zeros(num_segments, samples_per_window/2 + 1);
        % 
        %     % Calculate the power spectral density for each segment
        %     for i = 1:num_segments
        %         [spectra(i, :), frequencies] = pwelch(segments(:, i), [], 0, [], sampling_frequency);
        %     end
        % 
        %     if ~isempty(max_freq)
        % 
        %         max_freq_idx = max(find(frequencies<max_freq)); 
        %     else 
        % 
        %         max_freq_idx = max(find(frequencies<51));
        %     end
        % 
        %     spectra = 10*log10(spectra(:,1:max_freq_idx)); % return spectra in DB  
        %     rel_spectra = spectra./sum(spectra); 
        %     frequencies = frequencies(1:max_freq_idx); 
        % 
        % end 

        function [segments] = make_segments(sampling_frequency, signal, window_length, overlap_percent)
            % signal is the timeseries 
           rmpath('C:\Users\Maryam\Documents\GitHub\fieldtrip-20240309\realtime\src\buffer\matlab')

            %% setting defaults 
            if isempty(window_length)
                window_length = 10; % seconds
            end
            if isempty(sampling_frequency)
                sampling_frequency = 512; % Hz
            end
            if isempty(overlap_percent)
                overlap_percent = 50; % percent
            end
         
            % Calculate derived parameters
            samples_per_window = window_length * sampling_frequency;
            overlap_samples = floor(samples_per_window * (overlap_percent / 100));
            
            
            % Extract segments for spectral analysis
            segments = buffer(signal, samples_per_window, overlap_samples, 'nodelay');
            segments(:,size(segments,2))=[];  % last column is zeros 
        end


        function [mt_fof_sepctra,mt_fof_spectra_log,freqs] = get_mtfoof(signal, fs)

            rmpath('C:\Users\Maryam\Documents\GitHub\fieldtrip-20240309\realtime\src\buffer\matlab')
                
            ndim = size(signal); 
            if ndim(1)> ndim(2) % meaning time samples are on first dimension 
                signal = signal'; 
            end 

            data_matrix = signal;  % size: [nSamples x nChan]
            
            % Basic info
            
            % Create FieldTrip data structure
            data = [];
            data.label = arrayfun(@(x) ['chan' num2str(x)], 1:size(data_matrix,1), 'UniformOutput', false);
            data.fsample = fs;
            data.trial = {data_matrix};
            data.time = { (0:size(data_matrix,2)-1)/fs }; 

            % compute the fractal and original spectra
            cfg               = [];
            cfg.foilim        = [1 51];
            cfg.pad           = 'nextpow2';
            % cfg.pad            = 4; 
            cfg.tapsmofrq     = 0.5;
            cfg.method        = 'mtmfft';
            cfg.output        = 'fooof_aperiodic';
            fractal = ft_freqanalysis(cfg, data);
            cfg.output        = 'pow';
            original = ft_freqanalysis(cfg, data);
        
            % subtract the fractal component from the power spectrum
            cfg               = [];
            cfg.parameter     = 'powspctrm';
            cfg.operation     = 'x2-x1';
            oscillatory = ft_math(cfg, fractal, original);
            
            % original implementation by Donoghue et al. 2020 operates through the semilog-power 
            % (linear frequency, log10-power) space and transformed back into linear-linear space.
            % thus defining an alternative expression for the oscillatory component as the quotient of 
            % the power spectrum and the fractal component
            cfg               = [];
            cfg.parameter     = 'powspctrm';
            cfg.operation     = 'x2./x1';  % equivalent to 10^(log10(x2)-log10(x1))
            oscillatory_alt = ft_math(cfg, fractal, original);
            mt_fof_sepctra = oscillatory_alt.powspctrm; 
            mt_fof_spectra_log= log(oscillatory_alt.powspctrm(1,:)); 
            freqs = oscillatory_alt.freq; 
        
        end


        %%  

        function concat_two_min_baseline = get_two_min(sig_struct,datafield1, datafield2)
        fields =  fieldnames(sig_struct);


            for i = 1:length(fields)
                field = fields{i};

                match_field = endsWith(field, '_twominbaseline', 'IgnoreCase', true);
                % if (match_field && ~isempty(Signal.EEG.(field))) % if the field matches with the name if it is empty an empty ,matrix is going to concantenate which is fine! 
                if match_field % if the field matches with the name if it is empty an empty ,matrix is going to concantenate which is fine! 

                    EEG_two_baseline = Signal.EEG.(field); 
                    break
                end 
                 
            end

        end
    end


 %     for datafield_idx = 1:length(datafields)
 %        datafield = char(datafields(datafield_idx));
 % 
 % 
 %        segment_start = 1;
 %        for trial_idx = 1:6
 %                % The final event is event code 2 for emotional response (no
 %                % grey screen) in emo001
 %                if  isequal(PID, 'emo001') && trial_idx == 6 
 %                    break
 %                end
 % 
 %                %% now replace the twio min baseline with cleaned signal for indexing, refer to V3_preprocessing_baseline
 %                fields =  fieldnames(sigstruct); 
 % 
 %                for i = 1:length(fields)
 %                    field = fields{i};
 % 
 %                    match_field = endsWith(field, '_twominbaseline', 'IgnoreCase', true);
 %                    % if (match_field && ~isempty(Signal.EEG.(field))) % if the field matches with the name if it is empty an empty ,matrix is going to concantenate which is fine! 
 %                    if match_field % if the field matches with the name if it is empty an empty ,matrix is going to concantenate which is fine! 
 %                        end_index = size(sigstruct.([strcat(datafield, '_twominbaseline')]),2); 
 %                        sigstruct.(field)= sigstruct.(datafield)(:,1:end_index); 
 %                        segment_start = end_index +1;  % start catenating the cross hair after the two-minbaseline
 %                        break
 %                    end
 % 
 %                end 
 %                event_length = size(sigstruct.([strcat(datafield, '_epoched')]){trial_idx, 3}, 2);
 %                segment_data = sigstruct.(datafield)(:, segment_start : segment_start + event_length-1);
 % 
 %                sigstruct.([datafield, '_epoched']){trial_idx, 1} = segment_data;
 % 
 %                segment_start = segment_start + event_length ;
 % 
 % 
 %        end
 %        % keep epoched which the baseline is cleaned and the data which is
 %        % concatenated baseline with two min if it is b1
 % 
 %        % sigstruct.(datafield) = sigstruct.([datafield, '_epoched']);
 %        % sigstruct = rmfield(sigstruct, [datafield, '_epoched']);
 % end
 
end


