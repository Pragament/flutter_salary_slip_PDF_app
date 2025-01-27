import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/services/base/database/hive_manager/models.dart';
import 'package:flutter_template/services/providers/cur_group_provider.dart';
import 'package:go_router/go_router.dart';

class ItemsList extends ConsumerStatefulWidget {
  final String title;
  final List<dynamic> items;
  final void Function(dynamic switched) onSwitch;

  const ItemsList({super.key, required this.title, required this.items, required this.onSwitch});

  @override
  ConsumerState<ItemsList> createState() => _ItemsListState();
}

class _ItemsListState extends ConsumerState<ItemsList> {
  late TextEditingController _searchController;
  late List<dynamic> _filteredItems;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredItems = widget.items; // Initialize with all items

    _searchController.addListener(() {
      setState(() {
        _filteredItems = widget.items
            .where((item) =>
            item.name.toLowerCase().contains(_searchController.text.toLowerCase()))
            .toList();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          // Search Box
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          if(widget.title=="Switch Group")ElevatedButton(onPressed: (){
            ref.read(currentGroupProvider.notifier).setGroup(Group("All Groups", null,
                {}, "allGroups"));
            context.pop();
          }, child: Text("Select All",style: TextStyle(color: Colors.white),),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade700,
              minimumSize: const Size(200, 50),
            ),
          ),
          // Filtered List
          Expanded(
            child: ListView.builder(
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Card(
                    elevation: 3,
                    color: Colors.grey.shade100,
                    child: ListTile(
                      title: Text(_filteredItems[index].name),
                      onTap: () {
                        widget.onSwitch(_filteredItems[index]);
                        context.pop();
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
