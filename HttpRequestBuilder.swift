//
//  HttpRequestBuilder.swift
//
//  Created by NLS52-MAC on 11/10/2019.
//  Copyright © 2019 Bhadresh Kathiriya. All rights reserved.
//

import Foundation
import UIKit

class HttpRequestBuilder
{
    private var url : URL
    private var method : HttpMethod = .GET
    private var headers : [HttpHeader] = []
    private var params : [HttpParam] = []
    private var files : [HttpFileParam] = []

    init (url: URL) {
        self.url = url

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        let osVersion = UIDevice.current.systemVersion

        _ = self.header(name: "X-App-Platform", value: "iOS")
            .header(name: "X-App-Platform-Version", value: osVersion)
            .header(name: "X-App-Version", value: version)
            .header(name: "X-App-Build", value: build)
    }

    convenience init? (string: String) {
        if let url = URL(string: string) {
            self.init(url: url)
        } else {
            return nil
        }
    }

    func method(_ m : HttpMethod) -> HttpRequestBuilder
    {
        method = m
        return self
    }

    func header(_ h : HttpHeader) -> HttpRequestBuilder
    {
        headers.append(h)
        return self
    }

    func header(name: String, value : String) -> HttpRequestBuilder
    {
        return header(HttpHeader(name: name, value: value))
    }

    func params(_ pairs : [(name: String, value: String)]) -> HttpRequestBuilder {
        for pair in pairs {
            _ = param(name: pair.name, value: pair.value)
        }
        return self
    }

    func params(_ params : [HttpParam]) -> HttpRequestBuilder
    {
        for p in params {
            _ = param(p)
        }
        return self
    }

    func param(_ p : HttpParam) -> HttpRequestBuilder
    {
        params.append(p)
        return self
    }

    func param(name : String, value: String) -> HttpRequestBuilder
    {
        return param(HttpParam(name: name, value: value))
    }

    func file(_ f : HttpFileParam) -> HttpRequestBuilder
    {
        files.append(f)
        return self
    }

    func file(name : String, filename : String, data : Data, mimetype: String?) -> HttpRequestBuilder
    {
        return file(HttpFileParam(name: name, filename: filename, data: data, mimetype: mimetype))
    }

    func files(_ fs : [HttpFileParam]) -> HttpRequestBuilder
    {
        for f in fs {
            _ = file(f)
        }
        return self
    }

    func files(_ tripples : [(name: String, filename: String, data: Data, mimetype: String?)]) -> HttpRequestBuilder
    {
        for t in tripples {
            _ = file(
                HttpFileParam(name: t.name, filename: t.filename, data: t.data, mimetype: t.mimetype)
            )
        }
        return self
    }

    func build() -> URLRequest
    {
        var finalUrl = url
        if method == .GET {
            var components = URLComponents(string: url.absoluteString)!
            for p in params {
                components.queryItems?.append(URLQueryItem(name: p.name, value: p.value))
            }
            finalUrl = components.url!
        }

        var req = URLRequest(url: finalUrl)

        req.httpMethod = method.toString()

        for h in headers {
            req.addValue(h.value, forHTTPHeaderField: h.name)
        }

        if method == .POST {
            if files.count > 0 {
                req = self.addMultiPartData(req)
            } else {
                req = self.addWwwEncodedData(req)
            }
        }

        return req
    }

    private func addMultiPartData(_ original : URLRequest) -> URLRequest
    {
        var req = original
        let boundary = "Boundary-" + UUID().uuidString
        let crlf = "\r\n"

        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let body = NSMutableData()

        for p in params {
            body.append("--\(boundary)\(crlf)")
            body.append("Content-Disposition: form-data; name=\"\(p.name)\"\(crlf)\(crlf)")
            body.append("\(p.value)\(crlf)")
        }

        for f in files {
            body.append("--\(boundary)\(crlf)")
            body.append("Content-Disposition: form-data; name=\"\(f.name)\"; filename=\"\(f.filename)\"\(crlf)")
            if let m = f.mimetype {
                body.append("Content-Type: \(m)\(crlf)\(crlf)")
            }
            body.append(f.data)
            body.append(crlf)
        }
        body.append("--\(boundary)--\(crlf)")

        req.httpBody = body as Data

        return req
    }

    private func addWwwEncodedData(_ original : URLRequest) -> URLRequest
    {
        var req = original

        req.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        req.httpBody = params.map({ (p : HttpParam) -> String in
            var v = p.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            v = v.replacingOccurrences(of: "+", with: "%2B")
            v = v.replacingOccurrences(of: "&", with: "%26")
            return p.name + "=" + v
        }).joined(separator: "&").data(using: .utf8)

        return req
    }
}

enum HttpMethod {
    case GET
    case POST

    func toString() -> String {
        switch (self) {
            case .GET : return "GET"
            case .POST : return "POST"
        }
    }
}

struct HttpHeader {
    let name : String
    let value : String
}

struct HttpParam {
    let name : String
    let value : String
}

struct HttpFileParam {
    let name : String
    let filename : String
    let data : Data
    let mimetype : String?
}
