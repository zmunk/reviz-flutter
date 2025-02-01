import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class ScrollableTileList extends StatefulWidget {
  const ScrollableTileList({super.key});

  @override
  State<ScrollableTileList> createState() => _ScrollableTileListState();
}

class _ScrollableTileListState extends State<ScrollableTileList> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: tileListNotifier,
      builder: (context, tiles, child) {
        return ListView.builder(
          itemCount: tiles.length,
          itemBuilder: (context, index) {
            return ListTile(title: Text(tiles[index]));
          },
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  void _showAddTileDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add a New Tile'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Enter tile name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  Navigator.of(context).pop(); // Close the dialog
                  tileListNotifier.addTile(controller.text); // Add the new tile
                }
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: ScrollableTileList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // show alert dialog that allows user to create a new tile
          _showAddTileDialog(context);
        },
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

// Create a global instance of TileListNotifier
final tileListNotifier = TileListNotifier();

class TileListNotifier extends ChangeNotifier
    implements ValueListenable<List<String>> {
  List<String> _tiles = [];

  // Required by ValueListenable
  @override
  List<String> get value => _tiles;

  TileListNotifier() {
    _loadTiles(); // Load tiles when the notifier is created
  }

  // Load tiles from SharedPreferences
  Future<void> _loadTiles() async {
    final prefs = await SharedPreferences.getInstance();
    _tiles = prefs.getStringList('tiles') ?? [];
  }

  // Save tiles to SharedPreferences
  Future<void> _saveTiles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('tiles', _tiles);
  }

  // Add a new tile and save to SharedPreferences
  void addTile(String text) {
    _tiles.add(text);
    _saveTiles(); // Save the updated list to SharedPreferences
    notifyListeners(); // Notify listeners to update the UI
  }
}
