import Flutter
import UIKit
import KinDevPlatform

public class SwiftFlutterKinSdkPlugin: NSObject, FlutterPlugin {
    
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
            
            do {
                try Kin.shared.start(userId: "myUserId", jwt: token, environment: .playground)
            } catch {
                print(error)
            }
        }
        if(call.method.elementsEqual("initBalanceObserver")){
            do {
                _ = try Kin.shared.addBalanceObserver { balance in
                    let intBalance = (balance.amount as NSDecimalNumber).intValue
                    SwiftFlutterKinSdkPlugin.balanceFlutterController.eventCallback?(intBalance)
                    print("balance: \(balance.amount)")
                }
            } catch {
                self.sendReport(type: "balanceObserver", status: false, message: String(describing: error))
                print("Error setting balance observer: \(error)")
            }
        }
        if(call.method.elementsEqual("launchKinMarket")){
            let viewController = (UIApplication.shared.delegate?.window??.rootViewController)!;
            Kin.shared.launchMarketplace(from: viewController)
        }
        if(call.method.elementsEqual("getWallet")){
            result(Kin.shared.publicAddress)
        }
        if(call.method.elementsEqual("kinEarn")){
            let arguments = call.arguments as? NSDictionary
            let jwt = arguments!["jwt"] as? String
            kinEarn(jwt: jwt!)
        }
        if(call.method.elementsEqual("kinSpend")){
            let arguments = call.arguments as? NSDictionary
            let jwt = arguments!["jwt"] as? String
            kinSpend(jwt: jwt!)
        }
        if(call.method.elementsEqual("kinPayToUser")){
            let arguments = call.arguments as? NSDictionary
            let jwt = arguments!["jwt"] as? String
            kinPayToUser(jwt: jwt!)
        }
        if(call.method.elementsEqual("orderConfirmation")){
            
        }
    }
    
    private func kinEarn(jwt : String){
        _ = Kin.shared.purchase(offerJWT: jwt) { jwtConfirmation, error in
            if jwtConfirmation != nil {
                self.sendReport(type: "kinEarn", status: true, message: String(describing: jwtConfirmation))
            } else if let e = error {
                self.sendReport(type: "kinEarn", status: false, message: String(describing: e))
            }
        }
    }
    
    private func kinSpend(jwt : String){
        let handler: ExternalOfferCallback = { jwtConfirmation, error in
            _ = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
            if jwtConfirmation != nil {
                self.sendReport(type: "kinSpend", status: true, message: String(describing: jwtConfirmation))
            } else if let e = error {
                self.sendReport(type: "kinSpend", status: false, message: String(describing: e))
            }
        }
        _ = Kin.shared.requestPayment(offerJWT: jwt, completion: handler)
    }
    
    private func kinPayToUser(jwt : String){
        _ = Kin.shared.payToUser(offerJWT: jwt) { jwtConfirmation, error in
            if jwtConfirmation != nil {
                self.sendReport(type: "kinPayToUser", status: true, message: String(describing: jwtConfirmation))
            } else if let e = error {
                self.sendReport(type: "kinPayToUser", status: false, message: String(describing: e))
            }
        }
    }
    
    private func sendReport(type: String, status: Bool, message: String){
        let info = Info(type: type, status: status, message: message)
        let encoder = JSONEncoder()
        let data = try! encoder.encode(info)
        SwiftFlutterKinSdkPlugin.infoFlutterController.eventCallback?(String(data: data, encoding: .utf8)!)
    }
    
    class FlutterStreamController : NSObject, FlutterStreamHandler {
        var eventCallback: FlutterEventSink?
        
        public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
            eventCallback = events
            return nil
        }
        
        public func onCancel(withArguments arguments: Any?) -> FlutterError? {
            return nil
        }
    }
    
    struct Info:Encodable {
        let type: String
        let status: Bool
        let message: String
    }
}
