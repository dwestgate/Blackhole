//
//  BlackholeList.swift
//  AdScrubber
//
//  Created by David Westgate on 12/31/15.
//  Copyright © 2016 David Westgate
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions: The above copyright
// notice and this permission notice shall be included in all copies or
// substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE

import Foundation
import SwiftyJSON
import SafariServices

/// Provides functions for downloading and creating JSON ContentBlocker lists
struct BlackholeList {
  
  // MARK: -
  // MARK: Variables
  /// Convenience var for accessing group.com.refabricants.adscrubber
  static let sharedContainer = NSUserDefaults.init(suiteName: "group.com.refabricants.adscrubber")
  
  /// Convenience var for accessing the default container
  static let defaultContainer = NSUserDefaults.standardUserDefaults()
  
  /// Metadata for the bundled ContentBlocker blocklist
  static var preloadedBlacklist = Blacklist(withListName: "preloaded", url: "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts", fileType: "built-in", entryCount: "27167", etag: "9011c48902c695e9a92b259a859f971f7a9a5f75")
  
  /// Metadata for the currently loaded custom blocklist
  static var currentBlacklist = Blacklist(withListName: "current")
  
  /// Metadata for the blacklist stored in the TextView
  static var displayedBlacklist = Blacklist(withListName: "displayed")
  
  /// Metadata for the blacklist stored in the TextView but not yet validated or loaded
  static var candidateBlacklist = Blacklist(withListName: "candidate")
  
  // MARK: Metadata Handling
  /// Stores metadata associated with a blacklist
  struct Blacklist {
    
    /// The name of the blacklist
    private let name: String
    
    /**
        Writes metadata for a new blacklist to the default store
    */
    init(withListName value: String, url: String, fileType: String, entryCount: String, etag: String) {
      name = value
      setValueWithKey(url, forKey: "URL")
      setValueWithKey(fileType, forKey: "FileType")
      setValueWithKey(entryCount, forKey: "EntryCount")
      setValueWithKey(etag, forKey: "Etag")
    }
    
    init(withListName: String, url: String, fileType: String) {
      name = withListName
      setValueWithKey(url, forKey: "URL")
      setValueWithKey(fileType, forKey: "FileType")
    }
    
    init(withListName: String) {
      name = withListName
    }
    
    func getValueForKey(key: String) -> String? {
      if let value = defaultContainer.objectForKey("\(name)Blacklist\(key)") as? String {
        return value
      } else {
        return nil
      }
    }
    
    func setValueWithKey(value: String, forKey: String) {
      defaultContainer.setObject(value, forKey: "\(name)Blacklist\(forKey)")
    }
    
    func removeValueForKey(key: String) {
      defaultContainer.removeObjectForKey("\(name)\(key)")
    }
    
    func removeAllValues() {
      removeValueForKey("URL")
      removeValueForKey("FileType")
      removeValueForKey("EntryCount")
      removeValueForKey("Etag")
    }
    
  }
  
  
  static func getIsUseCustomBlocklistOn() -> Bool {
    if let value = sharedContainer!.boolForKey("isUseCustomBlocklistOn") as Bool? {
      return value
    } else {
      let value = false
      sharedContainer!.setBool(value, forKey: "isUseCustomBlocklistOn")
      return value
    }
  }
  
  
  static func setIsUseCustomBlocklistOn(value: Bool) {
    sharedContainer!.setBool(value, forKey: "isUseCustomBlocklistOn")
  }
  
  
  static func getDownloadedBlacklistType() -> String {
    if let value = sharedContainer!.objectForKey("downloadedBlacklistType") as? String {
      return value
    } else {
      let value = "none"
      sharedContainer!.setObject(value, forKey: "downloadedBlacklistType")
      return value
    }
  }
  
  
  static func setDownloadedBlacklistType(value: String) {
    sharedContainer!.setObject(value, forKey: "downloadedBlacklistType")
  }
  
  
  static func getIsReloading() -> Bool {
    if let value = sharedContainer!.boolForKey("isReloading") as Bool? {
      return value
    } else {
      let value = false
      sharedContainer!.setBool(value, forKey: "isReloading")
      return value
    }
  }
  
  
  static func setIsReloading(value: Bool) {
    sharedContainer!.setBool(value, forKey: "isReloading")
  }
  
  
  static func getIsBlockingSubdomains() -> Bool {
    if let value = sharedContainer!.boolForKey("isBlockSubdomainsOn") as Bool? {
      return value
    } else {
      let value = false
      sharedContainer!.setBool(value, forKey: "isBlockSubdomainsOn")
      return value
    }
  }
  
  
  static func setIsBlockingSubdomains(value: Bool) {
    sharedContainer!.setBool(value, forKey: "isBlockSubdomainsOn")
  }
  
  
  static func validateURL(hostsFile:NSURL, completion:((updateStatus: ListUpdateStatus) -> ())?) {
    print("\n>>> Entering: \(__FUNCTION__) <<<\n")
    setIsReloading(true)
    let request = NSMutableURLRequest(URL: hostsFile)
    request.HTTPMethod = "HEAD"
    let session = NSURLSession.sharedSession()
    
    let task = session.dataTaskWithRequest(request, completionHandler: { data, response, error -> Void in
      
      var result = ListUpdateStatus.UpdateSuccessful
      
      defer {
        if completion != nil {
          dispatch_async(dispatch_get_main_queue(), { () -> Void in
            completion!(updateStatus: result)
          })
        }
      }
      
      print("Response = \(response?.description)")
      guard let httpResp: NSHTTPURLResponse = response as? NSHTTPURLResponse else {
        result = ListUpdateStatus.ServerNotFound
        return
      }
      
      guard httpResp.statusCode == 200 else {
        result = ListUpdateStatus.NoSuchFile
        return
      }
      
      if let candidateEtag = httpResp.allHeaderFields["Etag"] as? NSString {
        if let currentEtag = currentBlacklist.getValueForKey("Etag") {
          if candidateEtag.isEqual(currentEtag) {
            result = ListUpdateStatus.NoUpdateRequired
            print("\n\nNo need to update - etags match: \(candidateEtag) == \(currentEtag)\n\n")
            print("  candidateEtag: \(candidateEtag)")
            print("  currentEtag:   \(currentEtag)")
          } else {
            currentBlacklist.setValueWithKey(candidateEtag as String, forKey: "Etag")
            print("\n\nSetting currentBlacklist Etag to \(hostsFile.absoluteString)\n\n")
            print("  candidateEtag: \(candidateEtag)")
            print("  currentEtag:   \(currentEtag)")
          }
        } else {
          currentBlacklist.setValueWithKey(candidateEtag as String, forKey: "Etag")
          print("\n\nNo existing etag - setting default to \(hostsFile.absoluteString)\n\n")
          print("  candidateEtag: \(candidateEtag)")
        }
      } else {
        currentBlacklist.removeValueForKey("Etag")
        print("\n\nDeleting etag")
      }
    })
    
    task.resume()
  }
  
  
  static func downloadBlocklist(hostsFile: NSURL) throws -> NSURL? {
    print("\n>>> Entering: \(__FUNCTION__) <<<\n")
    setIsReloading(true)
    let documentDirectory =  NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first! as NSURL
    let localFile = documentDirectory.URLByAppendingPathComponent("downloadedBlocklist.txt")
    print(localFile)
    
    guard let myHostsFileFromUrl = NSData(contentsOfURL: hostsFile) else {
      throw ListUpdateStatus.ErrorDownloading
    }
    guard myHostsFileFromUrl.writeToURL(localFile, atomically: true) else {
      throw ListUpdateStatus.ErrorSavingToLocalFilesystem
    }
    return localFile
  }
  
  
  static func createBlockerListJSON(blockList: NSURL) -> (updateStatus: ListUpdateStatus, blacklistFileType: String?, numberOfEntries: Int?) {
    print("\nEntering: \(__FUNCTION__)\n")
    setIsReloading(true)
    var updateStatus = ListUpdateStatus.UpdateSuccessful
    let fileManager = NSFileManager.defaultManager()
    let sharedFolder = fileManager.containerURLForSecurityApplicationGroupIdentifier("group.com.refabricants.adscrubber")! as NSURL
    
    let blockerListURL = sharedFolder.URLByAppendingPathComponent("blockerList.json")
    let wildcardBlockerListURL = sharedFolder.URLByAppendingPathComponent("wildcardBlockerList.json")
    
    var wildcardDomains: Set<String>
    var blocklistFileType = "hosts"
    var numberOfEntries = 0
    var jsonSet = [[String: [String: String]]]()
    var jsonWildcardSet = [[String: [String: String]]]()
    var blockerListEntry = ""
    var wildcardBlockerListEntry = ""
    
    let data = NSData(contentsOfURL: blockList)
    
    if let jsonArray = JSON(data: data!).arrayObject {
      if NSJSONSerialization.isValidJSONObject(jsonArray) {
        
        for element in jsonArray {
          
          guard let newElement = element as? [String : NSDictionary] else {
            return (ListUpdateStatus.InvalidJSON, nil, nil)
          }
          
          guard newElement.keys.count == 2 else {
            return (ListUpdateStatus.InvalidJSON, nil, nil)
          }
          
          let hasAction = contains(Array(newElement.keys), text: "action")
          let hasTrigger = contains(Array(newElement.keys), text: "trigger")
          
          guard hasAction && hasTrigger else {
            return (ListUpdateStatus.InvalidJSON, nil, nil)
          }
          
          numberOfEntries++
        }
        
        do {
          _ = try? fileManager.removeItemAtURL(blockerListURL)
          try fileManager.moveItemAtURL(blockList, toURL: blockerListURL)
        } catch {
          return (ListUpdateStatus.ErrorSavingToLocalFilesystem, nil, nil)
        }
        blocklistFileType = "JSON"
      }
      
    } else {
      
      let validFirstChars = "01234567890abcdef"
      
      _ = try? NSFileManager.defaultManager().removeItemAtPath(blockerListURL.path!)
      _ = try? NSFileManager.defaultManager().removeItemAtPath(wildcardBlockerListURL.path!)
      
      guard let sr = StreamReader(path: blockList.path!) else {
        return (ListUpdateStatus.ErrorParsingFile, nil, nil)
      }
      
      guard let blockerListStream = NSOutputStream(toFileAtPath: blockerListURL.path!, append: true) else {
        return (ListUpdateStatus.ErrorSavingParsedFile, nil, nil)
      }
      
      guard let wildcardBlockerListStream = NSOutputStream(toFileAtPath: wildcardBlockerListURL.path!, append: true) else {
        return (ListUpdateStatus.ErrorSavingParsedFile, nil, nil)
      }
      
      blockerListStream.open()
      wildcardBlockerListStream.open()
      
      defer {
        sr.close()
        
        blockerListStream.write("]}}]")
        blockerListStream.close()
        
        wildcardBlockerListStream.write("]}}]")
        wildcardBlockerListStream.close()
      }
      
      var firstPartOfString = "[{\"action\":{\"type\":\"block\"},\"trigger\":{\"url-filter\":\".*\",\"resource-type\":[\"script\"],\"load-type\":[\"third-party\"]}},"
        
      firstPartOfString += "{\"action\":{\"type\":\"block\"},\"trigger\":{\"url-filter\":\".*\",\"if-domain\":["
      
      while let line = sr.nextLine() {
        
        if ((!line.isEmpty) && (validFirstChars.containsString(String(line.characters.first!)))) {
          
          var uncommentedText = line
          
          if let commentPosition = line.characters.indexOf("#") {
            uncommentedText = line[line.startIndex.advancedBy(0)...commentPosition.predecessor()]
          }
          
          let lineAsArray = uncommentedText.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
          let listOfDomainsFromLine = lineAsArray.filter { $0 != "" }
          
          for entry in Array(listOfDomainsFromLine[1..<listOfDomainsFromLine.count]) {
            
            guard let validatedURL = NSURL(string: "http://" + entry) else { break }
            guard let validatedHost = validatedURL.host else { break }
            var components = validatedHost.componentsSeparatedByString(".")
            guard components[0].lowercaseString != "localhost" else { break }
            
            let domain = components.joinWithSeparator(".")
            
            numberOfEntries++
            blockerListEntry = ("\(firstPartOfString)\"\(domain)\"")
            wildcardBlockerListEntry = ("\(firstPartOfString)\"*\(domain)\"")
            firstPartOfString = ","
            
            blockerListStream.write(blockerListEntry)
            wildcardBlockerListStream.write(wildcardBlockerListEntry)
          }
        }
      }
    }
    _ = try? NSFileManager.defaultManager().removeItemAtPath(blockList.path!)
    
    if numberOfEntries > 50000 {
      updateStatus = ListUpdateStatus.TooManyEntries
    }
    
    setIsReloading(false)
    return (updateStatus, blocklistFileType, numberOfEntries)
  }
  
  
  static func contains(elements: Array<String>, text: String) -> Bool {
    
    for element in elements {
      if (element.caseInsensitiveCompare(text) == NSComparisonResult.OrderedSame) {
        return true
      }
    }
    return false
  }
  
}