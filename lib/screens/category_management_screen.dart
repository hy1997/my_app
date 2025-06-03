import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:flutter/services.dart';
import '../models/category.dart';

class CategoryManagementScreen extends StatefulWidget {
  final int userId;

  const CategoryManagementScreen({Key? key, required this.userId}) : super(key: key);

  @override
  CategoryManagementScreenState createState() => CategoryManagementScreenState();
}

class CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final _apiService = ApiService();
  List<dynamic> _categories = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final categories = await ApiService().getCategories(widget.userId);
      print('获取到分类列表: ${categories.length} 个');
      
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      print('加载分类列表失败: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载分类列表失败: $e')),
      );
    }
  }

  Future<void> _addCategory() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CategoryDialog(userId: widget.userId),
    );

    if (result != null) {
      try {
        await _apiService.addCategory(widget.userId, result);
        _loadCategories();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加分类成功')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加分类失败: $e')),
        );
      }
    }
  }

  Future<void> _editCategory(Category category) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CategoryDialog(category: category, userId: widget.userId),
    );

    if (result != null) {
      try {
        await _apiService.updateCategory(category.id, result);
        _loadCategories();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新分类成功')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新分类失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteCategory(Category category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除确认'),
        content: Text('确定要删除分类"${category.name}"吗？\n删除后无法恢复，且会影响使用该分类的账单。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiService.deleteCategory(category.id);
        _loadCategories();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除分类成功')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除分类失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('分类管理'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadCategories,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: TextStyle(color: Colors.red)),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadCategories,
                        child: Text('重试'),
                      ),
                    ],
                  ),
                )
              : _categories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('暂无分类'),
                          SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _addCategory,
                            icon: Icon(Icons.add),
                            label: Text('添加分类'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        return Card(
                          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: Text(
                              category.icon ?? '📝',
                              style: TextStyle(fontSize: 24),
                            ),
                            title: Text(category.name ?? '未命名'),
                            subtitle: Text(category.description ?? ''),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _editCategory(category),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteCategory(category),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCategory,
        child: Icon(Icons.add),
        tooltip: '添加分类',
      ),
    );
  }
}

class CategoryDialog extends StatefulWidget {
  final Category? category;
  final int? userId;

  const CategoryDialog({Key? key, this.category, this.userId}) : super(key: key);

  @override
  CategoryDialogState createState() => CategoryDialogState();
}

class CategoryDialogState extends State<CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _iconController;
  bool _isFixed = false;
  final List<String> _availableIcons = [
    '📊', '🍔', '🚕', '🛒', '🏠', '📱', '🎮', '🎓', '🏥', '🎁', '⛽', 
    '🍺', '🛍️', '💄', '🖥️', '📚', '🚿', '🚇', '🛫', '🏫', '🏛️', '🧸', 
    '🌴', '🥗', '📆', '🎬', '👕', '💼', '🏋️', '🎯', '🎨', '🎸', '🏦', '💊',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name);
    _descriptionController = TextEditingController(text: widget.category?.description);
    _iconController = TextEditingController(text: widget.category?.icon);
    _isFixed = widget.category?.isFixed ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  // 根据分类名称自动生成图标
  String _generateIconFromName(String categoryName) {
    if (categoryName.isEmpty) return '📝'; // 默认图标

    // 为常见类别分配对应图标
    final Map<String, String> commonCategories = {
      '餐饮': '🍔', '饮食': '🍽️', '吃': '🍗', '外卖': '🥡', '食物': '🍲', '食品': '🥘',
      '交通': '🚕', '公交': '🚌', '地铁': '🚇', '打车': '🚖', '高铁': '🚄', '火车': '🚂',
      '购物': '🛒', '服装': '👕', '衣服': '👚', '超市': '🏪', '日用': '🧴', 
      '住房': '🏠', '房租': '🏘️', '水电': '💡', '电费': '⚡', '水费': '💧',
      '通讯': '📱', '电话': '☎️', '网络': '🌐', '宽带': '📶',
      '娱乐': '🎮', '游戏': '🎯', '电影': '🎬', '旅游': '🏝️', '旅行': '🧳',
      '教育': '📚', '学习': '🎓', '书籍': '📖', '培训': '👨‍🏫',
      '医疗': '🏥', '药品': '💊', '看病': '🩺', '保健': '🧬',
      '礼物': '🎁', '礼品': '🎀', 
      '汽车': '🚗', '加油': '⛽', '停车': '🅿️', '维修': '🔧',
      '酒水': '🍺', '饮料': '🥤', '咖啡': '☕',
      '美容': '💄', '护肤': '🧴', '理发': '💇‍♀️',
      '数码': '🖥️', '电子': '📱', '电器': '⌚',
      '办公': '💼', '文具': '✏️',
      '运动': '🏋️', '健身': '🏃‍♂️', 
      '艺术': '🎨', '音乐': '🎵', '乐器': '🎸',
      '银行': '🏦', '投资': '📈', '理财': '💰',
      '固定支出': '📅', '订阅': '🔄', '会员': '🔑',
    };

    // 先尝试直接匹配分类名
    for (final entry in commonCategories.entries) {
      if (categoryName.contains(entry.key)) {
        return entry.value;
      }
    }

    // 如果没有匹配到，根据名称首字符选择一个随机图标
    int nameHash = categoryName.hashCode.abs();
    int iconIndex = nameHash % _availableIcons.length;
    return _availableIcons[iconIndex];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? '添加分类' : '编辑分类'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '分类名称',
                  hintText: '请输入分类名称',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入分类名称';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: '描述',
                  hintText: '请输入分类描述（可选）',
                ),
                maxLines: 2,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _iconController,
                decoration: InputDecoration(
                  labelText: '图标',
                  hintText: '请输入表情符号作为图标（留空将自动生成）',
                  helperText: '留空将根据分类名称自动生成合适的图标',
                  suffixIcon: IconButton(
                    icon: Icon(Icons.auto_awesome),
                    onPressed: () {
                      setState(() {
                        _iconController.text = _generateIconFromName(_nameController.text);
                      });
                    },
                    tooltip: '自动生成图标',
                  ),
                ),
              ),
              SizedBox(height: 16),
              SwitchListTile(
                title: Text('固定支出'),
                subtitle: Text('标记为固定支出分类'),
                value: _isFixed,
                onChanged: (value) {
                  setState(() {
                    _isFixed = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('取消'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              // 如果用户没有输入图标，自动生成一个
              if (_iconController.text.isEmpty) {
                _iconController.text = _generateIconFromName(_nameController.text);
              }
              
              Navigator.pop(context, {
                'name': _nameController.text,
                'description': _descriptionController.text,
                'icon': _iconController.text,
                'isFixed': _isFixed,
                'id': widget.category?.id,
                'userId': widget.userId,
                'type': widget.category?.type ?? 'expense',
                'orderIndex': widget.category?.orderIndex ?? 0,
              });
            }
          },
          child: Text('确定'),
        ),
      ],
    );
  }
} 