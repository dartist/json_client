JsonClient for Dart
===================

Is a generic async HTTP Client optimized for consuming JSON web services. 

Until the Dart package manager is built [JsonClient.dart](https://github.com/mythz/DartJsonClient/blob/master/JsonClient.dart) is a single, stand-alone .dart file that's an easy drop-in any project. The current version relies on the **dart:io** package so only works in the Dart VM. A future update will include an identical JsonClient that wraps XMLHttpRequest so can be transpiled to JavaScript and run in all browsers. You can watch this repo or follow [@demisbellot](http://twitter.com/demisbellot) for updates.

JsonClient takes advantages of Dart's **noSuchMethod** language feature to offer a succinct, ruby-esque dynamic API as well as the standard get/post/put/delete HTTP Client methods found in most HTTP clients. 

What ever your preference, each method supports both a Futures response (akin to promise in jQuery or Task in C#) or async callback styles.

# Usage

The only required argument needed is the **urlRoot** which is the base Url that all relative Urls will base themselves off.

    String urlRoot = "http://www.servicestack.net/Backbone.Todos";
    var client = new JsonClient(urlRoot);

The Url above points to a [REST API backend](http://www.servicestack.net/Backbone.Todos/metadata) for the [Backbone.js TODOs demo app](http://www.servicestack.net/Backbone.Todos) built with the [ServiceStack .NET Webservices Framework](http://www.servicestack.net). 

With the just client and the url in-place, we can now start making API calls - Where getting the entire TODO list is no harder than:

    client.todos();

This call makes a JSON request for the [/todos](http://www.servicestack.net/Backbone.Todos/todos?format=json) url. Since all API methods on the client are async, the two ways we have to access the response include:

### Normal async callbacks

The standard in JavaScript, where you pass a callback function that gets called when the response is received - which in Dart looks like:

    client.todos( (response) => print("I have ${response.length} things left todo") );

The other option is to use Dart's [Future's API](http://api.dartlang.org/dart_core/Future.html) to attach your callback as a continuation on the returned Future, which looks like:

    client.todos()
      .then( (response) => print("I have ${response.length} things left todo") );

The dynamic API also supports optional params, any scalar variable (e.g. String, number) is combined with the **urlRoot** and the **dynamicMethod()** name to form the url like: `{urlRoot}/{dynamicMethod}/{scalarParam}`. Knowing this we can fetch a single todo with:

    client.todos(1, (todo) => print("I still need to do ${todo['content']}") );

or the same with Futures:

    client.todos(1)
      .then( (todo) => print("I still need to do ${todo['content']}") );

Which will GET the JSON at `{urlRoot}/todos/1`. The param can also be a String which is just appended as-is so can also include queryString params. Here's another example of making a GET request for fileInfo from the [WebDav-like RestFiles Service](http://www.servicestack.net/RestFiles):

    var client = new JsonClient("http://www.servicestack.net/RestFiles");
    client.files("services/FilesService.cs.txt").then( 
        (fileInfo) => print("${fileInfo['Name']} is ${fileInfo['FileSizeBytes']} bytes") );

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

## Callbacks vs Futures

Now that we've covered the basics, lets go through a more complete demo to give you a taste of how the different async API styles compare. For this example we'll delete all the existing TODOs, create new ones from a list and re-use an existing function to mark one of them as completed.

The todos and function all examples will use is below:

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

### Using Async Callbacks

The normal javascript way to handle async calls is with callbacks and the shortest code to achieve what we want with callbacks would look something like:

    createTodos() {
        int i=0;
        List results = [];
        todos.forEach((text) => client.todos({'content':text, 'order':i++}, 
            (r){ 
                results.add(r); 
                if (results.length == todos.length) 
                    markTodoCompleted(results);
            }));
    }

    client.todos((List existingTodos){      
        int asyncCount=existingTodos.length;
        existingTodos.forEach((x) => client.delete('todos/${x['id']}', 
          (_){ if (--asyncCount == 0) createTodos(); }));

        if (asyncCount == 0) 
            createTodos();
    });    

From this example we can see using callbacks can lead to coupling of the request with the custom response handler logic which inhibits re-usability and DRY. We also have to be wary when making multiple async calls that we only continue after we've processed the last response. There are a few pitfalls to be careful of here like if there are no existing TODOs, none of your inner delete callbacks will get fired so you have to make a special case for when there are no existing TODOs. 

### Futures in Dart

Futures in Dart also go by the name of [Promises](http://en.wikipedia.org/wiki/Futures_and_promises) in other languages. They're purpose is to hold a value that is yet to be determined but will still allow you to attach and compose continuation logic to be executed when the value is computed (or in our case when our response is received). The same logic above re-written to use Futures looks like:

    client.todos()
      .then((List existingTodos){
        Futures.wait( existingTodos.map((x) => client.delete('todos/${x['id']}')) )
          .then((_) { 
              int i=0;
              Futures.wait( todos.map((text) => client.todos({'content':text, 'order':i++})) )
                .then( markTodoCompleted );
          });      
      });    

Straight away we see that the Futures example is smaller - about 1/2 the size. It's easier to read and less prone to errors where the complex logic to determine when all async callbacks have been processed (if any) is encapsulated in the built-in `Futures.wait()` utiility method. It also reads top-to-bottom, since continuation logic is chained to returned futures, as opposed to your eyes darting back and forward to follow the flow of logic in the callback example.

### Re-usable logic with De-coupled callbacks

For completeness lets also see what the same logic would look like if it were created with de-coupled callback methods. In this example each method is decoupled from the other making it now possible for re-use. As they're generic they also need to additional boilerplate to handle invocations with no callbacks:

    deleteTodos(List existingTodos, [Function callback]){
      int asyncCount=existingTodos.length;
      if (asyncCount == 0) 
        return callback == null ? null : callback(); 
      
      existingTodos.forEach((x) => client.delete('todos/${x['id']}', 
        (_){ if (--asyncCount == 0 && callback != null) callback(); })
      );
    }
    
    createTodos(List newTodos, [Function callback]){
      int i=0;
      if (newTodos.length == 0) 
        return callback == null ? null : callback(); 

      List results = [];
      newTodos.forEach((text) => client.todos({'content':text, 'order':i++}, 
        (r){ 
          if (callback == null) return;

          results.add(r); 
          if (results.length == todos.length) 
            callback(results);
        })
      );
    }

    client.todos((List existingTodos){
      deleteTodos(existingTodos, (){ 
        createTodos(todos, 
          markTodoCompleted);
      });    
    });    

The last snippet of logic is where it all comes together. Now that the callbacks are named the logic becomes much easier to read. I prefer putting my callbacks on a new line as it visually better denotes a sequential logic step, instead of confusing it to be a core part of the function invocation.

Although the de-coupled callback example is now re-usable with the composite part now more readable, it does come with the cost of being more than 3x the size of the equivalent Futures example. 

As terseness also has a strong correlation to readability my preference is to use Futures for any more than 2 nested callbacks or whenever multiple async IO calls are involved.  

### More Examples

More client usage examples can be seen at [Example.dart](https://github.com/mythz/DartJsonClient/blob/master/Example.dart)

### Feedback Welcome

Hopefully this library proves useful, and am always interested in any feedback or issues. 

Contributions in any form e.g. Documentation, tests, examples, etc are greatly appreciated. 
This will be packaged into a library as soon as the Dart package manager comes into fruition and more tests added when the Mirrors Reflection API has been added and a solid test-suite has emerged.

In the meantime you can follow [@demisbellot](http://twitter.com/demisbellot) for updates.
