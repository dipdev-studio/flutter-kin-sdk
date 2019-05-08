import Flutter
import UIKit
import KinSDK
import Foundation
import KinUtil

public class SwiftFlutterKinSdkPlugin: NSObject, FlutterPlugin {
    
    private var kinClient : KinClient?
    private var isProduction = false
    
    static let balanceFlutterController = FlutterStreamController()
    static let infoFlutterController = FlutterStreamController()
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: Constants.FLUTTER_KIN_SDK.rawValue, binaryMessenger: registrar.messenger())
        let balanceEventChannel = FlutterEventChannel.init(name: Constants.FLUTTER_KIN_SDK_BALANCE.rawValue, binaryMessenger: registrar.messenger())
        let infoEventChannel = FlutterEventChannel.init(name: Constants.FLUTTER_KIN_SDK_INFO.rawValue, binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterKinSdkPlugin()
        balanceEventChannel.setStreamHandler(balanceFlutterController)
        infoEventChannel.setStreamHandler(infoFlutterController)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if(call.method.elementsEqual(Constants.INIT_KIN_CLIENT.rawValue)){
            let arguments = call.arguments as? NSDictionary
            isProduction = arguments!["isProduction"] as! Bool
            let appId = arguments!["appId"] as? String
            let serverUrl = arguments!["serverUrl"] as? String
//            if(isProduction) {
//                sendError(code: "-0", type: Constants.INIT_KIN_CLIENT.rawValue, message: "Sorry, but the production network is not implemented in this version of plugin")
//                return
//            }
            initKinClient(appId: appId, serverUrl: serverUrl)
            sendReport(type: Constants.INIT_KIN_CLIENT.rawValue, message: "Kin init successful")
        } else {
            if(!isKinClientInit()){return}
        }
        
        if(call.method.elementsEqual(Constants.CREATE_ACCOUNT.rawValue)){
            result(self.createAccount())
        }
        
        if(call.method.elementsEqual(Constants.DELETE_ACCOUNT.rawValue)){
            let arguments = call.arguments as? NSDictionary
            let publicAddress = arguments!["publicAddress"] as? String
            if (publicAddress == nil){return}
            let accountNum: Int? = getAccountNum(publicAddress: publicAddress!)
            if (accountNum == nil){return}
            deleteAccount(accountNum: accountNum!)
        }
        
        if(call.method.elementsEqual(Constants.IMPORT_ACCOUNT.rawValue)){
            let arguments = call.arguments as? NSDictionary
            let recoveryString = arguments!["recoveryString"] as? String
            let secretPassphrase = arguments!["secretPassphrase"] as? String
            if (recoveryString == nil || secretPassphrase == nil){return}
            let account = importAccount(json: recoveryString!, secretPassphrase: secretPassphrase!)
            if (account == nil) {return}
            result(account!.publicAddress)
        }
        
        if(call.method.elementsEqual(Constants.EXPORT_ACCOUNT.rawValue)){
            let arguments = call.arguments as? NSDictionary
            let publicAddress = arguments!["publicAddress"] as? String
            let secretPassphrase = arguments!["secretPassphrase"] as? String
            if (publicAddress == nil || secretPassphrase == nil){return}
            let accountNum: Int? = getAccountNum(publicAddress: publicAddress!)
            if (accountNum == nil){return}
            let recoveryString = exportAccount(accountNum: accountNum!, secretPassphrase: secretPassphrase!)
            if (recoveryString != nil) {result(recoveryString)}
        }
        
        if(call.method.elementsEqual(Constants.GET_ACCOUNT_BALANCE.rawValue)){
            let arguments = call.arguments as? NSDictionary
            let publicAddress = arguments!["publicAddress"] as? String
            let accountNum: Int? = getAccountNum(publicAddress: publicAddress!)
            if (accountNum == nil){return}
            getAccountBalance(accountNum: accountNum!){ (balance) -> () in
                result(balance)
            }
        }
        
        if(call.method.elementsEqual(Constants.GET_ACCOUNT_STATE.rawValue)){
            let arguments = call.arguments as? NSDictionary
            let publicAddress = arguments!["publicAddress"] as? String
            let accountNum: Int? = getAccountNum(publicAddress: publicAddress!)
            if (accountNum == nil){return}
            getAccountState(accountNum: accountNum!){ (state) -> () in
                result(state)
            }
        }
        
        if(call.method.elementsEqual(Constants.SEND_TRANSACTION.rawValue)){
            let arguments = call.arguments as? NSDictionary
            let publicAddress = arguments!["publicAddress"] as? String
            let toAddress = arguments!["toAddress"] as? String
            let kinAmount = arguments!["kinAmount"] as? Int
            let memo = arguments!["memo"] as? String
            let fee = arguments!["fee"] as? Int
            if (publicAddress == nil || toAddress == nil || kinAmount == nil || fee == nil){return}
            let accountNum: Int? = getAccountNum(publicAddress: publicAddress!)
            if (accountNum == nil){return}
            sendTransaction(fromAccountNum: accountNum!, toAddress: toAddress!, kinAmount: kinAmount!, memo: memo, fee: fee!)
        }
        
        if(call.method.elementsEqual(Constants.SEND_WHITELIST_TRANSACTION.rawValue)){
            let arguments = call.arguments as? NSDictionary
            let whitelistServiceUrl = arguments!["whitelistServiceUrl"] as? String
            let publicAddress = arguments!["publicAddress"] as? String
            let toAddress = arguments!["toAddress"] as? String
            let kinAmount = arguments!["kinAmount"] as? Int
            let memo = arguments!["memo"] as? String
            let fee = arguments!["fee"] as? Int
            if (whitelistServiceUrl == nil || publicAddress == nil || toAddress == nil || kinAmount == nil || fee == nil){return}
            let accountNum: Int? = getAccountNum(publicAddress: publicAddress!)
            if (accountNum == nil){return}
            sendWhitelistTransaction(whitelistServiceUrl: whitelistServiceUrl!, fromAccountNum: accountNum!, toAddress: toAddress!, kinAmount: kinAmount!, memo: memo, fee: fee!)
        }
        
        if(call.method.elementsEqual(Constants.FUND.rawValue)){
            let arguments = call.arguments as? NSDictionary
            let publicAddress = arguments!["publicAddress"] as? String
            let kinAmount = arguments!["kinAmount"] as? Int
            if (publicAddress == nil || kinAmount == nil){return}
            let accountNum: Int? = getAccountNum(publicAddress: publicAddress!)
            if (accountNum == nil){return}
            fund(accountNum: accountNum!, amount: kinAmount!)
        }
    }
    
    private func initKinClient(appId: String? = nil, serverUrl: String? = nil){
        if (appId == nil) {return}
        var url: String
        var network : Network
        if (isProduction) {
            network = .mainNet
            url = "https://horizon-ecosystem.kininfrastructure.com"
        }else{
            network = .testNet
            url = "https://horizon-testnet.kininfrastructure.com"
        }
        guard let providerUrl = URL(string: url) else {return}
        do {
            kinClient = KinClient(with: providerUrl, network: network, appId: try AppId(appId!))
        } catch let error {
            sendError(type: Constants.INIT_KIN_CLIENT.rawValue, error: error)
        }
        receiveAccountsPaymentsAndBalanceChanges()
    }
    
    private func createAccount() -> String?{
        do {
            let account = try kinClient!.addAccount()
            let accountNum = getAccountNum(publicAddress: account.publicAddress)
            if (accountNum == nil) {return nil}
            
            if (!isProduction){
                createAccountOnPlayground(account: account, accountNum: accountNum!) { (result: [String : Any]?) in
                    guard result != nil else {
                        self.sendError(code: "-1", type: Constants.CREATE_ACCOUNT_ON_PLAYGROUND_BLOCKCHAIN.rawValue, message: "Account creation on playground blockchain failed and account has already deleted")
                        self.deleteAccount(accountNum: accountNum!)
                        return
                    }
                    self.receiveAccountPayment(accountNum: accountNum!)
                    self.receiveBalanceChanges(accountNum: accountNum!)
                    self.sendReport(type: Constants.CREATE_ACCOUNT_ON_PLAYGROUND_BLOCKCHAIN.rawValue, message: "Account in playground was created successfully", value: account.publicAddress)
                }
            }else{
                receiveAccountPayment(accountNum: accountNum!)
                receiveBalanceChanges(accountNum: accountNum!)
            }
            
            return account.publicAddress
            
        } catch {
            let err = ErrorReport(type: Constants.CREATE_ACCOUNT.rawValue, message: "Account creation exception")
            sendError(code: "-2", message: "Account creation exception", details: err)
        }
        
        return nil
    }
    
    private func createAccountOnPlayground(account: KinAccount, accountNum: Int,
                                           completionHandler: @escaping (([String: Any]?) -> ())) {
        let createUrlString = "https://friendbot-testnet.kininfrastructure.com?addr=\(account.publicAddress)&amount=100"
        guard let createUrl = URL(string: createUrlString) else {
            sendError(code: "-3", type: Constants.CREATE_ACCOUNT_ON_PLAYGROUND_BLOCKCHAIN.rawValue, message: "Create Url string error")
            self.deleteAccount(accountNum: accountNum)
            return
        }
        let request = URLRequest(url: createUrl)
        let task = URLSession.shared.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            if let error = error {
                self.sendError(type: Constants.CREATE_ACCOUNT_ON_PLAYGROUND_BLOCKCHAIN.rawValue, error: error)
                completionHandler(nil)
                return
            }
            guard let data = data,
                let json = try? JSONSerialization.jsonObject(with: data, options: []),
                let result = json as? [String: Any] else {
                    self.sendError(code: "-4", type: Constants.CREATE_ACCOUNT_ON_PLAYGROUND_BLOCKCHAIN.rawValue, message: "Account creation on playground blockchain failed with no parsable JSON")
                    completionHandler(nil)
                    return
            }
            guard result["status"] == nil else {
                self.sendError(code: "-5", type: Constants.CREATE_ACCOUNT_ON_PLAYGROUND_BLOCKCHAIN.rawValue, message: "Error status \(result)")
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
            sendReport(type: Constants.DELETE_ACCOUNT.rawValue, message: "Account deletion was a success")
        }
        catch let error {
            sendError(type: Constants.DELETE_ACCOUNT.rawValue, error: error)
        }
    }
    
    private func importAccount(json: String, secretPassphrase: String) -> KinAccount?{
        do {
            let account:KinAccount = try kinClient!.importAccount(json, passphrase: secretPassphrase)
            
            let accountNum = getAccountNum(publicAddress: account.publicAddress)
            if (accountNum == nil) {return nil}
            receiveAccountPayment(accountNum: accountNum!)
            receiveBalanceChanges(accountNum: accountNum!)
            
            return account
        }
        catch let error {
            sendError(type: Constants.IMPORT_ACCOUNT.rawValue, error: error)
        }
        return nil
    }
    
    private func exportAccount(accountNum: Int, secretPassphrase: String) -> String?{
        let account = getAccount(accountNum: accountNum)
        if (account == nil) {return nil}
        let json = try! account!.export(passphrase: secretPassphrase)
        return json
    }
    
    private func getAccount(accountNum: Int) -> KinAccount? {
        if (isAccountCreated(accountNum: accountNum)){
            return kinClient!.accounts[accountNum]
        }
        return nil
    }
    
    private func getAccountNum(publicAddress: String) -> Int? {
        if(kinClient?.accounts.count == 0){return nil}
        for index in 0...((kinClient?.accounts.count)! - 1) {
            if (getAccount(accountNum: index)?.publicAddress == publicAddress) {return index}
        }
        
        sendError(code: "-13", type: Constants.ACCOUNT_STATE_CHECK.rawValue, message: "Account is not created")
        return nil
    }
    
    private func isAccountCreated(accountNum: Int = 0) -> Bool {
        if((kinClient?.accounts.count)! < accountNum){
            sendError(code: "-13", type: Constants.ACCOUNT_STATE_CHECK.rawValue, message: "Account is not created")
            return false
        }
        return true
    }
    
    private func getAccountPublicAddress(accountNum: Int) -> String? {
        let account = getAccount(accountNum: accountNum)
        if (account == nil) {return nil}
        return account!.publicAddress
    }
    
    private func getAccountState(accountNum: Int, completion: @escaping (_ result: String)->()) {
        let account = getAccount(accountNum: accountNum)
        if (account == nil) {return}
        account!.status { (status: AccountStatus?, error: Error?) in
            if (error != nil){
                self.sendError(type: Constants.GET_ACCOUNT_STATE.rawValue, error: error!)
                return
            }
            guard let status = status else { return }
            switch status {
            case .created:
                completion("Account is created")
                ()
            case .notCreated:
                completion("Account is not created")
                ()
            }
        }
    }
    
    private func getAccountBalance(accountNum: Int, completion: @escaping (_ result: Int)->()){
        let account = getAccount(accountNum: accountNum)
        if (account == nil) {return}
        getAccountBalance(forAccount: account!) { kin in
            guard let kin = kin else {
                self.sendError(code: "-6", type: Constants.GET_ACCOUNT_BALANCE.rawValue, message: "Error getting the balance")
                return
            }
            completion(NSDecimalNumber(decimal: kin).intValue)
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
        if (account == nil) {return}
        sendTransaction(fromAccount: account!, toAddress: toAddress, kinAmount: Kin(kinAmount), memo: memo,fee: UInt32(fee)) { txId in
            self.sendReport(type: Constants.SEND_TRANSACTION.rawValue, message: "Transaction was sent successfully for \(account!.publicAddress)", value: String(kinAmount))
            
            self.getAccountBalance(accountNum: fromAccountNum){ (balance) -> () in
                self.sendBalance(publicAddress: self.kinClient!.accounts[fromAccountNum]!.publicAddress, amount: balance)
            }
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
                self.sendError(code: "-7", type: Constants.SEND_TRANSACTION.rawValue, message: "Could not generate the transaction")
                if let error = error {
                    self.sendError(type: Constants.SEND_TRANSACTION.rawValue, error: error)
                }
                completionHandler?(nil)
                return
            }
            
            account.sendTransaction(envelope!) { (txId, error) in
                if error != nil || txId == nil {
                    self.sendError(code: "-8", type: Constants.SEND_TRANSACTION.rawValue, message: "Error send transaction")
                    if let error = error {
                        self.sendError(type: Constants.SEND_TRANSACTION.rawValue, error: error)
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
        if (account == nil) {return}
        self.sendWhitelistTransaction(whitelistServiceUrl: whitelistServiceUrl,
                                      fromAccount: account!, toAddress: toAddress,
                                      kinAmount: Kin(kinAmount),
                                      memo: memo,
                                      fee: UInt32(fee)) { txId in
            self.sendReport(type: Constants.SEND_WHITELIST_TRANSACTION.rawValue, message: "Transaction was sent successfully for \(kinAmount) Kin - id: \(txId!)", value: String(kinAmount))
            
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
                self.sendError(code: "-9", type: Constants.SEND_WHITELIST_TRANSACTION.rawValue, message: "Could not generate the transaction")
                if let error = error {
                    self.sendError(type: Constants.SEND_WHITELIST_TRANSACTION.rawValue, error: error)
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
                                                self.sendError(code: "-10", type: Constants.SEND_WHITELIST_TRANSACTION.rawValue, message: "Error whitelisting the envelope")
                                                if let error = error {
                                                    self.sendError(type: Constants.SEND_WHITELIST_TRANSACTION.rawValue, error: error)
                                                }
                                                completionHandler?(nil)
                                                return
                                            }
                                            account.sendTransaction(signedEnvelope!) { (txId, error) in
                                                if error != nil || txId == nil {
                                                    self.sendError(code: "-11", type: Constants.SEND_WHITELIST_TRANSACTION.rawValue, message: "Error send whitelist transaction")
                                                    if let error = error {
                                                        self.sendError(type: Constants.SEND_WHITELIST_TRANSACTION.rawValue, error: error)
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
    
    private func fund(accountNum: Int, amount: Int){
        let account = getAccount(accountNum: accountNum)
        if (account == nil) {return}
        let url = URL(string: "http://friendbot-testnet.kininfrastructure.com/fund?addr=\(account!.publicAddress)&amount=\(amount)")!
        
        URLSession.shared.dataTask(with: url, completionHandler: { data, response, error in
            guard
                let data = data,
                let jsonOpt = try? JSONSerialization.jsonObject(with: data, options: []),
                let _ = jsonOpt as? [String: Any]
                else {
                    self.sendError(code: "-16", type: Constants.FUND.rawValue, message: "Invalid response")
                    return
            }
            
            self.sendReport(type: Constants.FUND.rawValue, message: "Fund successful to \(account!.publicAddress)", value: String(amount))
            self.getAccountBalance(accountNum: accountNum){ (balance) -> () in
                self.sendBalance(publicAddress: self.kinClient!.accounts[accountNum]!.publicAddress, amount: balance)
            }
        }).resume()
    }
    
    private func receiveAccountsPaymentsAndBalanceChanges() {
        if(!isKinClientInit() || kinClient?.accounts.count == 0){return}
        for index in 0...((kinClient?.accounts.count)! - 1) {
            receiveAccountPayment(accountNum: index)
            receiveBalanceChanges(accountNum: index)
        }
    }
    
    private func receiveAccountPayment(accountNum: Int) {
        let linkBag = LinkBag()
        let watch: PaymentWatch
        do{
            watch = try kinClient!.accounts[accountNum]!.watchPayments(cursor: nil)
            watch.emitter
                .on(next: {
                    self.sendReport(type: Constants.PAYMENT_EVENT.rawValue, message: NSString(format: "to = %@, from = %@", $0.destination, $0.source) as String, value: String(($0.amount as NSDecimalNumber).intValue))
                })
                .add(to: linkBag)
        }catch{
            sendError(type: Constants.PAYMENT_EVENT.rawValue, error: error)
        }
    }
    
    private func receiveBalanceChanges(accountNum: Int) {
        let linkBag = LinkBag()
        let watch: BalanceWatch
        
        do {
            if(!isKinClientInit()) {return}
            watch = try kinClient!.accounts[accountNum]!.watchBalance(nil)
            watch.emitter
                .on(next: {
                    self.sendBalance(publicAddress: self.kinClient!.accounts[accountNum]!.publicAddress, amount: ($0 as NSDecimalNumber).intValue)
                })
                .add(to: linkBag)
        } catch {
            sendError(code: "-12", type: Constants.GET_ACCOUNT_BALANCE.rawValue, message: "Balance change exception")
        }
        getAccountBalance(accountNum: accountNum){ (balance) -> () in
            self.sendBalance(publicAddress: self.kinClient!.accounts[accountNum]!.publicAddress, amount: balance)
        }
    }
    
    private func isKinClientInit() -> Bool{
        if(kinClient == nil){
            sendError(code: "-14", type: Constants.INIT_KIN_CLIENT.rawValue, message: "Kin client not inited")
            return false
        }
        return true
    }
    
    private func sendBalance(publicAddress: String, amount: Int) {
        let balanceReport = BalanceReport(publicAddress: publicAddress, amount: amount)
        let encoder = JSONEncoder()
        var data: Data? = nil
        do {
            data = try encoder.encode(balanceReport)
        } catch {
            sendError(type: Constants.SEND_BALANCE_JSON.rawValue, error: error)
        }
        if (data != nil) {
            SwiftFlutterKinSdkPlugin.balanceFlutterController.eventCallback?(String(data: data!, encoding: .utf8)!)
        }
    }
    
    private func sendReport(type: String, message: String, value: String? = nil){
        var info: InfoReport
        if (value != nil){
            info = InfoReport(type: type, message: message, value: value)
        }else{
            info = InfoReport(type: type, message: message)
        }
        let encoder = JSONEncoder()
        var data: Data? = nil
        do {
            data = try encoder.encode(info)
        } catch {
            sendError(type: Constants.SEND_INFO_JSON.rawValue, error: error)
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
    
    private func sendError(code: String, type: String, message: String, isBalance: Bool = false) {
        let err = ErrorReport(type: type, message: message)
        sendError(code: code, message: message, details: err, isBalance: isBalance)
    }
    
    private func sendError(code: String, message: String?, details: ErrorReport, isBalance: Bool = false) {
        let encoder = JSONEncoder()
        var data: Data? = nil
        do {
            data = try encoder.encode(details)
        } catch {
            sendError(type: Constants.SEND_ERROR_JSON.rawValue, error: error)
        }
        if (data != nil) {
            if (!isBalance){
                SwiftFlutterKinSdkPlugin.infoFlutterController.error(code, message: message, details: String(data: data!, encoding: .utf8)!)
            } else{
                SwiftFlutterKinSdkPlugin.balanceFlutterController.error(code, message: message, details: String(data: data!, encoding: .utf8)!)
            }
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
        let publicAddress: String
        let amount: Int
    }
    
    struct InfoReport:Encodable {
        let type: String
        let message: String
        let value: String?
        init(type: String, message: String, value: String? = nil) {
            self.type = type
            self.message = message
            self.value = value
        }
    }
    
    struct ErrorReport:Encodable {
        let type: String
        let message: String
    }
    
    enum Constants: String {
        case FLUTTER_KIN_SDK = "flutter_kin_sdk"
        case FLUTTER_KIN_SDK_BALANCE = "flutter_kin_sdk_balance"
        case FLUTTER_KIN_SDK_INFO = "flutter_kin_sdk_info"
        case INIT_KIN_CLIENT = "InitKinClient"
        case CREATE_ACCOUNT = "CreateAccount"
        case DELETE_ACCOUNT = "DeleteAccount"
        case IMPORT_ACCOUNT = "ImportAccount"
        case EXPORT_ACCOUNT = "ExportAccount"
        case GET_ACCOUNT_BALANCE = "GetAccountBalance"
        case GET_ACCOUNT_STATE = "GetAccountState"
        case SEND_TRANSACTION = "SendTransaction"
        case SEND_WHITELIST_TRANSACTION = "SendWhitelistTransaction"
        case FUND = "Fund"
        case CREATE_ACCOUNT_ON_PLAYGROUND_BLOCKCHAIN = "CreateAccountOnPlaygroundBlockchain"
        case PAYMENT_EVENT = "PaymentEvent"
        case ACCOUNT_STATE_CHECK = "AccountStateCheck"
        case SEND_INFO_JSON = "SendInfoJson"
        case SEND_BALANCE_JSON = "SendBalanceJson"
        case SEND_ERROR_JSON = "SendErrorJson"
    }
}
