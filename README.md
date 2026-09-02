# 🚀 FiberJet — Next-Gen ISP Management & Field Operations Platform

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Melos](https://img.shields.io/badge/Melos-Monorepo-1E293B?style=for-the-badge&logo=dart&logoColor=white)](https://melos.invertase.dev)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15+-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![License](https://img.shields.io/badge/License-MIT-green.style=for-the-badge)](LICENSE)

**FiberJet** is an end-to-end Internet Service Provider (ISP) ecosystem and field management platform built with Flutter and Dart. It unifies customer account management, technician field operations, sales lead tracking, network security diagnostics, and administrative control in a modular monorepo architecture.

---

## ✨ Features Overview

### 👤 1. Customer Self-Service Portal
* **Internet Plans & Upgrades**: Browse tier options, bandwidth limits, billing cycles, and execute instant plan upgrades.
* **Modem / ONT Info & Diagnostics**: View device status, connected IP, optical signal levels, and perform remote resets.
* **Integrated Speed Test**: Run real-time latency, download, and upload bandwidth tests with diagnostic reports.
* **Live Technician Tracking**: Real-time map-based GPS tracking of dispatched service technicians.
* **OTT & Entertainment Claims**: Claim bundled subscriptions (Netflix, Prime, Disney+) linked to active internet plans.
* **Personal Cloud Drive**: Integrated cloud storage space provided with premium high-speed tiers.
* **Support & Ticketing**: Submit support requests, report outages, and rate completed technician jobs.

### 🛠️ 2. Field Technician Portal
* **Active Job Workflow**: Accept/reject assigned installation or repair tasks with step-by-step resolution checklists.
* **Live GPS Tracking & Navigation**: Signal active status and broadcast location to customers en route.
* **Modem / ONT Assignment**: Scan, pair, and provision customer premises equipment (CPE).
* **Earnings & Payout Requests**: Track per-job commissions, view payment history, and request payout withdrawals.
* **Job Rejection & Support Escalation**: Submit job rejection reasons directly to admin operations for reassignment.

### 💼 3. Sales Representative Portal
* **Leads Pipeline (Kanban Board)**: Drag-and-drop management of sales leads across pipeline stages (*New*, *Contacted*, *Survey*, *Converted*).
* **New Lead Capture**: Instant registration form for prospective broadband subscribers with geotagged locations.
* **Sales Commission Tracker**: Real-time tracking of closed deals, earned commissions, and targets.
* **Profit Calculator**: Estimate recurring revenue and gross profit margins based on custom bandwidth quotes.
* **Lead History & Activity Feed**: Document site visit notes, customer communications, and follow-up schedules.

### 🛡️ 4. Admin Management Console
* **User & Role Approval**: Multi-tier approval system for new technicians, sales agents, and customer registrations.
* **Payout Approvals**: Review and approve technician payout requests with transaction logging.
* **Ad & Banner Control Panel**: Publish in-app promotional banners, announcements, and plan upgrade offers.
* **Network Security Diagnostics**: Integrated Wi-Fi security scanner, open-port audits, and vulnerability threat alerts.
* **System Analytics & Operations**: Real-time monitoring of active jobs, network load, and revenue performance.

---

## 🏗️ Repository Architecture (Melos Monorepo)

```
fiberjet/
├── apps/
│   └── mobile/                       # Multi-role Flutter application (Android, iOS, Web, Desktop)
│       ├── lib/
│       │   ├── screens/              # Role-based UI Screens (Customer, Tech, Sales, Admin)
│       │   ├── services/             # API Service, Auth Provider, Location, Diagnostics
│       │   ├── widgets/              # Reusable UI Components & Custom Controls
│       │   └── main.dart             # App Entry point & Role-based Router
│       └── pubspec.yaml
├── packages/
│   ├── backend/                      # Dart Server API & SQL Migration Handlers
│   │   ├── bin/                      # Server entry point
│   │   ├── lib/                      # Route controllers, middleware, & DB connections
│   │   └── pubspec.yaml
│   └── fiberjet_shared/              # Shared Domain Models & Business Logic
│       ├── lib/
│       │   └── src/models/           # User, Job, Lead, Plan, Payout, Notification Models
│       └── pubspec.yaml
├── ui _friberjet/                    # High-fidelity Stitch UI Prototypes & Assets
├── migrations/                       # Database migration SQL files
├── database_schema.sql               # Core PostgreSQL database schema
├── seed_plans.sql                    # Initial seed data for broadband plans
├── melos.yaml                        # Monorepo workspace configuration
└── pubspec.yaml                      # Root pubspec configuration
```

---

## 🚀 Getting Started

### Prerequisites
* **Flutter SDK**: `>=3.19.0`
* **Dart SDK**: `>=3.3.0`
* **Melos**: Install globally via `dart pub global activate melos`
* **PostgreSQL**: `15+` (for backend database)

### Installation & Setup

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/Salamon2608/Fiberjet.git
   cd Fiberjet
   ```

2. **Bootstrap the Monorepo Workspace**:
   ```bash
   melos bootstrap
   ```

3. **Database Configuration**:
   Create a PostgreSQL database and run the schema & seed scripts:
   ```bash
   psql -U postgres -d fiberjet -f database_schema.sql
   psql -U postgres -d fiberjet -f seed_plans.sql
   ```

4. **Run the Backend API Server**:
   ```bash
   cd packages/backend
   dart run bin/server.dart
   ```

5. **Run the Mobile / Web App**:
   ```bash
   cd apps/mobile
   flutter run
   ```

---

## 🛠️ Melos Commands

* **Analyze all packages**:
  ```bash
  melos run analyze
  ```
* **Run tests across monorepo**:
  ```bash
  melos run test
  ```

---

## 📜 License

Distributed under the MIT License. See `LICENSE` for more information.

---

<p center="align">Built with ❤️ for High-Speed Broadband Operations.</p>
