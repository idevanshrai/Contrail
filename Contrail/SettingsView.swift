//
//  SettingsView.swift
//  Contrail
//

import SwiftUI

/// App settings — map style, departure airport, sound preferences.
struct SettingsView: View {

    @AppStorage("preferredMapStyle") private var preferredMapStyle: String = "imagery"
    @AppStorage("lastAirportIATA") private var lastAirportIATA: String = "BER"
    @AppStorage("ambientSoundEnabled") private var ambientSoundEnabled: Bool = true

    @State private var editingIATA: String = ""
    @State private var isEditingAirport = false

    private let mapStyles: [(label: String, value: String, icon: String, description: String)] = [
        ("Standard",   "standard",  "map",              "Classic map with roads and labels"),
        ("Satellite",  "imagery",   "globe.americas",   "Satellite imagery — dark globe look"),
        ("Hybrid",     "hybrid",    "map.circle",       "Satellite with road overlay"),
    ]

    var body: some View {
        ZStack {
            ContrailTheme.darkNavy.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(ContrailTheme.skyBlue)
                        Text("Settings")
                            .font(ContrailTheme.titleFont)
                            .foregroundStyle(ContrailTheme.contrailWhite)
                    }
                    .padding(.top, 20)

                    // Map Style
                    settingsSection("Map Style") {
                        VStack(spacing: 4) {
                            ForEach(mapStyles, id: \.value) { style in
                                mapStyleRow(style)
                            }
                        }
                    }

                    // Departure Airport
                    settingsSection("Departure Airport") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Current")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(ContrailTheme.mutedText)
                                    Text(lastAirportIATA)
                                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                                        .foregroundStyle(ContrailTheme.contrailWhite)
                                }

                                Spacer()

                                Button {
                                    editingIATA = lastAirportIATA
                                    isEditingAirport.toggle()
                                } label: {
                                    Text(isEditingAirport ? "Done" : "Change")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(ContrailTheme.skyBlue)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(ContrailTheme.skyBlue.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }

                            if isEditingAirport {
                                HStack(spacing: 8) {
                                    TextField("IATA code (e.g. JFK)", text: $editingIATA)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                                        .foregroundStyle(ContrailTheme.contrailWhite)
                                        .padding(10)
                                        .background(ContrailTheme.darkNavy)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .stroke(ContrailTheme.contrailWhite.opacity(0.1), lineWidth: 1)
                                        )
                                        .onSubmit {
                                            applyIATAChange()
                                        }

                                    Button("Set") {
                                        applyIATAChange()
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(ContrailTheme.darkNavy)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(ContrailTheme.skyBlue)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                            }
                        }
                    }

                    // Sound
                    settingsSection("Sound") {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Ambient Cabin Sound")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(ContrailTheme.contrailWhite)
                                Text("Play cabin ambience during focus sessions")
                                    .font(.system(size: 12))
                                    .foregroundStyle(ContrailTheme.mutedText)
                            }

                            Spacer()

                            Toggle("", isOn: $ambientSoundEnabled)
                                .toggleStyle(.switch)
                                .tint(ContrailTheme.skyBlue)
                                .labelsHidden()
                        }
                    }
                }
                .padding(40)
                .frame(maxWidth: 550)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Helpers

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ContrailTheme.mutedText)
                .textCase(.uppercase)
                .tracking(1)

            VStack(spacing: 0) {
                content()
            }
            .contrailCard()
        }
    }

    private func mapStyleRow(_ style: (label: String, value: String, icon: String, description: String)) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                preferredMapStyle = style.value
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: style.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(
                        preferredMapStyle == style.value ? ContrailTheme.skyBlue : ContrailTheme.mutedText
                    )
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(style.label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ContrailTheme.contrailWhite)
                    Text(style.description)
                        .font(.system(size: 11))
                        .foregroundStyle(ContrailTheme.mutedText)
                }

                Spacer()

                if preferredMapStyle == style.value {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(ContrailTheme.skyBlue)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func applyIATAChange() {
        let code = editingIATA.uppercased().trimmingCharacters(in: .whitespaces)
        if code.count == 3 {
            lastAirportIATA = code
            isEditingAirport = false
        }
    }
}

#Preview {
    SettingsView()
}
