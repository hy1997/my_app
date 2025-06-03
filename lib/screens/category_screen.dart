import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CategoryScreen extends StatefulWidget {
  final int userId;

  const CategoryScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _CategoryScreenState createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final _apiService = ApiService();
  List<dynamic> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final categories = await _apiService.getCategories(widget.userId);
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载分类失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('分类管理'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _showCategoryDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? Center(child: Text('暂无分类，点击右上角添加'))
              : ReorderableListView.builder(
                  itemCount: _categories.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      final item = _categories.removeAt(oldIndex);
                      _categories.insert(newIndex, item);
                      
                      // 更新排序索引
                      for (int i = 0; i < _categories.length; i++) {
                        _categories[i]['orderIndex'] = i;
                        
                        // 保存更新
                        int categoryId = _categories[i]['id'];
                        _apiService.updateCategory(categoryId, _categories[i]);
                      }
                    });
                  },
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    return ListTile(
                      key: Key(category['id'].toString()),
                      leading: Text(
                        category['icon'] ?? '📊',
                        style: TextStyle(fontSize: 24),
                      ),
                      title: Text(category['name'] ?? '未命名'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit),
                            onPressed: () => _showCategoryDialog(category: category),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () => _confirmDelete(category),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  void _confirmDelete(Map<String, dynamic> category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认删除'),
        content: Text('确定要删除 ${category['name']} 分类吗？这会影响已经使用该分类的交易记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _apiService.deleteCategory(category['id']);
                _loadCategories();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('删除失败: $e')),
                );
              }
            },
            child: Text('删除'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  void _showCategoryDialog({Map<String, dynamic>? category}) {
    final isEditing = category != null;
    final nameController = TextEditingController(
      text: isEditing ? category['name'] : '',
    );
    String selectedIcon = isEditing ? (category['icon'] ?? '📊') : '📊';

    final icons = [
      '📊', '🍔', '🚕', '🛒', '🏠', '📱', '🎮',
      '🎓', '🏥', '🎁', '⛽', '🍺', '🛍️', '💄',
      '🖥️', '📚', '🚿', '🚇', '🛫', '🏫', '🏛️',
      '🧸', '🌴', '🥗', '📆',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEditing ? '编辑分类' : '新增分类'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: '分类名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                Text('选择图标'),
                SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: icons.map((icon) {
                    return InkWell(
                      onTap: () => setState(() => selectedIcon = icon),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: selectedIcon == icon
                              ? Colors.blue.withOpacity(0.2)
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selectedIcon == icon
                                ? Colors.blue
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(icon, style: TextStyle(fontSize: 24)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('分类名称不能为空')),
                  );
                  return;
                }

                Navigator.pop(context);

                try {
                  if (isEditing) {
                    // 更新分类
                    final updatedCategory = Map<String, dynamic>.from(category);
                    updatedCategory['name'] = name;
                    updatedCategory['icon'] = selectedIcon;
                    await _apiService.updateCategory(
                        category['id'], updatedCategory);
                  } else {
                    // 创建新分类
                    final newCategory = {
                      'userId': widget.userId,
                      'name': name,
                      'icon': selectedIcon,
                      'orderIndex': _categories.length,
                    };
                    await _apiService.addCategory(widget.userId, newCategory);
                  }
                  _loadCategories();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('保存失败: $e')),
                  );
                }
              },
              child: Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
} 