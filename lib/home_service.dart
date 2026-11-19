import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';

// CRUD SERVICE
class CrudService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // READ
  Stream<QuerySnapshot<Map<String, dynamic>>> getItems() {
    return _firestore.collection('items').snapshots();
  }

  // CREATE
  Future<void> addItem(String name, int quantity) {
    return _firestore.collection('items').add({
      'name': name,
      'quantity': quantity,
      'isFavorite': false,
    });
  }

  // UPDATE
  Future<void> updateItem(String id, String name, int quantity) {
    return _firestore.collection('items').doc(id).update({
      'name': name,
      'quantity': quantity,
    });
  }

  Future<void> updateFavorite(String id, bool isFavorite) {
    return _firestore.collection('items').doc(id).update({
      'isFavorite': isFavorite,
    });
  }

  // DELETE
  Future<void> deleteItem(String id) {
    return _firestore.collection('items').doc(id).delete();
  }
}

// HOME PAGE
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final CrudService service = CrudService();

  final TextEditingController nameCtrl = TextEditingController();

  final TextEditingController qtyCtrl = TextEditingController();

  bool _showFavoritesOnly = false;

  @override
  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    super.dispose();
  }

  // MAIN UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey,

      // APP BAR
      appBar: AppBar(
        title: const Text('Firebase Diano'),
        centerTitle: true,
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await AuthService().signOut();
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Sign out failed: $error')),
                );
              }
            },
          ),
        ],
      ),

      // ADD BUTTON
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => openAddDialog(context),
      ),

      // READ DATA
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.getItems(),

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong!'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('No Items Found'));
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text('NO Items Found', style: TextStyle(fontSize: 18)),
            );
          }

          final visibleDocs = _showFavoritesOnly
              ? docs.where((item) => item.data()['isFavorite'] == true).toList()
              : docs;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: FilterChip(
                  avatar: const Icon(Icons.favorite),
                  label: const Text('Favorites only'),
                  selected: _showFavoritesOnly,
                  onSelected: (selected) {
                    setState(() => _showFavoritesOnly = selected);
                  },
                ),
              ),
              if (visibleDocs.isEmpty)
                const Expanded(
                  child: Center(child: Text('No favorite items yet.')),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: visibleDocs.length,
                    itemBuilder: (context, index) {
                      final item = visibleDocs[index];
                      final isFavorite = item.data()['isFavorite'] == true;

                      return Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          title: Text(
                            item.data()['name'] ?? '',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Quantity: ${item.data()['quantity'] ?? 0}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: isFavorite
                                    ? 'Remove from favorites'
                                    : 'Add to favorites',
                                icon: Icon(
                                  isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isFavorite ? Colors.red : Colors.grey,
                                ),
                                onPressed: () async {
                                  try {
                                    await service.updateFavorite(
                                      item.id,
                                      !isFavorite,
                                    );
                                  } catch (error) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Could not update favorite: $error',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.orange,
                                ),
                                onPressed: () {
                                  openEditDialog(context, item);
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  _confirmDelete(context, item.id);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // DELETE UI
  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete item'),

        content: const Text('Are you sure you want to delete this item?'),

        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.pop(dialogContext);
            },
          ),

          TextButton(
            child: const Text('Delete', style: TextStyle(color: Colors.red)),

            onPressed: () async {
              try {
                await service.deleteItem(id);

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              } catch (e) {
                debugPrint('Delete error: $e');
              }
            },
          ),
        ],
      ),
    );
  }

  // ADD UI
  void openAddDialog(BuildContext context) {
    nameCtrl.clear();
    qtyCtrl.clear();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add item'),

        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // FIRST BOX - NAME
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // SECOND BOX - QUANTITY
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),

        actions: [
          // CANCEL
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.pop(dialogContext);
            },
          ),

          // SAVE
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),

            child: const Text('Save', style: TextStyle(color: Colors.white)),

            onPressed: () async {
              final name = nameCtrl.text.trim();
              final quantity = int.tryParse(qtyCtrl.text.trim());

              if (name.isEmpty || quantity == null || quantity < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid name and quantity.'),
                  ),
                );
                return;
              }

              try {
                await service.addItem(name, quantity);

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              } catch (e) {
                debugPrint('Add error: $e');
              }
            },
          ),
        ],
      ),
    );
  }

  // EDIT UI
  void openEditDialog(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> item,
  ) {
    nameCtrl.text = item.data()?['name'] ?? '';
    qtyCtrl.text = item.data()?['quantity']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Item'),

        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // NAME
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // QUANTITY
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),

        actions: [
          // CANCEL
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.pop(dialogContext);
            },
          ),

          // UPDATE
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),

            child: const Text('Update', style: TextStyle(color: Colors.white)),

            onPressed: () async {
              final name = nameCtrl.text.trim();
              final quantity = int.tryParse(qtyCtrl.text.trim());

              if (name.isEmpty || quantity == null || quantity < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid name and quantity.'),
                  ),
                );
                return;
              }

              try {
                await service.updateItem(item.id, name, quantity);

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              } catch (e) {
                debugPrint('Update error: $e');
              }
            },
          ),
        ],
      ),
    );
  }
}
