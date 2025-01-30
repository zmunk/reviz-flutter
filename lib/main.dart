import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
      home: MyHomePage(title: 'Flutter Demo Home Page'),
      debugShowCheckedModeBanner: false,
    );
  }
}

int getDaysSinceDate(String isoDate) {
  DateTime date = DateTime.parse(isoDate);
  DateTime now = DateTime.now();
  Duration difference = now.difference(date);
  return difference.inDays;
}

class ScrollableTileList extends StatefulWidget {
  final TileListNotifier tileListNotifier;
  final Function(int?) onSelection;

  const ScrollableTileList(
      {super.key, required this.tileListNotifier, required this.onSelection});

  @override
  State<ScrollableTileList> createState() => _ScrollableTileListState();
}

class _ScrollableTileListState extends State<ScrollableTileList> {
  int? _selectedIndex; // tracks index of selected tile

  void exitSelectionMode() {
    _handleSelection(null);
  }

  void _handleSelection(int? index) {
    widget.onSelection(index);
    setState(() {
      _selectedIndex = index;
    });
  }

  void resetSelectedTileDate() {
    widget.tileListNotifier.resetTileDate(_selectedIndex);
    exitSelectionMode();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.tileListNotifier,
      builder: (context, tiles, child) {
        return ReorderableListView(
          buildDefaultDragHandles: false, // Disable default right handle
          onReorder: (int oldIndex, int newIndex) async {
            if (oldIndex < newIndex) {
              newIndex -= 1;
            }
            int? newSelectedIndex = _selectedIndex;
            if (_selectedIndex != null) {
              if (oldIndex < _selectedIndex! && _selectedIndex! <= newIndex) {
                newSelectedIndex = _selectedIndex! - 1;
              } else if (newIndex <= _selectedIndex! &&
                  _selectedIndex! < oldIndex) {
                newSelectedIndex = _selectedIndex! + 1;
              } else if (_selectedIndex! == oldIndex) {
                newSelectedIndex = newIndex;
              }
            }
            setState(() => _selectedIndex = newSelectedIndex);
            widget.tileListNotifier.moveTile(oldIndex, newIndex);
          },
          children: List.generate(tiles.length, (index) {
            int daysSince = getDaysSinceDate(tiles[index]['date']);

            // if at least 14 days have passed, show red
            // otherwise show a color between green and red
            const expirationDays = 14;
            double colorInterp = (daysSince / expirationDays).clamp(0.0, 1.0);

            return InkWell(
              key: Key("$index"),
              onLongPress: () => _handleSelection(index),
              child: Container(
                color: index == _selectedIndex
                    ? Colors.blue.withAlpha(77)
                    : Colors.transparent,
                child: Row(
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: Container(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.drag_indicator,
                          color: Colors.grey.withAlpha(180),
                          size: 24.0,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
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
                            borderRadius: BorderRadius.circular(16.0),
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
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  final TileListNotifier tileListNotifier = TileListNotifier();

  MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _selectionModeEnabled = false;
  final GlobalKey<_ScrollableTileListState> _tileListKey = GlobalKey();

  void _tileSelected(int? index) {
    setState(() {
      _selectionModeEnabled = index != null;
    });
  }

  void _exitSelectionMode() {
    _tileListKey.currentState?.exitSelectionMode();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        // override back navigation
        if (_selectionModeEnabled) {
          // disable selection mode but don't navigate back
          _exitSelectionMode();
        } else if (Navigator.canPop(context)) {
          // navigate back
          Navigator.of(context).pop();
        } else {
          // if no previous screen, exit app
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _selectionModeEnabled
              ? IconButton(
                  icon: Icon(Icons.close,
                      color: Theme.of(context).colorScheme.onPrimary),
                  onPressed: _exitSelectionMode,
                )
              : null,
          backgroundColor: _selectionModeEnabled
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.primaryContainer,
          title: Text(
            _selectionModeEnabled ? "" : widget.title,
            style: TextStyle(
              color: _selectionModeEnabled
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        body: ScrollableTileList(
          key: _tileListKey,
          tileListNotifier: widget.tileListNotifier,
          onSelection: _tileSelected,
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            if (_selectionModeEnabled) {
              _tileListKey.currentState?.resetSelectedTileDate();
            } else {
              showDialog(
                // show alert dialog that allows user to create a new tile
                context: context,
                builder: (context) => AddTileDialog(
                  onSubmit: (text) => widget.tileListNotifier.addTile(text),
                ),
              );
            }
          },
          tooltip: _selectionModeEnabled ? 'Reset data' : 'Add tile',
          backgroundColor: _selectionModeEnabled
              ? Colors.green
              : Theme.of(context).colorScheme.primary,
          shape: _selectionModeEnabled ? CircleBorder() : null,
          child: Icon(_selectionModeEnabled ? Icons.done : Icons.add,
              color: Colors.white),
        ),
      ),
    );
  }
}

class AddTileDialog extends StatefulWidget {
  final Function(String) onSubmit;
  const AddTileDialog({super.key, required this.onSubmit});

  @override
  State<AddTileDialog> createState() => _AddTileDialogState();
}

class _AddTileDialogState extends State<AddTileDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Add a New Tile',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: 'Enter tile name',
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
            if (_controller.text.isNotEmpty) {
              Navigator.of(context).pop(); // Close the dialog
              widget.onSubmit(_controller.text);
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
  }
}

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
    notifyListeners();
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
    _saveTiles();
    notifyListeners(); // Notify listeners to update the UI
  }

  void moveTile(int oldIndex, int newIndex) {
    final tile = _tiles.removeAt(oldIndex);
    _tiles.insert(newIndex, tile);
    _saveTiles();
  }

  void resetTileDate(int? tileIndex) {
    if (tileIndex != null) {
      _tiles[tileIndex]['date'] = DateTime.now().toIso8601String();
    }
    _saveTiles();
    notifyListeners();
  }
}
