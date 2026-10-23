"""
cl_circular_emotion_clusters_rings_diffcolors_rename.py
============================
Circular / polar visualisation of EEG and physiological feature clusters
per emotion.

  • Arc colour   → cluster assignment
  • Arc height   → |feature value|  (normalised)
  • Arc fill     → SOLID for positive values / HATCHED for negative values
  • Arc sector   → physiological category (coloured arc + label on outer rim)
  • Dashed rings → reference gridlines for |feature value|

Public API
----------
    categorize_feature(name)                  -> str
    feature_values_from_corr(C, L, signed)    -> ndarray
    auto_name_clusters(names, labels)         -> dict[int, str]
    plot_circular_emotion(...)                -> (fig, ax)
    plot_emotion_grid(emotions_data, ...)     -> (fig, axes)
"""

from __future__ import annotations

from collections import Counter, defaultdict
from typing import Dict, List, Optional, Sequence, Tuple, Union

import matplotlib.colors as mc
import matplotlib.patches as mpatches
import matplotlib.pyplot as plt
import numpy as np


# ── Category configuration ────────────────────────────────────────────────────

CATEGORY_ORDER: List[str] = [
    "EDA", "TREV", "Heart Rate", "BP", "Respiration",
    "Zygomaticus", "Corrugator", "Eye/Blink",
    "EEG Alpha", "EEG Alpha-Low", "EEG Beta", "EEG Gamma",
    "EEG Delta", "EEG Theta",
    "Other",
]

CATEGORY_COLORS: Dict[str, str] = {
    # ── Peripheral physiology — green / orange family ────────────────────
    "EDA":           "#1D9E75",   # green
    "TREV":          "#5BA88E",   # blue-green (related to EDA but distinct)
    "Heart Rate":    "#0F6E56",   # dark green
    "BP":            "#7A2E20",   # dark red (blood-related)
    "Respiration":   "#5DCAA5",   # mint
    "Zygomaticus":   "#D85A30",   # red-orange
    "Corrugator":    "#F0997B",   # peach
    "Eye/Blink":     "#BA7517",   # ochre
    # ── EEG — diverging hues for visual separability ─────────────────────
    "EEG Alpha":     "#E24B4A",   # red       (alpha = headline rhythm)
    "EEG Alpha-Low": "#C24FA0",   # magenta   (related to alpha but distinct)
    "EEG Beta":      "#F39C12",   # amber/gold (high-freq excitatory)
    "EEG Gamma":     "#7B3294",   # deep purple (highest-freq band)
    "EEG Delta":     "#0C447C",   # navy      (slowest, deepest blue)
    "EEG Theta":     "#2DB5A0",   # teal      (between delta and alpha)
    "Other":         "#888780",   # neutral grey
}

# Outer ring (arc + label) colours — DECOUPLED from the bar colours above.
CATEGORY_RING_COLORS: Dict[str, str] = {
    "EDA":           "#9C7B5B",
    "TREV":          "#8E7D6A",
    "Heart Rate":    "#6E5A40",
    "BP":            "#7C5040",
    "Respiration":   "#C2A87A",
    "Zygomaticus":   "#B8694A",
    "Corrugator":    "#D49A82",
    "Eye/Blink":     "#A88652",
    "EEG Alpha":     "#5D7A99",
    "EEG Alpha-Low": "#7E7AAA",
    "EEG Beta":      "#4E8A8E",
    "EEG Gamma":     "#6E5C9E",
    "EEG Delta":     "#3D5575",
    "EEG Theta":     "#587390",
    "Other":         "#999999",
}

CATEGORY_SHORT: Dict[str, str] = {
    "EDA":           "EDA",
    "TREV":          "TREV",
    "Heart Rate":    "HR",
    "BP":            "BP",
    "Respiration":   "Resp.",
    "Zygomaticus":   "Zygom.",
    "Corrugator":    "Corrugat.",
    "Eye/Blink":     "Eye",
    "EEG Alpha":     r"EEG $\alpha$",
    "EEG Alpha-Low": r"EEG $\alpha$-low",
    "EEG Beta":      r"EEG $\beta$",
    "EEG Gamma":     r"EEG $\gamma$",
    "EEG Delta":     r"EEG $\delta$",
    "EEG Theta":     r"EEG $\theta$",
    "Other":         "Other",
}

_CLUSTER_BASENAME: Dict[str, str] = {
    "EDA":           "EDA (Autonomic Arousal)",
    "TREV":          "TREV",
    "Heart Rate":    "Cardiovascular",
    "BP":            "Blood Pressure",
    "Respiration":   "Respiration Rate",
    "Zygomaticus":   "Zygomaticus",
    "Corrugator":    "Corrugator",
    "Eye/Blink":     "Oculomotor (Eye/Blink)",
    "EEG Alpha":     "Cortical Alpha",
    "EEG Alpha-Low": "Cortical Low-Alpha",
    "EEG Beta":      "Cortical Beta",
    "EEG Gamma":     "Cortical Gamma",
    "EEG Delta":     "Cortical Delta",
    "EEG Theta":     "Frontotemporal Theta",
    "Other":         "Mixed Physiological",
}

DEFAULT_CLUSTER_COLORS: List[str] = [
    "#1D9E75", "#378ADD", "#D85A30", "#7F77DD", "#BA7517",
    "#D4537E", "#639922", "#185FA5", "#993C1D", "#534AB7",
    "#5DCAA5", "#F0997B", "#B5D4F4", "#EF9F27", "#E24B4A",
]

ROMAN = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
         "XI", "XII", "XIII", "XIV", "XV"]

NEG_HATCH = "////"


# ── Internal utilities ────────────────────────────────────────────────────────

def _lighten(hex_color: str, amount: float = 0.55) -> str:
    """Blend *hex_color* toward white by *amount* ∈ (0, 1)."""
    try:
        rgb = np.asarray(mc.to_rgb(hex_color))
        return mc.to_hex(np.clip(rgb + (1.0 - rgb) * amount, 0, 1))
    except ValueError:
        return hex_color


def _darken(hex_color: str, amount: float = 0.35) -> str:
    """Blend *hex_color* toward black by *amount* ∈ (0, 1)."""
    try:
        rgb = np.asarray(mc.to_rgb(hex_color))
        return mc.to_hex(np.clip(rgb * (1.0 - amount), 0, 1))
    except ValueError:
        return hex_color


_REGION_SHADE: Dict[str, Tuple[str, float]] = {
    "Frontal":   ("lighten", 0.35),
    "Mid":       ("lighten", 0.10),
    "Posterior": ("darken",  0.30),
}


def _shade_for_region(base_hex: str, region: Optional[str]) -> str:
    if region is None or region not in _REGION_SHADE:
        return base_hex
    op, amt = _REGION_SHADE[region]
    return _lighten(base_hex, amt) if op == "lighten" else _darken(base_hex, amt)


def _normalise_labels(labels: Sequence[int]) -> np.ndarray:
    arr = np.asarray(labels)
    mapping = {old: new for new, old in enumerate(sorted(set(arr.tolist())), 1)}
    return np.array([mapping[v] for v in arr])


# ── Public helpers ────────────────────────────────────────────────────────────

def categorize_feature(feature_name: str) -> str:
    n = feature_name.lower()
    if "delta"     in n: return "EEG Delta"
    if "theta"     in n: return "EEG Theta"
    if "alpha_low" in n: return "EEG Alpha-Low"
    if "alpha"     in n: return "EEG Alpha"
    if "beta"      in n: return "EEG Beta"
    if "gamma"     in n: return "EEG Gamma"
    if "trev"      in n: return "TREV"
    if any(t in n for t in ("eda", "phasic", "tonic")): return "EDA"
    if "resp"      in n: return "Respiration"
    if "_hr"       in n: return "Heart Rate"
    if any(t in n for t in ("dia", "sys")):              return "BP"
    if "zyg"       in n: return "Zygomaticus"
    if "corrug"    in n: return "Corrugator"
    if "blink"     in n: return "Eye/Blink"
    return "Other"


def feature_values_from_corr(
    corr_matrix: np.ndarray,
    cluster_labels: Sequence[int],
    signed: bool = True,
) -> np.ndarray:
    C = np.asarray(corr_matrix, dtype=float)
    L = _normalise_labels(cluster_labels)
    N = C.shape[0]
    if C.shape != (N, N):
        raise ValueError(f"corr_matrix must be square; got {C.shape}")
    if len(L) != N:
        raise ValueError("cluster_labels length must match corr_matrix size")

    values = np.zeros(N)
    for i in range(N):
        peers = (L == L[i])
        peers[i] = False
        if peers.sum() > 0:
            vals = C[i, peers]
            values[i] = vals.mean() if signed else np.abs(vals).mean()
    return values


def _dominant_region(feature_names: Sequence[str]) -> Optional[str]:
    counts: Counter = Counter()
    for f in feature_names:
        fl = f.lower()
        if "_front" in fl: counts["Frontal"]   += 1
        elif "_post" in fl: counts["Posterior"] += 1
        elif "_mid"  in fl: counts["Mid"]      += 1
    if not counts:
        return None
    top, top_n = counts.most_common(1)[0]
    if top_n == 0:
        return None
    return top


def _is_eeg_category(cat: str) -> bool:
    return cat.startswith("EEG ")


def auto_name_clusters(
    feature_names: Sequence[str],
    cluster_labels: Sequence[int],
) -> Dict[int, str]:
    cats = [categorize_feature(f) for f in feature_names]
    L = _normalise_labels(cluster_labels)
    unique_ids = sorted(set(L.tolist()))

    names: Dict[int, str] = {}
    for cid in unique_ids:
        cf  = [feature_names[i] for i, c in enumerate(L) if c == cid]
        cc  = [cats[i] for i, c in enumerate(L) if c == cid]
        dom = Counter(cc).most_common(1)[0][0]
        base = _CLUSTER_BASENAME.get(dom, dom)

        if _is_eeg_category(dom):
            band = base
            if band.startswith("Cortical "):
                band = band[len("Cortical "):]
            elif band.startswith("Frontotemporal "):
                band = band[len("Frontotemporal "):]

            region = _dominant_region(cf)
            names[cid] = f"{region} {band}" if region else band
        else:
            names[cid] = base

    return names


# ── Main plotting function ────────────────────────────────────────────────────

def plot_circular_emotion(
    emotion_name: str,
    feature_names: Sequence[str],
    cluster_labels: Sequence[int],
    feature_values: Optional[Sequence[float]] = None,
    corr_matrix: Optional[np.ndarray] = None,
    cluster_names: Optional[Dict[int, str]] = None,
    cluster_colors: Optional[List[str]] = None,
    silhouette_score: Optional[float] = None,
    # Layout
    sort_by_category: bool = True,
    category_gap_deg: float = 6.0,
    inner_frac: float = 0.26,
    bar_fill_frac: float = 0.88,
    arc_r: float = 1.08,
    label_r: float = 1.30,
    ring_color_source: str = "bar",
    # Reference rings
    show_ref_rings: bool = True,
    ref_ring_values: Optional[Sequence[float]] = None,
    ref_ring_color: str = "#bfbfbf",
    ref_ring_lw: float = 0.7,
    ref_ring_dashes: Tuple[float, float] = (3, 3),
    ref_ring_label: bool = True,
    ref_ring_label_color: str = "#888888",
    ref_ring_label_fontsize: int = 9,
    ref_ring_label_angle_deg: float = 90.0,
    # Negative-bar style
    neg_hatch: str = NEG_HATCH,
    neg_lighten: float = 0.55,
    neg_edge_lw: float = 0.6,
    # Labels
    show_feature_labels: bool = False,
    label_fontsize: int = 7,
    category_label_fontsize: Optional[int] = None,
    center_fontsize: int = 13,
    show_legend: bool = True,
    legend_fontsize: Optional[int] = None,
    legend_ncol: Optional[int] = None,
    legend_bbox_y: float = -0.16,
    # Figure
    figsize: Tuple[float, float] = (9, 9),
    ax: Optional[plt.Axes] = None,
    bg_color: str = "white",
    circle_pad: float = 0.22,
) -> Tuple[plt.Figure, plt.Axes]:
    
    feature_names = list(feature_names)
    N = len(feature_names)
    cluster_labels_arr = _normalise_labels(cluster_labels)
    if len(cluster_labels_arr) != N:
        raise ValueError("cluster_labels must have the same length as feature_names")

    if feature_values is not None:
        vals = np.asarray(feature_values, dtype=float)
        if len(vals) != N:
            raise ValueError("feature_values must have the same length as feature_names")
    elif corr_matrix is not None:
        vals = feature_values_from_corr(corr_matrix, cluster_labels_arr, signed=True)
    else:
        vals = np.ones(N)

    signs      = np.sign(vals)
    abs_vals   = np.abs(vals)

    lo = inner_frac + 0.08
    v_min, v_max = abs_vals.min(), abs_vals.max()
    if v_max > v_min:
        norm_abs = lo + (1.0 - lo) * (abs_vals - v_min) / (v_max - v_min)
    else:
        norm_abs = np.full(N, (lo + 1.0) / 2)

    def _value_to_radius(v: float) -> float:
        v = abs(float(v))
        if v_max > v_min:
            return lo + (1.0 - lo) * (v - v_min) / (v_max - v_min)
        return (lo + 1.0) / 2

    unique_cls = sorted(set(cluster_labels_arr.tolist()))
    K = len(unique_cls)

    if cluster_names is None:
        cluster_names = auto_name_clusters(feature_names, cluster_labels_arr)

    if cluster_colors is None:
        cats_per_feat = [categorize_feature(f) for f in feature_names]
        color_map: Dict[int, str] = {}
        cat_region_usage: Dict[Tuple[str, Optional[str]], int] = defaultdict(int)
        for cid in unique_cls:
            members_idx  = [i for i, c in enumerate(cluster_labels_arr) if c == cid]
            members_cats = [cats_per_feat[i] for i in members_idx]
            dom_cat = Counter(members_cats).most_common(1)[0][0]
            base    = CATEGORY_COLORS.get(dom_cat, "#888888")

            if _is_eeg_category(dom_cat):
                region = _dominant_region([feature_names[i] for i in members_idx])
                base   = _shade_for_region(base, region)
            else:
                region = None

            key = (dom_cat, region)
            n_seen = cat_region_usage[key]
            color_map[cid] = (
                base if n_seen == 0
                else _lighten(base, amount=min(0.20 + 0.15 * n_seen, 0.60))
            )
            cat_region_usage[key] += 1
    else:
        color_map = {
            cid: cluster_colors[i % len(cluster_colors)]
            for i, cid in enumerate(unique_cls)
        }

    cats = [categorize_feature(f) for f in feature_names]

    groups: Dict[str, List[int]] = defaultdict(list)
    for i, cat in enumerate(cats):
        groups[cat].append(i)

    if sort_by_category:
        ordered_cats = [c for c in CATEGORY_ORDER if c in groups]
        for c in groups:
            if c not in ordered_cats:
                ordered_cats.append(c)
        ordered_idx: List[int] = []
        for cat in ordered_cats:
            ordered_idx.extend(
                sorted(groups[cat], key=lambda i: cluster_labels_arr[i])
            )
    else:
        ordered_cats = list(dict.fromkeys(cats))
        ordered_idx  = list(range(N))
        groups = defaultdict(list)
        for rank, i in enumerate(ordered_idx):
            groups[cats[i]].append(rank)

    n_cats = len(ordered_cats)

    total_gap_deg = category_gap_deg * n_cats
    feature_deg   = (360.0 - total_gap_deg) / N
    feature_rad   = np.radians(feature_deg * bar_fill_frac)

    if ax is None:
        fig, ax = plt.subplots(figsize=figsize, subplot_kw=dict(projection="polar"))
    else:
        fig = ax.get_figure()

    ax.set_theta_zero_location("N")
    ax.set_theta_direction(-1)
    ax.set_ylim(0, label_r + circle_pad)
    ax.set_axis_off()

    if show_ref_rings:
        if ref_ring_values is None:
            if v_max > 0:
                ring_vals = np.array([0.25, 0.5, 0.75, 1.0]) * v_max
            else:
                ring_vals = np.array([])
        else:
            ring_vals = np.asarray([abs(float(v)) for v in ref_ring_values],
                                   dtype=float)

        if ring_vals.size:
            ring_vals = ring_vals[(ring_vals >= v_min - 1e-12) &
                                  (ring_vals <= v_max + 1e-12)]

        theta_full = np.linspace(0, 2 * np.pi, 361)
        for rv in ring_vals:
            r = _value_to_radius(rv)
            ax.plot(
                theta_full, np.full_like(theta_full, r),
                color=ref_ring_color, linewidth=ref_ring_lw,
                linestyle=(0, ref_ring_dashes),
                zorder=2,
            )

            if ref_ring_label:
                if abs(rv - round(rv)) < 1e-3 and abs(rv) >= 1:
                    txt = f"{rv:.0f}"
                elif abs(rv) >= 1:
                    txt = f"{rv:.1f}"
                else:
                    txt = f"{rv:.2f}"

                ax.text(
                    np.radians(ref_ring_label_angle_deg), r,
                    txt,
                    fontsize=ref_ring_label_fontsize,
                    color=ref_ring_label_color,
                    ha="center", va="center",
                    bbox=dict(facecolor=bg_color, edgecolor="none",
                              pad=0.8, alpha=0.85),
                    zorder=2.5,
                )

    angle_deg   = 0.0
    cat_spans: List[Tuple[str, float, float]] = []
    feat_ptr    = 0

    for cat in ordered_cats:
        n_in_cat      = len(groups[cat])
        cat_start_deg = angle_deg

        for _ in range(n_in_cat):
            fi  = ordered_idx[feat_ptr]; feat_ptr += 1
            cid = cluster_labels_arr[fi]
            is_neg = signs[fi] < 0

            mid_rad = np.radians(angle_deg + feature_deg / 2)
            height  = norm_abs[fi] - inner_frac
            base_color = color_map[cid]

            face_color = _lighten(base_color, neg_lighten) if is_neg else base_color
            edge_color = base_color
            lw         = neg_edge_lw if is_neg else 0.0

            container = ax.bar(
                x        = mid_rad,
                height   = height,
                width    = feature_rad,
                bottom   = inner_frac,
                color    = face_color,
                edgecolor= edge_color,
                linewidth= lw,
                align    = "center",
                zorder   = 3,
            )

            if is_neg:
                for patch in container:
                    patch.set_hatch(neg_hatch)

            if show_feature_labels:
                ax.text(
                    mid_rad, norm_abs[fi] + 0.03,
                    feature_names[fi],
                    fontsize=max(4, label_fontsize - 2),
                    ha="center", va="center", color="#333",
                    rotation=np.degrees(mid_rad) - 90,
                    rotation_mode="anchor",
                )

            angle_deg += feature_deg

        cat_spans.append((cat, cat_start_deg, angle_deg))
        angle_deg += category_gap_deg

    # ── Outer category arcs & labels ──────────────────────────────────────
    cat_fontsize = (category_label_fontsize
                    if category_label_fontsize is not None
                    else label_fontsize + 5)
    for cat, start_deg, end_deg in cat_spans:
        if end_deg <= start_deg:
            continue
            
        # REQUESTED CHANGE: Strip the system coloring and make the outer rings black
        ring_color = "black"
        
        n_pts = max(30, int((end_deg - start_deg) * 3))
        theta_arc = np.radians(np.linspace(start_deg + 0.5, end_deg - 0.5, n_pts))

        ax.plot(
            theta_arc, np.full(n_pts, arc_r),
            color=ring_color, linewidth=5,
            solid_capstyle="round", zorder=4,
        )

        mid_rad = np.radians((start_deg + end_deg) / 2)
        ax.text(
            mid_rad, label_r,
            CATEGORY_SHORT.get(cat, cat),
            ha="center", va="center",
            fontsize=cat_fontsize, color=ring_color,
            fontweight="bold", zorder=5,
        )

    theta_mask = np.linspace(0, 2 * np.pi, 300)
    ax.fill(theta_mask, np.full(300, inner_frac + 0.02),
            color=bg_color, zorder=6, linewidth=0)

    sil_str = f"\nsil = {silhouette_score:.2f}" if silhouette_score is not None else ""
    ax.text(
        0.5, 0.5,
        f"{emotion_name}\nn = {N}  ·  K = {K}{sil_str}",
        transform=ax.transAxes,
        ha="center", va="center",
        fontsize=center_fontsize, fontweight="bold",
        color="#111", zorder=10, linespacing=1.55,
    )

    cluster_patches = [
        mpatches.Patch(
            facecolor=color_map[cid],
            edgecolor="none",
            label=f"C{cid}: {cluster_names.get(cid, f'Cluster {cid}')}",
        )
        for cid in unique_cls
    ]

    style_patches = [
        mpatches.Patch(facecolor="#888888", edgecolor="none",
                       label="(+) Positive value"),
        mpatches.Patch(facecolor=_lighten("#888888", neg_lighten),
                       edgecolor="#888888", linewidth=0.7,
                       hatch=neg_hatch, label="(–) Negative value"),
    ]

    all_patches = cluster_patches + [mpatches.Patch(visible=False)] + style_patches

    if show_legend:
        leg_fs = legend_fontsize if legend_fontsize is not None else max(8, label_fontsize + 1)
        leg_nc = legend_ncol if legend_ncol is not None else min(3, K)
        ax.legend(
            handles=all_patches,
            loc="lower center",
            bbox_to_anchor=(0.5, legend_bbox_y),
            ncol=leg_nc,
            fontsize=leg_fs,
            framealpha=0.9,
            edgecolor="#ccc",
            handlelength=1.6,
            handleheight=1.1,
            columnspacing=1.0,
            labelspacing=0.4,
        )

    return fig, ax


def plot_emotion_grid(
    emotions_data: List[Dict],
    n_cols: int = 5,
    figsize: Optional[Tuple[float, float]] = None,
    suptitle: str = "Feature cluster map per emotion",
    universal_legend: bool = True,
    universal_legend_fontsize: int = 11,
    universal_legend_ncol: Optional[int] = None,
    universal_legend_y: float = -0.02,
    **kwargs,
) -> Tuple[plt.Figure, np.ndarray]:
    
    n      = len(emotions_data)
    n_rows = int(np.ceil(n / n_cols))
    if figsize is None:
        figsize = (n_cols * 4.2, n_rows * 4.4)

    fig, axes = plt.subplots(
        n_rows, n_cols, figsize=figsize,
        subplot_kw=dict(projection="polar"),
    )
    axes_flat = np.array(axes).flatten()

    if universal_legend:
        kwargs = {**kwargs, "show_legend": False}

    for i, ed in enumerate(emotions_data):
        call_kw = {**ed, **kwargs, "ax": axes_flat[i]}
        plot_circular_emotion(**call_kw)

    for j in range(n, len(axes_flat)):
        axes_flat[j].set_visible(False)

    if universal_legend:
        name_to_color: Dict[str, str]     = {}
        name_to_cat:   Dict[str, str]     = {}
        name_to_reg:   Dict[str, Optional[str]] = {}
        region_priority = {"Frontal": 0, "Mid": 1, "Posterior": 2, None: 3}

        for ed in emotions_data:
            feats  = ed.get("feature_names", [])
            labels = _normalise_labels(ed.get("cluster_labels", []))
            cnames = ed.get("cluster_names") or auto_name_clusters(feats, labels)
            cats   = [categorize_feature(f) for f in feats]
            for cid in sorted(set(labels.tolist())):
                cname = cnames.get(cid, f"Cluster {cid}")
                if cname in name_to_color:
                    continue
                cluster_idx  = [i for i, c in enumerate(labels) if c == cid]
                cluster_cats = [cats[i] for i in cluster_idx]
                if not cluster_cats:
                    continue
                dom = Counter(cluster_cats).most_common(1)[0][0]
                base = CATEGORY_COLORS.get(dom, "#888")
                if _is_eeg_category(dom):
                    region = _dominant_region([feats[i] for i in cluster_idx])
                    base   = _shade_for_region(base, region)
                else:
                    region = None
                name_to_color[cname] = base
                name_to_cat[cname]   = dom
                name_to_reg[cname]   = region

        cat_priority = {cat: i for i, cat in enumerate(CATEGORY_ORDER)}
        def _name_priority(name: str) -> Tuple[int, int, str]:
            return (
                cat_priority.get(name_to_cat.get(name, ""), 99),
                region_priority.get(name_to_reg.get(name), 99),
                name,
            )
        sorted_names = sorted(name_to_color.keys(), key=_name_priority)

        cluster_patches = [
            mpatches.Patch(facecolor=name_to_color[n], edgecolor="none", label=n)
            for n in sorted_names
        ]
        style_patches = [
            mpatches.Patch(facecolor="#888888", edgecolor="none",
                           label="(+) Positive value"),
            mpatches.Patch(facecolor=_lighten("#888888", 0.55),
                           edgecolor="#888888", linewidth=0.7,
                           hatch=NEG_HATCH, label="(–) Negative value"),
        ]
        all_patches = cluster_patches + style_patches

        ncol = (universal_legend_ncol
                if universal_legend_ncol is not None
                else min(len(all_patches), max(4, n_cols)))

        fig.legend(
            handles=all_patches,
            loc="lower center",
            bbox_to_anchor=(0.5, universal_legend_y),
            ncol=ncol,
            fontsize=universal_legend_fontsize,
            framealpha=0.95,
            edgecolor="#cccccc",
            handlelength=1.6,
            handleheight=1.1,
            columnspacing=1.2,
            labelspacing=0.5,
        )

    if suptitle:
        fig.suptitle(suptitle, fontsize=13, fontweight="bold", y=1.01)

    fig.tight_layout()
    return fig, axes_flat