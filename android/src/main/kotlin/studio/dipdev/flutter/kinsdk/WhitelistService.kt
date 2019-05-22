package studio.dipdev.flutter.kinsdk

import android.os.Handler
import android.os.Looper
import android.util.Log

import org.json.JSONException
import org.json.JSONObject

import java.io.IOException
import java.util.concurrent.TimeUnit

import kin.sdk.WhitelistableTransaction
import okhttp3.Call
import okhttp3.Callback
import okhttp3.MediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.Response

internal class WhitelistService(private val URL_WHITELISTING_SERVICE:String) {

    private val okHttpClient: OkHttpClient = OkHttpClient.Builder()
            .connectTimeout(20, TimeUnit.SECONDS)
            .readTimeout(20, TimeUnit.SECONDS)
            .build()
    private val handler: Handler = Handler(Looper.getMainLooper())

    @Throws(JSONException::class)
    fun whitelistTransaction(whitelistableTransaction: WhitelistableTransaction,
                             whitelistServiceListener:FlutterKinSdkPlugin.WhitelistServiceCallbacks) {
        val json = toJson(whitelistableTransaction)

        Log.d("Transaction", "whitelistTransaction - json: $json")
        val requestBody = RequestBody.create(JSON, json)
        val request = Request.Builder()
                .url(URL_WHITELISTING_SERVICE)
                .post(requestBody)
                .build()
        okHttpClient.newCall(request)
                .enqueue(object : Callback {
                    override fun onFailure(call: Call, e: IOException) {
                        Log.d("Transaction", "whitelistTransaction - onFailure: ${e.message}")
                        fireOnFailure(whitelistServiceListener, e)
                    }

                    @Throws(IOException::class)
                    override fun onResponse(call: Call, response: Response) {
                        Log.d("Transaction", "whitelistTransaction - onResult: ${response.body().toString()}")
                        handleResponse(response, whitelistServiceListener)
                    }
                })
    }

    @Throws(IOException::class)
    private fun handleResponse(response: Response, whitelistServiceListener:FlutterKinSdkPlugin.WhitelistServiceCallbacks?) {
        if (whitelistServiceListener != null) {
            if (response.body() != null) {
                fireOnSuccess(whitelistServiceListener, response.body()!!.string())
            } else {
                fireOnFailure(whitelistServiceListener, Exception("Whitelist - no body, response code is " + response.code()))
            }
        }
        val code = response.code()
        response.close()
        if (code != 200) {
            fireOnFailure(whitelistServiceListener, Exception("Whitelist - response code is " + response.code()))
        }
    }

    @Throws(JSONException::class)
    private fun toJson(whitelistableTransaction: WhitelistableTransaction): String {
        val jo = JSONObject()
        jo.put("envelope", whitelistableTransaction.transactionPayload)
        jo.put("network_id", whitelistableTransaction.networkPassphrase)
        return jo.toString()
    }


    private fun fireOnFailure(whitelistServiceListener:FlutterKinSdkPlugin.WhitelistServiceCallbacks?, e: Exception) {
        handler.post { whitelistServiceListener!!.onFailure(e) }
    }

    private fun fireOnSuccess(whitelistServiceListener:FlutterKinSdkPlugin.WhitelistServiceCallbacks, response: String) {
        handler.post { whitelistServiceListener.onSuccess(response) }
    }

    companion object {
        private val JSON = MediaType.parse("application/json; charset=utf-8")
    }
}
