#!/usr/bin/env dart

import '../lib/json_client.dart';
import 'dart:io';
import "dart:async";

JsonClient newClient(String url) =>
  new JsonClient(url)
    ..logLevel = LogLevel.Error;

Do_Rockstars(){
  var client = newClient("http://razor.servicestack.net/");
  client.rockstars
    .then(print);
  client.rockstars()
    .then(print);
  client.rockstars(1)
    .then(print);  
}

Do_Northwind(){
  print("Do_Northwind(): ");

  var client = newClient("http://www.servicestack.net/ServiceStack.Northwind");  
  client.customers()
    .then((response) { 
      var mexicanNames = response['Customers']
          .where((x) => x['Country'] == "Mexico")
          .map((x) => x['ContactName'])
          .toList();
      
      print("Mexican Customers: $mexicanNames");
    });
}

Do_RestFiles(){
  print("Do_RestFiles(): ");
  
  var client = newClient("http://mono.servicestack.net/RestFiles");
  
  client.files
    .then((r) => print("GET response: ${r}"));
  
  client.files("dtos/Operations/RevertFiles.cs.txt")
    .then((r) => print("GET response: $r"));

  client.get('files/Global.asax.cs.txt')
    .then((r) => print("Global.asax:\n\n${r['File']['Contents']}"));  
  
  int nowMs = (new DateTime.now()).millisecondsSinceEpoch;
  client.files({'path':'newFolder$nowMs'}, (r) => print("POST response: ${r}") );

  client.files('?path=services', (r) => print("GET response: ${r}") );
  client.get('files?path=services')
    .then((r) => print("GET response: ${r}"));

  print("Testing error handler on invalid requests...");
  client.post('files?forDownload=1BrokenRequest')
    .catchError((e) => print("POST error response: ${e}"));
}

Do_BackboneTodos(){
  print("Do_BackboneTodos(): ");
  
  var client = newClient("http://mono.servicestack.net/Backbone.Todos/");
  
  List todos = [
    'Learn Dart!', 
    'Clear all existing todo items',
    'Add all these todos',
    'Mark this todo as done',
    'do ALL THE THINGS!'
  ];
  final String completeTodo = 'Mark this todo as done';

  markTodoCompleted(List createdTodos) {
    List matchingTodos = createdTodos.where((x) => x['content'] == completeTodo).toList();
    var todo = matchingTodos[0];
    todo['done'] = true;
    client.put("todos/${todo['id']}", todo);    
  }
    
  client.todos()
    .then((List existingTodos){
      Future.wait(existingTodos.map((x) => client.delete('todos/${x['id']}')) )
        .then((_) { 
            int i=0;
            Future.wait( todos.map((text) => client.todos({'content':text, 'order':i++})) )
              .then( markTodoCompleted );
        });      
    });    
}

void main() {
  print("Running JsonClient Examples...\n"); 
  
  Do_Rockstars();
  Do_RestFiles();
  Do_Northwind();
  Do_BackboneTodos();
  
  print("\nDone!");
}
