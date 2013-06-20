JsonClient for Dart
===================

Is a generic async HTTP Client optimized for consuming JSON web services. 

## [Installing via Pub](http://pub.dartlang.org/packages/json_client)	

Add this to your package's pubspec.yaml file:

	dependencies:
	  json_client: 0.1.1

The current version relies on the **dart:io** package so only works in the Dart VM. A future update will include an 
identical JsonClient that wraps HttpRequest (i.e. Ajax's XMLHttpRequest) so can be transpiled to JavaScript and run 
in all browsers. Watch this repo or follow [@demisbellot](http://twitter.com/demisbellot) for updates.

JsonClient takes advantages of Dart's **noSuchMethod** language feature to offer a succinct, ruby-esque dynamic API 
as well as the standard get/post/put/delete HTTP Client methods found in most HTTP clients. 

## Usage

The only argument needed is the **urlRoot** which is the base Url that all relative Urls will base themselves off.

    String urlRoot = "http://www.servicestack.net/Backbone.Todos";
    var client = new JsonClient(urlRoot);

The Url above points to a [REST API backend](http://www.servicestack.net/Backbone.Todos/metadata) for the [Backbone.js TODOs demo app](http://www.servicestack.net/Backbone.Todos) built with the [ServiceStack .NET Webservices Framework](http://www.servicestack.net). 

With the just client and the url in-place, we can now start making API calls - Where getting the entire TODO list is no harder than:

    client.todos;

or as a method:

    client.todos();

This call makes a JSON request for the [/todos](http://www.servicestack.net/Backbone.Todos/todos?format=json) url. 

### Using Futures in Dart 

We use Dart's [Future's API](http://api.dartlang.org/dart_core/Future.html) to attach your callback as a continuation on the returned Future, which looks like:

    client.todos()
      .then((todoItems) => print("I have ${todoItems.length} things left todo"));

The dynamic API also supports optional params, any scalar variable (e.g. String, number) is combined with the **urlRoot** and the **dynamicMethod()** name to form the url like: `{urlRoot}/{dynamicMethod}/{scalarParam}`. Knowing this we can fetch a single todo with:

    client.todos(1)
      .then((todo) => print("I still need to do ${todo['content']}"));

Which will GET the JSON at `{urlRoot}/todos/1`. The param can also be a String which is just appended as-is so can also include queryString params. Here's another example of making a GET request for fileInfo from the [WebDav-like RestFiles Service](http://www.servicestack.net/RestFiles):

    var client = new JsonClient("http://www.servicestack.net/RestFiles");
    client.files("services/FilesService.cs.txt")
      .then((fileInfo) => print("${fileInfo['Name']} is ${fileInfo['FileSizeBytes']} bytes"));

Which just makes a JSON GET request to [/files/services/FilesService.cs.txt](http://www.servicestack.net/RestFiles/files/services/FilesService.cs.txt).

If however the param is an **Object** or a **List** (i.e. Array in JavaScript) then a **POST** request is made instead so creating a new todo item can be done with:

    client.todos({'content':'Add a new TODO!', 'order':1});

Only GET's and POST's can be made with the dynamic API. To make PUT and DELETE requests you need to fallback to the slightly more verbose HTTP Verb methods. To update an existing TODO you would do:

    client.put('todos/1', {"content":"Learn Dart","done":true});

And likewise you can DELETE the above with:

    client.delete('todos/1');

Note: If you prefer the more explicit methods you can also issue GET and POST requests in the same way with `client.get()` and `client.post()`.

## More API

Apart from the methods described above, the JsonClient includes support for detailed logging (useful when debugging issues):

    client.logLevel = LogLevel.All; //or Debug, Error, etc.

Chainging the urlRoot:

    client.urlRoot = "http://host/new/base/url";

Request and response filters allowing you to decorate HTTP requests before they're sent, or HTTP responses before they're processed:

    client.requestFilter  = (HttpClientRequest httpReq)  { ... };
    client.responseFilter = (HttpClientResponse httpRes) { ... };

A global error handler should you wish to handle errors generically:

    client.onError = (e) { ... };

## Futures Example

Now that we've covered the basics, lets go through a more complete demo to give you a taste of how the different async API styles compare. For this example we'll delete all the existing TODOs, create new ones from a list and re-use an existing function to mark one of them as completed.

    List todos = [
        'Learn Dart!', 
        'Clear all existing todo items',
        'Add all these todos',
        'Mark this todo as done',
        'do ALL THE THINGS!'
    ];
    final String completeTodo = 'Mark this todo as done';

    markTodoCompleted(List createdTodos) {
        List matchingTodos = createdTodos.filter((x) => x['content'] == completeTodo);
        var todo = matchingTodos[0];
        todo['done'] = true;
        client.put("todos/${todo['id']}", todo);    
    }

You will be able to see your results after running each example at:
http://www.servicestack.net/Backbone.Todos/    

Futures in Dart also go by the name of [Promises](http://en.wikipedia.org/wiki/Futures_and_promises) in other languages. They're purpose is to hold a value that is yet to be determined but will still allow you to attach and compose continuation logic to be executed when the value is computed (or in our case when our response is received). The same logic above re-written to use Futures looks like:

    client.todos()
      .then((List existingTodos){
        Future.wait(existingTodos.map((x) => client.delete('todos/${x['id']}')) )
          .then((_) { 
            int i=0;
            Future.wait( todos.map((text) => client.todos({'content':text, 'order':i++})) )
              .then( markTodoCompleted );
          });      
      });    

### More Examples

More client usage examples can be seen at [Example.dart](https://github.com/dartist/json_client/blob/master/bin/Example.dart)

### Contributors

  - [mythz](https://github.com/mythz) (Demis Bellot)
