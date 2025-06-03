import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _apiService = ApiService();
  final _keywordController = TextEditingController();
  
  int? _userId;
  List<dynamic> _categories = [];
  dynamic _selectedCategory;
  DateTime? _startDate;
  DateTime? _endDate;
  double? _minAmount;
  double? _maxAmount;
  
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments;
    if (args is Map<String, dynamic>) {
      _userId = args['userId'];
      _loadCategories();
    }
  }

  Future<void> _loadCategories() async {
    if (_userId == null) return;
    
    try {
      final categories = await _apiService.getCategories(_userId!);
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      print('加载分类失败: $e');
    }
  }

  Future<void> _search() async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法获取用户ID')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });
    
    final Map<String, dynamic> params = {};
    
    // 添加关键词
    if (_keywordController.text.isNotEmpty) {
      params['keyword'] = _keywordController.text;
    }
    
    // 添加日期筛选
    if (_startDate != null) {
      params['startDate'] = DateFormat('yyyy-MM-dd').format(_startDate!);
    }
    if (_endDate != null) {
      params['endDate'] = DateFormat('yyyy-MM-dd').format(_endDate!);
    }
    
    // 添加分类筛选
    if (_selectedCategory != null) {
      params['categoryId'] = _selectedCategory['id'];
    }
    
    // 添加金额筛选
    if (_minAmount != null) {
      params['minAmount'] = _minAmount;
    }
    if (_maxAmount != null) {
      params['maxAmount'] = _maxAmount;
    }
    
    try {
      final result = await _apiService.searchBills(_userId!, params);
      setState(() {
        _searchResults = result['results'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('搜索失败: $e')),
      );
    }
  }

  void _resetFilters() {
    setState(() {
      _keywordController.clear();
      _selectedCategory = null;
      _startDate = null;
      _endDate = null;
      _minAmount = null;
      _maxAmount = null;
      _hasSearched = false;
      _searchResults = [];
    });
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('搜索'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _resetFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // 关键词搜索
                TextField(
                  controller: _keywordController,
                  decoration: InputDecoration(
                    labelText: '关键词',
                    hintText: '搜索分类或备注',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
                
                SizedBox(height: 16),
                
                // 日期范围选择
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _selectStartDate,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_startDate == null
                                  ? '开始日期'
                                  : DateFormat('yyyy-MM-dd').format(_startDate!)),
                              Icon(Icons.calendar_today, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: _selectEndDate,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_endDate == null
                                  ? '结束日期'
                                  : DateFormat('yyyy-MM-dd').format(_endDate!)),
                              Icon(Icons.calendar_today, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 16),
                
                // 分类选择
                if (_categories.isNotEmpty)
                  DropdownButtonFormField<dynamic>(
                    value: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: '分类',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text('所有分类'),
                      ),
                      ..._categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Row(
                            children: [
                              Text(category['icon'] ?? '📊'),
                              SizedBox(width: 8),
                              Text(category['name'] ?? '未命名'),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    },
                  ),
                
                SizedBox(height: 16),
                
                // 金额范围
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: '最小金额',
                          prefixText: '¥ ',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _minAmount = double.tryParse(value);
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: '最大金额',
                          prefixText: '¥ ',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _maxAmount = double.tryParse(value);
                          });
                        },
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 16),
                
                // 搜索按钮
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _search,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? CircularProgressIndicator()
                        : Text('搜索', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
          
          // 搜索结果
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _hasSearched
                    ? _searchResults.isEmpty
                        ? Center(child: Text('没有找到符合条件的记录'))
                        : ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final bill = _searchResults[index];
                              final category = bill['categoryName'] ?? '未分类';
                              final icon = bill['categoryIcon'] ?? '📊';
                              final amount = bill['amount']?.toString() ?? '0';
                              final note = bill['note'] ?? '';
                              
                              DateTime? dateTime;
                              String formattedDate = '';
                              
                              if (bill['time'] != null) {
                                try {
                                  dateTime = DateTime.parse(bill['time']);
                                  formattedDate = DateFormat('yyyy-MM-dd').format(dateTime);
                                } catch (e) {
                                  print('解析日期失败: $e');
                                }
                              }
                              
                              return ListTile(
                                leading: Text(icon, style: TextStyle(fontSize: 24)),
                                title: Text(category),
                                subtitle: Text('$formattedDate ${note.isNotEmpty ? "• $note" : ""}'),
                                trailing: Text('¥$amount', style: TextStyle(fontWeight: FontWeight.bold)),
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/expense-detail',
                                    arguments: {
                                      'userId': _userId,
                                      'expense': bill,
                                    },
                                  ).then((value) {
                                    if (value == true) {
                                      _search(); // 刷新列表
                                    }
                                  });
                                },
                              );
                            },
                          )
                    : Center(child: Text('请输入搜索条件')),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }
} 