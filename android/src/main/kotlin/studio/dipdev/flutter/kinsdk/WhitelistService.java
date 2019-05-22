/*
package studio.dipdev.flutter.kinsdk;

import android.os.Handler;
import android.os.Looper;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.util.concurrent.TimeUnit;

import kin.sdk.WhitelistableTransaction;
import okhttp3.Call;
import okhttp3.Callback;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;

public class WhitelistService {

    private String URL_WHITELISTING_SERVICE;
    private static final MediaType JSON = MediaType.parse("application/json; charset=utf-8");

    private final OkHttpClient okHttpClient;
    private final Handler handler;

    WhitelistService(String URL_WHITELISTING_SERVICE) {
        this.URL_WHITELISTING_SERVICE = URL_WHITELISTING_SERVICE;
        handler = new Handler(Looper.getMainLooper());
        okHttpClient = new OkHttpClient.Builder()
                .connectTimeout(20, TimeUnit.SECONDS)
                .readTimeout(20, TimeUnit.SECONDS)
                .build();
    }

    void whitelistTransaction(WhitelistableTransaction whitelistableTransaction,
                              final FlutterKinSdkPlugin.WhitelistServiceCallbacks whitelistServiceListener) throws JSONException {
        RequestBody requestBody = RequestBody.create(JSON, toJson(whitelistableTransaction));
        Request request = new Request.Builder()
                .url(URL_WHITELISTING_SERVICE)
                .post(requestBody)
                .build();
        okHttpClient.newCall(request)
                .enqueue(new Callback() {
                    @Override
                    public void onFailure(Call call, IOException e) {
                        if (whitelistServiceListener != null) {
                            onFailure(whitelistServiceListener, e);
                        }
                    }

                    @Override
                    public void onResponse(Call call, Response response) throws IOException {
                        handleResponse(response, whitelistServiceListener);
                    }
                });
    }

    private void handleResponse(Response response, FlutterKinSdkPlugin.WhitelistServiceCallbacks whitelistServiceListener) throws IOException {
        if (whitelistServiceListener != null) {
            if (response.body() != null) {
                fireOnSuccess(whitelistServiceListener, response.body().string());
            } else {
                fireOnFailure(whitelistServiceListener, new Exception("Whitelist - no body, response code is " + response.code()));
            }
        }
        int code = response.code();
        response.close();
        if (code != 200) {
            fireOnFailure(whitelistServiceListener, new Exception("Whitelist - response code is " + response.code()));
        }
    }

    private String toJson(WhitelistableTransaction whitelistableTransaction) throws JSONException {
        JSONObject jo = new JSONObject();
        jo.put("envelope", whitelistableTransaction.getTransactionPayload());
        jo.put("network_id", whitelistableTransaction.getNetworkPassphrase());
        return jo.toString();
    }


    private void fireOnFailure(FlutterKinSdkPlugin.WhitelistServiceCallbacks whitelistServiceListener, Exception e) {
        handler.post(() -> whitelistServiceListener.onFailure(e));
    }

    private void fireOnSuccess(FlutterKinSdkPlugin.WhitelistServiceCallbacks whitelistServiceListener, String response) {
        handler.post(() -> whitelistServiceListener.onSuccess(response));
    }

}
*/
