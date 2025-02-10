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
            seedColor: Colors.green.shade200, brightness: Brightness.light),
        useMaterial3: true,
      ),
      home: MyHomePage(title: 'Tasks'),
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

final redHSV = HSVColor.fromColor(Colors.red);
final yellowHSV = HSVColor.fromColor(Colors.yellow.shade800);
final greenHSV = HSVColor.fromColor(Colors.green);

// if at least 14 days have passed, show red
// otherwise show a color between green and yellow or yellow and red
Color getPillColor(int days) {
  const expirationDays = 14;
  HSVColor startHSV, endHSV;
  double ratio;
  if (days <= expirationDays / 2) {
    startHSV = greenHSV;
    endHSV = yellowHSV;
    ratio = days / (expirationDays / 2);
  } else {
    startHSV = yellowHSV;
    endHSV = redHSV;
    ratio = (days - expirationDays / 2) / (expirationDays / 2);
  }
  ratio = ratio.clamp(0, 1);
  return HSVColor.lerp(startHSV, endHSV, ratio)!.toColor();
}

class ScrollableTileList extends StatefulWidget {
  final TileListNotifier tileListNotifier;
  final Function(int?) onSelection;
  final bool Function() isSelectionModeEnabled;

  const ScrollableTileList(
      {super.key,
      required this.tileListNotifier,
      required this.onSelection,
      required this.isSelectionModeEnabled});

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

  void updateTileName(String text) {
    if (_selectedIndex != null) {
      widget.tileListNotifier.updateTileName(_selectedIndex!, text);
    }
  }

  String? getSelectedTileText() {
    if (_selectedIndex != null) {
      return widget.tileListNotifier.getTileName(_selectedIndex!);
    } else {
      return null;
    }
  }

  void deleteSelectedTile() {
    if (_selectedIndex != null) {
      widget.tileListNotifier.deleteTile(_selectedIndex!);
      _handleSelection(null);
    }
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
            final int daysSince = getDaysSinceDate(tiles[index]['date']);
            final Color pillColor = getPillColor(daysSince);
            final isSelected = index == _selectedIndex;

            return InkWell(
              key: Key("$index"),
              onLongPress: () => _handleSelection(index),
              onTap: () {
                if (widget.isSelectionModeEnabled()) {
                  _handleSelection(index);
                }
              },
              child: Container(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                child: Row(
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: Container(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.drag_indicator,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surfaceDim,
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
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        trailing: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 12.0, vertical: 6.0),
                          decoration: BoxDecoration(
                            color: pillColor.withAlpha(230),
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

  bool isSelectionModeEnabled() => _selectionModeEnabled;

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
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          leading: _selectionModeEnabled
              ? IconButton(
                  icon: Icon(Icons.close,
                      color: Theme.of(context).colorScheme.onPrimary),
                  onPressed: _exitSelectionMode,
                )
              : null,
          backgroundColor: _selectionModeEnabled
              ? Theme.of(context).colorScheme.tertiary
              : Theme.of(context).colorScheme.secondary,
          title: Text(
            _selectionModeEnabled ? "" : widget.title,
            style: TextStyle(
              color: _selectionModeEnabled
                  ? Theme.of(context).colorScheme.onTertiary
                  : Theme.of(context).colorScheme.onSecondary,
            ),
          ),
          actions: _selectionModeEnabled
              ? [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: PopupMenuButton<String>(
                      color: Theme.of(context).colorScheme.surface,
                      icon: Icon(
                        Icons.more_vert,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      onSelected: (String value) {
                        if (value == "rename") {
                          showDialog(
                            // show alert dialog that allows user to rename tile
                            context: context,
                            builder: (context) => InputDialog(
                              title: "Rename Task",
                              submitButtonName: "Save",
                              onSubmit: (text) {
                                _tileListKey.currentState?.updateTileName(text);
                                _exitSelectionMode();
                              },
                              initialText: _tileListKey.currentState
                                      ?.getSelectedTileText() ??
                                  "",
                            ),
                          );
                        } else if (value == "delete") {
                          _tileListKey.currentState?.deleteSelectedTile();
                        }
                      },
                      itemBuilder: (BuildContext context) {
                        return [
                          PopupMenuItem<String>(
                            value: 'rename',
                            child: Text('Rename'),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ];
                      },
                    ),
                  ),
                ]
              : null,
        ),
        body: ScrollableTileList(
          key: _tileListKey,
          tileListNotifier: widget.tileListNotifier,
          onSelection: _tileSelected,
          isSelectionModeEnabled: isSelectionModeEnabled,
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            if (_selectionModeEnabled) {
              _tileListKey.currentState?.resetSelectedTileDate();
            } else {
              showDialog(
                // show alert dialog that allows user to create a new tile
                context: context,
                builder: (context) => InputDialog(
                  title: 'Add a New Task',
                  submitButtonName: "Add",
                  onSubmit: (text) => widget.tileListNotifier.addTile(text),
                ),
              );
            }
          },
          tooltip: _selectionModeEnabled ? 'Reset date' : 'Add tile',
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

class InputDialog extends StatefulWidget {
  final String title;
  final String submitButtonName;
  final String initialText;
  final Function(String) onSubmit;

  const InputDialog({
    super.key,
    required this.title,
    required this.submitButtonName,
    required this.onSubmit,
    this.initialText = "",
  });

  @override
  State<InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<InputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: 'Enter task name',
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
            widget.submitButtonName,
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

  void updateTileName(int tileIndex, String text) {
    _tiles[tileIndex]['name'] = text;
    _saveTiles();
    notifyListeners();
  }

  String getTileName(int tileIndex) {
    return _tiles[tileIndex]['name'];
  }

  void deleteTile(int tileIndex) {
    _tiles.removeAt(tileIndex);
    _saveTiles();
  }
}
