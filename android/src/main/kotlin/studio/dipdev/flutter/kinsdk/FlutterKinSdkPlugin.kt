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
import kin.devplatform.Environment
import kin.devplatform.Kin
import kin.devplatform.KinCallback
import kin.devplatform.base.Observer
import kin.devplatform.data.model.Balance
import kin.devplatform.data.model.OrderConfirmation
import kin.devplatform.exception.KinEcosystemException

class FlutterKinSdkPlugin(private var activity: Activity, private var context: Context) : MethodCallHandler {

    var isKinInit = false

    private var balanceObserver = object : Observer<Balance>() {
        override fun onChanged(p0: Balance?) {
            if (p0 != null) {
                balanceCallback?.success(p0.amount.longValueExact())
            }
        }
    }

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
            call.method == "kinStart" -> {
                val token: String = call.argument("token") ?: return
                Kin.start(context, token, Environment.getProduction(), object : KinCallback<Void> {
                    override fun onFailure(error: KinEcosystemException?) {
                        isKinInit = false
                        sendError("kinStart", error)
                    }

                    override fun onResponse(response: Void?) {
                        isKinInit = true
                        sendReport("kinStart", true, "Kin started")                       
                    }
                })
            }
            call.method == "initBalanceObserver" -> if (ifKinInit()) Kin.addBalanceObserver(balanceObserver)
            call.method == "launchKinMarket" -> if (ifKinInit()) Kin.launchMarketplace(activity)
            call.method == "getWallet" -> if (ifKinInit()) result.success(Kin.getPublicAddress())
            call.method == "kinEarn" -> {
                if (!ifKinInit()) return
                val jwt: String? = call.argument("jwt")
                if (jwt != null) kinEarn(jwt)
            }
            call.method == "kinSpend" -> {
                val jwt: String? = call.argument("jwt")
                if (jwt != null) kinSpend(jwt)
            }
            call.method == "kinPayToUser" -> {
                val jwt: String? = call.argument("jwt")
                if (jwt != null) kinPayToUser(jwt)
            }
            call.method == "orderConfirmation" -> {
                val offerId: String? = call.argument("offerId")
                if (offerId != null) orderConfirmation(offerId)
            }
            else -> result.notImplemented()
        }
    }

    private fun kinEarn(jwt: String) {
        try {
            Kin.requestPayment(jwt, object : KinCallback<OrderConfirmation> {
                override fun onFailure(p0: KinEcosystemException?) {
                    //sendReport("kinEarn", false, p0.toString())
                    sendError("kinEarn", p0)
                }

                override fun onResponse(p0: OrderConfirmation?) {
                    sendReport("kinEarn", true, p0.toString())
                }
            })
        } catch (e: Throwable) {
            sendError("kinEarn", e)
        }
    }

    private fun kinSpend(jwt: String) {
        try {
            Kin.purchase(jwt, object : KinCallback<OrderConfirmation> {
                override fun onFailure(p0: KinEcosystemException?) {
                    //sendReport("kinSpend", false, p0.toString())
                    sendError("kinSpend", p0)
                }

                override fun onResponse(p0: OrderConfirmation?) {
                    sendReport("kinSpend", true, p0.toString())
                }
            })
        } catch (e: Throwable) {
            sendError("kinSpend", e)
        }
    }

    private fun kinPayToUser(jwt: String) {
        try {
            Kin.payToUser(jwt, object : KinCallback<OrderConfirmation> {
                override fun onFailure(p0: KinEcosystemException?) {
                    //sendReport("kinPayToUser", false, p0.toString())
                    sendError("kinPayToUser", p0)
                }

                override fun onResponse(p0: OrderConfirmation?) {
                    sendReport("kinPayToUser", true, p0.toString())
                }
            })
        } catch (e: Throwable) {
            sendError("kinPayToUser", e)
        }

    }

    private fun orderConfirmation(offerId: String) {
        try {
            Kin.getOrderConfirmation(offerId, object : KinCallback<OrderConfirmation> {
                override fun onFailure(p0: KinEcosystemException?) {
                    //sendReport("orderConfirmation", false, p0.toString())
                    sendError("orderConfirmation", p0)
                }

                override fun onResponse(p0: OrderConfirmation?) {
                    sendReport("orderConfirmation", true, p0.toString())
                }
            })
        } catch (e: Exception) {
            sendError("orderConfirmation", e)
        }
    }

    private fun sendReport(type: String, status: Boolean, message: String) {
        val info = Info(type, status, message)
        var jsonInfo: String? = null
        try {
            jsonInfo = Gson().toJson(info)
        } catch (e: Throwable) {
            sendError("json", e)
        }
        if (jsonInfo != null) infoCallback?.success(jsonInfo)
    }

    private fun sendError(type: String, error: Throwable) {
        val err = Error(type, error.localizedMessage)
        var message: String? = error.message
        if (message == null) message = ""
        sendError(message, error.localizedMessage, err)
    }

    private fun sendError(type: String, error: KinEcosystemException?) {
        if (error == null) return
        val err = Error(type, error.localizedMessage)
        sendError(error.code.toString(), error.localizedMessage, err)
    }

    private fun sendError(code: String, message: String?, details: Error) {
        infoCallback?.error(code, message, details)
    }

    private fun ifKinInit(): Boolean {
        val err = Error("kinStart", "Kin SDK not started")
        sendError("0", "Kin SDK not started", err)
        return isKinInit
    }

    data class Info(val type: String, val status: Boolean, val message: String)
    data class Error(val type: String, val message: String)
}
