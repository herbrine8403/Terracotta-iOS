import Foundation
import os

class ProfileStore: ObservableObject {
    @Published var profiles: [String: TerracottaOptions] = [:]
    
    private let useICloudKey = "profilesUseICloud"
    
    init() {
        loadProfiles()
    }
    
    func saveProfile(name: String, profile: TerracottaOptions) {
        profiles[name] = profile
        saveProfiles()
    }
    
    func deleteProfile(name: String) {
        profiles.removeValue(forKey: name)
        saveProfiles()
    }
    
    func loadProfile(name: String) -> TerracottaOptions? {
        return profiles[name]
    }
    
    func loadProfiles() {
        let useICloud = UserDefaults.standard.bool(forKey: useICloudKey)
        
        if useICloud {
            loadProfilesFromICloud()
        } else {
            loadProfilesFromLocal()
        }
    }
    
    func saveProfiles() {
        let useICloud = UserDefaults.standard.bool(forKey: useICloudKey)
        
        if useICloud {
            saveProfilesToICloud()
        } else {
            saveProfilesToLocal()
        }
    }
    
    private func loadProfilesFromLocal() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "profiles"),
           let loadedProfiles = try? JSONDecoder().decode([String: TerracottaOptions].self, from: data) {
            profiles = loadedProfiles
        }
    }
    
    private func saveProfilesToLocal() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(profiles) {
            defaults.set(data, forKey: "profiles")
        }
    }
    
    private func loadProfilesFromICloud() {
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: ICLOUD_CONTAINER_ID) else {
            os_log("Failed to get iCloud container", log: OSLog.default, type: .error)
            loadProfilesFromLocal()
            return
        }
        
        let profilesURL = containerURL.appendingPathComponent("Documents/profiles.json")
        
        do {
            let data = try Data(contentsOf: profilesURL)
            if let loadedProfiles = try? JSONDecoder().decode([String: TerracottaOptions].self, from: data) {
                profiles = loadedProfiles
            }
        } catch {
            os_log("Failed to load profiles from iCloud: %{public}s", log: OSLog.default, type: .error, error.localizedDescription)
            loadProfilesFromLocal()
        }
    }
    
    private func saveProfilesToICloud() {
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: ICLOUD_CONTAINER_ID) else {
            os_log("Failed to get iCloud container", log: OSLog.default, type: .error)
            saveProfilesToLocal()
            return
        }
        
        let documentsURL = containerURL.appendingPathComponent("Documents")
        let profilesURL = documentsURL.appendingPathComponent("profiles.json")
        
        do {
            // 创建 Documents 目录（如果不存在）
            try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true, attributes: nil)
            
            // 编码并写入文件
            let data = try JSONEncoder().encode(profiles)
            try data.write(to: profilesURL, options: .atomic)
        } catch {
            os_log("Failed to save profiles to iCloud: %{public}s", log: OSLog.default, type: .error, error.localizedDescription)
            saveProfilesToLocal()
        }
    }
}
