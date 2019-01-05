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
import android.app.Activity
import android.util.Log

class FlutterKinSdkPlugin(private var activity: Activity, private var context: Context) : MethodCallHandler {

    var kinInit = false

    private var balanceObserver = object : Observer<Balance>() {
        override fun onChanged(p0: Balance?) {
            if (p0 != null) {
                balanceCallback.success(p0.amount.longValueExact())
            }
        }
    }

    companion object {
        lateinit var balanceCallback: EventChannel.EventSink

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
            call.method == "getWallet" -> Kin.getPublicAddress()
            call.method == "kinEarn" -> {
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
                    println("🔥 onFailute " + p0.toString())
                }

                override fun onResponse(p0: OrderConfirmation?) {
                    println("🔥 onResponse" + p0.toString())
                }
            })
        } catch (e: Throwable) {
        }
    }

    private fun kinSpend(jwt: String) {
        try {
            Kin.purchase(jwt, object : KinCallback<OrderConfirmation> {
                override fun onFailure(p0: KinEcosystemException?) {
                    println("🔥 onFailute " + p0.toString())
                }

                override fun onResponse(p0: OrderConfirmation?) {
                    println("🔥 onResponse" + p0.toString())
                }
            })
        } catch (e: Throwable) {

        }
    }


    private fun kinPayToUser(jwt: String) {
        try {
            Kin.payToUser(jwt, object : KinCallback<OrderConfirmation> {
                override fun onFailure(p0: KinEcosystemException?) {
                    println("🔥 onFailute " + p0.toString())
                }

                override fun onResponse(p0: OrderConfirmation?) {
                    println("🔥 onResponse" + p0.toString())
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
                }

                override fun onResponse(p0: OrderConfirmation?) {
                }
            })
        } catch (e: Throwable) {

        }
    }
}
