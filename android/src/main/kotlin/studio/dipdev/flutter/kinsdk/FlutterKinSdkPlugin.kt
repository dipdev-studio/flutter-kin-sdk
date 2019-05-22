package studio.dipdev.flutter.kinsdk

import android.app.Activity
import android.content.Context
import android.util.Log
import com.google.gson.Gson
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import kin.sdk.*
import kin.sdk.exception.CreateAccountException
import kin.utils.ResultCallback
import java.math.BigDecimal


class FlutterKinSdkPlugin(private var activity: Activity, private var context: Context) : MethodCallHandler {

    private lateinit var kinClient: KinClient
    private var isProduction: Boolean = false
    private var isKinInit = false
    private lateinit var whitelistService: WhitelistService

    companion object {
        lateinit var balanceCallback: EventChannel.EventSink
        lateinit var infoCallback: EventChannel.EventSink

        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val channel = MethodChannel(registrar.messenger(), "flutter_kin_sdk")
            val instance = FlutterKinSdkPlugin(registrar.activity(), registrar.activity().applicationContext)
            channel.setMethodCallHandler(instance)

            EventChannel(registrar.view(), Constants.FLUTTER_KIN_SDK_BALANCE.value).setStreamHandler(
                    object : EventChannel.StreamHandler {
                        override fun onListen(args: Any?, events: EventChannel.EventSink) {
                            balanceCallback = events
                        }

                        override fun onCancel(args: Any?) {
                        }
                    }
            )

            EventChannel(registrar.view(), Constants.FLUTTER_KIN_SDK_INFO.value).setStreamHandler(
                    object : EventChannel.StreamHandler {
                        override fun onListen(args: Any?, events: EventChannel.EventSink) {
                            infoCallback = events
                        }

                        override fun onCancel(args: Any?) {
                        }
                    }
            )

        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == Constants.INIT_KIN_CLIENT.value) {
            val isProductionInput: Boolean? = call.argument("isProduction")
            val appId: String = call.argument("appId") ?: return
            if (isProductionInput != null) this.isProduction = isProductionInput
            initKinClient(appId)
            sendReport(Constants.INIT_KIN_CLIENT.value, "Kin init successful")
        } else {
            if (!isKinClientInit()) return
        }

        when {
            call.method == Constants.CREATE_ACCOUNT.value -> {
                result.success(createAccount())
            }

            call.method == Constants.RECEIVE_PRODUCTION_PAYMENTS_AND_BALANCE.value -> {
                val publicAddress: String = call.argument("publicAddress") ?: return
                val accountNum: Int = getAccountIndexByPublicAddress(publicAddress) ?: return
                receiveAccountPayment(accountNum)
                receiveBalanceChanges(accountNum)
            }

            call.method == Constants.DELETE_ACCOUNT.value -> {
                val publicAddress: String = call.argument("publicAddress") ?: return
                val accountNum: Int = getAccountIndexByPublicAddress(publicAddress) ?: return
                deleteAccount(accountNum)
            }

            call.method == Constants.IMPORT_ACCOUNT.value -> {
                val recoveryString: String = call.argument("recoveryString") ?: return
                val secretPassphrase: String = call.argument("secretPassphrase") ?: return
                val account: KinAccount? = importAccount(recoveryString, secretPassphrase)
                        ?: return
                result.success(account!!.publicAddress)
            }

            call.method == Constants.EXPORT_ACCOUNT.value -> {
                val publicAddress: String = call.argument("publicAddress") ?: return
                val secretPassphrase: String = call.argument("secretPassphrase") ?: return
                val accountNum: Int = getAccountIndexByPublicAddress(publicAddress) ?: return
                val recoveryString: String? = exportAccount(accountNum, secretPassphrase)
                        ?: return
                result.success(recoveryString)
            }

            call.method == Constants.GET_ACCOUNT_BALANCE.value -> {
                val publicAddress: String = call.argument("publicAddress") ?: return
                val accountNum: Int = getAccountIndexByPublicAddress(publicAddress) ?: return
                getAccountBalance(accountNum, fun(balance: BigDecimal) { result.success(balance.toInt()) })
            }

            call.method == Constants.GET_ACCOUNT_STATE.value -> {
                val publicAddress: String = call.argument("publicAddress") ?: return
                val accountNum: Int = getAccountIndexByPublicAddress(publicAddress) ?: return
                getAccountState(accountNum, fun(state: String) { result.success(state) })
            }

            call.method == Constants.SEND_TRANSACTION.value -> {
                val publicAddress: String = call.argument("publicAddress") ?: return
                val toAddress: String = call.argument("toAddress") ?: return
                val kinAmount: Int = call.argument("kinAmount") ?: return
                val memo: String? = call.argument("memo")
                val fee: Int = call.argument("fee") ?: return
                val accountNum: Int = getAccountIndexByPublicAddress(publicAddress) ?: return
                sendTransaction(accountNum, toAddress, kinAmount, memo, fee)
            }

            call.method == Constants.SEND_WHITELIST_PLAYGROUND_TRANSACTION.value -> {
                var publicAddress: String = call.argument("publicAddress") ?: return
                var whitelistServiceUrl: String = call.argument("whitelistServiceUrl") ?: return
                var toAddress: String = call.argument("toAddress") ?: return
                var kinAmount: Int = call.argument("kinAmount") ?: return
                var memo: String? = call.argument("memo")
                var fee: Int = call.argument("fee") ?: return

            }

            call.method == Constants.SEND_WHITELIST_PRODUCTION_TRANSACTION.value -> {
                val publicAddress: String = call.argument("publicAddress") ?: return
                val whitelistServiceUrl: String = call.argument("whitelistServiceUrl") ?: return
                val toAddress: String = call.argument("toAddress") ?: return
                val kinAmount: Int = call.argument("kinAmount") ?: return
                val memo: String? = call.argument("memo")
                val fee: Int = call.argument("fee") ?: return

                val accountNum: Int = getAccountIndexByPublicAddress(publicAddress) ?: return
                sendWhitelistProductionTransaction(accountNum, whitelistServiceUrl, toAddress, kinAmount, memo, fee)
            }

            call.method == Constants.FUND.value -> {
                val publicAddress: String = call.argument("publicAddress") ?: return
                val kinAmount: Int = call.argument("kinAmount") ?: return
                val accountNum: Int = getAccountIndexByPublicAddress(publicAddress) ?: return
                fund(accountNum, kinAmount)
            }
        }
    }

    private fun initKinClient(appId: String? = null) {
        if (appId == null) return
        val network: Environment = if (isProduction) {
            Environment.PRODUCTION
        } else {
            Environment.TEST
        }

        try {
            kinClient = KinClient(context, network, appId)
            isKinInit = true
        } catch (error: Throwable) {
            sendError(Constants.INIT_KIN_CLIENT.value, error)
        }

        receiveAccountsPaymentsAndBalanceChanges()
    }

    private fun createAccount(): String? {
        try {
            val account: KinAccount = kinClient.addAccount()

            if (!isProduction) {
                createAccountOnPlayground(account)
            }

            return account.publicAddress

        } catch (e: CreateAccountException) {
            val err = ErrorReport(Constants.CREATE_ACCOUNT.value, "Account creation exception")
            sendError("-2", "Account creation exception", err)
        }
        return null
    }

    private fun createAccountOnPlayground(account: KinAccount) {
        AccountOnPlayground().onBoard(account, object : AccountOnPlayground.Callbacks {
            override fun onSuccess() {

                val publicAddress = account.publicAddress ?: return
                val accountNum = getAccountIndexByPublicAddress(publicAddress) ?: return

                receiveAccountPayment(accountNum)
                receiveBalanceChanges(accountNum)
                sendReport(Constants.CREATE_ACCOUNT_ON_PLAYGROUND_BLOCKCHAIN.value, "Account in playground was created successfully", account.publicAddress)
            }

            override fun onFailure(e: Exception) {
                sendError(Constants.CREATE_ACCOUNT_ON_PLAYGROUND_BLOCKCHAIN.value, e)
            }
        })
    }

    private fun deleteAccount(accountNum: Int) {
        if (!isAccountCreated()) return
        try {
            kinClient.deleteAccount(accountNum)
            sendReport(Constants.DELETE_ACCOUNT.value, "Account deletion was a success")
        } catch (error: Throwable) {
            sendError(Constants.DELETE_ACCOUNT.value, error)
        }
    }

    private fun importAccount(json: String, secretPassphrase: String): KinAccount? {
        try {
            val account: KinAccount = kinClient.importAccount(json, secretPassphrase)

            val publicAddress = account.publicAddress ?: return null
            val accountNum = getAccountIndexByPublicAddress(publicAddress) ?: return null

            receiveAccountPayment(accountNum)
            receiveBalanceChanges(accountNum)

            return account
        } catch (error: Throwable) {
            sendError(Constants.IMPORT_ACCOUNT.value, error)
        }
        return null
    }

    private fun exportAccount(accountNum: Int, secretPassphrase: String): String? {
        val account = getAccount(accountNum) ?: return null
        try {
            return account.export(secretPassphrase)
        } catch (error: Throwable) {
            sendError(Constants.EXPORT_ACCOUNT.value, error)
        }
        return null
    }

    private fun getAccountBalance(accountNum: Int, completion: (balance: BigDecimal) -> Unit) {
        if (isProduction) return
        val account = getAccount(accountNum) ?: return
        account.balance.run(
                object : ResultCallback<Balance> {
                    override fun onResult(result: Balance) {
                        completion(result.value())
                    }

                    override fun onError(e: Exception) {
                        sendError("-6", Constants.GET_ACCOUNT_BALANCE.value, "Error getting the balance", true)
                    }
                })
    }

    private fun getAccountState(accountNum: Int, completion: (state: String) -> Unit) {
        val account = getAccount(accountNum) ?: return

        account.status.run(
                object : ResultCallback<Int> {
                    override fun onResult(result: Int?) {
                        when (result) {
                            AccountStatus.CREATED -> completion("Account is created")
                            AccountStatus.NOT_CREATED -> completion("Account is not created")
                        }
                    }

                    override fun onError(e: Exception) {
                        sendError("-15", Constants.GET_ACCOUNT_STATE.value, e.localizedMessage)
                    }
                })
    }

    private fun sendTransaction(accountNum: Int, toAddress: String, kinAmount: Int, memo: String?, fee: Int) {
        val account = getAccount(accountNum) ?: return
        val amountInKin = BigDecimal(kinAmount.toString())
        val buildTransactionRequest = account.buildTransaction(toAddress, amountInKin, fee, memo)

        buildTransactionRequest.run(object : ResultCallback<Transaction> {

            override fun onResult(transaction: Transaction) {

                val sendTransactionRequest = account.sendTransaction(transaction)
                sendTransactionRequest.run(object : ResultCallback<TransactionId> {

                    override fun onResult(id: TransactionId) {
                        account.publicAddress?.let { sendReport(Constants.SEND_TRANSACTION.value, it, kinAmount.toString()) }
                    }

                    override fun onError(e: Exception) {
                        sendError(Constants.SEND_TRANSACTION.value, e)
                    }
                })
            }

            override fun onError(e: Exception) {
                sendError(Constants.SEND_TRANSACTION.value, e)
            }
        })
    }

    private fun sendWhitelistProductionTransaction(accountNum: Int, whitelistServiceUrl: String, toAddress: String, kinAmount: Int, memo: String?, fee: Int) {
        val account = getAccount(accountNum) ?: return
        val amountInKin = BigDecimal(kinAmount.toString())
        whitelistService = WhitelistService(whitelistServiceUrl)
        val buildTransactionRequest = account.buildTransaction(toAddress, amountInKin, fee, memo)

        buildTransactionRequest.run(object : ResultCallback<Transaction> {

            override fun onResult(transaction: Transaction) {

                Log.d("Transaction", "onResult: networkPassphrase - " + transaction.whitelistableTransaction.networkPassphrase + ", transactionPayload - " + transaction.whitelistableTransaction.transactionPayload.toString())

                whitelistService.whitelistTransaction(transaction.whitelistableTransaction, object : WhitelistServiceCallbacks {
                    override fun onSuccess(whitelistTransaction: String) {
                        Log.d("Transaction", "whitelistTransaction: $whitelistTransaction")

                        val sendTransactionRequest = account.sendWhitelistTransaction(whitelistTransaction)
                        sendTransactionRequest.run(object : ResultCallback<TransactionId> {
                            override fun onResult(result: TransactionId?) {
                                Log.d("Transaction", "sendTransactionRequest - onResult: ${result?.id()}")

                                account.publicAddress?.let { sendReport(Constants.SEND_WHITELIST_PRODUCTION_TRANSACTION.value, it, kinAmount.toString()) }
                            }

                            override fun onError(e: java.lang.Exception?) {

                                if (e == null) return
                                Log.d("Transaction", "sendTransactionRequest - onError: ${e.message}")

                                sendError(Constants.SEND_WHITELIST_PRODUCTION_TRANSACTION.value, e)
                            }
                        })
                    }

                    override fun onFailure(e: Exception) {
                        sendError(Constants.SEND_WHITELIST_PRODUCTION_TRANSACTION.value, e)
                    }
                })
            }

            override fun onError(e: Exception) {
                sendError(Constants.SEND_TRANSACTION.value, e)
            }
        })
    }

    private fun fund(accountNum: Int, kinAmount: Int) {
        val account = kinClient.getAccount(accountNum)
        AccountOnPlayground().fundOnAccount(account, kinAmount, object : AccountOnPlayground.Callbacks {
            override fun onSuccess() {
                sendReport(Constants.FUND.value, String.format("Fund successful to %s", account.publicAddress), kinAmount.toString())
            }

            override fun onFailure(e: Exception) {
                sendError(Constants.FUND.value, e)
            }
        })
    }

    private fun receiveAccountsPaymentsAndBalanceChanges() {
        if (!isKinClientInit() || kinClient.accountCount == 0) return

        for (index in 0 until kinClient.accountCount) {
            receiveAccountPayment(index)
            receiveBalanceChanges(index)
        }
    }

    private fun receiveAccountPayment(accountNum: Int) {
        val account: KinAccount = getAccount(accountNum) ?: return
        account.addPaymentListener { payment ->
            account.publicAddress?.let { sendReport(Constants.PAYMENT_EVENT.value, it, payment.amount().toPlainString()) }
        }
    }

    private fun receiveBalanceChanges(accountNum: Int) {
        val account: KinAccount = getAccount(accountNum) ?: return
        val publicAddress = account.publicAddress ?: return
        getAccountBalance(accountNum, fun(balance: BigDecimal) {
            sendBalance(publicAddress, balance.toInt())
        })
        account.addBalanceListener { balance ->
            sendBalance(publicAddress, balance.value().toInt())
        }
    }

    private fun isKinClientInit(): Boolean {
        if (!isKinInit) {
            sendError("-14", Constants.INIT_KIN_CLIENT.value, "Kin client not inited")
            return false
        }
        return true
    }

    private fun getAccount(accountNum: Int): KinAccount? {
        if (isAccountCreated(accountNum)) {
            return kinClient.getAccount(accountNum)
        }
        return null
    }

    private fun getAccountIndexByPublicAddress(publicAddress: String): Int? {
        if (kinClient.accountCount == 0) return null
        for (index in 0 until kinClient.accountCount) {
            if (getAccount(index)?.publicAddress == publicAddress) {
                return index
            }
        }
        sendError("-13", Constants.ACCOUNT_STATE_CHECK.value, "Account is not created")
        return null
    }


    private fun isAccountCreated(accountNum: Int = 0): Boolean {
        if (kinClient.accountCount < accountNum) {
            sendError("-13", Constants.ACCOUNT_STATE_CHECK.value, "Account is not created")
            return false
        }
        return true
    }


    private fun sendBalance(publicAddress: String, amount: Int) {
        val balanceReport = BalanceReport(publicAddress, amount)
        var json: String? = null
        try {
            json = Gson().toJson(balanceReport)
        } catch (e: Throwable) {
            sendError(Constants.SEND_BALANCE_JSON.value, e)
        }
        if (json != null) balanceCallback.success(json)
    }

    private fun sendReport(type: String, message: String, value: String? = null) {
        val infoReport: InfoReport = if (value != null)
            InfoReport(type, message, value)
        else
            InfoReport(type, message)
        var json: String? = null
        try {
            json = Gson().toJson(infoReport)
        } catch (e: Throwable) {
            sendError(Constants.SEND_INFO_JSON.value, e)
        }
        if (json != null) infoCallback.success(json)
    }

    private fun sendError(type: String, error: Throwable) {
        val err = ErrorReport(type, error.localizedMessage)
        var message: String? = error.message
        if (message == null) message = ""
        sendError(message, error.localizedMessage, err)
    }

    private fun sendError(code: String, type: String, message: String, isBalance: Boolean = false) {
        val err = ErrorReport(type, message)
        sendError(code, message, err, isBalance)
    }

    private fun sendError(code: String, message: String?, details: ErrorReport, isBalance: Boolean = false) {
        var json: String? = null
        try {
            json = Gson().toJson(details)
        } catch (e: Throwable) {
            sendError(Constants.SEND_ERROR_JSON.value, e)
        }
        if (json != null) {
            if (!isBalance)
                infoCallback.error(code, message, json)
            else
                balanceCallback.error(code, message, json)
        }
    }

    interface WhitelistServiceCallbacks {
        fun onSuccess(whitelistTransaction: String)
        fun onFailure(e: Exception)
    }

    data class BalanceReport(val publicAddress: String, val amount: Int)
    data class InfoReport(val type: String, val message: String, val value: String? = null)
    data class ErrorReport(val type: String, val message: String)

    enum class Constants(val value: String) {
        FLUTTER_KIN_SDK("flutter_kin_sdk"),
        FLUTTER_KIN_SDK_BALANCE("flutter_kin_sdk_balance"),
        FLUTTER_KIN_SDK_INFO("flutter_kin_sdk_info"),
        INIT_KIN_CLIENT("InitKinClient"),
        CREATE_ACCOUNT("CreateAccount"),
        DELETE_ACCOUNT("DeleteAccount"),
        IMPORT_ACCOUNT("ImportAccount"),
        EXPORT_ACCOUNT("ExportAccount"),
        GET_ACCOUNT_BALANCE("GetAccountBalance"),
        GET_ACCOUNT_STATE("GetAccountState"),
        SEND_TRANSACTION("SendTransaction"),
        SEND_WHITELIST_PRODUCTION_TRANSACTION("SendWhitelistProductionTransaction"),
        SEND_WHITELIST_PLAYGROUND_TRANSACTION("SendWhitelistPlaygroundTransaction"),
        FUND("Fund"),
        CREATE_ACCOUNT_ON_PLAYGROUND_BLOCKCHAIN("CreateAccountOnPlaygroundBlockchain"),
        RECEIVE_PRODUCTION_PAYMENTS_AND_BALANCE("ReceiveProductionPaymentsAndBalance"),
        PAYMENT_EVENT("PaymentEvent"),
        ACCOUNT_STATE_CHECK("AccountStateCheck"),
        SEND_INFO_JSON("SendInfoJson"),
        SEND_BALANCE_JSON("SendBalanceJson"),
        SEND_ERROR_JSON("SendErrorJson")
    }
}