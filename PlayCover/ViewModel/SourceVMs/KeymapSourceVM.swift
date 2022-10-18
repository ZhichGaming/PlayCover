//
//  KeymapSourceVM.swift
//  PlayCover
//
//  Created by Isaac Marovitz on 18/10/2022.
//

import Foundation

class KeymapSourceVM: SourceVM {
    @Published var keymaps: [KeymapData] = []

    override func resolveSources() {
        if !NetworkVM.isConnectedToNetwork() { return }

        for index in 0..<sources.count {
            sources[index].status = .checking
            DispatchQueue.global(qos: .userInteractive).async {
                guard let url = URL(string: self.sources[index].source) else {
                    DispatchQueue.main.async {
                        self.sources[index].status = .badurl
                    }
                    return
                }

                do {
                    let contents = try String(contentsOf: url)
                    let jsonData = contents.data(using: .utf8)!
                    do {
                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .convertFromSnakeCase
                        let data = try decoder.decode([KeymapFolderSourceData].self, from: jsonData)

                        for index in 0..<data.count {
                            let keymapContents = try String(contentsOf: URL(string: data[index].url)!)
                            let keymapJsonData = keymapContents.data(using: .utf8)!
                            let keymapData = try decoder.decode([KeymapSourceData].self, from: keymapJsonData)

                            let fetchedKeymaps = keymapData.filter {
                                $0.downloadUrl.contains(".playmap")
                            }

                            if fetchedKeymaps.count > 0 {
                                DispatchQueue.main.async {
                                    self.sources[index].status = .valid
                                    self.appendKeymapData(data)
                                }
                                return
                            }
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.sources[index].status = .badjson
                        }
                        return
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.sources[index].status = .badurl
                    }
                    return
                }
            }
        }
    }
    
    func appendKeymapData(_ data: [KeymapFolderSourceData]) {
        for element in data {
            DispatchQueue.global(qos: .userInteractive).async {
                do {
                    let contents = try String(contentsOf: URL(string: element.url)!)
                    let jsonData = contents.data(using: .utf8)!
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let data: [KeymapSourceData] = try decoder.decode([KeymapSourceData].self, from: jsonData)

                    for source in data where source.name.contains(".playmap") {
                        var keymapData = KeymapData()
                        keymapData.bundleID = element.name
                        keymapData.htmlUrl = element.htmlUrl

                        keymapData.name = source.name.replacingOccurrences(of: ".playmap", with: "")
                        keymapData.url = source.downloadUrl
                        keymapData.repoName = self.getRepoName(source.downloadUrl)
                        DispatchQueue.main.async {
                            self.keymaps.append(keymapData)
                        }
                    }
                } catch {
                    Log.shared.error(error)
                }
            }
        }
    }

    func getRepoName(_ downloadLink: String) -> String {
        var downloadLink = downloadLink

        if let reposRange = downloadLink.range(of: "https://raw.githubusercontent.com/") {
            downloadLink.removeSubrange(downloadLink.startIndex..<reposRange.upperBound)
        }

        let sourceComponents = downloadLink.components(separatedBy: "/")

        return "\(sourceComponents[0])/\(sourceComponents[1]) (\(sourceComponents[2]))"
    }
}

struct KeymapFolderSourceData: Codable, Equatable {
    let name: String
    let url: String
    let htmlUrl: String
}

struct KeymapSourceData: Codable, Equatable {
    let name: String
    let downloadUrl: String
}

struct KeymapData: Codable, Equatable, Hashable {
    var bundleID: String = ""
    var name: String = ""
    var htmlUrl: String = ""
    var url: String = ""
    var repoName: String = ""
}
