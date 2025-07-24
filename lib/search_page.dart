import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toko_online_material/product_card.dart';
import '../models/product.dart';
import '../models/category.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  
  String _searchQuery = '';
  String _selectedCategoryId = '';
  String _selectedPriceRange = '';
  String _sortBy = 'newest';
  bool _isGridView = true;
  bool _isLoading = false;
  
  List<Product> _searchResults = [];
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _searchFocus.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('categories')
          .orderBy('name')
          .get();
      
      setState(() {
        _categories = snapshot.docs
            .map((doc) => Category.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _performSearch() async {
    if (_searchQuery.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      Query query = FirebaseFirestore.instance
          .collection('products')
          .where('isActive', isEqualTo: true);

      // Add category filter
      if (_selectedCategoryId.isNotEmpty) {
        query = query.where('categoryId', isEqualTo: _selectedCategoryId);
      }

      final snapshot = await query.get();
      
      List<Product> results = snapshot.docs
          .map((doc) => Product.fromFirestore(doc))
          .where((product) {
            final searchLower = _searchQuery.toLowerCase();
            return product.name.toLowerCase().contains(searchLower) ||
                   product.description.toLowerCase().contains(searchLower) ||
                   product.categoryName.toLowerCase().contains(searchLower) ||
                   product.sku.toLowerCase().contains(searchLower);
          })
          .toList();

      // Apply price filter
      if (_selectedPriceRange.isNotEmpty) {
        results = _filterByPrice(results);
      }

      // Apply sorting
      results = _sortProducts(results);

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Product> _filterByPrice(List<Product> products) {
    switch (_selectedPriceRange) {
      case 'under_100k':
        return products.where((p) => p.price < 100000).toList();
      case '100k_500k':
        return products.where((p) => p.price >= 100000 && p.price < 500000).toList();
      case '500k_1m':
        return products.where((p) => p.price >= 500000 && p.price < 1000000).toList();
      case 'over_1m':
        return products.where((p) => p.price >= 1000000).toList();
      default:
        return products;
    }
  }

  List<Product> _sortProducts(List<Product> products) {
    switch (_sortBy) {
      case 'price_low':
        products.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_high':
        products.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'name':
        products.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'newest':
      default:
        products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    return products;
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      const Text(
                        'Filter & Urutkan',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedCategoryId = '';
                            _selectedPriceRange = '';
                            _sortBy = 'newest';
                          });
                          setState(() {
                            _selectedCategoryId = '';
                            _selectedPriceRange = '';
                            _sortBy = 'newest';
                          });
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Category Filter
                  const Text(
                    'Kategori',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Semua'),
                        selected: _selectedCategoryId.isEmpty,
                        onSelected: (selected) {
                          setModalState(() {
                            _selectedCategoryId = '';
                          });
                          setState(() {
                            _selectedCategoryId = '';
                          });
                        },
                      ),
                      ..._categories.map((category) {
                        return FilterChip(
                          label: Text(category.name),
                          selected: _selectedCategoryId == category.id,
                          onSelected: (selected) {
                            setModalState(() {
                              _selectedCategoryId = selected ? category.id : '';
                            });
                            setState(() {
                              _selectedCategoryId = selected ? category.id : '';
                            });
                          },
                        );
                      }).toList(),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Price Range Filter
                  const Text(
                    'Rentang Harga',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Semua Harga'),
                        selected: _selectedPriceRange.isEmpty,
                        onSelected: (selected) {
                          setModalState(() {
                            _selectedPriceRange = '';
                          });
                          setState(() {
                            _selectedPriceRange = '';
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('< Rp 100rb'),
                        selected: _selectedPriceRange == 'under_100k',
                        onSelected: (selected) {
                          setModalState(() {
                            _selectedPriceRange = selected ? 'under_100k' : '';
                          });
                          setState(() {
                            _selectedPriceRange = selected ? 'under_100k' : '';
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Rp 100rb - 500rb'),
                        selected: _selectedPriceRange == '100k_500k',
                        onSelected: (selected) {
                          setModalState(() {
                            _selectedPriceRange = selected ? '100k_500k' : '';
                          });
                          setState(() {
                            _selectedPriceRange = selected ? '100k_500k' : '';
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Rp 500rb - 1jt'),
                        selected: _selectedPriceRange == '500k_1m',
                        onSelected: (selected) {
                          setModalState(() {
                            _selectedPriceRange = selected ? '500k_1m' : '';
                          });
                          setState(() {
                            _selectedPriceRange = selected ? '500k_1m' : '';
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('> Rp 1jt'),
                        selected: _selectedPriceRange == 'over_1m',
                        onSelected: (selected) {
                          setModalState(() {
                            _selectedPriceRange = selected ? 'over_1m' : '';
                          });
                          setState(() {
                            _selectedPriceRange = selected ? 'over_1m' : '';
                          });
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Sort Options
                  const Text(
                    'Urutkan Berdasarkan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text('Terbaru'),
                        value: 'newest',
                        groupValue: _sortBy,
                        onChanged: (value) {
                          setModalState(() {
                            _sortBy = value!;
                          });
                          setState(() {
                            _sortBy = value!;
                          });
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('Harga Terendah'),
                        value: 'price_low',
                        groupValue: _sortBy,
                        onChanged: (value) {
                          setModalState(() {
                            _sortBy = value!;
                          });
                          setState(() {
                            _sortBy = value!;
                          });
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('Harga Tertinggi'),
                        value: 'price_high',
                        groupValue: _sortBy,
                        onChanged: (value) {
                          setModalState(() {
                            _sortBy = value!;
                          });
                          setState(() {
                            _sortBy = value!;
                          });
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('Nama A-Z'),
                        value: 'name',
                        groupValue: _sortBy,
                        onChanged: (value) {
                          setModalState(() {
                            _sortBy = value!;
                          });
                          setState(() {
                            _sortBy = value!;
                          });
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _performSearch();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Terapkan Filter',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  
                  // Bottom padding for safe area
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 40,
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            decoration: InputDecoration(
              hintText: 'Cari produk, kategori...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _searchResults = [];
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
              
              // Debounce search
              Future.delayed(const Duration(milliseconds: 500), () {
                if (_searchQuery == value) {
                  _performSearch();
                }
              });
            },
            onSubmitted: (value) => _performSearch(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.black),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Active Filters
          if (_selectedCategoryId.isNotEmpty || _selectedPriceRange.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_selectedCategoryId.isNotEmpty)
                    Chip(
                      label: Text(
                        _categories
                            .firstWhere((c) => c.id == _selectedCategoryId)
                            .name,
                      ),
                      onDeleted: () {
                        setState(() {
                          _selectedCategoryId = '';
                        });
                        _performSearch();
                      },
                    ),
                  if (_selectedPriceRange.isNotEmpty)
                    Chip(
                      label: Text(_getPriceRangeText()),
                      onDeleted: () {
                        setState(() {
                          _selectedPriceRange = '';
                        });
                        _performSearch();
                      },
                    ),
                ],
              ),
            ),
          
          // Results Header
          if (_searchQuery.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  Text(
                    _isLoading
                        ? 'Mencari...'
                        : '${_searchResults.length} hasil untuk "$_searchQuery"',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (_searchResults.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.grid_view,
                              color: _isGridView ? const Color(0xFF1E88E5) : Colors.grey,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _isGridView = true;
                              });
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.list,
                              color: !_isGridView ? const Color(0xFF1E88E5) : Colors.grey,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _isGridView = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          
          // Search Results
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchQuery.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Cari Produk',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Ketik nama produk atau kategori yang Anda cari',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak ada hasil untuk "$_searchQuery"',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Coba gunakan kata kunci yang berbeda atau hapus filter',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_isGridView) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          return ProductCard(product: _searchResults[index]);
        },
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          return ProductListCard(product: _searchResults[index]);
        },
      );
    }
  }

  String _getPriceRangeText() {
    switch (_selectedPriceRange) {
      case 'under_100k':
        return '< Rp 100rb';
      case '100k_500k':
        return 'Rp 100rb - 500rb';
      case '500k_1m':
        return 'Rp 500rb - 1jt';
      case 'over_1m':
        return '> Rp 1jt';
      default:
        return '';
    }
  }
}