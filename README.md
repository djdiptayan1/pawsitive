# Pawsitive

Pawsitive is an application connecting citizens and rescuers to help animals in distress. It allows citizens to report animal emergencies (SOS) and dispatches nearby verified rescuers using real-time location tracking to provide immediate assistance.

## Features
- **SOS Reporting & Triage:** Citizens can report animal emergencies with photos, location, and severity (Severe, Moderate, Minor). The system calculates urgency scores and handles duplicate cases by grouping reports.
- **Intelligent Dispatch System:** Automatically alerts nearby verified rescuers using a dynamic expanding ring radius based on incident severity and proximity wait times.
- **Real-Time Location & ETA:** Tracks rescuer locations via WebSockets for precise dispatching and provides live ETA updates to citizens and NGOs.
- **Rescue Condition & Staging Logs:** Rescuers can log the condition of the animal at various stages (`en_route`, `on_scene`, `first_aid`, `in_transport`, `at_vet`, `recovered`) including adding notes and photos.
- **Drop-off Handling:** Tracks where the animal was taken (`vet_hospital`, `ngo_shelter`, or `treated_on_scene`).
- **User Roles & Dashboards:** Distinct interfaces for Citizens (reporting and tracking), Rescuers (managing active rescues and status), and NGOs.
- **Credit System:** Rescuers earn credits for their contributions and successful rescues.
- **Rescue Replay & History:** Stores rescue location history for detailed activity logging and potential replay/review of rescues.

## Tech Stack
- **Frontend:** iOS application built with Swift and SwiftUI, utilizing MVVM architecture.
- **Backend:** Node.js, Express, and WebSockets (for real-time tracking).
- **Database & Auth:** Supabase (PostgreSQL) for relational data and authentication.
- **Media Storage:** Cloudinary for image uploads.

## Project Structure
- `backend/`: Contains the Node.js Express server. Features API routes for incidents, dispatch, users, and WebSocket server for real-time location updates.
- `pawsitive-app/`: The iOS application source code containing the SwiftUI views, view models, and services.

## Setup Instructions

### Backend
1. Navigate to the `backend/` directory:
   ```bash
   cd backend
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Copy the example environment file and configure the variables (Supabase URLs, keys, database connection, Cloudinary, etc.):
   ```bash
   cp .env.example .env
   ```
4. Start the development server:
   ```bash
   npm run dev
   ```
   The backend runs on `http://localhost:3000` by default.

### iOS App
1. Ensure you have Xcode installed.
2. Navigate to the `pawsitive-app/` directory and open the project:
   ```bash
   cd pawsitive-app
   open pawsitive-app.xcodeproj
   ```
3. Make sure to configure the `AppConfig.swift` to point the `ApiEndpoints.baseURL` to your running backend (e.g., your local machine's IP address when running on a physical device, or `localhost` for simulator).
4. Build and run the app in Xcode.
