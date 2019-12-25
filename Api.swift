//
//  Api.swift
//
//  Created by NLS52-MAC on 11/10/2019.
//  Copyright © 2019 Bhadresh Kathiriya. All rights reserved.
//

import Foundation

class Api
{
    let baseUrlLive = "http://"
    let baseUrlTest = "http://"
    let apiPath = "/api/v1/"
    
    
    let supportEmail = ""
    
    let set = ""
    let get = ""
    
    let networkUnavailableMessage = NSLocalizedString("Network connection is not available right now. Please try again later", comment: "Error message")
    let genericErrorMessage = NSLocalizedString("Internal communication error", comment: "Error message")
    
    private let dateFormatter = {
        () -> DateFormatter in
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd\'T\'HH:mm:ssZ"
        return df
    }()
    
    private static var instance : Api?
    let settings : Settings
    
    private init() {
        self.settings = Settings.getInstance()
    }
    
    static func getInstance() -> Api {
        if (instance === nil) {
            instance = Api()
        }
        return instance!
    }
    
    static func isAnyNetworkAvailable() -> Bool {
        return Reach().connectionStatus().isOnline()
    }
    
    func getBaseUrl() -> String {
        // Develop Mode
        //            return baseUrlTest
        // Live Mode
        return baseUrlLive
    }
    
    func getBaseAPIUrl() -> String {
        // Develop Mode
        //            return baseUrlTest
        // Live Mode
        return baseUrlLive + apiPath
    }
    
    
    
    func set(
        name : String,
        email : String,
        mobile : String,
        socialID : String,
        success successCallback : @escaping () -> Void,
        error errorCallback : @escaping (String) -> Void
    )
    {
        if (!Api.isAnyNetworkAvailable()) {
            errorCallback(networkUnavailableMessage)
            return
        }
        APPLICATION.startActivityIndicator()
        var params : [(String,String)]
        if socialID.count <= 0 {
            params = [
                ("name" , name),
                ("email" , email),
                ("mobile" , mobile),
            ]
        } else {
            params = [
                ("name" , name),
                ("social_media_profile_id" , socialID),
            ]
        }
        
        let request = HttpRequestBuilder(string: getBaseAPIUrl() + registerUri)!
            .method(.POST)
            .params(params)
            .build()
        
        let task = URLSession.shared.dataTask(with: request, completionHandler: {
            (data, response : URLResponse?, error) -> Void in
            APPLICATION.stopActivityIndicator()
            if self.handleError(data, response, error, acceptableStatuses: [200,401]) {
                let message = self.genericErrorMessage + "#001";
                self.logError(message, code: 1, response: response, data: data)
                errorCallback(message)
                return
            }
            
            if (response as? HTTPURLResponse)?.statusCode == 401 {
                errorCallback(NSLocalizedString("Invalid credentials", comment: "Login failure message"))
                return
            }
            
            let json : [String:Any]
            do {
                json = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions()) as! [String:Any]
            } catch {
                errorCallback("Invalid credentials")
                return
            }
            
            if json["success"] as? Bool ?? false {
                DispatchQueue.main.async {
                }
                DispatchQueue.main.async {
                    successCallback()
                }
            } else {
                errorCallback(json["message"] as? String ?? "Invalid credentials")
                return
            }
        })
        
        task.resume()
    }
    
    func get(success callback: @escaping (Person) -> Void, error errorCallback: @escaping (String) -> Void)
    {
        if (!Api.isAnyNetworkAvailable()) {
            errorCallback(networkUnavailableMessage)
            return
        }
        APPLICATION.startActivityIndicator()
        
        let request = HttpRequestBuilder(string: getBaseAPIUrl() + profileUri)!
            .method(.POST)
            .header(name: "x-access-token", value: "\(settings.apiToken!)")
            .param(name: "user_id", value: settings.lastUserId ?? "")
            .build()

        let task = URLSession.shared.dataTask(with: request, completionHandler: {
            (data, response : URLResponse?, error) -> Void in
            APPLICATION.stopActivityIndicator()
            if self.handleError(data, response, error, acceptableStatuses: [200,401]) {
                let message = self.genericErrorMessage + "#002";
                errorCallback(message)
                return
            }

            if (response as? HTTPURLResponse)?.statusCode == 401 {
                errorCallback(NSLocalizedString("Invalid credentials", comment: "Login failure message"))
                return
            }

            let json : [String:Any]
            do {
                json = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions()) as! [String:Any]
            } catch {
                errorCallback("Invalid credentials")
                return
            }

            if json["success"] as? Bool ?? false {
                DispatchQueue.main.async {
                    callback(---)
                }
            } else {
                self.TokenExpireCheckMethod(messageStr: json["message"] as? String ?? "")
                errorCallback(json["message"] as? String ?? "Invalid credentials")
                return
            }
        })

        task.resume()
    }
    
    func downloadFile(url urlString: String, callback: @escaping (Data?) -> Void, error errorCallback: @escaping (String) -> Void)
    {
        if (!Api.isAnyNetworkAvailable()) {
            errorCallback(networkUnavailableMessage)
            return
        }

        if settings.apiToken == nil {
            APPLICATION.gotoAuthenticationController()
            return
        }
        
        if urlString.isEmpty {
            return
        }
//        APPLICATION.startActivityIndicator()
        let req = HttpRequestBuilder(string: urlString)!
            .header(name: "Authorization", value: "Bearer \(settings.apiToken!)")
            .build()

        URLSession.shared.dataTask(with: req, completionHandler: {
            data, response, error in
//            APPLICATION.stopActivityIndicator()
            if self.handleError(data, response, error, acceptableStatuses: [200], validateJson: false) {
                let message = self.genericErrorMessage + "#009";
                self.logError(message, code: 9, response: response, data: data)
                errorCallback(message)
                return
            }

            callback(data)

        }).resume()
    }
    
    func TokenExpireCheckMethod(messageStr : String){
        if messageStr == TokenExpiredMsg {
            self.ResetTokenAndDataMethod()
        }
    }
    
    func ResetTokenAndDataMethod()  {
        self.settings.apiToken = nil
        self.settings.save()
    }
    
    private func handleError(
        _ data: Data?,
        _ response: URLResponse?,
        _ error: Error?,
        acceptableStatuses : [Int] = [200],
        validateJson : Bool = true
    ) -> Bool
    {
        if (error != nil) {
            print("Api Error: Received error \(error!.localizedDescription)")
            return true
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            
            print("Api: handleError / statusCode=\(httpResponse.statusCode) for url \(String(describing: httpResponse.url))")
            
            if acceptableStatuses.contains(httpResponse.statusCode) {
                if !validateJson {
                    return false
                }
                
                do {
                    _ = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions()) as? [String:Any]
                    return false
                } catch {
                    Application.logError(
                        NSError(
                            domain: "Api",
                            code: 2,
                            userInfo: [
                                "data"  : data!,
                                "error": error.localizedDescription
                            ]
                        )
                    )
                    print("API: Could not parse HTTP response as JSON")
                    print(String(data: data!, encoding: String.Encoding.utf8) ?? "")
                    return true
                }
            } else if (httpResponse.statusCode == 401) {
                print("Api Error: Got status 401, redirecting to login")
                goToLogin()
                return true
            } else if (httpResponse.statusCode == 403) {
                print("Api Error: Got status 403, redirecting to login")
                let msg = NSLocalizedString(
                    "Your account does not have sufficient permissions",
                    comment: "Error message for status 403 (unallowed role)")
                goToLogin(withMessage: msg)
                return true
            } else if (httpResponse.statusCode == 409) {
                print("Api Error: Got status 409, redirecting to login")
                let rawMsg = "You can only be logged in on one device at a time. Please log in again to use this device and log out any others"
                let msg = NSLocalizedString(rawMsg, comment: "Error message for OneDevicePolicy")
                goToLogin(withMessage: msg)
                return true
            } else if httpResponse.statusCode >= 400 && httpResponse.statusCode < 500 {
                do {
                    let json = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions()) as? [String:Any]
                    if let msg = json?["message"] as? String {
                        print("Api Error: received JSON error message: \(msg)")
                    }
                } catch {
                    Application.logError(
                        NSError(
                            domain: "Api",
                            code: 3,
                            userInfo: [
                                "data"  : data!,
                                "error": error.localizedDescription
                            ]
                        )
                    )
                    print("API: Could not parse HTTP response as JSON")
                    print(String(data: data!, encoding: String.Encoding.utf8) ?? "")
                }
                return true
            }
        } else {
            print("Api Error: Received response which is not an HTTPURLResponse")
            return true
        }
        
        return false
    }
    
    private func logError(_ message : String, code : Int, response : URLResponse?, data : Data? = nil)
    {
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Api: received response which is not an HTTPURLResponse but rather \(String(describing: type(of: response)))")
            return
        }
        
        guard let data = data else {
            print("Api: received data which is nil")
            return
        }
        
        print("Api: Logging error - \(message) - \(httpResponse.statusCode) @ \(String(describing: httpResponse.url?.absoluteString))")
        print("Api: ResponseBody: \(String(data: data, encoding: String.Encoding.utf8) ?? "N/A")")
    }
    
    
}

