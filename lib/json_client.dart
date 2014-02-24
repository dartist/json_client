library json_client;

import "dart:core";
import "dart:io";
import "dart:mirrors";
import "dart:async";
import "dart:convert";

typedef void RequestFilter(HttpClientRequest httpReq);
typedef void ResponseFilter(HttpClientResponse httpRes);

class LogLevel {
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
  HttpClient _client;
  int logLevel;

  JsonClient(String urlRoot, [HttpClient client = null])
  {
    baseUri = Uri.parse(urlRoot);
    logLevel = LogLevel.Warn;
    _client = client;
  }

  void set urlRoot(String url) {
    baseUri = Uri.parse(url);
  }

  void logDebug (arg) {
    if (logLevel >= LogLevel.Debug) print(arg);
  }
  void logInfo (arg) {
    if (logLevel >= LogLevel.Info) print(arg);
  }
  void logError (arg) {
    if (logLevel >= LogLevel.Error) print(arg);
  }
  
  String _trimStart(String str, String start) {
    if (str.startsWith(start) && str.length > start.length) {
      return str.substring(start.length);
    }
    return str;
  }
  
  String _combinePaths(List paths){
    var sb = new StringBuffer();
    bool endsWithSlash = false;
    for (var oPath in paths){
      if (oPath == null) continue;
      String path = oPath.toString();
      if (path.isEmpty) continue;
      
      if (sb.length > 0 && !endsWithSlash)
        sb.write('/');
      
      String sanitizedPath = _trimStart(path.replaceAll("\\", "/"), "/");
      sb.write(sanitizedPath);
      endsWithSlash = sanitizedPath.endsWith("/");
    }
    return sb.toString();
  }

  Future get (url) =>
    ajax('GET', url, null);

  Future post (url, [data]) =>
    ajax('POST', url, data);

  Future put (url, [data]) =>
    ajax('PUT', url, data);

  Future delete (url) =>
    ajax('DELETE', url, null);

  Future noSuchMethod(Invocation im) {
    var reqData;
    Function successFn, errorFn;
   
    var name = MirrorSystem.getName(im.memberName);
    var args = im.positionalArguments;

    if (args.length > 0) {
      reqData = args[0];
    }

    String url = name;
    Map postData = null;
    if (reqData is Map || reqData is List) {
      postData = reqData;
    } else if (reqData != null) {
      if (reqData is String && reqData.startsWith("?")){
        url = "$url$reqData";
      }
      else {
        url = _combinePaths([url, reqData]);        
      }        
    }

    String httpMethod = postData == null ? 'GET' : 'POST';
    
    return ajax(httpMethod, url, postData);
  } 
  
  Future ajax (String httpMethod, String url, [Object postData]){

    var task = new Completer();    
    
    int port = baseUri.port == 0 ? 80 : baseUri.port;

    bool isFullUrl = url.startsWith("http");
    Uri uri = isFullUrl ? Uri.parse(url) : baseUri;
    String path = isFullUrl
      ? "${uri.path}${uri.query}"
      : url.startsWith("/")
        ? url
        : _combinePaths([uri.path, url]);

    if (logLevel >= LogLevel.Debug) {
      Map status = {
        'hasData': postData != null,
        'hasSuccess': successFn != null,
        'hasError': errorFn != null,
        'httpMethod': httpMethod,
        'postData': postData,
        'port': port,
        'url': url,
        'uri': uri,
        'uri.host': uri.host,
        'uri.path': uri.path,
        'uri.query': uri.query,
        'path': path
      };
      logDebug("${status}");
    }

    var client = _client == null ? new HttpClient() : _client;
    client.open(httpMethod, uri.host, port, path).then((HttpClientRequest httpReq){
      logDebug("onReq: httpMethod: $httpMethod, postData: $postData, path: $path");

      //Already gets sent
      //httpReq.headers.set(HttpHeaders.HOST, uri.domain);
      httpReq.headers.set(HttpHeaders.ACCEPT, "application/json");

      if (requestFilter != null) requestFilter(httpReq);

      if (httpMethod == "POST" || httpMethod == "PUT") {
        httpReq.headers.set(HttpHeaders.CONTENT_TYPE, "application/json");
        if (postData != null) {
          var jsonData = JSON.encode(postData);
          logDebug("writting: ${jsonData} at ${path}");
          httpReq.contentLength = jsonData.length;
          httpReq.write(jsonData);
        }
        else {
          httpReq.contentLength = 0;
        }
      }

      return httpReq.close();
    })
    .then((HttpClientResponse httpRes){
      logDebug("httpRes: ${httpRes.statusCode}");
      if (responseFilter != null) responseFilter(httpRes);

      StringBuffer sb = new StringBuffer();
      httpRes.transform(new AsciiDecoder(allowInvalid: true))
        .listen((String data){
          sb.write(data);
        })
        .onDone((){
          var data = sb.toString();
          Object response = null;
          try {
            logDebug("RECV onData: $data");            
            response = data.isEmpty 
              ? null
              : JSON.decode(data);
          }
          catch(e) { _notifyError(task, e, "Error Parsing: $data"); return; }

          if (httpRes.statusCode < 400) {
            try {
              task.complete(response);
            } catch(e) { logError(e); return; }
          } else {
            _notifyError(task, httpRes, "Error statusCode: ${httpRes.statusCode}");
            return;
          }

        });

    });
    
    return task.future;    
  }

  void _notifyError (Completer task, e, [String msg]){
    HttpClientResponse httpRes = e is HttpClientResponse ? e : null;
    HttpException httpEx = e is HttpException ? e : null;
    if (httpRes != null)
      logInfo("HttpResponse(${httpRes.statusCode}): ${httpRes.reasonPhrase}. msg:$msg");
    else if (httpEx != null)
      logError("HttpException($msg): ${httpEx.message}");
    else
      logError("_notifyError($msg): ${e.toString()}");

    if (onError != null)
      onError(e);

    try {
      task.completeError(e);
    } catch (ex){
      logError("Error on task.completeException(e): $ex. Return true in ExHandler to mark as handled");
    }
  }
}
