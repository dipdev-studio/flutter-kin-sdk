import Flutter
import UIKit
import KinDevPlatform

public class SwiftFlutterKinSdkPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    
    private var balanceCallback: FlutterEventSink?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_kin_sdk", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel.init(name: "flutter_kin_sdk_balance", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterKinSdkPlugin()
        eventChannel.setStreamHandler(instance)
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
                    var balanceObserverId: String? = nil
                    do {
                        balanceObserverId = try Kin.shared.addBalanceObserver { balance in
                            let intBalance = (balance.amount as NSDecimalNumber).intValue
                            self.balanceCallback?(intBalance)
                            print("balance: \(balance.amount)")
                        }
                    } catch {
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
        Kin.shared.purchase(offerJWT: jwt) { jwtConfirmation, error in
            if let confirm = jwtConfirmation {
                print("🔥 kinEarn confirm")
            } else if let e = error {
                print("🔴 kinEarn error \(e)")
            }
        }
    }
    
    private func kinSpend(jwt : String){
        let handler: ExternalOfferCallback = { jwtConfirmation, error in
            let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
            if let confirm = jwtConfirmation {
                print("🔥 kinSpend confirm")
            } else if let e = error {
                print("🔴 kinSpend error \(e)")
            }
        }
        Kin.shared.requestPayment(offerJWT: jwt, completion: handler)
    }
    
    private func kinPayToUser(jwt : String){
        Kin.shared.payToUser(offerJWT: jwt) { jwtConfirmation, error in
            if let confirm = jwtConfirmation {
                print("🔥 kinPayToUser confirm")
            } else if let e = error {
                print("🔴 kinPayToUser error \(e)")
            }
        }
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        balanceCallback = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }
}
