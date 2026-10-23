# Emosense

Code and materials to reproduce **"Individualized brain-body signatures of positive emotions revealed by large-scale multimodal neurophysiological recording."**

Four participants each viewed 168 emotion-evoking video clips while 128-channel EEG and 28 autonomic, ocular and facial channels were recorded simultaneously, with self-reported categorical ratings collected after every clip. This repository contains the full analysis path for that study: MATLAB preprocessing of the raw BioSemi and Biopac recordings, multimodal feature extraction, per-participant elastic-net classification of 15 positive and neutral emotions against baseline, and the SHAP-based interpretability and visualization used in the figures.

The pipeline runs in three stages:

```
emo0XX/              MATLAB   raw recordings  ->  cleaned, epoched signals
post_processing/     MATLAB   cleaned signals ->  brain + physiological feature tables
python_scripts/      Python   feature tables  ->  classifiers, SHAP, figures
```

# Contents of Repo

## Per-participant preprocessing — `emo001/`, `emo005/`, `emo006/`, `emo007/`

Each participant folder holds the same six-step EEG and physiology pipeline, with participant-specific settings for sessions, blocks, bad electrodes and rejected ICA components. Scripts are run in order; each step reads the output folder written by the previous one.

| Step | Script | What it does |
| --- | --- | --- |
| 1 | `V_Step1_ImportAll.m` | Imports the BioSemi `.bdf` (128 scalp channels plus auxiliary EMG, EOG and EGG), the Biopac `.mat` (EDA, ECG, respiration, continuous blood pressure, TREV) and the behavioral `.csv`. Recodes and synchronizes event pulses across systems, applies a 55 Hz lowpass FIR plus notch filters, downsamples EEG by a factor of 4 to 512 Hz and Biopac from 1000 Hz to 500 Hz, and merges everything into a single `Signal` struct. |
| 2 | `V_Step2_Identify_BadElecs.m` | Interactive review of channel quality; writes the bad-electrode list used downstream. |
| 3 | `V_Step3_Preprocessing.m` | Spherical interpolation of bad channels (`pop_interp`), 0.5 Hz zero-phase FIR highpass, threshold-based artifact rejection, Morlet-wavelet extraction of the gastric band (0.033–0.067 Hz), spline-method HRV (0.04–0.4 Hz), then epoching and concatenation in preparation for ICA. |
| 3b | `V_Step3_Concat_Preprocessing_Baseline.m` | The same preparation for the resting-baseline blocks. |
| 4 | `V_Step4_runICA_perblocks.m` · `..._baseline.m` | Runs ICA per block on the concatenated EEG and EOG data. |
| 5 | `V_Step5_Identify_ICAcomp_perblock.m` · `..._baseline.m` | Inspection and flagging of ocular and muscle components. |
| 6 | `V_Step6_cleanandrerefEEG_perblock.m` · `..._baseline.m` | Removes flagged components and re-references the cleaned EEG. |

`epoch_by_trial.m` and `V_fEpochMMBS.m` are the shared epoching helpers that cut continuous recordings into per-trial segments aligned to clip onset.

## Feature extraction — `post_processing/`

`brain_feature_Functions.m` is a static class for EEG spectral features. It computes Welch spectra over 10 s segments with 50% overlap (512 Hz default), converts to dB, and averages absolute, relative and log power within delta (1–4 Hz), theta (4–8 Hz), low alpha (8–10 Hz), alpha (10–12 Hz), beta (13–30 Hz) and gamma (30–50 Hz). It also provides a FieldTrip-based separation of fractal (aperiodic) from oscillatory spectral components over 1–51 Hz, in the spirit of Donoghue et al. (2020).

`physio_Functions.m` is the matching static class for the peripheral channels:

| Signal | Features |
| --- | --- |
| EDA | Resampling, z-scoring, detrending, and decomposition into phasic and tonic components via cvxEDA |
| ECG | R-peak detection with MODWT enhancement, instantaneous heart rate, mean RR, SDNN, RMSSD |
| Impedance cardiography | Cardiac output and contractility from first-difference and trapezoidal-integration measures |
| EGG | Waveform length, log-scaled fractal length, average amplitude change |
| Respiration | Detrending, peak detection, breaths per minute |
| Facial EMG | Corrugator and zygomaticus: bandpass, rectification, moving-average smoothing, normalization, moving variance |
| EOG | Blink rate from vertical EOG; saccade start, end and duration from the horizontal difference channel with Savitzky–Golay velocity estimation |
| All | Mean, min, max, standard deviation, kurtosis, mean absolute value, RMS |

`cvxEDA-master/` is a vendored copy of the cvxEDA convex-optimization EDA decomposition toolbox, used by `extract_EDA`. It carries its own GPLv3 license — see **License** below.

## Classification, interpretability and figures — `python_scripts/`

`train_all_emo_baseline_final_V2.ipynb` is the main analysis notebook, run once per participant. For each of the 15 emotions it fits a binary classifier separating task segments in which that emotion was reported from resting-baseline segments.

- **Models.** Elastic-net logistic regression (`saga`, `max_iter=5000`) is the primary model, with a linear SVM and a random forest as comparators. Hyperparameters are tuned by an inner 2-fold `GridSearchCV` scored on ROC-AUC; the elastic-net grid spans `l1_ratio` over five values in [0, 1] and `C` over {0.5, 1, 5, 10}.
- **Cross-validation.** Block-stratified 4-fold CV, so that every test fold receives a held-out emotion-positive block and no block is split across train and test. Each fold is run with 5 balanced subsamples, giving 20 train/test datasets per emotion. `MinMaxScaler` is fit on training data only. Seed is fixed at 77.
- **Features.** EEG band-power features are concatenated with HRV, EDA, blood pressure, respiration, EGG, EOG, EMG and TREV features. Session, trial and block indices are carried as metadata and excluded from scaling.
- **Outputs.** Pickled models and performance records, SHAP values aggregated across folds, stable-feature tables trimmed at 90% cumulative importance, per-emotion feature-correlation clustermaps, and the ROC and performance figures as SVG/PDF.

The three plotting modules build the circular feature maps:

- `circular_emotion_cluster_ring_black.py` — polar plot for one emotion. Each feature is a bar around the circle: color encodes its cluster, height encodes normalized absolute importance, and hatching marks negative values. Bars are grouped into labelled sectors by modality (EDA, heart rate, EEG alpha, and so on), and the center reports the emotion name, feature count, cluster count and silhouette score. `plot_emotion_grid` tiles several emotions with a shared legend.
- `circular_emotion_cluster_ring_black_colors.py` — the same plot with per-category ring coloring rather than black outer arcs.
- `circular_emotion_wrapper_topfeat_quart.py` — notebook-facing wrapper. Builds per-emotion payloads from the notebook's `output`, `en_stable_trimmed` and correlation `matrices`, dispatches to the plotting functions, and extracts above-threshold features (default threshold: the 25th percentile of absolute importance).

# Installation

Clone the repository:

```bash
git clone https://github.com/abbasilab/Emosense.git
cd Emosense
```

**MATLAB** (preprocessing and feature extraction). Tested with the Signal Processing, Wavelet, and Statistics and Machine Learning toolboxes. The following must be on the MATLAB path:

- [EEGLAB](https://sccn.ucsd.edu/eeglab/) — `pop_fileio`, `pop_interp`, `eegplot`, `topoplot`
- [FieldTrip](https://www.fieldtriptoolbox.org/) — `ft_defaults`, used for the fractal/oscillatory spectral separation
- `pan_tompkin` — Pan–Tompkins QRS detector, called by `compute_avg_heartrate`
- `cvxEDA` — included at `post_processing/cvxEDA-master/src`

**Python** (classification and figures). Python 3.9 or newer:

```bash
pip install numpy pandas scipy scikit-learn shap matplotlib seaborn networkx joblib
```

The notebook also imports `get_strategy` from a local `utils.ml_utils` module, which must be available on the Python path.

**Before running anything**, set the data and output locations. Input and output directories are currently defined at the top of each MATLAB script, and the notebook collects its settings in the `2. Configuration — edit here` cell, where the participant, session and block to process are also selected.

# Data sharing

Raw and preprocessed recordings for the four participants are available at `<data repository / DOI>`. The feature tables consumed by `train_all_emo_baseline_final_V2.ipynb` are available at `<link>`.

The emotion labels follow the taxonomy of Cowen and Keltner; the 15 categories analysed here are Calmness, Entrancement, Confusion, Boredom, Interest, Satisfaction, Relief, Excitement, Awkwardness, Amusement, Adoration, Joy, Admiration, Awe and Aesthetic Appreciation.

# Citation

```bibtex
@article{bijanzadeh2026individualized,
  title   = {Individualized brain-body signatures of positive emotions revealed
             by large-scale multimodal neurophysiological recording},
  author  = {Bijanzadeh, Maryam and Nandi, Bijurika and Wang, Vincent and
             Kalisetti, Bhavesh and Campusano, Richard and Townsend, Jennifer and
             Anguera-Singla, Roger and Hartley, Isabella D. and Osheroff, Melissa and
             Ziegler, David A. and Zanto, Theodore P. and Gazzaley, Adam and
             Abbasi-Asl, Reza},
  journal = {bioRxiv},
  year    = {2026}
}
```

# License

See LICENSE.txt

Note that `post_processing/cvxEDA-master/` is third-party code distributed under the GNU General Public License v3. Consider whether to keep it vendored or declare it as an external dependency, since GPLv3 is copyleft and constrains the license you can apply to the combined distribution.
