//
//  Setup.swift
//  PureKFD
//
//  Created by Lrdsnow on 12/17/23.
//

import Foundation
import SwiftUI

@available(iOS 15.0, *)
struct IssueView: View {
    // Setup:
    @Binding var lock: Bool
    
    var body: some View {
        VStack(alignment: .center) {
            Spacer()
            VStack(alignment: .center, spacing: 8) {
                Image(systemName: "slash.circle")
                    .resizable()
                    .foregroundColor(Color.red)
                    .frame(width: 80, height: 80)
                    .cornerRadius(20)
                    .padding()

                Text("Something Went Wrong")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.red)
                
                Text("Things to try:\n- Manually setting your offsets\n- Try disabling some tweaks\n- Report the issue to the developer")
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.red)
                
            }.padding(.bottom).padding(.horizontal)
            Spacer()
            VStack {
                Button(action: {
                    lock = false
                }, label: {
                    HStack {
                        Spacer()
                        Text("Close").padding(.vertical, 10)
                        Spacer()
                    }
                }).borderedprombuttonc().buttonBorderShape(.roundedRectangle(radius: 13)).tintC(.red).shadowC(color: Color.red.opacity(0.5), radius: 3, x: 1, y: 2)
            }.padding()
        }.foregroundStyle(Color(uiColor: .label))
    }
}

@available(iOS 15.0, *)
struct FirstTimeLoadingView: View {
    @Binding var isLoading: Bool
    @Binding var appColors: AppColors
    @EnvironmentObject var appData: AppData
    let mainView: MainView
    
    @State private var currentStep = 0
    @State private var downloadingRepos = false
    @State private var downloadingRepos_Status = (0, 0)
    @State private var loadingSteps = [
        "Detecting device compatibility...",
        "Configuring exploit method...",
        "Setting up default theme...",
        "Downloading repositories...",
        "Finalizing setup..."
    ]
    
    var body: some View {
        VStack(alignment: .center) {
            Spacer()
            
            VStack(alignment: .center, spacing: 24) {
                Image(uiImage: UIImage(named: "DisplayAppIcon") ?? UIImage())
                    .renderingMode(.original)
                    .resizable()
                    .frame(width: 120, height: 120)
                    .shadowC(color: Color.black.opacity(0.5), radius: 3, x: 1, y: 2)
                    .cornerRadius(20)
                    .padding()

                Text("Welcome to PureKFD")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                ProgressView()
                    .scaleEffect(1.2)
                    .tintC(Color.accentColor)
                
                if currentStep < loadingSteps.count {
                    Text(loadingSteps[currentStep])
                        .font(.subheadline)
                        .foregroundColor(Color(uiColor: .secondaryLabel))
                }
                
                if downloadingRepos {
                    Text("(\(downloadingRepos_Status.0)/\(downloadingRepos_Status.1))")
                        .font(.caption)
                        .foregroundColor(Color(uiColor: .tertiaryLabel))
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .foregroundStyle(Color(uiColor: .label))
        .onAppear {
            performAutoSetup()
        }
    }
    
    private func performAutoSetup() {
        Task {
            await updateStep(0)
            let deviceInfo = getDeviceInfo(appData: appData)
            await updateStep(1)
            appData.UserData.exploit_method = deviceInfo.0 == -1 ? 2 : deviceInfo.0
            if deviceInfo.0 == 0 { // KFD
                appData.UserData.kfd.use_static_headroom = true
            }
            await updateStep(2)
            setupDefaultTheme()
            await updateStep(3)
            await downloadRepositories()
            await updateStep(4)
            finalizeSetup()
            try? Data().write(to: URL.documents.appendingPathComponent("config/setup_done"))
            isLoading = false
        }
    }
    
    private func updateStep(_ step: Int) async {
        await MainActor.run {
            currentStep = step
        }
        try? await Task.sleep(nanoseconds: 800_000_000)
    }
    
    private func setupDefaultTheme() {
        appColors.name = Color.primary
        appColors.author = Color.secondary
        appColors.description = Color.secondary
        appColors.accent = Color.accentColor
        appColors.background = Color(uiColor: .systemBackground)
    }
    
    private func downloadRepositories() async {
        downloadingRepos = true
        var repourls = SavedRepoData()
        repourls.urls += appData.RepoData.urls
        let repoCount = repourls.urls.count
        downloadingRepos_Status = (0, repoCount)
        
        let repoCacheDir = URL.documents.appendingPathComponent("config/repoCache")
        if FileManager.default.fileExists(atPath: repoCacheDir.path) {
            try? FileManager.default.removeItem(at: repoCacheDir)
        }
        try? FileManager.default.createDirectory(at: repoCacheDir, withIntermediateDirectories: true)
        
        await getRepos(appdata: appData, completion: { repo in
            Task { @MainActor in
                if repo.name != "Unkown" {
                    downloadingRepos_Status.0 += 1
                    let jsonEncoder = JSONEncoder()
                    do {
                        let jsonData = try jsonEncoder.encode(repo)
                        do {
                            try jsonData.write(to: repoCacheDir.appendingPathComponent("\(repo.name).json"))
                        } catch {
                            log("Error saving repo data: \(error)")
                        }
                    } catch {
                        log("Error encoding repo: \(error)")
                    }
                } else {
                    log("\(repo.desc)")
                }
            }
        })
        
        downloadingRepos = false
    }
    
    private func finalizeSetup() {
        appData.UserData.savedAppColors = SavedAppColors(
            name: appColors.name.toHex(includeAlpha: true),
            author: appColors.author.toHex(includeAlpha: true),
            description: appColors.description.toHex(includeAlpha: true),
            background: appColors.background.toHex(includeAlpha: true),
            accent: appColors.accent.toHex(includeAlpha: true)
        )
        appData.appColors = appColors
        appData.save()
    }
}

//
