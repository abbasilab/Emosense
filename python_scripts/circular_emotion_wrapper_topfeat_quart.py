"""
circular_emotion_wrapper_topfeats.py
===========================
Notebook-friendly wrappers around `circular_emotion_cluster_ring_black_colors.plot_circular_emotion`
designed to plug directly into the EmoSense pipeline.
"""
from __future__ import annotations

import os
from typing import Dict, List, Optional, Tuple, Sequence

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

from circular_emotion_cluster_ring_black_colors import (
    plot_circular_emotion,
    plot_emotion_grid,
    auto_name_clusters,
)


# ── Core adapter ──────────────────────────────────────────────────────────────

def build_emotion_payload(
    emotion: str,
    output: Dict,
    en_stable_trimmed: pd.DataFrame,
    matrices: Optional[Dict[str, pd.DataFrame]] = None,
    use_signed_importance: bool = True,
) -> Dict:
    if emotion not in output:
        raise KeyError(
            f"Emotion {emotion!r} not in output. "
            f"Available: {list(output.keys())}"
        )

    emo_data = output[emotion]
    full_df: pd.DataFrame = emo_data["full_df"].copy()

    feature_names  = full_df["feature"].tolist()
    cluster_labels = full_df["cluster"].astype(int).tolist()

    payload = {
        "emotion_name":     emotion,
        "feature_names":    feature_names,
        "cluster_labels":   cluster_labels,
        "silhouette_score": float(emo_data.get("silhouette_score", np.nan)),
    }

    if use_signed_importance:
        feat_col = f"{emotion}_Stable_Feature"
        imp_col  = f"{emotion}_Mean_Importance"
        if feat_col not in en_stable_trimmed.columns or imp_col not in en_stable_trimmed.columns:
            raise KeyError(
                f"Columns {feat_col!r} / {imp_col!r} missing in en_stable_trimmed."
            )

        sub = en_stable_trimmed[[feat_col, imp_col]].dropna()
        imp_map = dict(zip(sub[feat_col].astype(str), sub[imp_col].astype(float)))

        feature_values = [imp_map.get(f, 0.0) for f in feature_names]
        missing = [f for f in feature_names if f not in imp_map]
        if missing:
            print(f"[{emotion}] Warning: {len(missing)} features had no importance "
                  f"in en_stable_trimmed (defaulted to 0): {missing[:5]}"
                  f"{'...' if len(missing) > 5 else ''}")
        payload["feature_values"] = feature_values
    else:
        if matrices is None or emotion not in matrices:
            raise ValueError(
                "matrices dict required when use_signed_importance=False"
            )
        corr = matrices[emotion].loc[feature_names, feature_names].to_numpy()
        payload["corr_matrix"] = corr

    payload["cluster_names"] = auto_name_clusters(feature_names, cluster_labels)

    return payload


# ── Single-emotion wrapper ────────────────────────────────────────────────────

def plot_one_emotion(
    emotion: str,
    output: Dict,
    en_stable_trimmed: pd.DataFrame,
    matrices: Optional[Dict[str, pd.DataFrame]] = None,
    use_signed_importance: bool = True,
    save_path: Optional[str] = None,
    **plot_kwargs,
) -> Tuple[plt.Figure, plt.Axes]:
    payload = build_emotion_payload(
        emotion, output, en_stable_trimmed, matrices,
        use_signed_importance=use_signed_importance,
    )
    fig, ax = plot_circular_emotion(**payload, **plot_kwargs)

    if save_path:
        fig.savefig(save_path, dpi=150, bbox_inches="tight")
        print(f"Saved → {save_path}")

    return fig, ax


# ── All-emotions wrapper ──────────────────────────────────────────────────────

def plot_all_emotions(
    output: Dict,
    en_stable_trimmed: pd.DataFrame,
    matrices: Optional[Dict[str, pd.DataFrame]] = None,
    use_signed_importance: bool = True,
    grid: bool = True,
    n_cols: int = 5,
    save_dir: Optional[str] = None,
    save_grid_path: Optional[str] = None,
    file_ext: str = "png",
    figsize: Optional[Tuple[float, float]] = None,
    suptitle: str = "Feature cluster map per emotion",
    emotions: Optional[List[str]] = None,
    **plot_kwargs,
):
    emo_list = emotions if emotions is not None else list(output.keys())

    payloads = []
    for emo in emo_list:
        if emo not in output:
            print(f"  [skip] {emo!r} not in output.")
            continue
        try:
            payloads.append(build_emotion_payload(
                emo, output, en_stable_trimmed, matrices,
                use_signed_importance=use_signed_importance,
            ))
        except Exception as e:
            print(f"  [skip] {emo}: {e}")

    if not payloads:
        raise RuntimeError("No emotions could be plotted — check inputs.")

    if grid:
        fig, axes = plot_emotion_grid(
            emotions_data=payloads,
            n_cols=n_cols,
            figsize=figsize,
            suptitle=suptitle,
            **plot_kwargs,
        )
        if save_grid_path:
            fig.savefig(save_grid_path, dpi=150, bbox_inches="tight")
            print(f"Saved grid → {save_grid_path}")
        return fig, axes

    if save_dir:
        os.makedirs(save_dir, exist_ok=True)

    out_list = []
    fs = figsize or (9, 9)
    for payload in payloads:
        fig, ax = plot_circular_emotion(**payload, figsize=fs, **plot_kwargs)
        emo = payload["emotion_name"]
        if save_dir:
            path = os.path.join(save_dir, f"{emo}.{file_ext}")
            fig.savefig(path, dpi=150, bbox_inches="tight")
            print(f"Saved → {path}")
        out_list.append((emo, fig, ax))

    return out_list


# ── Ring & above-threshold feature extraction ────────────────────────────────

def compute_auto_ring_values(
    feature_values: Sequence[float],
    fractions: Sequence[float] = (0.25, 0.5, 0.75, 1.0),
) -> np.ndarray:
    vals = np.asarray(feature_values, dtype=float)
    if vals.size == 0:
        return np.array([])
    abs_vals = np.abs(vals)
    v_max = float(abs_vals.max())
    v_min = float(abs_vals.min())
    if v_max <= 0:
        return np.array([])
    ring_vals = np.asarray(fractions, dtype=float) * v_max
    ring_vals = ring_vals[(ring_vals >= v_min - 1e-12)
                          & (ring_vals <= v_max + 1e-12)]
    return np.sort(ring_vals)


def extract_top_features(
    emotion: str,
    output: Dict,
    en_stable_trimmed: pd.DataFrame,
    threshold: Optional[float] = None,
    fractions: Sequence[float] = (0.25, 0.5, 0.75, 1.0),
    ring_index: int = 0,
    cluster_names: Optional[Dict[int, str]] = None,
) -> Tuple[pd.DataFrame, np.ndarray]:
    
    payload = build_emotion_payload(
        emotion, output, en_stable_trimmed, use_signed_importance=True,
    )
    feature_names = payload["feature_names"]
    cluster_labels = payload["cluster_labels"]
    feature_values = np.asarray(payload["feature_values"], dtype=float)

    ring_values = compute_auto_ring_values(feature_values, fractions=fractions)
    abs_vals = np.abs(feature_values)

    # REQUESTED CHANGE: Compute threshold based on the 25th percentile of absolute feature values within the plot
    if threshold is not None:
        cutoff = float(abs(threshold))
    else:
        cutoff = float(np.percentile(abs_vals, 25))

    if cluster_names is None:
        cluster_names = payload["cluster_names"]

    mask = abs_vals > cutoff

    df = pd.DataFrame({
        "emotion":        emotion,
        "feature":        np.asarray(feature_names)[mask],
        "importance":     feature_values[mask],
        "abs_importance": abs_vals[mask],
        "cluster_id":     np.asarray(cluster_labels)[mask].astype(int),
        "threshold_used": cutoff,
    })
    df["cluster_name"] = df["cluster_id"].map(
        lambda cid: cluster_names.get(int(cid), f"Cluster {int(cid)}")
    )
    df = df[["emotion", "feature", "importance", "abs_importance",
             "cluster_id", "cluster_name", "threshold_used"]]
    df = df.sort_values("abs_importance", ascending=False, ignore_index=True)
    return df, ring_values


def extract_top_features_all_emotions(
    output: Dict,
    en_stable_trimmed: pd.DataFrame,
    threshold: Optional[float] = None,
    fractions: Sequence[float] = (0.25, 0.5, 0.75, 1.0),
    ring_index: int = 0,
    emotions: Optional[List[str]] = None,
) -> Dict:
    emo_list = emotions if emotions is not None else list(output.keys())

    by_emotion: Dict[str, pd.DataFrame] = {}
    ring_values: Dict[str, np.ndarray] = {}
    summary_rows = []

    for emo in emo_list:
        if emo not in output:
            print(f"  [skip] {emo!r} not in output.")
            continue
        try:
            df, rings = extract_top_features(
                emo, output, en_stable_trimmed,
                threshold=threshold, fractions=fractions, ring_index=ring_index,
            )
        except Exception as e:
            print(f"  [skip] {emo}: {e}")
            continue

        by_emotion[emo] = df
        ring_values[emo] = rings
        summary_rows.append({
            "emotion": emo,
            "n_features_total": int(
                len(build_emotion_payload(
                    emo, output, en_stable_trimmed,
                    use_signed_importance=True,
                )["feature_names"])
            ),
            "n_above_threshold": int(len(df)),
            "threshold_used": float(df["threshold_used"].iloc[0]) if len(df) else np.nan,
            "ring_1": float(rings[0]) if rings.size > 0 else np.nan,
            "ring_2": float(rings[1]) if rings.size > 1 else np.nan,
            "ring_3": float(rings[2]) if rings.size > 2 else np.nan,
            "ring_4": float(rings[3]) if rings.size > 3 else np.nan,
        })

    long_df = (
        pd.concat(by_emotion.values(), ignore_index=True)
        if by_emotion else
        pd.DataFrame(columns=["emotion", "feature", "importance",
                              "abs_importance", "cluster_id",
                              "cluster_name", "threshold_used"])
    )

    summary = pd.DataFrame(summary_rows)

    return {
        "long_df":     long_df,
        "by_emotion":  by_emotion,
        "ring_values": ring_values,
        "summary":     summary,
    }