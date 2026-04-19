"""
NSW TransitIQ — Transit Intelligence Dashboard
Target Users: Transit Operators & Network Planners
Problems Solved:
  1. Route Confusion     → Unified route browser with smart filters
  2. Coverage Gaps       → Operator footprint & region analysis
  3. Disruption Tracking → Planned replacement & temporary service detection
  4. Poor Planning       → Distance distribution & efficiency scoring
"""

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import numpy as np
import os

# ── Page config ──────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="NSW TransitIQ",
    page_icon="🚌",
    layout="wide",
    initial_sidebar_state="expanded",
)

# ── Custom CSS ────────────────────────────────────────────────────────────────
st.markdown("""
<style>
    /* Main background */
    .stApp { background-color: #0f1117; }
    
    /* Metric cards */
    div[data-testid="metric-container"] {
        background: linear-gradient(135deg, #1a1f2e 0%, #1e2535 100%);
        border: 1px solid #2d3748;
        border-radius: 12px;
        padding: 16px;
    }
    div[data-testid="metric-container"] label {
        color: #a0aec0 !important;
        font-size: 0.78rem !important;
        letter-spacing: 0.06em;
        text-transform: uppercase;
    }
    div[data-testid="metric-container"] div[data-testid="stMetricValue"] {
        color: #e2e8f0 !important;
        font-size: 2rem !important;
        font-weight: 700;
    }
    div[data-testid="metric-container"] div[data-testid="stMetricDelta"] {
        color: #68d391 !important;
    }

    /* Sidebar */
    section[data-testid="stSidebar"] {
        background-color: #141824;
        border-right: 1px solid #2d3748;
    }
    section[data-testid="stSidebar"] .stSelectbox label,
    section[data-testid="stSidebar"] .stMultiSelect label,
    section[data-testid="stSidebar"] .stSlider label {
        color: #a0aec0 !important;
        font-size: 0.8rem;
        text-transform: uppercase;
        letter-spacing: 0.05em;
    }

    /* Section headers */
    .section-title {
        color: #e2e8f0;
        font-size: 1.05rem;
        font-weight: 600;
        letter-spacing: 0.03em;
        padding: 6px 0 4px 0;
        border-bottom: 2px solid #3182ce;
        margin-bottom: 14px;
    }
    
    /* Alert boxes */
    .alert-box {
        background: linear-gradient(135deg, #2d1b1b, #1a1515);
        border-left: 4px solid #fc8181;
        border-radius: 8px;
        padding: 12px 16px;
        margin: 8px 0;
        color: #fed7d7;
        font-size: 0.88rem;
    }
    .alert-box-warn {
        background: linear-gradient(135deg, #2d2416, #1a1a10);
        border-left: 4px solid #f6ad55;
        border-radius: 8px;
        padding: 12px 16px;
        margin: 8px 0;
        color: #fefcbf;
        font-size: 0.88rem;
    }
    .insight-box {
        background: linear-gradient(135deg, #1a2d20, #111a16);
        border-left: 4px solid #68d391;
        border-radius: 8px;
        padding: 12px 16px;
        margin: 8px 0;
        color: #c6f6d5;
        font-size: 0.88rem;
    }

    /* Tab styling */
    .stTabs [data-baseweb="tab-list"] {
        background-color: #141824;
        border-radius: 10px;
        padding: 4px;
        gap: 4px;
    }
    .stTabs [data-baseweb="tab"] {
        border-radius: 8px;
        color: #a0aec0;
        font-size: 0.85rem;
    }
    .stTabs [aria-selected="true"] {
        background-color: #2b3a5c;
        color: #90cdf4 !important;
    }

    /* DataFrame */
    .stDataFrame { border-radius: 10px; }
    
    /* Logo area */
    .logo-area {
        display: flex;
        align-items: center;
        gap: 10px;
        padding: 8px 0 20px 0;
    }
    .logo-text {
        color: #90cdf4;
        font-size: 1.4rem;
        font-weight: 800;
        letter-spacing: -0.02em;
    }
    .logo-sub {
        color: #4a5568;
        font-size: 0.7rem;
        text-transform: uppercase;
        letter-spacing: 0.1em;
    }
</style>
""", unsafe_allow_html=True)

# ── Data Loading ──────────────────────────────────────────────────────────────
# Resolve paths relative to this script file, regardless of CWD
_HERE = os.path.dirname(os.path.abspath(__file__))

def _find_file(filename):
    """Search for a CSV file: script dir → CWD → None"""
    for candidate in [
        os.path.join(_HERE, filename),
        os.path.join(os.getcwd(), filename),
    ]:
        if os.path.isfile(candidate):
            return candidate
    return None

@st.cache_data
def load_data(bus_bytes=None, routes_bytes=None):
    import io
    if bus_bytes is not None:
        bus_routes = pd.read_csv(io.BytesIO(bus_bytes))
    else:
        path = _find_file("bus_routes.csv")
        bus_routes = pd.read_csv(path)

    if routes_bytes is not None:
        routes_detail = pd.read_csv(io.BytesIO(routes_bytes))
    else:
        path = _find_file("routes_1.csv")
        routes_detail = pd.read_csv(path)

    # Clean up bus_routes
    bus_routes["route_distance"] = pd.to_numeric(bus_routes["route_distance"], errors="coerce")
    bus_routes["st_length(shape)"] = pd.to_numeric(bus_routes["st_length(shape)"], errors="coerce")
    bus_routes["routevarianttypeid"] = bus_routes["routevarianttypeid"].fillna("Unknown")

    # Fix routes_detail typos
    routes_detail["route_variant_type"] = routes_detail["route_variant_type"].replace({
        "school": "School", "Schol": "School"
    })

    # Distance buckets for bus_routes
    def dist_bucket(d):
        if pd.isna(d): return "Unknown"
        if d <= 10: return "Short (≤10km)"
        if d <= 30: return "Medium (11–30km)"
        if d <= 60: return "Long (31–60km)"
        return "Very Long (60km+)"

    bus_routes["distance_bucket"] = bus_routes["route_distance"].apply(dist_bucket)

    return bus_routes, routes_detail

bus_routes_path = _find_file("bus_routes.csv")
routes_path     = _find_file("routes_1.csv")

if bus_routes_path is None or routes_path is None:
    st.markdown("## 🚌 NSW TransitIQ — Setup")
    st.warning("⚠️ 数据文件未找到，请上传 CSV 文件以继续。")
    st.markdown("需要以下两个文件：`bus_routes.csv` 和 `routes_1.csv`")
    col_u1, col_u2 = st.columns(2)
    with col_u1:
        uf1 = st.file_uploader("上传 bus_routes.csv", type="csv")
    with col_u2:
        uf2 = st.file_uploader("上传 routes_1.csv", type="csv")
    if uf1 and uf2:
        bus_routes, routes_detail = load_data(
            bus_bytes=uf1.read(), routes_bytes=uf2.read()
        )
    else:
        st.info("👆 请先上传两个 CSV 文件，或将文件放到 app.py 同级目录后重新运行。")
        st.stop()
else:
    bus_routes, routes_detail = load_data()

# ── Sidebar ───────────────────────────────────────────────────────────────────
with st.sidebar:
    st.markdown("""
    <div class="logo-area">
        <span style="font-size:2rem">🚌</span>
        <div>
            <div class="logo-text">TransitIQ</div>
            <div class="logo-sub">NSW Open Transport Data</div>
        </div>
    </div>
    """, unsafe_allow_html=True)

    st.markdown("---")
    st.markdown("**🎛️ GLOBAL FILTERS**")

    # Route type filter
    all_route_types = sorted(bus_routes["routevarianttypeid"].unique())
    selected_types = st.multiselect(
        "Service Type",
        options=all_route_types,
        default=all_route_types,
        help="Filter by service category"
    )

    # Direction filter
    all_dirs = sorted(bus_routes["directionid"].unique())
    selected_dirs = st.multiselect(
        "Direction",
        options=all_dirs,
        default=all_dirs
    )

    # Distance range
    min_d, max_d = 0, 200
    dist_range = st.slider(
        "Route Distance (km)",
        min_value=min_d, max_value=max_d,
        value=(min_d, max_d),
        step=5
    )

    st.markdown("---")
    st.markdown("**📊 QUICK STATS**")
    
    total_ops = bus_routes["operator_name"].nunique()
    total_routes = len(bus_routes)
    disruption_count = len(routes_detail[routes_detail["route_variant_type"] == "Temporary"])
    
    st.metric("Total Route Variants", f"{total_routes:,}")
    st.metric("Operators on Network", f"{total_ops:,}")
    st.metric("Active Disruptions", f"{disruption_count:,}", delta="Planned replacements")

    st.markdown("---")
    st.caption("🔄 Data: NSW Open Transport · Built with TransitIQ")

# ── Apply global filters ──────────────────────────────────────────────────────
filtered = bus_routes[
    (bus_routes["routevarianttypeid"].isin(selected_types)) &
    (bus_routes["directionid"].isin(selected_dirs)) &
    (bus_routes["route_distance"].between(dist_range[0], dist_range[1], inclusive="both") | bus_routes["route_distance"].isna())
]

# ── Main content ──────────────────────────────────────────────────────────────
st.markdown("## 🚌 NSW TransitIQ — Network Intelligence Dashboard")
st.caption("Real-time analysis of NSW Open Transport route data · Helping operators understand their network")

# ── KPI Row ───────────────────────────────────────────────────────────────────
kpi1, kpi2, kpi3, kpi4, kpi5 = st.columns(5)
with kpi1:
    st.metric("Filtered Routes", f"{len(filtered):,}", delta=f"{len(filtered)-len(bus_routes):+,} vs all")
with kpi2:
    st.metric("Avg Route Distance", f"{filtered['route_distance'].mean():.1f} km")
with kpi3:
    school_pct = len(filtered[filtered["routevarianttypeid"] == "School"]) / max(len(filtered), 1) * 100
    st.metric("School Services", f"{school_pct:.0f}%")
with kpi4:
    st.metric("Active Operators", f"{filtered['operator_name'].nunique():,}")
with kpi5:
    repl = len(routes_detail[routes_detail["route_variant_type"] == "Temporary"])
    st.metric("Replacement Buses", f"{repl:,}", delta="⚠ Disruption indicator")

st.markdown("---")

# ── Tabs ──────────────────────────────────────────────────────────────────────
tab1, tab2, tab3, tab4 = st.tabs([
    "📍 Route Explorer",
    "🏢 Operator Intelligence",
    "⚠️ Disruption Tracker",
    "🗺️ Network Coverage"
])

# ════════════════════════════════════════════════════════════════════════════════
# TAB 1: Route Explorer
# ════════════════════════════════════════════════════════════════════════════════
with tab1:
    st.markdown('<div class="section-title">🔍 Route Explorer — Find & Analyse Routes</div>', unsafe_allow_html=True)
    
    col_search, col_op = st.columns([2, 2])
    with col_search:
        search_query = st.text_input("🔎 Search route name", placeholder="e.g. Maitland, Shoalhaven, Parramatta...")
    with col_op:
        top_operators = ["All"] + sorted(filtered["operator_name"].value_counts().head(20).index.tolist())
        selected_op = st.selectbox("Filter by Operator", top_operators)

    # Apply local filters
    explore_df = filtered.copy()
    if search_query:
        mask = (
            explore_df["route_name"].str.contains(search_query, case=False, na=False) |
            explore_df["route_variant_name"].str.contains(search_query, case=False, na=False)
        )
        explore_df = explore_df[mask]
    if selected_op != "All":
        explore_df = explore_df[explore_df["operator_name"] == selected_op]

    # Charts row
    chart_col1, chart_col2 = st.columns(2)

    with chart_col1:
        # Distance distribution
        dist_counts = explore_df["distance_bucket"].value_counts().reset_index()
        dist_counts.columns = ["Category", "Count"]
        order = ["Short (≤10km)", "Medium (11–30km)", "Long (31–60km)", "Very Long (60km+)", "Unknown"]
        dist_counts["Category"] = pd.Categorical(dist_counts["Category"], categories=order, ordered=True)
        dist_counts = dist_counts.sort_values("Category")
        
        fig_dist = px.bar(
            dist_counts, x="Category", y="Count",
            title="Route Distance Distribution",
            color="Count",
            color_continuous_scale=["#2b3a5c", "#3182ce", "#90cdf4"],
            template="plotly_dark"
        )
        fig_dist.update_layout(
            paper_bgcolor="#1a1f2e", plot_bgcolor="#1a1f2e",
            title_font_color="#e2e8f0", showlegend=False,
            coloraxis_showscale=False, height=300,
            margin=dict(t=40, b=20, l=10, r=10)
        )
        fig_dist.update_traces(marker_line_color="#141824", marker_line_width=1.5)
        st.plotly_chart(fig_dist, use_container_width=True)

    with chart_col2:
        # Service type donut
        type_counts = explore_df["routevarianttypeid"].value_counts().reset_index()
        type_counts.columns = ["Type", "Count"]
        
        colors = ["#3182ce", "#68d391", "#f6ad55", "#fc8181", "#b794f4", "#76e4f7", "#fbd38d", "#feb2b2"]
        fig_donut = px.pie(
            type_counts, names="Type", values="Count",
            title="Service Type Breakdown",
            hole=0.55,
            template="plotly_dark",
            color_discrete_sequence=colors
        )
        fig_donut.update_layout(
            paper_bgcolor="#1a1f2e", plot_bgcolor="#1a1f2e",
            title_font_color="#e2e8f0", height=300,
            legend=dict(font=dict(color="#a0aec0", size=11)),
            margin=dict(t=40, b=10, l=10, r=10)
        )
        st.plotly_chart(fig_donut, use_container_width=True)

    # Results table
    st.markdown(f'<div class="section-title">📋 Results — {len(explore_df):,} routes found</div>', unsafe_allow_html=True)
    
    display_cols = ["route_variant_name", "operator_name", "routevarianttypeid", 
                    "directionid", "route_distance", "regionname"]
    col_labels = {
        "route_variant_name": "Route Name",
        "operator_name": "Operator",
        "routevarianttypeid": "Type",
        "directionid": "Direction",
        "route_distance": "Distance (km)",
        "regionname": "Contract Region"
    }
    
    table_df = explore_df[display_cols].rename(columns=col_labels).head(500)
    st.dataframe(
        table_df,
        use_container_width=True,
        height=360,
        column_config={
            "Distance (km)": st.column_config.NumberColumn(format="%.1f km"),
        }
    )
    
    if len(explore_df) > 500:
        st.caption(f"⚠ Showing top 500 of {len(explore_df):,} results. Refine your filters.")

# ════════════════════════════════════════════════════════════════════════════════
# TAB 2: Operator Intelligence
# ════════════════════════════════════════════════════════════════════════════════
with tab2:
    st.markdown('<div class="section-title">🏢 Operator Intelligence — Who Runs What</div>', unsafe_allow_html=True)

    op_summary = (
        filtered.groupby("operator_name")
        .agg(
            route_count=("route", "count"),
            avg_distance=("route_distance", "mean"),
            total_distance=("route_distance", "sum"),
            school_routes=("routevarianttypeid", lambda x: (x == "School").sum()),
            regular_routes=("routevarianttypeid", lambda x: (x == "Regular").sum()),
        )
        .reset_index()
        .sort_values("route_count", ascending=False)
    )
    op_summary["school_pct"] = (op_summary["school_routes"] / op_summary["route_count"] * 100).round(1)
    op_summary["efficiency_score"] = (
        op_summary["regular_routes"] / op_summary["route_count"] * 50 +
        np.clip(100 - op_summary["avg_distance"], 0, 50)
    ).round(1)

    top_n = st.slider("Show top N operators", 5, 30, 15)
    top_ops = op_summary.head(top_n)

    op_col1, op_col2 = st.columns(2)
    
    with op_col1:
        fig_ops = px.bar(
            top_ops.sort_values("route_count"),
            x="route_count", y="operator_name",
            orientation="h",
            title=f"Top {top_n} Operators by Route Count",
            color="school_pct",
            color_continuous_scale=["#3182ce", "#f6ad55", "#fc8181"],
            labels={"route_count": "Routes", "operator_name": "", "school_pct": "School %"},
            template="plotly_dark"
        )
        fig_ops.update_layout(
            paper_bgcolor="#1a1f2e", plot_bgcolor="#1a1f2e",
            title_font_color="#e2e8f0", height=420,
            coloraxis_colorbar=dict(title="School %", tickfont=dict(color="#a0aec0")),
            margin=dict(t=40, b=20, l=10, r=10)
        )
        st.plotly_chart(fig_ops, use_container_width=True)

    with op_col2:
        fig_scatter = px.scatter(
            top_ops,
            x="avg_distance",
            y="route_count",
            size="total_distance",
            color="school_pct",
            hover_name="operator_name",
            title="Distance vs Volume (bubble = total km operated)",
            labels={
                "avg_distance": "Avg Route Distance (km)",
                "route_count": "Number of Routes",
                "school_pct": "School %"
            },
            color_continuous_scale=["#3182ce", "#fc8181"],
            template="plotly_dark"
        )
        fig_scatter.update_layout(
            paper_bgcolor="#1a1f2e", plot_bgcolor="#1a1f2e",
            title_font_color="#e2e8f0", height=420,
            margin=dict(t=40, b=20, l=10, r=10)
        )
        st.plotly_chart(fig_scatter, use_container_width=True)

    # Stacked bar: school vs regular split per operator
    st.markdown('<div class="section-title">📊 Service Mix by Operator</div>', unsafe_allow_html=True)
    
    mix_data = top_ops.melt(
        id_vars="operator_name",
        value_vars=["school_routes", "regular_routes"],
        var_name="Service Type", value_name="Count"
    )
    mix_data["Service Type"] = mix_data["Service Type"].map({
        "school_routes": "School", "regular_routes": "Regular"
    })
    
    fig_stack = px.bar(
        mix_data,
        x="operator_name", y="Count",
        color="Service Type",
        barmode="stack",
        title="School vs Regular Route Mix",
        color_discrete_map={"School": "#f6ad55", "Regular": "#3182ce"},
        template="plotly_dark"
    )
    fig_stack.update_layout(
        paper_bgcolor="#1a1f2e", plot_bgcolor="#1a1f2e",
        title_font_color="#e2e8f0", height=350,
        xaxis_tickangle=-40,
        legend=dict(font=dict(color="#a0aec0")),
        margin=dict(t=40, b=100, l=10, r=10)
    )
    st.plotly_chart(fig_stack, use_container_width=True)

    # Operator detail table
    st.markdown('<div class="section-title">📋 Operator Summary Table</div>', unsafe_allow_html=True)
    display_op = op_summary.head(50).rename(columns={
        "operator_name": "Operator",
        "route_count": "Total Routes",
        "avg_distance": "Avg Distance (km)",
        "total_distance": "Total km Operated",
        "school_routes": "School Routes",
        "regular_routes": "Regular Routes",
        "school_pct": "School %",
        "efficiency_score": "Efficiency Score"
    })
    st.dataframe(
        display_op,
        use_container_width=True,
        height=320,
        column_config={
            "Avg Distance (km)": st.column_config.NumberColumn(format="%.1f"),
            "Total km Operated": st.column_config.NumberColumn(format="%.0f"),
            "School %": st.column_config.ProgressColumn(format="%.1f%%", min_value=0, max_value=100),
            "Efficiency Score": st.column_config.NumberColumn(format="%.1f ⭐"),
        }
    )

# ════════════════════════════════════════════════════════════════════════════════
# TAB 3: Disruption Tracker
# ════════════════════════════════════════════════════════════════════════════════
with tab3:
    st.markdown('<div class="section-title">⚠️ Disruption & Replacement Service Tracker</div>', unsafe_allow_html=True)

    # Disruptions from routes_detail
    disruptions = routes_detail[routes_detail["route_variant_type"].isin(["Temporary", "Planned Replacement"])]
    planned_repl = bus_routes[bus_routes["routevarianttypeid"] == "Planned Replacement"]

    # KPIs
    d1, d2, d3, d4 = st.columns(4)
    with d1:
        st.metric("⚠ Temporary Services", len(disruptions))
    with d2:
        st.metric("🔄 Planned Replacements", len(planned_repl))
    with d3:
        # Operators affected
        aff_ops = disruptions["operator_name"].nunique() if "operator_name" in disruptions.columns else "N/A"
        st.metric("🏢 Operators Affected", aff_ops)
    with d4:
        # Transport modes
        aff_modes = disruptions["transport_name"].value_counts().iloc[0] if len(disruptions) > 0 else 0
        top_mode = disruptions["transport_name"].value_counts().index[0] if len(disruptions) > 0 else "N/A"
        st.metric("🚆 Most Replaced Mode", top_mode[:25] if top_mode != "N/A" else "N/A")

    st.markdown("")

    # Alert boxes
    if len(disruptions) > 100:
        st.markdown(f"""
        <div class="alert-box">
            🚨 <strong>HIGH DISRUPTION LEVEL:</strong> {len(disruptions):,} temporary services currently active.
            Train replacement buses account for the majority. Commuter delays are likely on affected corridors.
        </div>
        """, unsafe_allow_html=True)
    
    st.markdown(f"""
    <div class="alert-box-warn">
        ⚠ <strong>PLANNED REPLACEMENT BUSES:</strong> {len(planned_repl):,} planned replacement bus services detected in the route network.
        These indicate scheduled track maintenance or planned service suspensions.
    </div>
    """, unsafe_allow_html=True)

    st.markdown(f"""
    <div class="insight-box">
        ✅ <strong>INSIGHT:</strong> Regular bus services remain operational across {filtered['operator_name'].nunique():,} operators.
        School services ({len(filtered[filtered['routevarianttypeid']=='School']):,} routes) are unaffected by current disruptions.
    </div>
    """, unsafe_allow_html=True)

    disr_col1, disr_col2 = st.columns(2)

    with disr_col1:
        # Disruption by transport mode
        if len(disruptions) > 0:
            mode_disruption = disruptions["transport_name"].value_counts().head(10).reset_index()
            mode_disruption.columns = ["Transport Mode", "Count"]
            fig_mode = px.bar(
                mode_disruption,
                x="Count", y="Transport Mode",
                orientation="h",
                title="Disruptions by Transport Mode",
                color="Count",
                color_continuous_scale=["#c05621", "#fc8181"],
                template="plotly_dark"
            )
            fig_mode.update_layout(
                paper_bgcolor="#1a1f2e", plot_bgcolor="#1a1f2e",
                title_font_color="#e2e8f0", height=360,
                showlegend=False, coloraxis_showscale=False,
                margin=dict(t=40, b=20, l=10, r=10)
            )
            st.plotly_chart(fig_mode, use_container_width=True)

    with disr_col2:
        # Planned replacement by region
        if len(planned_repl) > 0:
            reg_repl = planned_repl["regionname"].value_counts().head(10).reset_index()
            reg_repl.columns = ["Region / Contract", "Count"]
            fig_reg = px.bar(
                reg_repl,
                x="Count", y="Region / Contract",
                orientation="h",
                title="Planned Replacements by Contract Region",
                color="Count",
                color_continuous_scale=["#744210", "#f6ad55"],
                template="plotly_dark"
            )
            fig_reg.update_layout(
                paper_bgcolor="#1a1f2e", plot_bgcolor="#1a1f2e",
                title_font_color="#e2e8f0", height=360,
                showlegend=False, coloraxis_showscale=False,
                margin=dict(t=40, b=20, l=10, r=10)
            )
            st.plotly_chart(fig_reg, use_container_width=True)

    # Disruption detail table
    st.markdown('<div class="section-title">📋 Active Temporary Services</div>', unsafe_allow_html=True)
    
    if len(disruptions) > 0:
        disp_cols = [c for c in ["operator_name", "my_timetable_route_name", "transport_name",
                                  "route_variant_type", "route_search_name", "service_direction_name"] 
                     if c in disruptions.columns]
        st.dataframe(
            disruptions[disp_cols].rename(columns={
                "operator_name": "Operator",
                "my_timetable_route_name": "Route Code",
                "transport_name": "Mode",
                "route_variant_type": "Status",
                "route_search_name": "Corridor",
                "service_direction_name": "Direction"
            }),
            use_container_width=True,
            height=350
        )
    else:
        st.success("✅ No temporary disruption services currently detected.")

# ════════════════════════════════════════════════════════════════════════════════
# TAB 4: Network Coverage
# ════════════════════════════════════════════════════════════════════════════════
with tab4:
    st.markdown('<div class="section-title">🗺️ Network Coverage Analysis</div>', unsafe_allow_html=True)

    # Transport mode breakdown from routes_detail
    nc_col1, nc_col2 = st.columns(2)

    with nc_col1:
        transport_summary = routes_detail["transport_name"].value_counts().reset_index()
        transport_summary.columns = ["Mode", "Services"]
        transport_summary = transport_summary[transport_summary["Services"] > 5]
        
        fig_tree = px.treemap(
            transport_summary,
            path=["Mode"],
            values="Services",
            title="Service Count by Transport Mode",
            color="Services",
            color_continuous_scale=["#1a365d", "#3182ce", "#90cdf4"],
            template="plotly_dark"
        )
        fig_tree.update_layout(
            paper_bgcolor="#1a1f2e",
            title_font_color="#e2e8f0",
            height=400,
            margin=dict(t=40, b=10, l=10, r=10)
        )
        fig_tree.update_traces(textinfo="label+value", textfont_size=13)
        st.plotly_chart(fig_tree, use_container_width=True)

    with nc_col2:
        # Direction balance analysis
        dir_type = filtered.groupby(["routevarianttypeid", "directionid"]).size().reset_index(name="count")
        fig_dir = px.bar(
            dir_type,
            x="routevarianttypeid", y="count",
            color="directionid",
            barmode="group",
            title="Direction Balance by Service Type",
            labels={"routevarianttypeid": "Service Type", "count": "Routes", "directionid": "Direction"},
            color_discrete_map={"In": "#3182ce", "Out": "#68d391", "Loop": "#f6ad55"},
            template="plotly_dark"
        )
        fig_dir.update_layout(
            paper_bgcolor="#1a1f2e", plot_bgcolor="#1a1f2e",
            title_font_color="#e2e8f0", height=400,
            legend=dict(font=dict(color="#a0aec0")),
            margin=dict(t=40, b=20, l=10, r=10)
        )
        st.plotly_chart(fig_dir, use_container_width=True)

    # Contract region heatmap
    st.markdown('<div class="section-title">📊 Contract Region Coverage Matrix</div>', unsafe_allow_html=True)

    region_type = (
        filtered.groupby(["regionname", "routevarianttypeid"])
        .size()
        .reset_index(name="count")
    )
    # Focus on top regions
    top_regions = filtered["regionname"].value_counts().head(20).index
    region_type_top = region_type[region_type["regionname"].isin(top_regions)]

    region_pivot = region_type_top.pivot_table(
        index="regionname", columns="routevarianttypeid", values="count", fill_value=0
    )

    fig_hmap = px.imshow(
        region_pivot,
        title="Route Count Heatmap: Top 20 Contract Regions × Service Type",
        color_continuous_scale=["#141824", "#1a365d", "#3182ce", "#90cdf4"],
        template="plotly_dark",
        aspect="auto"
    )
    fig_hmap.update_layout(
        paper_bgcolor="#1a1f2e", plot_bgcolor="#1a1f2e",
        title_font_color="#e2e8f0", height=480,
        xaxis=dict(tickfont=dict(color="#a0aec0")),
        yaxis=dict(tickfont=dict(color="#a0aec0", size=10)),
        coloraxis_colorbar=dict(title="Routes", tickfont=dict(color="#a0aec0")),
        margin=dict(t=50, b=20, l=10, r=10)
    )
    st.plotly_chart(fig_hmap, use_container_width=True)

    # Insights
    st.markdown('<div class="section-title">💡 Network Intelligence Insights</div>', unsafe_allow_html=True)
    
    ins1, ins2, ins3 = st.columns(3)
    
    with ins1:
        school_pct_full = len(bus_routes[bus_routes["routevarianttypeid"] == "School"]) / len(bus_routes) * 100
        st.markdown(f"""
        <div class="alert-box-warn">
            🏫 <strong>SCHOOL SERVICE DEPENDENCY</strong><br>
            {school_pct_full:.0f}% of NSW bus routes are school services.
            These are vulnerable to term-time schedule changes and holiday reductions.
        </div>
        """, unsafe_allow_html=True)
    
    with ins2:
        loop_routes = len(filtered[filtered["directionid"] == "Loop"])
        st.markdown(f"""
        <div class="insight-box">
            🔁 <strong>LOOP ROUTE COVERAGE</strong><br>
            {loop_routes:,} loop routes identified. These serve circular corridors
            and are critical for local connectivity without transfer requirements.
        </div>
        """, unsafe_allow_html=True)
    
    with ins3:
        long_routes = len(filtered[filtered["route_distance"] > 60])
        st.markdown(f"""
        <div class="alert-box">
            🛣️ <strong>LONG-HAUL SERVICES</strong><br>
            {long_routes:,} routes exceed 60km. These face higher delay risk
            and may benefit from real-time GPS tracking priority and express alternatives.
        </div>
        """, unsafe_allow_html=True)
