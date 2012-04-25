#library("JsonClient");

#import("dart:uri");
#import("dart:io");
#import("dart:json");

typedef void RequestFilter(HttpClientRequest httpReq);
typedef void ResponseFilter(HttpClientResponse httpRes);

interface LogLevel {
  static final int None = 0;
  static final int Error = 1;
  static final int Warn = 2;
  static final int Info = 3;
  static final int Debug = 4;
  static final int All = 5;
}

class JsonClient {
  Uri baseUri;
  RequestFilter requestFilter;
  ResponseFilter responseFilter;
  Function onError;
  int logLevel;
  
  JsonClient(String urlRoot, [this.requestFilter, this.responseFilter])
  {
    baseUri = new Uri.fromString(urlRoot);
    logLevel = LogLevel.None; 
  }
  
  void set urlRoot(String url) {
    baseUri = new Uri.fromString(url);
  }
  
  void logDebug (arg) {
    if (logLevel >= LogLevel.Debug) print(arg);
  }
  void logError (arg) {
    if (logLevel >= LogLevel.Error) print(arg);
  }
  
  Future noSuchMethod(name, args) {
    
    var reqData;
    Function successFn, errorFn;
    
    if (args.length > 0) {
      reqData = args[0] is! Function ? args[0] : null;
      successFn = reqData == null && args[0] is Function ? args[0] : null;
      
      if (args.length > 1) {
        if (successFn == null)
          successFn = args[1];
        else 
          errorFn = args[1];
        
        if (args.length > 2)
          errorFn = args[2];
      }
    }    
    
    String url = name;
    Map postData = null;    
    if (reqData is Map || reqData is List) {
      postData = reqData;
    } else if (reqData != null) {
      url += "$reqData".startsWith("?") 
        ? reqData
        : "/$reqData"; 
    }

    String httpMethod = postData == null ? 'GET' : 'POST';    
    
    return ajax(httpMethod, url, postData, successFn, errorFn);
  }
  
  Future get (url, [success, error]) =>
    ajax('GET', url, null, success, error);
  
  Future post (url, [data, success, error]) =>
    ajax('POST', url, data, success, error);
  
  Future put (url, [data, success, error]) =>
    ajax('PUT', url, data, success, error);
  
  Future delete (url, [success, error]) =>
    ajax('DELETE', url, null, success, error);
    
  Future ajax (String httpMethod, String url, [postData, Function successFn, Function errorFn]){

    Completer task = new Completer();
    
    int port = baseUri.port == 0 ? 80 : baseUri.port; 
    
    bool isUrl = url.startsWith("http"); 
    Uri uri = isUrl ? new Uri.fromString(url) : baseUri;
    String path = isUrl 
      ? uri.path + uri.query 
      : url.startsWith("/")
        ? url
        : "${uri.path}/${url}";
    
    if (logLevel >= LogLevel.Debug) {
      Map status = {
        'hasData': postData != null,
        'hasSuccess': successFn != null,
        'hasError': errorFn != null,
        'httpMethod': httpMethod,
        'postData': postData,
        'port': port,
        'uri': uri,
        'uri.domain': uri.domain,
        'path': path
      };
      logDebug("${status}");
    }
    
    void notifyError (e, [String msg]) {      
      logError("onErr:");
      HttpException ex = e is HttpException ? e : null;
      if (ex != null)
        logError("HttpException($msg): ${ex.message}");
      else
        logError("Error($msg): ${e.toString()}");
      
      if (errorFn != null)
        errorFn(e);
      if (onError != null)
        onError(e);      
      
      task.completeException(e);
    }

    HttpClient client = new HttpClient(); 
    HttpClientConnection conn = client.open(httpMethod, uri.domain, port, path); 
    conn.onRequest = (HttpClientRequest httpReq) { 
      logDebug("onReq");
      
      //Already gets sent
      //httpReq.headers.set(HttpHeaders.HOST, uri.domain); 
      httpReq.headers.set(HttpHeaders.ACCEPT, "application/json");
      
      if (requestFilter != null) requestFilter(httpReq);
      
      bool hasRequestBody = false;
      if (httpMethod == "POST" || httpMethod == "PUT") {
        httpReq.headers.set(HttpHeaders.CONTENT_TYPE, "application/json"); 
        if (postData != null) {
          String jsonData = JSON.stringify(postData);
          httpReq.contentLength = jsonData.length;
          logDebug("writting: ${jsonData} at ${path}");
          httpReq.outputStream.writeString(jsonData);
          hasRequestBody = true;
        }
      }      
      //need to set since transfer is chunked-encoding
      if (!hasRequestBody) httpReq.contentLength = 0;             
      httpReq.outputStream.close(); 
    }; 
    conn.onResponse = (HttpClientResponse httpRes) { 
      logDebug("onRes: ${httpRes.statusCode}");
      if (responseFilter != null) responseFilter(httpRes);
      
      final StringInputStream input = new StringInputStream(httpRes.inputStream);
      StringBuffer buffer = new StringBuffer('');
      input.onData = () {
        logDebug("adding data..");
        buffer.add(input.read());
      };
      
      complete(response) {
        try {
          task.complete(response);
          if (successFn != null) successFn(response);
        } catch (final e) { logError(e); }
      }
      input.onClosed = (){
        logDebug("input.onClosed().. ${httpRes.statusCode}");
        if (buffer == null || buffer.isEmpty()) {
          complete(null);
        } else {
          String data = buffer.toString();
          try {
            var response = JSON.parse(data);
            if (httpRes.statusCode < 400) 
              complete(response);
            else
              notifyError(response);
          }
          catch (final e) {
            notifyError(e, "Error Parsing: $data");
          }
        }
        
        client.shutdown(); 
      };
    };
    conn.onError = notifyError;
    
    return task.future;
  }
  
}
