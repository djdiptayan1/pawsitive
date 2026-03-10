//
//  JobsView.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 09/03/26.
//

import Combine
import SwiftUI

// MARK: - ViewModel
@MainActor
class JobsViewModel: ObservableObject {
    @Published var incidents: [RecentActivityModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""

    init() {
        loadIncidents()
    }

    func loadIncidents() {
        Task {
            isLoading = true
            errorMessage = nil

            guard let token = KeychainManager.shared.getString(key: .accessToken) else {
                errorMessage = "Please log in again."
                isLoading = false
                return
            }

            do {
                struct PendingResponse: Decodable {
                    let incidents: [RecentActivityModel]
                }
                let result: PendingResponse = try await NetworkManager.shared.request(
                    endpoint: IncidentEndpoint.pendingIncidents(token: token),
                    keyDecodingStrategy: .useDefaultKeys)
                incidents = result.incidents
            } catch {
                errorMessage = "Failed to load rescue jobs."
                print("JobsView fetch error: \(error)")
            }
            isLoading = false
        }
    }

    func refresh() async {
        loadIncidents()
    }

    func acceptIncident(id: String) async {
        guard let token = KeychainManager.shared.getString(key: .accessToken) else { return }

        do {
            struct AcceptResponse: Decodable {
                let success: Bool
                let error: String?
            }
            let result: AcceptResponse = try await NetworkManager.shared.request(
                endpoint: IncidentEndpoint.acceptIncident(token: token, id: id),
                keyDecodingStrategy: .useDefaultKeys)

            if result.success {
                incidents.removeAll { $0.id == id }
                alertTitle = "Rescue Accepted!"
                alertMessage =
                    "Head to the location now. Your GPS is being shared with the citizen."
            } else {
                alertTitle = "Could Not Accept"
                alertMessage = "Another rescuer may have already claimed this incident."
            }
        } catch {
            alertTitle = "Error"
            alertMessage = "Failed to accept rescue. Please try again."
        }
        showAlert = true
    }
}

// MARK: - View
struct JobsView: View {
    @StateObject private var viewModel = JobsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.incidents.isEmpty {
                    loadingView
                } else if viewModel.incidents.isEmpty {
                    emptyView
                } else {
                    incidentList
                }
            }
            .background(AppConfig.Colors.background)
            .navigationTitle("Rescue Jobs")
            .refreshable {
                await viewModel.refresh()
            }
            .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
                Button("OK") {}
            } message: {
                Text(viewModel.alertMessage)
            }
        }
        .onAppear {
            viewModel.loadIncidents()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .tint(AppConfig.Colors.accent)
                .scaleEffect(1.3)
            Text("Loading pending rescues...")
                .font(AppConfig.Fonts.body)
                .foregroundColor(AppConfig.Colors.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "pawprint.fill")
                .font(.system(size: 50))
                .foregroundColor(AppConfig.Colors.accent.opacity(0.5))
            Text("No Pending Rescues")
                .font(AppConfig.Fonts.headline)
                .foregroundColor(AppConfig.Colors.textPrimary)
            Text(
                "When citizens report animals in distress, rescue requests will appear here."
            )
            .font(AppConfig.Fonts.body)
            .foregroundColor(AppConfig.Colors.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var incidentList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.incidents) { incident in
                    JobCard(incident: incident) {
                        Task {
                            await viewModel.acceptIncident(id: incident.id)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Job Card
struct JobCard: View {
    let incident: RecentActivityModel
    let onAccept: () -> Void
    @State private var isAccepting = false

    var body: some View {
        VStack(spacing: 0) {
            // Photo
            if let photoUrlStr = incident.photoUrl, let photoUrl = URL(string: photoUrlStr) {
                AsyncImage(url: photoUrl) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else if phase.error != nil {
                        photoPlaceholder
                    } else {
                        Color.gray.opacity(0.2)
                            .overlay(ProgressView())
                    }
                }
                .frame(height: 160)
                .clipped()
            }

            VStack(alignment: .leading, spacing: 12) {
                // Title + Severity
                HStack {
                    Text(incident.title ?? "Animal in Distress")
                        .font(AppConfig.Fonts.bodyBold)
                        .foregroundColor(AppConfig.Colors.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text((incident.severity ?? "unknown").uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(severityColor)
                        .clipShape(Capsule())
                }

                // Location
                if let location = incident.locationName {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 14))
                            .foregroundColor(AppConfig.Colors.textSecondary)
                        Text(location)
                            .font(AppConfig.Fonts.small)
                            .foregroundColor(AppConfig.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }

                // Time
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 14))
                        .foregroundColor(AppConfig.Colors.textSecondary)
                    Text(DateUtils.formatSupabaseDate(incident.createdAt))
                        .font(AppConfig.Fonts.small)
                        .foregroundColor(AppConfig.Colors.textSecondary)
                }

                // Accept Button
                Button(action: {
                    isAccepting = true
                    onAccept()
                }) {
                    HStack {
                        if isAccepting {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text("Accept Rescue")
                    }
                    .font(AppConfig.Fonts.bodyBold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppConfig.Colors.success)
                    .cornerRadius(AppConfig.UI.buttonCornerRadius)
                }
                .disabled(isAccepting)
            }
            .padding()
        }
        .background(AppConfig.Colors.card)
        .cornerRadius(AppConfig.UI.cornerRadius)
        .shadow(
            color: .black.opacity(0.06), radius: AppConfig.UI.cardShadowRadius, x: 0,
            y: AppConfig.UI.cardShadowOffsetY)
    }

    private var photoPlaceholder: some View {
        AppConfig.Colors.accent.opacity(0.1)
            .frame(height: 160)
            .overlay(
                Image(systemName: "pawprint.fill")
                    .font(.largeTitle)
                    .foregroundColor(AppConfig.Colors.accent)
            )
    }

    private var severityColor: Color {
        switch incident.severity?.lowercased() {
        case "severe": return AppConfig.Colors.alert
        case "moderate": return AppConfig.Colors.warning
        default: return AppConfig.Colors.accent
        }
    }
}

#Preview {
    JobsView()
}
