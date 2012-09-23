#import("package:DartJsonClient/JsonClient.dart");

newClient(String url) {
  var client = new JsonClient(url);
  client.logLevel = LogLevel.Error;
  return client;
}

Do_Northwind(){
  print("Do_Northwind(): ");

  var client = newClient("http://www.servicestack.net/ServiceStack.Northwind");  
  client.customers()
    .then((response) { 
      var mexicanNames = response['Customers']
          .filter((x) => x['Country'] == "Mexico")
          .map((x) => x['ContactName']);
      
      print("Mexican Customers: $mexicanNames");
    });
}

Do_RestFiles(){
  print("Do_RestFiles(): ");
  
  var client = newClient("http://www.servicestack.net/RestFiles");
  
  client.files((r) => print("GET response: ${r}") );
  
  client.files("dtos/Operations/RevertFiles.cs.txt", (r) => print("GET response: $r") );

  client.get('files/Global.asax.cs.txt', (r) => print("Global.asax:\n\n${r['File']['Contents']}") );  
  
  int nowMs = (new Date.now()).millisecondsSinceEpoch;
  client.files({'path':'newFolder$nowMs'}, (r) => print("POST response: ${r}") );

  client.files('?path=services', (r) => print("GET response: ${r}") );
  client.get('files?path=services', (r) => print("GET response: ${r}") );

  print("Testing error handler on invalid requests...");
  client.post('files?forDownload=1BrokenRequest', success: null, 
    error: (e) => print("POST error response: ${e}") );
}

Do_BackboneTodos([option=1]){
  print("Do_BackboneTodos(): ");
  
  var client = newClient("http://www.servicestack.net/Backbone.Todos");
  
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
  
  Using_DeCoupled_Callbacks() { 
    print("  - Using_DeCoupled_Callbacks(): ");
    
    deleteTodos(List existingTodos, [Function callback]) {    
      int asyncCount=existingTodos.length;
      if (asyncCount == 0) 
        return callback == null ? null : callback(); 
      
      existingTodos.forEach((x) => client.delete('todos/${x['id']}', 
        (_){ if (--asyncCount == 0 && callback != null) callback(); })
      );
    }
    
    createTodos(List newTodos, [Function callback]) {
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
  }
  
  Using_Coupled_Callbacks() {
    print("  - Using_Coupled_Callbacks(): ");

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
  }
  
  Using_Futures() {   
    print("  - Using_Futures(): ");

    client.todos()
      .then((List existingTodos) {
        Futures.wait(existingTodos.map((x) => client.delete('todos/${x['id']}')))
          .then((_) { 
              int i=0;
              Futures.wait(todos.map((text) => client.todos({'content':text, 'order':i++})))
                .then(markTodoCompleted);
          });      
      });    
  }

  if (option == 1) Using_DeCoupled_Callbacks();
  if (option == 2) Using_Coupled_Callbacks();
  if (option == 3) Using_Futures();    
}

void main() {
  print("Running JsonClient Examples...\n"); 
  
  Do_RestFiles();
  Do_Northwind();
  Do_BackboneTodos(1);
  
  print("\nDone!");
}
