import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:http/http.dart' as http;
import 'package:quiver/core.dart';

class ListState {
  NotificationListenerCallback callback;
  List<String> items;

  ListState(this.callback, this.items);

  bool operator ==(o) => o is ListState && o.items == items;
  int get hashCode => hash2(callback.hashCode, items.hashCode);
}

class InsertWordPair {
  String wordPair;
  InsertWordPair(this.wordPair);
}

class RemoveWordPair {
  String wordPair;
  RemoveWordPair(this.wordPair);
}

class AddSuggestions {
  List<String> items;
  AddSuggestions(this.items);
}

class WordListState {
  Set<String> favorites;
  List<String> items;

  WordListState({this.favorites, this.items});
}

final favoritesReducer = combineReducers<Set<String>>([
  TypedReducer<Set<String>, RemoveWordPair>(removeFavorite),
  TypedReducer<Set<String>, InsertWordPair>(addFavorite)
]);

Set<String> removeFavorite(Set<String> favorites, RemoveWordPair action) {
  return Set<String>.from(favorites)..remove(action.wordPair);
}

Set<String> addFavorite(Set<String> favorites, InsertWordPair action) {
  return Set<String>.from(favorites)..add(action.wordPair);
}

final itemsReducer = combineReducers<List<String>>([
  TypedReducer<List<String>, AddSuggestions>(addSuggestions),
]);

List<String> addSuggestions(List<String> items, AddSuggestions action) {
  return List<String>.from(items)..addAll(action.items);
}

WordListState wordListStateReducer(WordListState state, action) {
  return WordListState(
      favorites: favoritesReducer(state.favorites, action),
      items: itemsReducer(state.items, action));
}

void main() {
  final store = Store<WordListState>(
    wordListStateReducer,
    initialState:
        WordListState(favorites: Set<String>(), items: List<String>()),
  );

  runApp(MyApp(store: store, title: 'Startup Name Generator'));
}

String getSuggestion(List<String> data) {
  var rng = new Random();
  String w1 = data[rng.nextInt(data.length)];
  String w2 = data[rng.nextInt(data.length)];

  return w1.substring(0, 1).toUpperCase() +
      w1.substring(1) +
      w2.substring(0, 1).toUpperCase() +
      w2.substring(1);
}

Future<List<String>> fetchSuggestions(int number) async {
  debugPrint("fetching " + number.toString());
  await new Future.delayed(const Duration(seconds: 1));
  final response =
      await http.get('https://www.randomlists.com/data/words.json');

  if (response.statusCode == 200) {
    // If the call to the server was successful, parse the JSON
    List<String> data = json.decode(response.body)['data'].cast<String>();
    var suggestions = List<String>();
    for (int i = 0; i < number; ++i) {
      suggestions.add(getSuggestion(data));
    }
    return suggestions;
  } else {
    // If that call was not successful, throw an error.
    throw Exception('Failed to load post');
  }
}

class MyApp extends StatelessWidget {
  final Store<WordListState> store;
  final String title;

  MyApp({Key key, this.store, this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    fetchSuggestions(20).then((sugg) => store.dispatch(AddSuggestions(sugg)));
    return StoreProvider<WordListState>(
      store: store,
      child: MaterialApp(
        title: title,
        theme: ThemeData(
          primaryColor: Colors.green,
        ),
        home: RandomWords(),
      ),
    );
  }
}

Widget _buildRow(String pair) {
  final _biggerFont = const TextStyle(fontSize: 18.0);
  return StoreBuilder<WordListState>(builder: (context, store) {
    final bool alreadySaved = store.state.favorites.contains(pair);
    return ListTile(
      title: Text(
        pair,
        style: _biggerFont,
      ),
      trailing: Icon(
        alreadySaved ? Icons.favorite : Icons.favorite_border,
        color: alreadySaved ? Colors.red : null,
      ),
      onTap: () {
        if (alreadySaved) {
          store.dispatch(RemoveWordPair(pair));
        } else {
          store.dispatch(InsertWordPair(pair));
        }
      },
    );
  });
}

class MyList extends StatelessWidget {
  var _running = false;

  _scrollListener(
      void call(_), int number, ScrollNotification notification) async {
    if (!_running &&
        notification.metrics.pixels >
            0.80 * notification.metrics.maxScrollExtent) {
      _running = true;
      debugPrint(notification.metrics.pixels.toString());
      debugPrint(notification.metrics.maxScrollExtent.toString());
      var sugg = await fetchSuggestions(number);
      call(AddSuggestions(sugg));
      _running = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<WordListState, ListState>(
        converter: (store) => ListState(
            (notification) {
              _scrollListener(store.dispatch, store.state.items.length, notification);
              return true;
            },
            store.state.items),
        distinct: true,
        builder: (context, state) {
          debugPrint("buildList");
          return NotificationListener<ScrollNotification>(
            onNotification: state.callback,
            child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: state.items.length * 2,
                // The itemBuilder callback is called once per suggested word pairing,
                // and places each suggestion into a ListTile row.
                // For even rows, the function adds a ListTile row for the word pairing.
                // For odd rows, the function adds a Divider widget to visually
                // separate the entries. Note that the divider may be difficult
                // to see on smaller devices.
                itemBuilder: (context, i) {
                  // Add a one-pixel-high divider widget before each row in theListView.
                  if (i.isOdd) return Divider();
                  return _buildRow(state.items[i ~/ 2]);
                }),
          );
        });
  }
}

class RandomWords extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Startup Name Generator'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => _buildFavorites())),
          ),
        ],
      ),
      body: _buildSuggestions(),
    );
  }

  Widget _buildFavorites() {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Saved suggestions'),
        ),
        body: StoreConnector<WordListState, Set<String>>(
          distinct: true,
          converter: (store) => store.state.favorites,
          rebuildOnChange: false,
          builder: (context, favorites) {
            final Iterable<Widget> tiles = favorites.map((String pair) {
              return _buildRow(pair);
            });
            final List<Widget> divided = ListTile
                .divideTiles(
                  context: context,
                  tiles: tiles,
                )
                .toList();
            return ListView(children: divided);
          },
        ));
  }

  Widget _buildSuggestions() {
    return MyList();
  }
}