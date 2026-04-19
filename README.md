# 🚌 NSW TransitIQ — Transit Intelligence Dashboard

## Product Overview

**TransitIQ** is a network intelligence dashboard built on NSW Open Transport Data.
It targets transit operators and network planners, solving four core problems:

| Problem | Solution |
|---|---|
| Route Confusion | Unified route browser with smart search + filters |
| Coverage Gaps | Operator footprint analysis + region heatmap |
| Disruption Tracking | Real-time replacement bus & temporary service tracker |
| Poor Planning | Distance distribution, service mix & efficiency scoring |

---

## Dataset

| File | Records | Description |
|---|---|---|
| `bus_routes.csv` | 14,635 | Route variants with operator, distance, contract region |
| `routes_1.csv` | 13,562 | Detailed route metadata including GTFS IDs, transport modes |

**Key findings from the data:**
- 53% of NSW bus routes are school services (high term-time dependency)
- 118 active temporary/replacement services (train disruption indicators)
- 89 planned replacement bus services detected
- Top operator: Busways R1 with 1,389 route variants
- Route distances range from 0.47km to 97,257km (data quality issue flagged)

---

## How to Run

### Requirements
```bash
pip install streamlit plotly pandas numpy
```

### Launch
```bash
# Place bus_routes.csv and routes_1.csv in the same folder as app.py
streamlit run app.py
```

The dashboard opens at **http://localhost:8501**

---

## Features

### 📍 Tab 1: Route Explorer
- Full-text search across 14,635 route variants
- Filter by operator, service type, direction, distance range
- Distance distribution bar chart + service type donut chart
- Sortable results table with 500-row preview

### 🏢 Tab 2: Operator Intelligence
- Top N operator leaderboard (configurable 5–30)
- Volume vs distance scatter plot (bubble = total km operated)
- School vs Regular service mix stacked bar
- Operator summary table with efficiency score + progress bars

### ⚠️ Tab 3: Disruption Tracker
- Active temporary and planned replacement service detection
- Disruption KPIs: affected operators, dominant mode, total count
- Alert-classified insight cards (critical / warning / healthy)
- Disruptions by transport mode + by contract region
- Detailed disruption table with corridor and direction info

### 🗺️ Tab 4: Network Coverage
- Treemap of all transport modes by service count
- Direction balance chart (Inbound vs Outbound vs Loop)
- Contract region × service type coverage heatmap
- Three automated network intelligence insight cards

---

## Target Users

| User | Tab Focus | Key Value |
|---|---|---|
| **Commuter Support Teams** | Route Explorer | Quick answers to "which route goes where" |
| **Network Planners** | Coverage + Operator | Identify gaps, rebalance contracts |
| **Operations Managers** | Disruption Tracker | Monitor replacements, alert stakeholders |

---

## Tech Stack
- **Python 3** · **Streamlit** · **Plotly** · **Pandas** · **NumPy**
- NSW Open Transport Open Data (bus_routes + routes metadata)
