import Flutter
import UIKit
import KinDevPlatform

public class SwiftFlutterKinSdkPlugin: NSObject, FlutterPlugin {
    
    private var balanceCallback: FlutterEventSink?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_kin_sdk", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterKinSdkPlugin()
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
            
//            var balanceObserverId: String? = nil
//            do {
//                balanceObserverId = try Kin.shared.addBalanceObserver { balance in
//                    self.balanceCallback!(balance.amount)
//                    print("balance: \(balance.amount)")
//                }
//            } catch {
//                print("Error setting balance observer: \(error)")
//            }
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
                // jwtConfirmation can be kept on digital service side as a receipt proving user received his Kin.
                // Send confirmation JWT back to the server in order prove that the user completed
                // the blockchain transaction and purchase can be unlocked for this user.
            } else if let e = error {
                // handle error
            }
        }
    }
    
    private func kinSpend(jwt : String){
        let handler: ExternalOfferCallback = { jwtConfirmation, error in
            let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
            if let confirm = jwtConfirmation {
                // Callback will be called once payment transaction to the user completed successfully.
                // jwtConfirmation can be kept on digital service side as a receipt proving user received his Kin.
            } else if let e = error {
                //handle error
            }
        }
        Kin.shared.requestPayment(offerJWT: jwt, completion: handler)
    }
    
    private func kinPayToUser(jwt : String){
        Kin.shared.payToUser(offerJWT: jwt) { jwtConfirmation, error in
            if let confirm = jwtConfirmation {
                // jwtConfirmation can be kept on digital service side as a receipt proving user received his Kin.
                // Send confirmation JWT back to the server in order prove that the user completed
                // the blockchain transaction and purchase can be unlocked for this user.
            } else if let e = error {
                // handle error
            }
        }
    }
}
