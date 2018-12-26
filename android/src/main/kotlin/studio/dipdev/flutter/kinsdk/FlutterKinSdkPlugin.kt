package studio.dipdev.flutter.kinsdk

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import kin.devplatform.Environment
import kin.devplatform.Kin
import android.app.Activity



class FlutterKinSdkPlugin(private var activity: Activity, private var context: Context) : MethodCallHandler  {
    companion object {
        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val channel = MethodChannel(registrar.messenger(), "flutter_kin_sdk")
            channel.setMethodCallHandler(FlutterKinSdkPlugin(registrar.activity(), registrar.context()))
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when {
            call.method == "kinStart" -> {
                val token : String? = call.argument("token")
                Kin.start(context, token!!, Environment.getProduction())
            }
            call.method == "launchKinMarket" -> Kin.launchMarketplace(activity)
            else -> result.notImplemented()
        }
    }
}
