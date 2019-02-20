package studio.dipdev.flutter.kinsdk

import android.app.Activity
import android.content.Context
import com.google.gson.Gson
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import kin.core.*
import kin.core.exception.CreateAccountException
import kin.core.AccountStatus
import java.lang.Exception
import kin.core.exception.OperationFailedException
import kin.core.TransactionId
import java.math.BigDecimal


class FlutterKinSdkPlugin(private var activity: Activity, private var context: Context) : MethodCallHandler {

    private lateinit var kinClient: KinClient
    private lateinit var kinAccounts: ArrayList<KinAccount>

    companion object {
        var balanceCallback: EventChannel.EventSink? = null
        var infoCallback: EventChannel.EventSink? = null

        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val channel = MethodChannel(registrar.messenger(), "flutter_kin_sdk")
            val instance = FlutterKinSdkPlugin(registrar.activity(), registrar.activity().applicationContext)
            channel.setMethodCallHandler(instance)

            EventChannel(registrar.view(), "flutter_kin_sdk_balance").setStreamHandler(
                    object : EventChannel.StreamHandler {
                        override fun onListen(args: Any?, events: EventChannel.EventSink) {
                            balanceCallback = events
                        }

                        override fun onCancel(args: Any?) {
                        }
                    }
            )

            EventChannel(registrar.view(), "flutter_kin_sdk_info").setStreamHandler(
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
        when {
            call.method == "kinInit" -> {
                val isTest: Boolean? = call.argument("isTest")
                val accountNum: Int? = call.argument("accountNum")
                kinInit(isTest, accountNum)
            }
            call.method == "getPublicAddress" -> {
                val accountNum: Int? = call.argument("accountNum")
                if (accountNum != null && ifAccountInit(accountNum))
                    kinAccounts[accountNum].publicAddress
            }
            call.method == "kinTransfer" -> {
                var fromAccount: Int? = call.argument("fromAccount")
                val toAccountAddress: String? = call.argument("toAccountAddress")
                val amount: String? = call.argument("amount")
                val memo: String? = call.argument("memo")

                if (toAccountAddress == null || amount == null) return
                if (fromAccount == null)
                    fromAccount = 0
                if (ifAccountInit(fromAccount))
                    transfer(fromAccount, toAccountAddress, amount, memo)
            }
            call.method == "kinTransferToYourself" -> {
                val fromAccount: Int? = call.argument("fromAccount")
                val toAccount: Int? = call.argument("toAccount")
                val amount: String? = call.argument("amount")
                val memo: String? = call.argument("memo")

                if (fromAccount == null || toAccount == null || amount == null) return
                if (ifAccountInit(fromAccount) && ifAccountInit(toAccount)) {
                    val toAccountAddress: String? = kinAccounts[toAccount].publicAddress
                    if ((toAccountAddress) != null)
                        transfer(fromAccount, toAccountAddress, amount, memo)
                    else
                        sendException("-7", "kinTransferToYourself", "Public address of the receiver was not found", null)
                }
            }
            call.method == "accountStateCheck" -> {
                val accountNum: Int? = call.argument("accountNum")
                if (accountNum != null) accountStateCheck(accountNum)
            }
            else -> result.notImplemented()
        }
    }

    private fun kinInit(isTest: Boolean? = null, num: Int? = null) {
        var networkId = ServiceProvider.NETWORK_ID_MAIN
        if (isTest == true) networkId = ServiceProvider.NETWORK_ID_TEST

        val horizonProvider = ServiceProvider("https://horizon.stellar.org", networkId)
        kinClient = KinClient(context, horizonProvider)
        receiveAccountsPayments()

        if (num != null && !isAccountCreated(num)) {
            ifAccountInit(num)
        } else if (num == null && !kinClient.hasAccount()) {
            initAccount()
        }
    }

    // create and activate
    private fun initAccount() {
        try {
            val account = kinClient.addAccount()
            kinAccounts.add(account)
            activateAccount(kinAccounts.lastIndex)
        } catch (e: CreateAccountException) {
            sendException("-6", "addAccount", "Account adding exception", e)
        }
    }

    private fun activateAccount(accountNum: Int) {
        val activationRequest: Request<Void> = kinAccounts[accountNum].activate()
        activationRequest.run(
                object : ResultCallback<Void> {
                    override fun onResult(result: Void?) {
                        sendReport("initAccount", "Successful activating an account")
                        receiveAccountPayment(accountNum)
                    }

                    override fun onError(e: java.lang.Exception?) {
                        sendException("-5", "accountActivation", "Account activation exception", e)
                    }
                }
        )
    }

    private fun receiveAccountsPayments() {
        for ((accountNum) in kinAccounts.withIndex()) {
            if (ifAccountInit(accountNum))
                receiveAccountPayment(accountNum)
        }
    }

    //TODO Send more detailed info which depends on accounts public addresses
    private fun receiveAccountPayment(accountNum: Int) {
        kinAccounts[accountNum].blockchainEvents()
                .addPaymentListener { payment ->
                    sendReport("paymentEvent", String
                            .format("to = %s, from = %s", payment.sourcePublicKey(),
                                    payment.destinationPublicKey(), payment.amount().toPlainString()), payment.amount().longValueExact())
                }
    }

    //TODO Send more detailed info with individual fields
    private fun transfer(fromAccount: Int, toAccountAddress: String, amount: String, memo: String?) {
        var transactionRequest = kinAccounts[fromAccount].sendTransaction(toAccountAddress, BigDecimal(amount), memo)
        if (memo == null) transactionRequest = kinAccounts[fromAccount].sendTransaction(toAccountAddress, BigDecimal(amount))
        transactionRequest.run(object : ResultCallback<TransactionId> {

            override fun onResult(result: TransactionId) {
                balanceChanged(fromAccount)
                sendReport("transfer", "Successful transferring $amount Kin to $toAccountAddress")
            }

            override fun onError(e: Exception) {
                sendException("-6", "transfer", "Transfer to account exception", e)
            }
        })
    }

    private fun accountStateCheck(accountNum: Int) {
        val statusRequest = kinAccounts[accountNum].status
        statusRequest.run(
                object : ResultCallback<Int> {
                    override fun onResult(result: Int?) {
                        when (result) {
                            AccountStatus.ACTIVATED -> {
                                sendReport("accountStateCheck", "Account is created and activated")
                            }
                            AccountStatus.NOT_ACTIVATED -> {
                                sendReport("accountStateCheck", "Account is not activated")
                            }
                            AccountStatus.NOT_CREATED -> {
                                sendReport("accountStateCheck", "Account is not created")
                            }
                        }
                    }

                    override fun onError(e: java.lang.Exception?) {
                        sendException("-4", "accountStateCheck", "Account state check exception", e)
                    }
                })
    }

    private fun balanceChanged(accountNum: Int) {
        val balanceRequest = kinAccounts[accountNum].balance
        balanceRequest.run(object : ResultCallback<Balance> {
            override fun onResult(result: Balance?) {
                if (result != null) {
                    sendBalance(accountNum, result.value().longValueExact())
                }
            }

            override fun onError(e: Exception?) {
                sendException("-3", "balanceChange", "Balance change exception", e)
            }
        })
    }

    private fun sendBalance(accountNum: Int, amount: Long) {
        val balanceReport = BalanceReport(accountNum, amount)
        var json: String? = null
        try {
            json = Gson().toJson(balanceReport)
        } catch (e: Throwable) {
            sendError("json", e)
        }
        if (json != null) balanceCallback.success(json)
    }

    private fun sendReport(type: String, message: String, amount: Long? = null) {
        val infoReport: InfoReport = if (amount != null)
            InfoReport(type, message, amount)
        else
            InfoReport(type, message)
        var json: String? = null
        try {
            json = Gson().toJson(infoReport)
        } catch (e: Throwable) {
            sendError("json", e)
        }
        if (json != null) infoCallback.success(json)
    }

    private fun sendError(type: String, error: Throwable) {
        val err = ErrorReport(type, error.localizedMessage)
        var message: String? = error.message
        if (message == null) message = ""
        sendError(message, error.localizedMessage, err)
    }

    private fun sendError(code: String, message: String?, details: ErrorReport) {
        var json: String? = null
        try {
            json = Gson().toJson(details)
        } catch (e: Throwable) {
            sendError("json", e)
        }
        if (json != null) infoCallback.error(code, message, json)
    }

    private fun sendException(code: String, type: String, message: String, error: Throwable?) {
        var stringException = message
        if (error != null) stringException = error.message!!
        val err = ErrorReport(type, stringException)
        sendError(code, stringException, err)
    }

    private fun ifAccountInit(accountNum: Int): Boolean {
        if (!isAccountCreated()) {
            val err = ErrorReport("accountStateCheck", "Account is not activated")
            sendError("-1", "Account is not activated", err)
            return false
        } else {
            try {
                val state = kinAccounts[accountNum].statusSync
                if (state == AccountStatus.NOT_ACTIVATED) {
                    val err = ErrorReport("accountStateCheck", "Account is not activated")
                    sendError("-2", "Account is not activated", err)
                    return false
                }
            } catch (e: OperationFailedException) {
                sendError("accountStateCheck", e)
                return false
            }
        }
        return true
    }

    private fun isAccountCreated(num: Int = 0): Boolean {
        return kinClient.accountCount > num
    }

    data class BalanceReport(val accountNum: Int, val amount: Long)
    data class InfoReport(val type: String, val message: String, val amount: Long? = null)
    data class ErrorReport(val type: String, val message: String)
}