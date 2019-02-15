import Flutter
import UIKit
import KinDevPlatform

public class SwiftFlutterKinSdkPlugin: NSObject, FlutterPlugin {
    
    var isKinInit: Bool = false
    var balance: Int = 0
    
    static let balanceFlutterController = FlutterStreamController()
    static let infoFlutterController = FlutterStreamController()
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_kin_sdk", binaryMessenger: registrar.messenger())
        let balanceEventChannel = FlutterEventChannel.init(name: "flutter_kin_sdk_balance", binaryMessenger: registrar.messenger())
        let infoEventChannel = FlutterEventChannel.init(name: "flutter_kin_sdk_info", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterKinSdkPlugin()
        balanceEventChannel.setStreamHandler(balanceFlutterController)
        infoEventChannel.setStreamHandler(infoFlutterController)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if(call.method.elementsEqual("kinStart")){
            let arguments = call.arguments as? NSDictionary
            let token = arguments!["token"] as? String
            let initBalanceObserver = arguments!["initBalanceObserver"] as? Bool
            let isProduction = arguments!["isProduction"] as? Bool
            if (token == nil || initBalanceObserver == nil || isProduction == nil) {return}
            let environment : Environment
            if (isProduction!){
                environment = .production
            }else{
                environment = .playground
            }
            do {
                try Kin.shared.start(userId: "myUserId", jwt: token, environment: environment)
                sendReport(type: "kinStart", message: "Kin started")
                isKinInit = true
                if (initBalanceObserver!){
                    do {
                        _ = try Kin.shared.addBalanceObserver { kinBalance in
                            self.balance = (kinBalance.amount as NSDecimalNumber).intValue
                            SwiftFlutterKinSdkPlugin.balanceFlutterController.eventCallback?(self.balance)
                        }
                    } catch {
                        self.sendError(type: "balanceObserver", error: error)
                    }
                }
            } catch {
                isKinInit = false
                sendError(type: "kinStart", error: error)
            }
        }
        if(call.method.elementsEqual("launchKinMarket")){
            if (!ifKinInit()) {return}
            let viewController = (UIApplication.shared.delegate?.window??.rootViewController)!;
            Kin.shared.launchMarketplace(from: viewController)
        }
        if(call.method.elementsEqual("getWallet")){
            if (!ifKinInit()) {return}
            result(Kin.shared.publicAddress)
        }
        if(call.method.elementsEqual("kinEarn")){
            if (!ifKinInit()) {return}
            let arguments = call.arguments as? NSDictionary
            let jwt = arguments!["jwt"] as? String
            kinEarn(jwt: jwt!)
        }
        if(call.method.elementsEqual("kinSpend")){
            if (!ifKinInit()) {return}
            let arguments = call.arguments as? NSDictionary
            let jwt = arguments!["jwt"] as? String
            kinSpend(jwt: jwt!)
        }
        if(call.method.elementsEqual("kinPayToUser")){
            if (!ifKinInit()) {return}
            let arguments = call.arguments as? NSDictionary
            let jwt = arguments!["jwt"] as? String
            kinPayToUser(jwt: jwt!)
        }
        if(call.method.elementsEqual("orderConfirmation")){
            let err = PluginError(type: "orderConfirmation", message: "Kin SDK iOS doesn't support function orderConfirmation.")
            sendError(code: "-2", message: "Kin SDK iOS doesn't support function orderConfirmation.", details: err)
        }
    }
    
    private func kinEarn(jwt : String){
        let prevBalance = balance
        _ = Kin.shared.purchase(offerJWT: jwt) { jwtConfirmation, error in
            if jwtConfirmation != nil {
                self.sendReport(type: "kinEarn", message: String(describing: jwtConfirmation), amount: self.balance - prevBalance)
            } else if let e = error {
                self.sendError(type: "kinEarn", error: e)
            }
        }
    }
    
    private func kinSpend(jwt : String){
        let handler: ExternalOfferCallback = { jwtConfirmation, error in
            _ = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
            if jwtConfirmation != nil {
                self.sendReport(type: "kinSpend", message: String(describing: jwtConfirmation))
            } else if let e = error {
                self.sendError(type: "kinSpend", error: e)
            }
        }
        _ = Kin.shared.requestPayment(offerJWT: jwt, completion: handler)
    }
    
    private func kinPayToUser(jwt : String){
        _ = Kin.shared.payToUser(offerJWT: jwt) { jwtConfirmation, error in
            if jwtConfirmation != nil {
                self.sendReport(type: "kinPayToUser", message: String(describing: jwtConfirmation))
            } else if let e = error {
                self.sendReport(type: "kinPayToUser", message: String(describing: e))
            }
        }
    }
    
    private func sendReport(type: String, message: String, amount: Int? = nil){
        var info: Info
        if (amount != nil){
            info = Info(type: type, message: message, amount: amount)
        }else{
            info = Info(type: type, message: message)
        }
        let encoder = JSONEncoder()
        var data: Data? = nil
        do {
            data = try encoder.encode(info)
        } catch {
            sendError(type: "json", error: error)
        }
        if (data != nil) {
            SwiftFlutterKinSdkPlugin.infoFlutterController.eventCallback?(String(data: data!, encoding: .utf8)!)
        }
    }
    
    private func sendError(type: String, error: Error) {
        let err = PluginError(type: type, message: error.localizedDescription)
        var message: String? = error.localizedDescription
        if (message == nil) {message = ""}
        sendError(code: "-3", message: message!, details: err)
    }
    
    private func sendError(code: String, message: String?, details: PluginError) {
        let encoder = JSONEncoder()
        var data: Data? = nil
        do {
            data = try encoder.encode(details)
        } catch {
            sendError(type: "json", error: error)
        }
        if (data != nil) {
            SwiftFlutterKinSdkPlugin.infoFlutterController.error(code, message: message, details: String(data: data!, encoding: .utf8)!)
        }
    }
    
    class FlutterStreamController : NSObject, FlutterStreamHandler {
        var eventCallback: FlutterEventSink?
        
        public func error(_ code : String, message: String?, details: Any?) {
            eventCallback?(FlutterError(code: code, message: message, details: details))
        }
        
        public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
            eventCallback = events
            return nil
        }
        
        public func onCancel(withArguments arguments: Any?) -> FlutterError? {
            return nil
        }
    }
    
    private func ifKinInit() -> Bool{
        if(!isKinInit){
            let err = PluginError(type: "kinStart", message: "Kin SDK not started")
            sendError(code: "-1", message: "Kin SDK not started", details: err)
        }
        return isKinInit
    }
    
    struct Info:Encodable {
        let type: String
        let message: String
        let amount: Int?
        init(type: String, message: String, amount: Int? = nil) {
            self.type = type
            self.message = message
            self.amount = amount
        }
    }
    
    struct PluginError:Encodable {
        let type: String
        let message: String
    }
}
