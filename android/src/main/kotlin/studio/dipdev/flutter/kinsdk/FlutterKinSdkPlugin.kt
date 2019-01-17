package studio.dipdev.flutter.kinsdk

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.EventChannel
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
import com.google.gson.*
import android.app.Activity
import android.util.Log

class FlutterKinSdkPlugin(private var activity: Activity, private var context: Context) : MethodCallHandler {

    var kinInit = false

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
                val token: String? = call.argument("token")
                if (token == null) return
                Kin.start(context, token, Environment.getProduction())
                kinInit = true
                Kin.addBalanceObserver(balanceObserver)
            }
            call.method == "launchKinMarket" -> Kin.launchMarketplace(activity)
            call.method == "getWallet" -> result.success(Kin.getPublicAddress())
            call.method == "kinEarn" -> {
                println("kinEarn start")
                val jwt: String? = call.argument("jwt")
                kinEarn(jwt!!)
            }
            call.method == "kinSpend" -> {
                val jwt: String? = call.argument("jwt")
                kinSpend(jwt!!)
            }
            call.method == "kinPayToUser" -> {
                println("🔥 in kotlin file")
                val jwt: String? = call.argument("jwt")
                kinPayToUser(jwt!!)
            }
            call.method == "orderConfirmation" -> {
                val offerId: String? = call.argument("offerId")
                orderConfirmation(offerId!!)
            }
            else -> result.notImplemented()
        }
    }

    private fun kinEarn(jwt: String) {
        try {
            Kin.requestPayment(jwt, object : KinCallback<OrderConfirmation> {
                override fun onFailure(p0: KinEcosystemException?) {
                    sendReport("kinEarn", false, p0.toString())
                }

                override fun onResponse(p0: OrderConfirmation?) {
                    sendReport("kinEarn", true, p0.toString())
                }
            })
        } catch (e: Throwable) {
        }
    }

    private fun kinSpend(jwt: String) {
        try {
            Kin.purchase(jwt, object : KinCallback<OrderConfirmation> {
                override fun onFailure(p0: KinEcosystemException?) {
                    sendReport("kinSpend", false, p0.toString())
                }

                override fun onResponse(p0: OrderConfirmation?) {
                    sendReport("kinSpend", true, p0.toString())
                }
            })
        } catch (e: Throwable) {

        }
    }


    private fun kinPayToUser(jwt: String) {
        try {
            Kin.payToUser(jwt, object : KinCallback<OrderConfirmation> {
                override fun onFailure(p0: KinEcosystemException?) {
                    sendReport("kinPayToUser", false, p0.toString())
                }

                override fun onResponse(p0: OrderConfirmation?) {
                    sendReport("kinPayToUser", true, p0.toString())
                }
            })
        } catch (e: Throwable) {
            println("🔥" + e.toString())
        }

    }

    fun orderConfirmation(offerId: String) {
        try {
            Kin.getOrderConfirmation(offerId, object : KinCallback<OrderConfirmation> {
                override fun onFailure(p0: KinEcosystemException?) {
                    sendReport("orderConfirmation", false, p0.toString())
                }

                override fun onResponse(p0: OrderConfirmation?) {
                    sendReport("orderConfirmation", true, p0.toString())
                }
            })
        } catch (e: Throwable) {

        }
    }

    fun sendReport(type: String, status: Boolean, message: String) {
        println("sendReport")
        val info: Info = Info(type, status, message)
        val gson = Gson()
        val jsonInfo = gson.toJson(info)
        infoCallback?.success(jsonInfo.toString())
    }

    data class Info(val type: String, val status: Boolean, val message: String)
}
