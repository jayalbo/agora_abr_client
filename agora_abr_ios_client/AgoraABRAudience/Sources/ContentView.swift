import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var manager = AgoraAudienceManager()

    @State private var appId = ""
    @State private var channel = ""
    @State private var token = ""
    @State private var uidText: String = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    GroupBox("Join") {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Agora App ID", text: $appId)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .textFieldStyle(.roundedBorder)

                            TextField("Channel", text: $channel)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .textFieldStyle(.roundedBorder)

                            TextField("Token (optional)", text: $token)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .textFieldStyle(.roundedBorder)

                            TextField("UID (optional, integer)", text: $uidText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)

                            Picker("Video Layer", selection: $manager.layerMode) {
                                ForEach(LayerMode.allCases) { mode in
                                    Text(mode.label).tag(mode)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: manager.layerMode) { mode in
                                manager.applyLayerMode(mode)
                            }

                            HStack {
                                Button(action: {
                                    let trimmedUID = uidText.trimmingCharacters(in: .whitespacesAndNewlines)
                                    let uid: UInt? = UInt(trimmedUID)
                                    manager.join(appId: appId, channel: channel, token: token, uid: uid)
                                }) {
                                    HStack(spacing: 6) {
                                        if manager.isJoining {
                                            ProgressView()
                                                .progressViewStyle(.circular)
                                        }
                                        Text(manager.isJoining ? "Joining…" : "Join")
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(manager.isJoined || manager.isJoining)

                                Button("Leave") {
                                    manager.leave()
                                }
                                .buttonStyle(.bordered)
                                .disabled(!manager.isJoined || manager.isJoining)
                            }
                        }
                    }

                    GroupBox("Remote Video") {
                        if manager.remoteUsers.isEmpty {
                            Text("No remote publishers yet")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(manager.remoteUsers, id: \.self) { uid in
                                    ZStack(alignment: .bottomLeading) {
                                        let subtitle = manager.remoteStats[uid]?.summary ?? "waiting for stats..."

                                        RemoteVideoView(uid: uid, manager: manager)
                                            .frame(height: 220)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))

                                        Text("uid=\(uid) | \(subtitle)")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(.black.opacity(0.55))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .padding(8)
                                    }
                                }
                            }
                        }
                    }

                    GroupBox("Log") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Spacer()
                                if let url = manager.logFileURL() {
                                    if #available(iOS 16.0, *) {
                                        ShareLink(item: url) {
                                            Label("Share Log", systemImage: "square.and.arrow.up")
                                        }
                                    } else {
                                        Button {
                                            presentShare()
                                        } label: {
                                            Label("Share Log", systemImage: "square.and.arrow.up")
                                        }
                                    }
                                } else {
                                    Button {
                                        // No log file yet; you can optionally append a log here.
                                        // manager.appendLog("No Agora log file found to share.")
                                    } label: {
                                        Label("Share Log", systemImage: "square.and.arrow.up")
                                    }
                                    .disabled(true)
                                }
                            }
                            ScrollViewReader { proxy in
                                ScrollView {
                                    LazyVStack(alignment: .leading, spacing: 6) {
                                        ForEach(manager.logs.indices, id: \.self) { index in
                                            Text(manager.logs[index])
                                                .font(.system(.footnote, design: .monospaced))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .id(index)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .onChange(of: manager.logs.count) { _ in
                                    // Auto-scroll to bottom as new logs arrive
                                    if let last = manager.logs.indices.last {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            proxy.scrollTo(last, anchor: .bottom)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(height: 220)
                    }
                }
                .padding()
            }
            .navigationTitle("Agora AV Subscriber")
        }
    }
    
    private func presentShare() {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController else { return }
        manager.presentLogShare(from: root)
    }
}

