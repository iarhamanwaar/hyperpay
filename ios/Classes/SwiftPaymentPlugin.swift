import Flutter
import UIKit
import SafariServices

public class SwiftPaymentPlugin: NSObject, FlutterPlugin, SFSafariViewControllerDelegate, OPPCheckoutProviderDelegate {
    var type: String = ""
    var mode: String = ""
    var checkoutid: String = ""
    var brand: String = ""
    var brandsReadyUi: [String] = []
    var STCPAY: String = ""
    var number: String = ""
    var holder: String = ""
    var year: String = ""
    var month: String = ""
    var cvv: String = ""
    var pMadaVExp: String = ""
    var prMadaMExp: String = ""
    var brands: String = ""
    var shopperResultURL: String = ""
    var tokenID: String = ""
    var payTypeSotredCard: String = ""
    var applePaybundel: String = ""
    var countryCode: String = ""
    var currencyCode: String = ""
    var setStorePaymentDetailsMode: String = ""
    var lang: String = ""
    var amount: Double = 1
    var themColorHex: String = ""
    var companyName: String = ""
    var safariVC: SFSafariViewController?
    var transaction: OPPTransaction?
    var provider = OPPPaymentProvider(mode: OPPProviderMode.test)
    var checkoutProvider: OPPCheckoutProvider?
    var Presult: FlutterResult?
    var window: UIWindow?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let flutterChannel: String = "Hyperpay.demo.fultter/channel"
        let channel = FlutterMethodChannel(name: flutterChannel, binaryMessenger: registrar.messenger())
        let instance = SwiftPaymentPlugin()
        registrar.addApplicationDelegate(instance)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        self.Presult = result

        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Arguments are missing or invalid", details: nil))
            return
        }

        guard let type = args["type"] as? String,
              let mode = args["mode"] as? String,
              let checkoutid = args["checkoutid"] as? String,
              let shopperResultURL = args["ShopperResultUrl"] as? String,
              let lang = args["lang"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing required arguments", details: nil))
            return
        }

        self.type = type
        self.mode = mode
        self.checkoutid = checkoutid
        self.shopperResultURL = shopperResultURL
        self.lang = lang

        if type == "ReadyUI" {
            guard let applePaybundel = args["merchantId"] as? String,
                  let countryCode = args["CountryCode"] as? String,
                  let companyName = args["companyName"] as? String,
                  let brandsReadyUi = args["brand"] as? [String],
                  let themColorHex = args["themColorHexIOS"] as? String,
                  let setStorePaymentDetailsMode = args["setStorePaymentDetailsMode"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing required arguments for ReadyUI", details: nil))
                return
            }

            self.applePaybundel = applePaybundel
            self.countryCode = countryCode
            self.companyName = companyName
            self.brandsReadyUi = brandsReadyUi
            self.themColorHex = themColorHex
            self.setStorePaymentDetailsMode = setStorePaymentDetailsMode

            DispatchQueue.main.async {
                self.openCheckoutUI(checkoutId: self.checkoutid, result1: result)
            }
        } else if type == "CustomUI" {
            guard let brands = args["brand"] as? String,
                  let number = args["card_number"] as? String,
                  let holder = args["holder_name"] as? String,
                  let year = args["year"] as? String,
                  let month = args["month"] as? String,
                  let cvv = args["cvv"] as? String,
                  let setStorePaymentDetailsMode = args["EnabledTokenization"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing required arguments for CustomUI", details: nil))
                return
            }

            self.brands = brands
            self.number = number
            self.holder = holder
            self.year = year
            self.month = month
            self.cvv = cvv
            self.setStorePaymentDetailsMode = setStorePaymentDetailsMode

            self.openCustomUI(checkoutId: self.checkoutid, result1: result)
        } else {
            result(FlutterError(code: "METHOD_NOT_FOUND", message: "Method name is not found", details: nil))
        }
    }

    private func openCheckoutUI(checkoutId: String, result1: @escaping FlutterResult) {
        self.provider = OPPPaymentProvider(mode: self.mode == "live" ? .live : .test)

        DispatchQueue.main.async {
            let checkoutSettings = OPPCheckoutSettings()
            checkoutSettings.paymentBrands = self.brandsReadyUi

            if self.brandsReadyUi.contains("APPLEPAY") {
                let paymentRequest = OPPPaymentProvider.paymentRequest(withMerchantIdentifier: self.applePaybundel, countryCode: self.countryCode)
                paymentRequest.paymentSummaryItems = [PKPaymentSummaryItem(label: self.companyName, amount: NSDecimalNumber(value: self.amount))]

                if #available(iOS 12.1.1, *) {
                    paymentRequest.supportedNetworks = [PKPaymentNetwork.mada, PKPaymentNetwork.visa, PKPaymentNetwork.masterCard]
                } else {
                    paymentRequest.supportedNetworks = [PKPaymentNetwork.visa, PKPaymentNetwork.masterCard]
                }

                checkoutSettings.applePayPaymentRequest = paymentRequest
            }

            checkoutSettings.language = self.lang
            checkoutSettings.shopperResultURL = self.shopperResultURL + "://result"

            if self.setStorePaymentDetailsMode == "true" {
                checkoutSettings.storePaymentDetails = .prompt
            }

            self.setThem(checkoutSettings: checkoutSettings, hexColorString: self.themColorHex)

            guard let checkoutProvider = OPPCheckoutProvider(paymentProvider: self.provider, checkoutID: checkoutId, settings: checkoutSettings) else {
                result1(FlutterError(code: "CHECKOUT_PROVIDER_ERROR", message: "Failed to initialize checkout provider", details: nil))
                return
            }

            self.checkoutProvider = checkoutProvider
            checkoutProvider.delegate = self

            checkoutProvider.presentCheckout(forSubmittingTransactionCompletionHandler: { transaction, error in
                if let error = error {
                    result1(FlutterError(code: "CHECKOUT_ERROR", message: "Transaction failed: \(error.localizedDescription)", details: nil))
                    return
                }

                guard let transaction = transaction else {
                    result1(FlutterError(code: "TRANSACTION_ERROR", message: "Transaction is invalid", details: nil))
                    return
                }

                self.transaction = transaction

                switch transaction.type {
                case .synchronous:
                    result1("SYNC")
                case .asynchronous:
                    NotificationCenter.default.addObserver(self, selector: #selector(self.didReceiveAsynchronousPaymentCallback), name: NSNotification.Name(rawValue: "AsyncPaymentCompletedNotificationKey"), object: nil)
                default:
                    result1(FlutterError(code: "TRANSACTION_CANCELLED", message: "Transaction was cancelled", details: nil))
                }
            }, cancelHandler: {
                result1(FlutterError(code: "CHECKOUT_CANCELLED", message: "User cancelled the payment", details: nil))
            })
        }
    }

    private func openCustomUI(checkoutId: String, result1: @escaping FlutterResult) {
        self.provider = OPPPaymentProvider(mode: self.mode == "live" ? .live : .test)

        // Validate card details
        guard OPPCardPaymentParams.isNumberValid(self.number, luhnCheck: true) else {
            self.createAlert(title: "Card Number is Invalid", message: "Please check the card number and try again.")
            result1(FlutterError(code: "INVALID_CARD_NUMBER", message: "Card Number is Invalid", details: nil))
            return
        }

        guard OPPCardPaymentParams.isHolderValid(self.holder) else {
            self.createAlert(title: "Card Holder is Invalid", message: "Please check the card holder name and try again.")
            result1(FlutterError(code: "INVALID_CARD_HOLDER", message: "Card Holder is Invalid", details: nil))
            return
        }

        guard OPPCardPaymentParams.isCvvValid(self.cvv) else {
            self.createAlert(title: "CVV is Invalid", message: "Please check the CVV and try again.")
            result1(FlutterError(code: "INVALID_CVV", message: "CVV is Invalid", details: nil))
            return
        }

        guard OPPCardPaymentParams.isExpiryYearValid(self.year) else {
            self.createAlert(title: "Expiry Year is Invalid", message: "Please check the expiry year and try again.")
            result1(FlutterError(code: "INVALID_EXPIRY_YEAR", message: "Expiry Year is Invalid", details: nil))
            return
        }

        guard OPPCardPaymentParams.isExpiryMonthValid(self.month) else {
            self.createAlert(title: "Expiry Month is Invalid", message: "Please check the expiry month and try again.")
            result1(FlutterError(code: "INVALID_EXPIRY_MONTH", message: "Expiry Month is Invalid", details: nil))
            return
        }

        do {
            // Attempt to create payment params
            let params: OPPCardPaymentParams
            if self.brands.isEmpty {
                // Automatic brand detection
                params = try OPPCardPaymentParams(checkoutID: checkoutId, holder: self.holder, number: self.number, expiryMonth: self.month, expiryYear: self.year, cvv: self.cvv)
            } else {
                // Explicit brand
                params = try OPPCardPaymentParams(checkoutID: checkoutId, paymentBrand: self.brands, holder: self.holder, number: self.number, expiryMonth: self.month, expiryYear: self.year, cvv: self.cvv)
            }

            // Set shopper result URL
            params.isTokenizationEnabled = self.setStorePaymentDetailsMode == "true"
            params.shopperResultURL = self.shopperResultURL + "://result"

            self.transaction = OPPTransaction(paymentParams: params)

            // Submit the transaction
            self.provider.submitTransaction(self.transaction!) { transaction, error in
                if let error = error {
                    self.createAlert(title: "Transaction Error", message: error.localizedDescription)
                    result1(FlutterError(code: "TRANSACTION_ERROR", message: error.localizedDescription, details: nil))
                    return
                }

                // Handle transaction response
                if transaction.type == .asynchronous, let redirectURL = transaction.redirectURL {
                    self.safariVC = SFSafariViewController(url: redirectURL)
                    self.safariVC?.delegate = self
                    UIApplication.shared.windows.first?.rootViewController?.present(self.safariVC!, animated: true, completion: nil)
                } else if transaction.type == .synchronous {
                    result1("success")
                } else {
                    self.createAlert(title: "Transaction Error", message: "Unexpected transaction type")
                    result1(FlutterError(code: "UNEXPECTED_TRANSACTION_TYPE", message: "Unexpected transaction type", details: nil))
                }
            }
        } catch let error as NSError {
            self.createAlert(title: "Transaction Error", message: error.localizedDescription)
            result1(FlutterError(code: "TRANSACTION_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    @objc func didReceiveAsynchronousPaymentCallback() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "AsyncPaymentCompletedNotificationKey"), object: nil)

        if self.type == "ReadyUI" || self.type == "APPLEPAY" || self.type == "StoredCards" {
            self.checkoutProvider?.dismissCheckout(animated: true) {
                self.Presult?("success")
            }
        } else {
            self.safariVC?.dismiss(animated: true) {
                self.Presult?("success")
            }
        }
    }

    public func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        guard let scheme = url.scheme, scheme.caseInsensitiveCompare(self.shopperResultURL) == .orderedSame else {
            return false
        }

        self.didReceiveAsynchronousPaymentCallback()
        return true
    }

    func createAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
            })
            UIApplication.shared.windows.first?.rootViewController?.present(alertController, animated: true, completion: nil)
        }
    }

    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        controller.dismiss(animated: true, completion: nil)
    }

    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, completion: @escaping (PKPaymentAuthorizationStatus) -> Void) {
        do {
            let params = try OPPApplePayPaymentParams(checkoutID: self.checkoutid, tokenData: payment.token.paymentData)
            self.transaction = OPPTransaction(paymentParams: params)
            self.provider.submitTransaction(self.transaction!) { transaction, error in
                if let error = error {
                    self.createAlert(title: "APPLEPAY Error", message: error.localizedDescription)
                    completion(.failure)
                } else {
                    completion(.success)
                    self.Presult?("success")
                }
            }
        } catch let error as NSError {
            self.createAlert(title: "APPLEPAY Error", message: error.localizedDescription)
            completion(.failure)
        }
    }

    func setThem(checkoutSettings: OPPCheckoutSettings, hexColorString: String) {
        checkoutSettings.theme.confirmationButtonColor = UIColor(hexString: hexColorString)
        checkoutSettings.theme.navigationBarBackgroundColor = UIColor(hexString: hexColorString)
        checkoutSettings.theme.cellHighlightedBackgroundColor = UIColor(hexString: hexColorString)
        checkoutSettings.theme.accentColor = UIColor(hexString: hexColorString)
    }
}

extension UIColor {
    convenience init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}
