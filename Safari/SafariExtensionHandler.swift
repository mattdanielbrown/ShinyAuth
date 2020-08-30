//
//  SafariExtensionHandler.swift
//  Safari
//
//  Created by Tim Gymnich on 10.7.20.
//

import SafariServices

final class SafariExtensionHandler: SFSafariExtensionHandler {
    
    enum Message: String, CaseIterable {
        case getToken = "getToken"
    }
    
    enum Event {
        case showPopup(label: String, token: String)
        case fillToken(token: String)
        
        var name: String {
            switch self {
            case .showPopup: return "showPopup"
            case .fillToken: return "fillToken"
            }
        }
        
        var userInfo: [String: Any]? {
            switch self {
            case let .showPopup(label, token): return ["label": label, "token": token]
            case let .fillToken(token): return ["token": token]
            }
        }
    }
    
    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String : Any]? = nil) {
        switch Message(rawValue: messageName) {
        case .getToken:
            page.getPropertiesWithCompletionHandler { properties in
                guard let url = properties?.url else { return }
                let accounts = try? SafariExtensionViewController.shared.viewModel.accounts(for: url)
                if let account = accounts?.first {
                    let token = account.otpGenerator.code().group(groupSize: 3)
                    let label = account.label
                    page.dispatchMessageToScript(Event.showPopup(label: label, token: token))
                }
            }
        default: break
        }
    }
        
    override func popoverWillShow(in window: SFSafariWindow) {
        window.getActiveTab { tab in
            tab?.getActivePage { page in
                page?.getPropertiesWithCompletionHandler { properties in
                    guard let url = properties?.url else { return }
                    NotificationCenter.default.post(name: .didNavigate, object: self, userInfo: ["url": url])
                }
            }
        }
    }
    
    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping ((Bool, String) -> Void)) {
        window.getToolbarItem { item in
            window.getActiveTab { tab in
                tab?.getActivePage { page in
                    page?.getPropertiesWithCompletionHandler { properties in
                        guard let url = properties?.url else {
                            item?.setEnabled(false)
                            return validationHandler(true,"")
                        }
                        let accounts = try? SafariExtensionViewController.shared.viewModel.accounts(for: url)
                        item?.setEnabled(!(accounts?.isEmpty ?? true))
                        return validationHandler(true, "")
                    }
                }
            }
            item?.setEnabled(false)
        }
        validationHandler(true, "")
    }
    
    override func popoverViewController() -> SFSafariExtensionViewController {
        return SafariExtensionViewController.shared
    }
    
}

extension SFSafariPage {
    func dispatchMessageToScript(_ event: SafariExtensionHandler.Event) {
        dispatchMessageToScript(withName: event.name, userInfo: event.userInfo)
    }
}
