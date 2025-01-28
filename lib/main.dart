import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

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
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blueAccent, brightness: Brightness.light),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ScrollableTileList extends StatefulWidget {
  const ScrollableTileList({super.key});

  @override
  State<ScrollableTileList> createState() => _ScrollableTileListState();
}

int getDaysSinceDate(String isoDate) {
  DateTime date = DateTime.parse(isoDate);
  DateTime now = DateTime.now();
  Duration difference = now.difference(date);
  return difference.inDays;
}

class _ScrollableTileListState extends State<ScrollableTileList> {
  int? _selectedIndex; // tracks index of selected tile
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: tileListNotifier,
      builder: (context, tiles, child) {
        return ListView.builder(
          itemCount: tiles.length,
          itemBuilder: (context, index) {
            int daysSince = getDaysSinceDate(tiles[index]['date']);

            // if at least 14 days have passed, show red
            // otherwise show a color between green and red
            const expirationDays = 14;
            double colorInterp = (daysSince / expirationDays).clamp(0.0, 1.0);

            return InkWell(
                onLongPress: () {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                child: Container(
                    color: index == _selectedIndex
                        ? Colors.blue.withAlpha(77)
                        : Colors.transparent,
                    child: ListTile(
                        title: Text(
                          tiles[index]['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        trailing: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 12.0, vertical: 6.0),
                          decoration: BoxDecoration(
                            color: Color.lerp(
                                    Colors.green, Colors.red, colorInterp)!
                                .withAlpha(
                                    230), // Interpolate between green and red based on `colorInterp`
                            borderRadius:
                                BorderRadius.circular(16.0), // Rounded corners
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 2,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            "$daysSince d",
                            style: TextStyle(
                              color: Colors.white, // Text color
                              fontSize: 12.0, // Text size
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ))));
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
          title: Text(
            'Add a New Tile',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Enter tile name',
              filled: true,
              fillColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest, // Replaced surfaceVariant with surfaceContainerHighest
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  Navigator.of(context).pop(); // Close the dialog
                  tileListNotifier.addTile(controller.text); // Add the new tile
                }
              },
              child: Text(
                'Add',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
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
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        title: Text(widget.title),
      ),
      body: ScrollableTileList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // show alert dialog that allows user to create a new tile
          _showAddTileDialog(context);
        },
        tooltip: 'Increment',
        backgroundColor: Theme.of(context).colorScheme.secondary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// Create a global instance of TileListNotifier
final tileListNotifier = TileListNotifier();

class TileListNotifier extends ChangeNotifier
    implements ValueListenable<List<Map<String, dynamic>>> {
  List<Map<String, dynamic>> _tiles = [];

  // Required by ValueListenable
  @override
  List<Map<String, dynamic>> get value => _tiles;

  TileListNotifier() {
    _loadTiles(); // Load tiles when the notifier is created
  }

  // Load tiles from SharedPreferences
  Future<void> _loadTiles() async {
    final prefs = await SharedPreferences.getInstance();

    final List<String>? tilesJson = prefs.getStringList('tiles');
    if (tilesJson != null) {
      _tiles = tilesJson
          .map((json) => Map<String, dynamic>.from(jsonDecode(json)))
          .toList();
    }
  }

  // Save tiles to SharedPreferences
  Future<void> _saveTiles() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> tilesJson =
        _tiles.map((tile) => jsonEncode(tile)).toList();
    await prefs.setStringList('tiles', tilesJson);
  }

  // Add a new tile and save to SharedPreferences
  void addTile(String text) {
    _tiles.add({'name': text, 'date': DateTime.now().toIso8601String()});
    _saveTiles(); // Save the updated list to SharedPreferences
    notifyListeners(); // Notify listeners to update the UI
  }
}
