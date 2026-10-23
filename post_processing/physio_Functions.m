classdef physio_Functions
     %% ----------Author : Maryam Bijanzadeh ------------------------------

    methods(Static)

        %% -------------------------------------analyze EDA --------------------------------
        function [Phasic,tonic,TimeVec,zEDAdata,Trigger_Ds,EDA_Ds]= extract_EDA(newfs,fs,EDA,Trigger)

            if ~isempty(Trigger)
                Trigger_Ds = resample(Trigger', newfs,fs); % This is either Photodiode or any other trigger pulse here we just downsample it 
            else 
                Trigger_Ds = []; 
            end

            if newfs == fs
                EDA_Ds = EDA; 
            else
                EDA_Ds = resample(EDA, newfs,fs);
            end
             
            lastTime = size(EDA_Ds,2);
            TimeVec = [0:1/newfs:(lastTime-1)/newfs];
            
            zEDAdata_raw=zscore(EDA_Ds);
            
            [b,dev,stats] = glmfit(TimeVec,zEDAdata_raw);
            yPredict = glmval(b,TimeVec,'identity')';
            zEDAdata=zEDAdata_raw-yPredict;
            
            tsamp=1/newfs;                     %sampling interval
            [Phasic, p, tonic, l, d, e, obj] = cvxEDA(zEDAdata, tsamp);
            Phasic = Phasic'; 
            tonic = tonic'; 
        end

        %% -------------------------------------TimeDomainHRV----------------------------

        function [meanRR, SDNN, RMSSD] = getTimeDomainHRV(RRintervals)
            meanRR = mean(RRintervals);
            SDNN = std(RRintervals);
            RMSSD = sqrt(mean(diff(RRintervals).^2));
        end


        %% ---------------------------This computes cardiac output and contractility from TREV and avg hr signal, from Bijurika's code 
        function [cont,tr] = getCardiacOuput_Contractility(Trev_Sig1,Trev_Sig2, Hr) 
                % Sig1 is data1 and Sig2 is data2, from Step1 of
                % preprocessing analyses of emosense 

               datum = squeeze(Trev_Sig2);
               cont.mean = mean(diff(datum));
               cont.max = max(diff(datum));
               cont.min = min(diff(datum));
 
               clear datum
               datum = squeeze(Trev_Sig1); % use data1 for velocity data
               h_rate = Hr;
               tr.int_velocity= trapz(datum);
               tr.CO = tr.int_velocity.*mean(h_rate);
               tr.info = { 'int_velocity -> integration of velocity (one final integration value)';'CO -> integration of velocity * heart rate'};

        end

        %% ----------------------This is mostly used for EGG --------------
        function [WaveformL,aac, MeanFractalL] = getWaveformL_fractal(signal)

            WaveformL = sum(abs(diff(signal))); 

            N = length(signal);
            
            for l = 1:N-1
                mf(l) = (signal(l+1) - signal(l))^2;
        
            end
            MeanFractalL = log10(sqrt(sum(mf)));



            %AAC (Average Amplitude Change)
            for  l = 1:N-1
                amp_ch(l) = abs(signal(l+1) - signal(l));
        
            end
            aac = mean(amp_ch);
          
        
        end

       %% --------------------------This is for respiratation rate analyses------------------
        
       function resp_rate = get_resp_rate(resp_signal,fs, plt_flag)
            t = 0:1/fs:length(resp_signal)/fs;
            resp_signal = detrend(resp_signal); % Remove baseline trend
            t = t(1:length(resp_signal));
            % Detect Peaks
            [peak_vals, peak_locs] = findpeaks(resp_signal, 'MinPeakHeight', 0.2, 'MinPeakDistance', fs/2);
            
            % Calculate Respiration Rate
            peak_intervals = diff(peak_locs) / fs; % Time between peaks (in seconds)
            resp_rate = 60 / mean(peak_intervals); % Convert to breaths per minute
            
            % Display Results
            disp(['Respiration Rate: ', num2str(resp_rate), ' breaths/min']);
            
            if plt_flag 
                % Plot Respiration Signal and Peaks
                figure;
                plot(t, resp_signal);
                hold on;
                plot(t(peak_locs), peak_vals, 'ro'); % Mark detected peaks
                xlabel('Time (s)');
                ylabel('Amplitude');
                title('Respiration Signal with Detected Peaks');
                grid on;
            end

       end

      %% ---------------------------Facial EMG analyses for Zygomatic and currogator muscles------------------------------


      function [normcorru,normzyg,vardiff_corru, vardiff_zygo] = preprocess_emg(data)
            
          % data is a a two row matrix 
            corrugatorEMG = data(1,:);
            zygomaticEMG = data(2,:);
            
            
            % ### 2️⃣ **Preprocessing the EMG Signals**  
            % - **Remove DC Offset (Mean Centering)**
            corrugatorEMG = detrend(corrugatorEMG);
            zygomaticEMG = detrend(zygomaticEMG);
            
            
            % - **Apply a Bandpass Filter (20–450 Hz typical for EMG)**
            
            fs = 512; % Sampling rate (adjust if needed)
            [b, a] = butter(4, [10 200] / (fs / 2), 'bandpass');
            corrugatorFiltered = filtfilt(b, a, corrugatorEMG);
            zygomaticFiltered = filtfilt(b, a, zygomaticEMG);
            
            
            % ### 3️⃣ **Rectification (Full-Wave)**
            % To get the absolute values:
            
            corrugatorRect = abs(corrugatorFiltered);
            zygomaticRect = abs(zygomaticFiltered);
            
          
            % ### 4️⃣ **Smoothing Using Moving Average and normalize to max**
            
            windowSize = round(fs/10); % Adjust based on data
            corrugatorSmooth = movmean(corrugatorRect, windowSize);
            zygomaticSmooth = movmean(zygomaticRect, windowSize);

            % normalize to max 
            normcorru = corrugatorSmooth/max(corrugatorSmooth); 
            normzyg = zygomaticSmooth/max(zygomaticSmooth); 

            
            vardiff_corru =  movvar(diff(normcorru),windowSize); 
            vardiff_zygo =  movvar(diff(normzyg),windowSize); 
            % var_corr = var(corrugatorFiltered, windowSize/5); 
            % var_zyg = var(zygomaticFiltered, windowSize/5);

      end




       %% -------------------------------This is for EOG analyses and blink rate extraction -------------------------
       function brate = get_blink_rate(VEOG,samplingRate,plt_flag)
         % VEOG is the vertical EOG channel 
        VEOG = -VEOG;  % check if this is needed
        lowCutoff = 1; % Hz
        highCutoff = 10; % Hz
        filterOrder = 4; % Filter order
        
        [b, a] = butter(filterOrder, [lowCutoff highCutoff] / (samplingRate / 2));
        filteredEOG = filtfilt(b, a, VEOG);


        % 2. Blink Detection (threshold-based)
        % Find peaks that correspond to blinks (adjust threshold as needed)
        threshold = 0.75 * max(filteredEOG); % Example threshold
        [~,locs] = findpeaks(filteredEOG, 'MinPeakHeight', threshold, 'MinPeakDistance', 0.2*samplingRate);  %Minimum peak distance to avoid double counting
            
        % 3. Blink Rate Calculation
        numBlinks = length(locs);
        signalDurationSeconds = length(VEOG) / samplingRate;
        brate = (numBlinks / signalDurationSeconds) * 60;  % Blinks per minute


        if plt_flag 
            % (Optional) Plot the results for visualization
            time = (0:length(VEOG)-1) / samplingRate;
            
            figure;
            subplot(2,1,1);
            plot(time, VEOG);
            title('Raw EOG Signal');
            xlabel('Time (s)');
            ylabel('Amplitude');
            
            subplot(2,1,2);
            plot(time, filteredEOG);
            hold on;
            plot(time(locs), filteredEOG(locs), 'ro'); % Mark detected blinks
            hold off;
            title('Filtered EOG with Detected Blinks');
            xlabel('Time (s)');
            ylabel('Amplitude');

        end
       end
            % from Bijurika 
%                 datum = -VEOG; % Blinks had negative amplitude based on bipolar derivation
% 
%                 % use golay filtering to smooth out baseline noise for better peak detection
%                 datum1 = sgolayfilt(detrend(-VEOG,5),7,101); % 5 (change parameters as fit)
% %                 plot(datum1,'k');hold on; 
%                 [PKS,LOCS] = findpeaks(datum1, 'MinPeakHeight',blink_height(p), 'MinPeakDistance',blink_dist(p));
%                 brate = length(PKS)*2.5; % change this factor according to the data
% 
%                 % To check if peaks were calculated right, plot the data
%                  if plt_flag 
%                     plot(datum1,'k');hold on;
%                     for t = 1:length(LOCS)
%                         plot(LOCS(t),PKS(t),'r*'); hold on;
%                     end
%                  end

       
         %% ---------------------------This just gets general statistical features including min, max, mean, std, kurtosis, variance of the difference(change)
         function [Mean,Min,Max,Std,Kurt] = getSimpleStatfeatures(signal) 
                
               datum = squeeze(signal);
               Mean= mean(datum);
               Max = max(datum);
               Min = min(datum);
               Std = std(datum); 
               Kurt = kurtosis(datum); 

               clear datum
               
         end
%%
        function [mav,rms] = get_mean_absoluteValue_rms(signal)

             mav = squeeze(mean(abs(signal)));
             rms = sqrt(mean(signal.^2));

        end

%%   
        function y = compute_modwt(data)
            % =======================================================
            % Compute maximal overlap discrete wavelet transform (MODWT)
            %% Inputs:
            % data (cxn matrix): The data matrix of the ECG (from ECG.data).
            % ========================================================
            wt = modwt(data, 5);   % Use the maximal overlap discrete wavelet transform (MODWT) to enhance the R peaks in the ECG waveform
            wtrec = zeros(size(wt));       % decompose the ECG waveform down to level 5 using the default 'sym4' wavelet.
            wtrec(4:5,:) = wt(4:5,:);      % Then, reconstruct a frequency-localized version of the ECG waveform using only the wavelet coefficients at scales 4 (11.25-22.5 Hz) and 5 (5.625-11.25 Hz)
            y = imodwt(wtrec,'sym4');
            y = abs(y).^2;     %Use the squared absolute values of the signal approximation built from the wavelet coefficients
        end
%% 
    
        function [Rpeaklocs, RRIntervals, avgHR ] = compute_avg_heartrate(ECG_data, ECG_srate)
                % =======================================================
                %% Inputs:
                % ECG trace 
                % and ECG srate  
                % qrspeaks (1xn array): An array containing the amplitudes of the n QRS peaks of the ECG.
                %% Outputs:
                % Signal struct with Signal.ECG.avgHR and Signal.ECG.RRIntervals
                % populated
                % ========================================================

                [qrspeaks, Rpeaklocs] = pan_tompkin(ECG_data,ECG_srate, 1);
                
                 assert(length(Rpeaklocs) == length(qrspeaks), 'Rpeaklocs and QRS peaks have a different length.')
            
                nSamples = length(ECG_data);
                avgHR = nan(1, nSamples);
            
                for s = 1:nSamples
                    % Find the two R-peaks that surround the current sample
                    laterRpeakIdx = find(Rpeaklocs > s, 1);
                    if isempty(laterRpeakIdx) || laterRpeakIdx == 1
                        % If 's' is before the first R-peak or after the last R-peak, the heart rate is undefined (leave as NaN)
                        continue;
                    end
                    earlierRpeakIdx = laterRpeakIdx - 1;
                    
                    % Calculate the R-R interval in seconds
                    RRInterval = (Rpeaklocs(laterRpeakIdx) - Rpeaklocs(earlierRpeakIdx)) / ECG_srate;
                    
                    candidate_heartrate = 60 / RRInterval;
            
                    % If there was noise detected as an Rpeak
                    if candidate_heartrate > 160
                        % Find the index of smaller Rpeak (assumed to be noise)
                        [~, smaller_idx] = min([qrspeaks(earlierRpeakIdx), qrspeaks(laterRpeakIdx)]);
                        smallerRpeakIdx = earlierRpeakIdx * (smaller_idx == 1) + laterRpeakIdx * (smaller_idx == 2);
            
                        % Delete the noisy Rpeak
                        Rpeaklocs(smallerRpeakIdx) = [];
            
                        % Recalculate the RpeakIdx after deletion
                        laterRpeakIdx = find(Rpeaklocs > s, 1);
                        earlierRpeakIdx = laterRpeakIdx - 1;
            
                        % Re-calculate the RRInterval using the next peak
                        RRInterval = (Rpeaklocs(laterRpeakIdx) - Rpeaklocs(earlierRpeakIdx)) / ECG_srate;
                    end
            
                    % Calculate the instantaneous heart rate (in beats per minute) at the current sample
                    avgHR(s) = 60 / RRInterval;
                end
            
                for peak_idx = 2:length(Rpeaklocs)
                    RRIntervals(1, peak_idx-1) = (Rpeaklocs(1,peak_idx) - Rpeaklocs(1,peak_idx-1)) / ECG_srate;
                end
            
                not_nan_indices = find(~isnan(avgHR));
                % assert(all(40 < avgHR(not_nan_indices) & avgHR(not_nan_indices) < 120), 'Average heart rate outside of the expected range')
                RRIntervals = RRIntervals * 1000; % RRIntervals need to be in ms for further processing
        end

        %% ------------------------------- Horizontal Eye movement---------------------

        function [saccades, velocity] = extract_saccades(loc, roc, fs, threshold_deg_s)
            % EXTRACT_SACCADES Detects horizontal eye movements from EOG channels
            % Inputs:
            %   loc: Left Outer Canthus signal (vector)
            %   roc: Right Outer Canthus signal (vector)
            %   fs: Sampling frequency (Hz)
            %   threshold_deg_s: Velocity threshold in degrees/second
            
            % 1. Calculate Differential Signal (Horizontal Plane)
            % Assumes LOC - ROC represents horizontal movement
            diff_eog = loc - roc;
            
            % 2. Band-pass filtering (0.1 - 30 Hz)
            nyquist = fs / 2;
            [b, a] = butter(2, [0.1 30] / nyquist, 'bandpass');
            clean_eog = filtfilt(b, a, diff_eog);
            
            % 3. Calculate Velocity (Savitzky-Golay)
            % 50ms window length
            window_len = round(0.05 * fs);
            if mod(window_len, 2) == 0, window_len = window_len + 1; end
            
            % Velocity in units/sec
            velocity = sgolayfilt(clean_eog, 2, window_len, [], 1) * fs;
            
            % 4. Identify Saccades
            is_saccade = abs(velocity) > threshold_deg_s;
            
            % 5. Find start/end indices
            diff_mask = diff([0; is_saccade; 0]);
            starts = find(diff_mask == 1);
            ends = find(diff_mask == -1);
            
            % Output as a table for easy access
            saccades = table(starts, ends, (ends-starts)/fs, 'VariableNames', {'Start', 'End', 'Duration'});
        end



    end
end

