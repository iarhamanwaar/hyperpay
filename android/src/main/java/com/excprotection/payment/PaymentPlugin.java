package com.excprotection.payment;

import android.app.Activity;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.widget.Toast;

import androidx.annotation.NonNull;

import com.oppwa.mobile.connect.checkout.dialog.CheckoutActivity;
import com.oppwa.mobile.connect.checkout.meta.CheckoutSettings;
import com.oppwa.mobile.connect.checkout.meta.CheckoutStorePaymentDetailsMode;
import com.oppwa.mobile.connect.exception.PaymentError;
import com.oppwa.mobile.connect.exception.PaymentException;
import com.oppwa.mobile.connect.payment.BrandsValidation;
import com.oppwa.mobile.connect.payment.ImagesRequest;
import com.oppwa.mobile.connect.payment.PaymentParams;
import com.oppwa.mobile.connect.payment.card.CardPaymentParams;
import com.oppwa.mobile.connect.payment.stcpay.STCPayPaymentParams;
import com.oppwa.mobile.connect.payment.stcpay.STCPayVerificationOption;
import com.oppwa.mobile.connect.payment.token.TokenPaymentParams;
import com.oppwa.mobile.connect.provider.Connect;
import com.oppwa.mobile.connect.provider.ITransactionListener;
import com.oppwa.mobile.connect.provider.OppPaymentProvider;
import com.oppwa.mobile.connect.provider.Transaction;
import com.oppwa.mobile.connect.provider.TransactionType;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class PaymentPlugin implements
        ActivityAware, ITransactionListener,
        FlutterPlugin, MethodChannel.MethodCallHandler {

  private MethodChannel.Result result;
  private String mode = "";
  private List<String> brandsReadyUi;
  private String brands = "";
  private String lang = "";
  private String enabledTokenization = "";
  private String shopperResultUrl = "";
  private String setStorePaymentDetailsMode = "";
  private String number, holder, cvv, year, month;
  private String tokenID = "";
  private OppPaymentProvider paymentProvider = null;
  private Activity activity;
  private Context context;
  private String transactionState;

  private final Handler handler = new Handler(Looper.getMainLooper());

  private MethodChannel channel;
  String CHANNEL = "Hyperpay.demo.flutter/channel";

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), CHANNEL);
    channel.setMethodCallHandler(this);
    context = flutterPluginBinding.getApplicationContext();
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    this.result = result;

    if (call.method.equals("gethyperpayresponse")) {

      String checkoutId = call.argument("checkoutid");
      String type = call.argument("type");
      mode = call.argument("mode");
      lang = call.argument("lang");
      shopperResultUrl = call.argument("ShopperResultUrl");

      switch (type != null ? type : "NullType") {
        case "ReadyUI":
          brandsReadyUi = call.argument("brand");
          setStorePaymentDetailsMode = call.argument("setStorePaymentDetailsMode");
          openCheckoutUI(checkoutId);
          break;
        case "StoredCards":
          cvv = call.argument("cvv");
          tokenID = call.argument("TokenID");
          storedCardPayment(checkoutId);
          break;

        case "CustomUI":
          brands = call.argument("brand");
          number = call.argument("card_number");
          holder = call.argument("holder_name");
          year = call.argument("year");
          month = call.argument("month");
          cvv = call.argument("cvv");
          enabledTokenization = call.argument("EnabledTokenization");
          openCustomUI(checkoutId);
          break;

        case "CustomUISTC":
          number = call.argument("phone_number");
          openCustomUISTC(checkoutId);
          break;

        default:
          error("1", "THIS TYPE NOT IMPLEMENTED: " + type, "");
      }

    } else {
      notImplemented();
    }
  }

  private void openCheckoutUI(String checkoutId) {
    Set<String> paymentBrands = new LinkedHashSet<>(brandsReadyUi);

    CheckoutSettings checkoutSettings;
    if (mode.equals("live")) {
      checkoutSettings = new CheckoutSettings(checkoutId, paymentBrands, Connect.ProviderMode.LIVE);
    } else {
      checkoutSettings = new CheckoutSettings(checkoutId, paymentBrands, Connect.ProviderMode.TEST);
    }

    checkoutSettings.setLocale(lang);

    if (setStorePaymentDetailsMode.equals("true")) {
      checkoutSettings.setStorePaymentDetailsMode(CheckoutStorePaymentDetailsMode.PROMPT);
    }

    Intent intent = new Intent(activity, CheckoutActivity.class);
    intent.putExtra(CheckoutActivity.CHECKOUT_SETTINGS, checkoutSettings);
    activity.startActivityForResult(intent, 100);  // 100 is an arbitrary request code
  }

  private void storedCardPayment(String checkoutId) {
    try {
      TokenPaymentParams paymentParams = new TokenPaymentParams(checkoutId, tokenID, brands, cvv);
      Transaction transaction = new Transaction(paymentParams);

      paymentProvider = new OppPaymentProvider(activity.getBaseContext(), getProviderMode());
      paymentProvider.submitTransaction(transaction, this);

    } catch (PaymentException e) {
      e.printStackTrace();
    }
  }

  private void openCustomUI(String checkoutId) {
    Toast.makeText(activity.getApplicationContext(), lang.equals("en_US") ? "Please Wait..." : "برجاء الانتظار...", Toast.LENGTH_SHORT).show();

    if (!CardPaymentParams.isNumberValid(number, true)) {
      Toast.makeText(activity.getApplicationContext(), lang.equals("en_US") ? "Card number is not valid" : "رقم البطاقة غير صالح", Toast.LENGTH_SHORT).show();
    } else if (!CardPaymentParams.isHolderValid(holder)) {
      Toast.makeText(activity.getApplicationContext(), lang.equals("en_US") ? "Holder name is not valid" : "اسم المالك غير صالح", Toast.LENGTH_SHORT).show();
    } else if (!CardPaymentParams.isExpiryYearValid(year)) {
      Toast.makeText(activity.getApplicationContext(), lang.equals("en_US") ? "Expiry year is not valid" : "سنة انتهاء الصلاحية غير صالحة", Toast.LENGTH_SHORT).show();
    } else if (!CardPaymentParams.isExpiryMonthValid(month)) {
      Toast.makeText(activity.getApplicationContext(), lang.equals("en_US") ? "Expiry month is not valid" : "شهر انتهاء الصلاحية غير صالح", Toast.LENGTH_SHORT).show();
    } else if (!CardPaymentParams.isCvvValid(cvv)) {
      Toast.makeText(activity.getApplicationContext(), lang.equals("en_US") ? "CVV is not valid" : "CVV غير صالح", Toast.LENGTH_SHORT).show();
    } else {
      boolean isTokenizationEnabled = enabledTokenization.equals("true");
      try {
        PaymentParams paymentParams = new CardPaymentParams(checkoutId, brands, number, holder, month, year, cvv)
                .setTokenizationEnabled(isTokenizationEnabled);

        Transaction transaction = new Transaction(paymentParams);

        paymentProvider = new OppPaymentProvider(activity.getBaseContext(), getProviderMode());
        paymentProvider.submitTransaction(transaction, this);

      } catch (PaymentException e) {
        error("0.1", e.getLocalizedMessage(), "");
      }
    }
  }

  private void openCustomUISTC(String checkoutId) {
    Toast.makeText(activity.getApplicationContext(), lang.equals("en_US") ? "Please Wait..." : "برجاء الانتظار...", Toast.LENGTH_SHORT).show();
    try {
      STCPayPaymentParams stcPayPaymentParams = new STCPayPaymentParams(checkoutId, STCPayVerificationOption.MOBILE_PHONE);
      stcPayPaymentParams.setMobilePhoneNumber(number);

      Transaction transaction = new Transaction(stcPayPaymentParams);

      paymentProvider = new OppPaymentProvider(activity.getBaseContext(), getProviderMode());
      paymentProvider.submitTransaction(transaction, this);

    } catch (PaymentException e) {
      e.printStackTrace();
    }
  }

  private Connect.ProviderMode getProviderMode() {
    return mode.equals("test") ? Connect.ProviderMode.TEST : Connect.ProviderMode.LIVE;
  }

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    activity = binding.getActivity();
    binding.addActivityResultListener((requestCode, resultCode, data) -> {
      if (requestCode == 100) {  // 100 is the arbitrary request code we used
        if (resultCode == Activity.RESULT_OK) {
          Transaction transaction = data.getParcelableExtra(CheckoutActivity.CHECKOUT_RESULT_TRANSACTION);
          if (transaction != null && transaction.getTransactionType() == TransactionType.SYNC) {
            transactionState = "COMPLETED";
            success("SYNC");
          } else {
            // Asynchronous payment; set state to PENDING and handle in onNewIntent
            transactionState = "PENDING";
          }
        } else if (resultCode == Activity.RESULT_CANCELED) {
          transactionState = "ABORTED";
          error("2", "Canceled", "");
        } else if (resultCode == CheckoutActivity.RESULT_ERROR) {
          PaymentError error = data.getParcelableExtra(CheckoutActivity.CHECKOUT_RESULT_ERROR);
          if (error != null) {
            transactionState = "ERROR";
            error("3", "Checkout Result Error: " + error.getErrorMessage(), "");
          }
        }
      }
      return true;
    });
  }

  // Removed the @Override and super call
  public void onNewIntent(Intent intent) {
    if (intent != null && intent.getScheme().equals("companyname")) {
      if ("PENDING".equals(transactionState)) {
        transactionState = "COMPLETED";
        // Request payment status here
        String resourcePath = intent.getData().getPath(); // Extract resource path if needed
        requestPaymentStatus(resourcePath);
      }
    }
  }

  private void requestPaymentStatus(String resourcePath) {
    // Implementation to request payment status from your backend using the resourcePath
    // This would involve making a network request to your backend API to get the payment status
  }

  // Removed the @Override and super call
  public void onResume() {
    if ("PENDING".equals(transactionState)) {
      // Handle aborted transaction
      error("4", "Transaction was aborted", "");
    } else if ("COMPLETED".equals(transactionState)) {
      // Handle completed transaction
      // Possibly already handled in onNewIntent, so you might not need to do anything here
    }
  }

  public void success(final Object result) {
    handler.post(() -> this.result.success(result));
  }

  public void error(@NonNull final String errorCode, final String errorMessage, final Object errorDetails) {
    handler.post(() -> this.result.error(errorCode, errorMessage, errorDetails));
  }

  public void notImplemented() {
    handler.post(() -> this.result.notImplemented());
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }

  @Override
  public void onDetachedFromActivity() {
    // Clean up any references to the activity
    activity = null;
  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    onAttachedToActivity(binding);
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity();
  }

  @Override
  public void transactionCompleted(@NonNull Transaction transaction) {
    if (transaction.getTransactionType() == TransactionType.SYNC) {
      success("SYNC");
    } else {
      Uri uri = Uri.parse(transaction.getRedirectUrl());
      Intent intent = new Intent(Intent.ACTION_VIEW, uri);
      activity.startActivity(intent);
    }
  }

  @Override
  public void transactionFailed(@NonNull Transaction transaction, @NonNull PaymentError paymentError) {
    error("transactionFailed", paymentError.getErrorMessage(), "transactionFailed");
  }

  @Override
  public void brandsValidationRequestSucceeded(@NonNull BrandsValidation brandsValidation) {
    // Implement this if necessary
  }

  @Override
  public void brandsValidationRequestFailed(@NonNull PaymentError paymentError) {
    // Implement this if necessary
  }

  @Override
  public void imagesRequestSucceeded(@NonNull ImagesRequest imagesRequest) {
    // Implement this if necessary
  }

  @Override
  public void imagesRequestFailed() {
    // Implement this if necessary
  }
}
