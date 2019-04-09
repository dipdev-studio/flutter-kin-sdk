import Flutter
import UIKit
import KinSDK
import Foundation
import KinUtil

public class SwiftFlutterKinSdkPlugin: NSObject, FlutterPlugin {
    
    private var kinClient : KinClient?
    private var isProduction : Bool?
    
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
        if(call.method.elementsEqual("initKinClient")){
            let arguments = call.arguments as? NSDictionary
            isProduction = arguments!["isProduction"] as? Bool
            let appId = arguments!["appId"] as? String
            let serverUrl = arguments!["serverUrl"] as? String
            if (isProduction == nil) {isProduction = false}
            if(isProduction == true) {
                sendError(code: "-0", type: "initKinClient", message: "Sorry, but the production network is not implemented in this version of plugin")
                return
            }
            initKinClient(appId: appId, serverUrl: serverUrl)
            sendReport(type: "initKinClient", message: "Kin init successful")
        } else {
            if(!isKinClientInit()){return}
        }
        if(call.method.elementsEqual("createAccount")){
            print("🔥🔥🔥")
            self.createAccount()
        }
        if(call.method.elementsEqual("deleteAccount")){
//            let arguments = call.arguments as? NSDictionary
//            let accountNum = arguments!["accountNum"] as? Int
//            if (accountNum == nil){return}
            deleteAccount(accountNum: 0)
        }
        if(call.method.elementsEqual("importAccount")){
            let arguments = call.arguments as? NSDictionary
            let recoveryString = arguments!["recoveryString"] as? String
            let secretPassphrase = arguments!["secretPassphrase"] as? String
            if (recoveryString == nil || secretPassphrase == nil){return}
            importAccount(json: recoveryString!, secretPassphrase: secretPassphrase!)
        }
        if(call.method.elementsEqual("exportAccount")){
            let arguments = call.arguments as? NSDictionary
//            let accountNum = arguments!["accountNum"] as? Int
            let secretPassphrase = arguments!["secretPassphrase"] as? String
            if (secretPassphrase == nil){return}
//            if (accountNum == nil || secretPassphrase == nil){return}
            let recoveryString = exportAccount(accountNum: 0, secretPassphrase: secretPassphrase!)
            if (recoveryString != nil) {result(recoveryString)}
        }
        if(call.method.elementsEqual("getAccountBalance")){
            getAccountBalance(accountNum: 0)
        }
        if(call.method.elementsEqual("getAccountState")){
            getAccountState(accountNum: 0)
        }
        if(call.method.elementsEqual("getPublicAddress")){
            if let account = getAccount(accountNum: 0){
                result(account.publicAddress)
            }
        }
        if(call.method.elementsEqual("sendTransaction")){
            let arguments = call.arguments as? NSDictionary
//            let fromAccountNum = arguments!["fromAccountNum"] as? Int
            let toAddress = arguments!["toAddress"] as? String
            let kinAmount = arguments!["kinAmount"] as? Int
            let memo = arguments!["memo"] as? String
            let fee = arguments!["fee"] as? Int
            if (toAddress == nil || kinAmount == nil || fee == nil){return}
            sendTransaction(fromAccountNum: 0, toAddress: toAddress!, kinAmount: kinAmount!, memo: memo, fee: fee!)
        }
        if(call.method.elementsEqual("sendWhitelistTransaction")){
            let arguments = call.arguments as? NSDictionary
            let whitelistServiceUrl = arguments!["whitelistServiceUrl"] as? String
//            let fromAccountNum = arguments!["fromAccountNum"] as? Int
            let toAddress = arguments!["toAddress"] as? String
            let kinAmount = arguments!["kinAmount"] as? Int
            let memo = arguments!["memo"] as? String
            let fee = arguments!["fee"] as? Int
            if (whitelistServiceUrl == nil || toAddress == nil || kinAmount == nil || fee == nil){return}
            sendWhitelistTransaction(whitelistServiceUrl: whitelistServiceUrl!, fromAccountNum: 0, toAddress: toAddress!, kinAmount: kinAmount!, memo: memo, fee: fee!)
        }
        if(call.method.elementsEqual("fund")){
            //TODO
        }
    }
    
    private func initKinClient(appId: String? = nil, serverUrl: String? = nil){
        if (appId == nil) {return}
        var url: String
        var network : Network
        if (isProduction == true) {
            if (serverUrl == nil) {return}
            url = serverUrl!
            network = .mainNet
        }else{
            url = "http://horizon-testnet.kininfrastructure.com"
            network = .playground
        }
        guard let providerUrl = URL(string: url) else {return}
        do {
            kinClient = KinClient(with: providerUrl, network: network, appId: try AppId(appId!))
        } catch let error {
            sendError(type: "InitKinClient", error: error)
        }
        receiveAccountsPayments()
    }
    
    private func createAccount(){
        do {
            let account = try kinClient!.addAccount()
            let accountNum = kinClient!.accounts.endIndex
            if (!isProduction!){
                createAccountOnPlayground(account: account, accountNum: accountNum) { (result: [String : Any]?) in
                    guard result != nil else {
                        self.sendError(code: "-1", type: "CreateAccountOnPlaygroundBlockchain", message: "Account creation on playground blockchain failed with no parsable JSON")
                        self.deleteAccount(accountNum: accountNum)
                        return
                    }
                    self.sendReport(type: "CreateAccountOnPlaygroundBlockchain", message: "Account was created successfully", intValue: accountNum)
                }
            }
        } catch {
            let err = ErrorReport(type: "CreateAccount", message: "Account creation exception")
            sendError(code: "-2", message: "Account creation exception", details: err)
        }
    }
    
    private func createAccountOnPlayground(account: KinAccount, accountNum: Int,
                                           completionHandler: @escaping (([String: Any]?) -> ())) {
        let createUrlString = "http://friendbot-testnet.kininfrastructure.com?addr=\(account.publicAddress)"
        guard let createUrl = URL(string: createUrlString) else {
            sendError(code: "-3", type: "CreateAccountOnPlaygroundBlockchain", message: "Create Url string error")
            self.deleteAccount(accountNum: accountNum)
            return
        }
        let request = URLRequest(url: createUrl)
        let task = URLSession.shared.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            if let error = error {
                self.sendError(type: "CreateAccountOnPlaygroundBlockchain", error: error)
                completionHandler(nil)
                return
            }
            guard let data = data,
                let json = try? JSONSerialization.jsonObject(with: data, options: []),
                let result = json as? [String: Any] else {
                    self.sendError(code: "-4", type: "CreateAccountOnPlaygroundBlockchain", message: "Account creation on playground blockchain failed with no parsable JSON")
                    completionHandler(nil)
                    return
            }
            guard result["status"] == nil else {
                self.sendError(code: "-5", type: "CreateAccountOnPlaygroundBlockchain", message: "Error status \(result)")
                completionHandler(nil)
                return
            }
            completionHandler(result)
        }
        task.resume()
    }
    
    private func deleteAccount(accountNum: Int) {
        if (!isAccountCreated()){return}
        do {
            try kinClient!.deleteAccount(at: accountNum)
            sendReport(type: "DeleteAccount", message: "Account deletion was a success")
        }
        catch let error {
            sendError(type: "DeleteAccount", error: error)
        }
    }
    
    private func importAccount(json: String, secretPassphrase: String){
        do {
            _ = try kinClient!.importAccount(json, passphrase: secretPassphrase)
        }
        catch let error {
            sendError(type: "ImportAccount", error: error)
        }
    }
    
    private func exportAccount(accountNum: Int, secretPassphrase: String) -> String?{
        let account = getAccount(accountNum: accountNum)
        if (account != nil) {return nil}
        let json = try! account!.export(passphrase: secretPassphrase)
        return json
    }
    
    private func getAccount(accountNum: Int) -> KinAccount? {
        if (isAccountCreated(accountNum: accountNum)){
            return kinClient!.accounts[accountNum]
        }
        return nil
    }
    
    private func getAccountPublicAddress(accountNum: Int) -> String? {
        let account = getAccount(accountNum: accountNum)
        if (account == nil) {return nil}
        return account!.publicAddress
    }
    
    private func getAccountState(accountNum: Int) {
        let account = getAccount(accountNum: accountNum)
        if (account != nil) {return}
        account!.status { (status: AccountStatus?, error: Error?) in
            if (error != nil){
                self.sendError(type: "GetAccountState", error: error!)
                return
            }
            guard let status = status else { return }
            switch status {
            case .notCreated:
                self.sendReport(type: "GetAccountState", message: "Account is not created")
                ()
            case .created:
                self.sendReport(type: "GetAccountState", message: "Account is created")
                ()
            }
        }
    }
    
    private func getAccountBalance(accountNum: Int){
        let account = getAccount(accountNum: accountNum)
        if (account != nil) {return}
        getAccountBalance(forAccount: account!) { kin in
            guard let kin = kin else {
                self.sendError(code: "-6", type: "GetAccountBalance", message: "Error getting the balance")
                return
            }
            self.sendReport(type: "GetAccountState", message: "Current balance of \(account!.publicAddress)", intValue: NSDecimalNumber(decimal: kin).intValue)
        }
    }
    
    private func getAccountBalance(forAccount account: KinAccount, completionHandler: ((Kin?) -> ())?) {
        account.balance { (balance: Kin?, error: Error?) in
            if error != nil || balance == nil {
                print("Error getting the balance")
                if let error = error { print("with error: \(error)") }
                completionHandler?(nil)
                return
            }
            completionHandler?(balance!)
        }
    }
    
    private func sendTransaction(fromAccountNum: Int, toAddress: String, kinAmount: Int, memo: String?, fee: Int) {
        let account = getAccount(accountNum: fromAccountNum)
        if (account != nil) {return}
        sendTransaction(fromAccount: account!, toAddress: toAddress, kinAmount: Kin(kinAmount), memo: memo,fee: UInt32(fee)) { txId in
            self.sendReport(type: "SendTransaction", message: "Transaction was sent successfully for \(kinAmount) Kin - id: \(txId!)")
        }
    }
    
    private func sendTransaction(fromAccount account: KinAccount,
                                 toAddress address: String,
                                 kinAmount kin: Kin,
                                 memo: String?,
                                 fee: Stroop,
                                 completionHandler: ((String?) -> ())?) {
        account.generateTransaction(to: address, kin: kin, memo: memo, fee: fee) { (envelope, error) in
            if error != nil || envelope == nil {
                self.sendError(code: "-7", type: "SendTransaction", message: "Could not generate the transaction")
                if let error = error {
                    self.sendError(type: "SendTransaction", error: error)
                }
                completionHandler?(nil)
                return
            }
            
            account.sendTransaction(envelope!) { (txId, error) in
                if error != nil || txId == nil {
                    self.sendError(code: "-8", type: "SendTransaction", message: "Error send transaction")
                    if let error = error {
                        self.sendError(type: "SendTransaction", error: error)
                    }
                    completionHandler?(nil)
                    return
                }
                completionHandler?(txId!)
            }
        }
    }
    
    private func sendWhitelistTransaction(whitelistServiceUrl: String, fromAccountNum: Int, toAddress: String, kinAmount: Int, memo: String?, fee: Int) {
        let account = getAccount(accountNum: fromAccountNum)
        if (account != nil) {return}
        self.sendWhitelistTransaction(whitelistServiceUrl: whitelistServiceUrl,
                                      fromAccount: account!, toAddress: toAddress,
                                      kinAmount: Kin(kinAmount),
                                      memo: memo,
                                      fee: UInt32(fee)) { txId in
            self.sendReport(type: "SendWhitelistTransaction", message: "Transaction was sent successfully for \(kinAmount) Kin - id: \(txId!)", intValue: kinAmount)
            
        }
    }
    
    private func sendWhitelistTransaction(whitelistServiceUrl: String,
                                          fromAccount account: KinAccount,
                                          toAddress address: String,
                                          kinAmount kin: Kin,
                                          memo: String?,
                                          fee: Stroop,
                                          completionHandler: ((String?) -> ())?) {
        account.generateTransaction(to: address, kin: kin, memo: memo, fee: fee) { (envelope, error) in
            if error != nil || envelope == nil {
                self.sendError(code: "-9", type: "SendWhitelistTransaction", message: "Could not generate the transaction")
                if let error = error {
                    self.sendError(type: "SendWhitelistTransaction", error: error)
                }
                completionHandler?(nil)
                return
            }
            
            let networkId = Network.testNet.id
            let whitelistEnvelope = WhitelistEnvelope(transactionEnvelope: envelope!, networkId: networkId)
            
            self.signWhitelistTransaction(whitelistServiceUrl: whitelistServiceUrl,
                                          envelope: whitelistEnvelope) { (signedEnvelope, error) in
                                            if error != nil || signedEnvelope == nil {
                                                print("Error whitelisting the envelope")
                                                self.sendError(code: "-10", type: "SendWhitelistTransaction", message: "Error whitelisting the envelope")
                                                if let error = error {
                                                    self.sendError(type: "SendWhitelistTransaction", error: error)
                                                }
                                                completionHandler?(nil)
                                                return
                                            }
                                            account.sendTransaction(signedEnvelope!) { (txId, error) in
                                                if error != nil || txId == nil {
                                                    self.sendError(code: "-11", type: "SendWhitelistTransaction", message: "Error send whitelist transaction")
                                                    if let error = error {
                                                        self.sendError(type: "SendWhitelistTransaction", error: error)
                                                    }
                                                    completionHandler?(nil)
                                                    return
                                                }
                                                completionHandler?(txId!)
                                            }
                                            
            }
        }
    }
    
    private func signWhitelistTransaction(whitelistServiceUrl: String,
                                          envelope: WhitelistEnvelope,
                                          completionHandler: @escaping ((KinSDK.TransactionEnvelope?, Error?) -> ())) {
        let whitelistingUrl = URL(string: whitelistServiceUrl)!
        
        var request = URLRequest(url: whitelistingUrl)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = try? JSONEncoder().encode(envelope)
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            do {
                let envelope = try TransactionEnvelope.decodeResponse(data: data, error: error)
                completionHandler(envelope, nil)
            }
            catch {
                completionHandler(nil, error)
            }
        }
        task.resume()
    }
    
    //TODO Release method
    //private func fund(amount: Kin) -> Promise<Bool> {}
    
    private func receiveAccountsPayments() {
        if(!isKinClientInit() || kinClient?.accounts.count == 0){return}
        for index in 0...((kinClient?.accounts.count)! - 1) {
            receiveAccountPayment(accountNum: index)
        }
    }
    
    //TODO Send more detailed info which depends on accounts public addresses
    private func receiveAccountPayment(accountNum: Int) {
        let linkBag = LinkBag()
        let watch: PaymentWatch
        do{
            watch = try kinClient!.accounts[accountNum]!.watchPayments(cursor: nil)
            watch.emitter
                .on(next: {
                    self.sendReport(type: "PaymentEvent", message: NSString(format: "to = %@, from = %@", $0.destination, $0.source) as String, intValue: ($0.amount as NSDecimalNumber).intValue)
                })
                .add(to: linkBag)
        }catch{
            sendError(type: "ReceiveAccountPayment", error: error)
        }
    }
    
    private func balanceChanged(accountNum: Int) {
        let linkBag = LinkBag()
        let watch: BalanceWatch
        
        do {
            if(!isKinClientInit()) {return}
            watch = try kinClient!.accounts[accountNum]!.watchBalance(nil)
            watch.emitter
                .on(next: {
                    self.sendBalance(accountNum: accountNum, amount: ($0 as NSDecimalNumber).intValue)
                })
                .add(to: linkBag)
        } catch {
            sendError(code: "-12", type: "BalanceChange", message: "Balance change exception")
        }
    }
    
    private func isAccountCreated(accountNum: Int = 0) -> Bool {
        if(kinClient!.accounts.count <= accountNum){
            sendError(code: "-13", type: "AccountStateCheck", message: "Account is not created")
            return false
        }
        return true
    }
    
    private func isKinClientInit() -> Bool{
        if(kinClient == nil){
            sendError(code: "-14", type: "KinClientInit", message: "Kin client not inited")
            return false
        }
        return true
    }
    
    private func getAccountNum(call: FlutterMethodCall) -> Int?{
        let arguments = call.arguments as? NSDictionary
        let accountNum = arguments!["accountNum"] as? Int
        return accountNum
    }
    
    private func sendBalance(accountNum: Int, amount: Int) {
        let balanceReport = BalanceReport(accountNum: accountNum, amount: amount)
        let encoder = JSONEncoder()
        var data: Data? = nil
        do {
            data = try encoder.encode(balanceReport)
        } catch {
            sendError(type: "SendBalanceJson", error: error)
        }
        if (data != nil) {
            SwiftFlutterKinSdkPlugin.balanceFlutterController.eventCallback?(String(data: data!, encoding: .utf8)!)
        }
    }
    
    private func sendReport(type: String, message: String, intValue: Int? = nil){
        var info: InfoReport
        if (intValue != nil){
            info = InfoReport(type: type, message: message, intValue: intValue)
        }else{
            info = InfoReport(type: type, message: message)
        }
        let encoder = JSONEncoder()
        var data: Data? = nil
        do {
            data = try encoder.encode(info)
        } catch {
            sendError(type: "SendReportJson", error: error)
        }
        if (data != nil) {
            SwiftFlutterKinSdkPlugin.infoFlutterController.eventCallback?(String(data: data!, encoding: .utf8)!)
        }
    }
    
    private func sendError(type: String, error: Error) {
        let err = ErrorReport(type: type, message: error.localizedDescription)
        var message: String? = error.localizedDescription
        if (message == nil) {message = ""}
        sendError(code: "-15", message: message!, details: err)
    }
    
    private func sendError(code: String, type: String, message: String) {
        let err = ErrorReport(type: type, message: message)
        sendError(code: code, message: message, details: err)
    }
    
    private func sendError(code: String, message: String?, details: ErrorReport) {
        let encoder = JSONEncoder()
        var data: Data? = nil
        do {
            data = try encoder.encode(details)
        } catch {
            sendError(type: "SendErrorJson", error: error)
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
    
    struct BalanceReport:Encodable {
        let accountNum: Int
        let amount: Int
    }
    
    struct InfoReport:Encodable {
        let type: String
        let message: String
        let intValue: Int?
        init(type: String, message: String, intValue: Int? = nil) {
            self.type = type
            self.message = message
            self.intValue = intValue
        }
    }
    
    struct ErrorReport:Encodable {
        let type: String
        let message: String
    }
}

