<p align="center">
  <img src="https://img.shields.io/badge/Google%20Solution%20Challenge-2026-4285F4?style=for-the-badge&logo=google&logoColor=white" alt="Google Solution Challenge 2026">
</p>

<h1 align="center">MediFlow</h1>
<p align="center"><b>AI-powered medical logistics platform focused on smart resource allocation</b></p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Firebase-039BE5?style=for-the-badge&logo=Firebase&logoColor=white" alt="Firebase">
  <img src="https://img.shields.io/badge/Gemini%20AI-8E75B2?style=for-the-badge&logo=google-gemini&logoColor=white" alt="Gemini AI">
  <img src="https://img.shields.io/badge/OpenRouteService-3E3E3E?style=for-the-badge&logo=openstreetmap&logoColor=white" alt="ORS">
</p>

---

## Table of Contents
- [Project Overview](#project-overview)
- [The Problem & Solution](#the-problem--the-solution)
- [Core Feature Set](#core-feature-set)
- [Technical Architecture](#technical-architecture)
- [Project Structure](#project-structure)
- [Data & Schema](#data--schema)
- [Development & Setup](#development--setup)
- [Roadmap](#roadmap)

---

## Project Overview
**MediFlow** is an enterprise-grade medical logistics platform engineered to solve the "Last Mile" medical supply crisis. By combining **Generative AI** for demand forecasting with **Heuristic Optimization** for redistribution, MediFlow transforms a fragmented, reactive supply chain into a proactive, life-saving ecosystem, specifically targeting cold-chain pharmaceutical integrity.

## The Problem | The Solution
**The Crisis:** Rural clinics often face 30% higher stockout rates for essential antibiotics, while urban hospitals simultaneously dispose of expired stock due to over-purchasing. This inequality is compounded by the lack of intelligent monitoring for cold-chain medicines (vaccines, insulin).

**The MediFlow Solution:** We don't just track inventory; we **predict** shortages before they happen and **automate** the movement of medicine from surplus hospitals to deficit clinics using road-accurate route optimization, ensuring that every life-saving resource is allocated where it’s needed most.

---

## Core Feature Set

| Module | Feature | Description |
| :--- | :--- | :--- |
| **Facility** | Smart Logging | Atomic tracking of daily usage with real-time burn rate computation. |
| **Facility** | AI Forecasting | 30-day predictive spikes powered by Gemini-1.5-Flash with reasoning. |
| **Facility** | Auto-Drafting | Intelligent population of restock indents based on AI predictions. |
| **Facility** | AI Assistant | 24/7 logistics expert for stock queries and expiry alerts via NLP. |
| **Admin** | Command Center | Network-wide regional oversight with deep-dive analytics. |
| **Admin** | Approval Pipeline | Secure multi-step hub for reviewing redistribution plans. |
| **Admin** | Logistics Map | Interactive map with road-accurate routing and site classification. |
| **Admin** | Global Optimization | High-speed matching of shortages to surpluses across the network. |

---

## Technical Architecture

MediFlow is built on **Clean Architecture** principles, ensuring that business logic is decoupled from the UI and external services.

### 1. The AI Engine (Gemini 1.5 Flash)
We leverage Gemini's large context window to process months of anonymized usage logs. The model acts as a **Predictive Reasoning Layer**, identifying non-obvious patterns like demographic-based medicine consumption surges.

### 2. The Optimization Heuristic (OTS)
Our proprietary **Optimal Transfer Score** ensures that redistribution is both efficient and equitable:
$$OTS = (w_{dist} \cdot Proximity) + (w_{prior} \cdot RuralPriority) + (w_{qty} \cdot QtyMatch)$$
*   **Proximity**: Minimizes logistics cost and time.
*   **Rural Priority**: A weight multiplier ensuring that remote facilities are never "starved" by the algorithm.

### 3. Geospatial Routing System
Integrated with **flutter_map** and **OSRM/OpenRouteService**, our routing engine decodes complex polylines to provide precise, road-accurate delivery paths, factoring in real-world geography.

---

## Project Structure

```bash
lib/
├── constants/
│   └── colors.dart             # Project-wide design tokens & premium palette
│
├── models/                     # Immutable Data Domain
│   ├── daily_usage_log.dart    # Atomic snapshots of medicine consumption
│   ├── facility.dart           # Metadata & Geospatial profiles for nodes
│   ├── inventory_item.dart     # Stock tracking & expiry metadata
│   ├── request.dart            # Ledger for redistribution & restock flows
│   └── usage_log.dart          # Helper models for analytics visualization
│
├── services/                   # Business Logic & Intelligence Layer
│   ├── ai_service.dart         # Gemini-1.5-Flash forecasting & reasoning
│   ├── chat_service.dart       # NLP pipeline for the AI Assistant
│   ├── firebase_service.dart   # Firestore infrastructure & transactions
│   ├── optimization_service.dart # OTS heuristic & matching algorithm
│   ├── routing_service.dart    # Geospatial OSRM/ORS pathfinding logic
│   ├── simulation_service.dart # Real-time demo data generation engine
│   └── tool_dispatcher.dart    # AI tool-calling & data registry
│
├── views/                      # Presentation Layer (UI)
│   ├── admin/                  # Central Command Module
│   │   ├── admin_indent_approval_page.dart
│   │   ├── admin_indent_status_page.dart
│   │   ├── admin_overview.dart
│   │   └── route_optimization_map.dart
│   │
│   ├── auth/                   # Security & Role Gatekeeping
│   │   ├── login_screen.dart
│   │   └── role_selection_screen.dart
│   │
│   ├── facility/               # Local Management Module
│   │   ├── active_indents_page.dart
│   │   ├── ai_forecast_page.dart
│   │   ├── alerts_page.dart
│   │   ├── daily_logging_page.dart
│   │   ├── facility_overview.dart
│   │   └── indent_creation_page.dart
│   │
│   └── shared/                 # Common & Reusable Components
│       ├── ai_chat_page.dart
│       ├── help_page.dart
│       └── sidebar_layout.dart
│
├── firebase_options.dart       # Cross-platform Firebase configuration
└── main.dart                   # Application entry & Router configuration
```

---

## Data & Schema
MediFlow utilizes a hierarchical Firestore schema designed for high-concurrency performance:
*   **`/facilities`**: Metadata, type (urban/rural), and geospatial coordinates.
*   **`/inventory/{fac_id}/medicines`**: Sub-collection tracking individual batches and live stock levels.
*   **`/requests`**: Global collection for tracking movement, status (Pending/Approved/Fulfilled), and manifest details.

---

## Development & Setup

### Prerequisites
- Flutter SDK (>=3.0.0)
- Firebase Project
- Google AI Studio API Key (Gemini)
- OpenRouteService API Key

### Quick Start
```bash
# 1. Clone & Install
git clone https://github.com/pavsoss/MediFlow.git && cd MediFlow
flutter pub get

# 2. Configure Environment
# Create .env and add:
# GEMINI_API_KEY=your_key
# ORS_API_KEY=your_key

# 3. Run Prototype
flutter run -d chrome --web-renderer html
```

---

## Roadmap
- [ ] **Offline-First Sync**: Native SQLite integration for zero-connectivity environments.
- [ ] **Batch Tracking**: QR-code integration for granular tracking of individual medicine strips.
- [ ] **IoT Cold Chain**: Integration with sensors to track temperature-sensitive vaccines during transit.

---

## The Team
Built with ❤️ for the **Google Solution Challenge 2026**.

- [Aarush Yadav]
- [Paavni Bansal]
- [Devansh Rana] 
- [Sharvi Singhal]

---
<p align="center">© 2026 MediFlow Team. <i>Engineering a smarter, healthier supply chain.</i></p>
