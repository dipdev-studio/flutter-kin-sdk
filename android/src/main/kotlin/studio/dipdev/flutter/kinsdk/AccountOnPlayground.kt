package studio.dipdev.flutter.kinsdk

import android.os.Handler
import android.os.Looper
import android.text.format.DateUtils

import java.io.IOException
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import kin.sdk.KinAccount
import kin.sdk.ListenerRegistration
import okhttp3.Call
import okhttp3.Callback
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response

internal class AccountOnPlayground {

    private val handler: Handler = Handler(Looper.getMainLooper())
    private var listenerRegistration: ListenerRegistration? = null
    private val okHttpClient: OkHttpClient = OkHttpClient.Builder()
            .connectTimeout(20, TimeUnit.SECONDS)
            .readTimeout(20, TimeUnit.SECONDS)
            .build()

    companion object {
        private const val FUND_KIN_AMOUNT = 100
        private const val URL_CREATE_ACCOUNT = "https://friendbot-testnet.kininfrastructure.com?addr=%s&amount=$FUND_KIN_AMOUNT"
        private const val URL_FUND_ON_ACCOUNT = "https://friendbot-testnet.kininfrastructure.com/fund?addr=%s&amount=%s"
    }

    fun onBoard(account: KinAccount, callbacks: Callbacks) {
        listenerRegistration = account.addAccountCreationListener { data ->
            listenerRegistration!!.remove()
            fireOnSuccess(callbacks)
        }
        createAccount(account, callbacks)
    }

    private fun createAccount(account: KinAccount, callbacks: Callbacks) {
        val request = Request.Builder()
                .url(String.format(URL_CREATE_ACCOUNT, account.publicAddress))
                .get()
                .build()
        okHttpClient.newCall(request)
                .enqueue(object : Callback {
                    override fun onFailure(call: Call, e: IOException) {
                        fireOnFailure(callbacks, e)
                    }

                    override fun onResponse(call: Call, response: Response) {
                        val code = response.code()
                        response.close()
                        if (code != 200) {
                            fireOnFailure(callbacks, Exception("Create account - response code is " + response.code()))
                        }
                    }
                })
    }

    fun fundOnAccount(account: KinAccount, kinAmount: Int, callbacks: Callbacks) {
        val request = Request.Builder()
                .url(String.format(URL_FUND_ON_ACCOUNT, account.publicAddress, kinAmount.toString()))
                .get()
                .build()
        okHttpClient.newCall(request)
                .enqueue(object : Callback {
                    override fun onFailure(call: Call, e: IOException) {
                        fireOnFailure(callbacks, e)
                    }

                    override fun onResponse(call: Call, response: Response) {
                        val code = response.code()
                        response.close()
                        if (code != 200) {
                            fireOnFailure(callbacks, Exception("Fund on account - response code is " + response.code()))
                        } else {
                            fireOnSuccess(callbacks)
                        }
                    }
                })
    }

    private fun fireOnFailure(callbacks: Callbacks, ex: Exception) {
        handler.post { callbacks.onFailure(ex) }
    }

    private fun fireOnSuccess(callbacks: Callbacks) {
        handler.post { callbacks.onSuccess() }
    }

    interface Callbacks {
        fun onSuccess()
        fun onFailure(e: Exception)
    }
}