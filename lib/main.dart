import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';

enum ActionType { Insert, Remove }

class Action {
  WordPair wordPair;
  ActionType type;

  Action(this.wordPair, this.type);
}

Set<WordPair> wordPairReducer(Set<WordPair> state, dynamic action) {
  var a = new Set<WordPair>.from(state);
  if (action.type == ActionType.Insert) {
    a.add(action.wordPair);
  }

  if (action.type == ActionType.Remove) {
    a.remove(action.wordPair);
  }

  return a;
}

void main() {
  final store = new Store<Set<WordPair>>(
    wordPairReducer,
    initialState: new Set<WordPair>(),
  );

  runApp(MyApp(store: store, title: 'Startup Name Generator'));
}

class MyApp extends StatelessWidget {
  final Store<Set<WordPair>> store;
  final String title;

  MyApp({Key key, this.store, this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreProvider<Set<WordPair>>(
      store: store,
      child: MaterialApp(
        title: title,
        theme: new ThemeData(
          primaryColor: Colors.green,
        ),
        home: RandomWords(),
      ),
    );
  }
}

class RandomWordsState extends State<RandomWords> {
  final _suggestions = <WordPair>[];
  final _biggerFont = const TextStyle(fontSize: 18.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Startup Name Generator'),
        actions: <Widget>[
          new IconButton(icon: const Icon(Icons.list), onPressed: _pushSaved),
        ],
      ),
      body: _buildSuggestions(),
    );
  }

  void _pushSaved() {
    Navigator
        .of(context)
        .push(new MaterialPageRoute<void>(builder: (BuildContext context) {
      return new Scaffold(
          appBar: new AppBar(
            title: const Text('Saved suggestions'),
          ),
          body: new StoreBuilder<Set<WordPair>>(
            rebuildOnChange: false,
            builder: (context, store) {
              final Iterable<Widget> tiles = store.state.map((WordPair pair) {
                return _buildRow(pair);
              });
              final List<Widget> divided = ListTile
                  .divideTiles(
                    context: context,
                    tiles: tiles,
                  )
                  .toList();
              return new ListView(children: divided);
            },
          ));
    }));
  }

  Widget _buildSuggestions() {
    return ListView.builder(
        padding: const EdgeInsets.all(16.0),
        // The itemBuilder callback is called once per suggested word pairing,
        // and places each suggestion into a ListTile row.
        // For even rows, the function adds a ListTile row for the word pairing.
        // For odd rows, the function adds a Divider widget to visually
        // separate the entries. Note that the divider may be difficult
        // to see on smaller devices.
        itemBuilder: (context, i) {
          // Add a one-pixel-high divider widget before each row in theListView.
          if (i.isOdd) return Divider();

          // The syntax "i ~/ 2" divides i by 2 and returns an integer result.
          // For example: 1, 2, 3, 4, 5 becomes 0, 1, 1, 2, 2.
          // This calculates the actual number of word pairings in the ListView,
          // minus the divider widgets.
          final index = i ~/ 2;
          // If you've reached the end of the available word pairings...
          if (index >= _suggestions.length) {
            // ...then generate 10 more and add them to the suggestions list.
            _suggestions.addAll(generateWordPairs().take(10));
          }
          return _buildRow(_suggestions[index]);
        });
  }

  Widget _buildRow(WordPair pair) {
    return StoreBuilder<Set<WordPair>>(builder: (context, store) {
      final bool alreadySaved = store.state.contains(pair);
      return new ListTile(
        title: Text(
          pair.asPascalCase,
          style: _biggerFont,
        ),
        trailing: new Icon(
          alreadySaved ? Icons.favorite : Icons.favorite_border,
          color: alreadySaved ? Colors.red : null,
        ),
        onTap: () {
          if (alreadySaved) {
            store.dispatch(new Action(pair, ActionType.Remove));
          } else {
            store.dispatch(new Action(pair, ActionType.Insert));
          }
        },
      );
    });
  }
}

class RandomWords extends StatefulWidget {
  @override
  RandomWordsState createState() => new RandomWordsState();
}
