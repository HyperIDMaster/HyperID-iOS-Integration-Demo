import UIKit
import WebKit

//************************************************************************************************************************
//  eConst
//------------------------------------------------------------------------------------------------------------------------
struct eConst
{
    static let CLIENT_ID                = "auth-test"
    static let CLIENT_SECRET            = "1mFnix5xk53Q620Jvn1XLecMluAwDQ9W"
    static let CLIENT_SCOPES            = "openid+email"
    
    static let BASE_REDIRECT_URI        = "com.deeplink.sample://com.deeplink.sample.com/auth/hyper-id/callback/"
    static let REDIRECT_URI             = "com.deeplink.sample://com.deeplink.sample.com/auth/hyper-id/callback/"
    
    static let AUTH_URL                 = "https://login-sandbox.hypersecureid.com/auth/realms/HyperID/protocol/openid-connect/auth"
    static let ACCESS_TOKEN_URL         = "https://login-sandbox.hypersecureid.com/auth/realms/HyperID/protocol/openid-connect/token"
    static let LOGOUT_URL               = "https://login-sandbox.hypersecureid.com/auth/realms/HyperID/protocol/openid-connect/logout"
    
    static let RESPONSE_TYPE_CODE       = "code"
    static let REDIRECT_TYPE_CODE       = "code"
    static let GRANT_TYPE_AUTH_CODE     = "authorization_code"
    static let GRANT_TYPE_REFRESH_TOKEN = "refresh_token"
}

//************************************************************************************************************************
//  eAccessTokenResponse
//------------------------------------------------------------------------------------------------------------------------
struct eAccessTokenResponse : Decodable
{
    let access_token: String
    let refresh_token: String
}

//************************************************************************************************************************
//  eBrowser
//------------------------------------------------------------------------------------------------------------------------
class eBrowser
{
    func Open()
    {
        var urlString : String = eConst.AUTH_URL + "?client_id="     + eConst.CLIENT_ID
                                                 + "&scope="         + eConst.CLIENT_SCOPES
                                                 + "&response_type=" + eConst.RESPONSE_TYPE_CODE
        urlString += "&redirect_uri=" + eConst.REDIRECT_URI.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        if let url : URL = URL(string: urlString),
           UIApplication.shared.canOpenURL(url)
        {
            UIApplication.shared.open(url)
        }
    }
}

extension Notification.Name
{
    static let DeepLink = Notification.Name("DeepLink")
}

//************************************************************************************************************************
//  CustomSchemeHandler
//------------------------------------------------------------------------------------------------------------------------
class CustomSchemeHandler : NSObject,WKURLSchemeHandler
{
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask)
    {
        if let url = urlSchemeTask.request.url, url.scheme == "com.deeplink.sample"
        {
            let notification = Notification(name: .DeepLink, object: url)
            NotificationCenter.default.post(notification)
        }
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask)
    {

    }
}

//************************************************************************************************************************
//  ViewController
//------------------------------------------------------------------------------------------------------------------------
class ViewController: UIViewController
{
    var accessToken : String = String()
    var refreshToken : String = String()
    var code : String = String()
    
    @IBOutlet weak var btnLoginWebView: UIButton!
    @IBOutlet weak var btnLogin: UIButton!
    @IBOutlet weak var btnLogout: UIButton!
    
    var webView: WKWebView!
    
    @IBAction func btnLoginClick(_ sender: UIButton!)
    {
        Login()
    }
    
    
    @IBAction func btnLoginWebViewClick(_ sender: UIButton!)
    {
        LoginWithWebView()
    }
    
    @IBAction func btnLogoutClick(_ sender: UIButton!)
    {
        Logout()
        btnLogin.isEnabled = true
        btnLoginWebView.isEnabled = true
        btnLogout.isEnabled = false
    }
    
    func StartAuthorizationWithUrl(url : URL)
    {
        let code : String = GetCodeFromUrl(url: url)!
        AccessTokenGet(code: code)
        AccessTokenRefresh()
        if(!accessToken.isEmpty)
        {
            btnLogin.isEnabled = false
            btnLoginWebView.isEnabled = false
            btnLogout.isEnabled = true
        }
    }
    
    func GetCodeFromUrl(url: URL) -> String?
    {
        let urlComponents = URLComponents(string: url.absoluteString)
        let code = urlComponents?.queryItems?.first(where: {$0.name == eConst.REDIRECT_TYPE_CODE})?.value
        if code != nil
        {
            return code
        }
        else
        {
            return ""
        }
    }
    
    func AccessTokenGet(code : String) -> Bool
    {
        let data : Data = "grant_type=\(eConst.GRANT_TYPE_AUTH_CODE)&client_id=\(eConst.CLIENT_ID)&code=\(code)&redirect_uri=\(eConst.REDIRECT_URI)&client_secret=\(eConst.CLIENT_SECRET)".data(using: .utf8)!
        
        let responseData : Data = SendRequest(requestData: data, requestUrl: eConst.ACCESS_TOKEN_URL)
        
        do
        {
            let accessTokenResponse : eAccessTokenResponse = try JSONDecoder().decode(eAccessTokenResponse.self, from: responseData)
            self.accessToken = accessTokenResponse.access_token
            self.refreshToken = accessTokenResponse.refresh_token
            return true
        }
        catch let jsonError as NSError
        {
            print("JSON decode failed: \(jsonError.localizedDescription)")
            return false
        }
    }
    
    func AccessTokenRefresh() -> Bool
    {
        let data : Data = "grant_type=\(eConst.GRANT_TYPE_REFRESH_TOKEN)&client_id=\(eConst.CLIENT_ID)&refresh_token=\(refreshToken)&redirect_uri=\(eConst.REDIRECT_URI)&client_secret=\(eConst.CLIENT_SECRET)".data(using: .utf8)!
        
        let responseData : Data = SendRequest(requestData: data, requestUrl: eConst.ACCESS_TOKEN_URL)
        
        do
        {
            let accessTokenResponse : eAccessTokenResponse = try JSONDecoder().decode(eAccessTokenResponse.self, from: responseData)
            self.accessToken = accessTokenResponse.access_token
            self.refreshToken = accessTokenResponse.refresh_token
            return true
        }
        catch let jsonError as NSError
        {
            print("JSON decode failed: \(jsonError.localizedDescription)")
            return false
        }
    }
    
    func SendRequest(requestData: Data, requestUrl: String) -> Data
    {
        let url : URL = URL(string: requestUrl)!
        
        let sem = DispatchSemaphore.init(value: 0)
        
        var request : URLRequest = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestData
        let config : URLSessionConfiguration = URLSessionConfiguration.default
        let session : URLSession = URLSession(configuration: config)
        
        var dataToReturn : Data = Data()
        
        let task : URLSessionDataTask = session.dataTask(with: request, completionHandler:
        {
            (data, response, error) in
            
            defer { sem.signal() }
            
            if (error != nil)
            {
                print(error!)
            }
            else
            {
                guard let responseData : Data = data
                else
                {
                    print("Error: did not receive data")
                    return
                }
                dataToReturn = responseData
            }
        })
        task.resume()
        sem.wait()
        return dataToReturn
    }
    
    func Login()
    {
        var browser : eBrowser = eBrowser()
        browser.Open()
    }
    
    func LoginWithWebView()
    {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(CustomSchemeHandler(), forURLScheme: "com.deeplink.sample")
        webView = WKWebView(frame: view.frame/*.zero*/, configuration: configuration)
        view.addSubview(webView)//view=webView
        
        var urlString : String = eConst.AUTH_URL + "?client_id="     + eConst.CLIENT_ID
                                                 + "&scope="         + eConst.CLIENT_SCOPES
                                                 + "&response_type=" + eConst.RESPONSE_TYPE_CODE
        urlString += "&redirect_uri=" + eConst.REDIRECT_URI.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        
        let request = URLRequest(url: URL(string: urlString)!)
        webView?.load(request)
    }
    
    func Logout()
    {
        let data : Data = "client_id=\(eConst.CLIENT_ID)&refresh_token=\(refreshToken)&client_secret=\(eConst.CLIENT_SECRET)".data(using: .utf8)!
        
        SendRequest(requestData: data, requestUrl: eConst.LOGOUT_URL)
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        btnLogin.isEnabled = true
        btnLoginWebView.isEnabled = true
        btnLogout.isEnabled = false
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.HandleDeepLink), name: .DeepLink, object: nil)
        
        
    }
    
    @objc func HandleDeepLink(notification: Notification)
    {
        webView?.removeFromSuperview()
        if let deepLinkUrl = notification.object as? URL
        {
            StartAuthorizationWithUrl(url: deepLinkUrl)
        }
    }
    
    deinit
    {
        NotificationCenter.default.removeObserver(self)
    }
}

