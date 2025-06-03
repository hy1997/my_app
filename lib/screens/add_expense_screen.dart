import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/category.dart';

class AddExpenseScreen extends StatefulWidget {
  final int userId;
  final Map<String, dynamic>? expenseToEdit;

  const AddExpenseScreen({
    Key? key,
    required this.userId,
    this.expenseToEdit,
  }) : super(key: key);

  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  List<Category> _categories = [];
  Category? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  bool _isFixedExpense = false;
  String _repeatType = '每月';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    
    // 如果是编辑模式，填充表单
    if (widget.expenseToEdit != null) {
      _amountController.text = widget.expenseToEdit!['amount'].toString();
      _noteController.text = widget.expenseToEdit!['note'] ?? '';
      
      if (widget.expenseToEdit!['time'] != null) {
        try {
          _selectedDate = DateTime.parse(widget.expenseToEdit!['time']);
        } catch (e) {
          print('解析日期失败: $e');
        }
      }
      _isFixedExpense = widget.expenseToEdit!['isFixed'] == true;
    }
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
        
        // 如果是编辑模式，设置当前选中的分类
        if (widget.expenseToEdit != null && widget.expenseToEdit!['categoryId'] != null) {
          final categoryId = widget.expenseToEdit!['categoryId'];
          if (_categories.isNotEmpty) {
          _selectedCategory = _categories.firstWhere(
              (category) => category.id == categoryId,
              orElse: () => _categories.first,
          );
          }
          print('设置当前分类: ${_selectedCategory?.name ?? "未找到匹配分类"}');
        } else if (_categories.isNotEmpty) {
          // 如果是新增模式，默认选择第一个分类
          _selectedCategory = _categories.first;
        }
        
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // Make sure a category is selected
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请选择一个分类')),
      );
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      final amount = double.parse(_amountController.text);
      final now = DateTime.now();
      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        now.hour,
        now.minute,
        now.second,
      );
      
      final bill = {
        'userId': widget.userId,
        'categoryId': _selectedCategory!.id,
        'amount': amount,
        'note': _noteController.text,
        'time': dateTime.toIso8601String(),
        'isFixed': _isFixedExpense,
      };
      
      // 如果是编辑模式
      if (widget.expenseToEdit != null) {
        await _apiService.updateBill(widget.expenseToEdit!['id'], bill, widget.userId);
      } else {
        await _apiService.createBill(bill, widget.userId);
        
        // 如果选择了固定支出选项
        if (_isFixedExpense) {
          final fixedExpense = {
            'userId': widget.userId,
            'name': _selectedCategory!.name,
            'amount': amount,
            'repeatType': _repeatType,
          };
          
          // TODO: 调用API保存固定支出
        }
      }
      
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.expenseToEdit != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑支出' : '添加支出'),
        actions: isEditing
            ? [
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => _confirmDelete(),
                ),
              ]
            : null,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 金额输入
                      Text('金额', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          prefixIcon: Container(
                            width: 40,
                            alignment: Alignment.center,
                            child: Text(
                              '¥',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                          hintText: '0.00',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                        ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Theme.of(context).primaryColor,
                              width: 2,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        style: TextStyle(fontSize: 18),
                        // 数字输入格式化与校验
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入金额';
                          }
                          
                          // 检查金额格式
                          final pattern = RegExp(r'^\d+(\.\d{1,2})?$');
                          if (!pattern.hasMatch(value)) {
                            return '请输入有效金额（最多两位小数）';
                          }
                          
                          // 检查金额范围
                          final amount = double.tryParse(value);
                          if (amount == null) {
                            return '请输入有效数字';
                          }
                          if (amount <= 0) {
                            return '金额必须大于0';
                          }
                          if (amount > 1000000) {
                            return '金额不能超过1,000,000';
                          }
                          
                          return null;
                        },
                        // 输入时自动格式化，只允许输入数字和小数点
                        onChanged: (value) {
                          // 移除非法字符（只保留数字和小数点）
                          final cleanedValue = value.replaceAll(RegExp(r'[^\d.]'), '');
                          
                          // 确保最多只有一个小数点
                          final parts = cleanedValue.split('.');
                          String formattedValue = parts[0];
                          if (parts.length > 1) {
                            // 如果有小数部分，最多保留两位
                            formattedValue += '.${parts[1].substring(0, parts[1].length > 2 ? 2 : parts[1].length)}';
                          }
                          
                          // 如果格式化后的值与当前值不同，更新控制器
                          if (formattedValue != value) {
                            _amountController.value = TextEditingValue(
                              text: formattedValue,
                              selection: TextSelection.collapsed(offset: formattedValue.length),
                            );
                          }
                        },
                      ),
                      
                      SizedBox(height: 16),
                      
                      // 分类选择
                      Text('分类', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      _categories.isEmpty
                          ? Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.red),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('没有可用的分类', style: TextStyle(color: Colors.red)),
                                  SizedBox(height: 8),
                                  Text('请先添加至少一个分类，或等待默认分类加载完成'),
                                ],
                              ),
                            )
                          : DropdownButtonFormField<Category>(
                              value: _selectedCategory,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              items: _categories.map((category) {
                                return DropdownMenuItem(
                                  value: category,
                                  child: Row(
                                    children: [
                                      Text(category.icon),
                                      SizedBox(width: 8),
                                      Text(category.name),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCategory = value;
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return '请选择分类';
                                }
                                return null;
                              },
                            ),
                      
                      SizedBox(height: 16),
                      
                      // 日期选择
                      Text('日期', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      InkWell(
                        onTap: _selectDate,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                              Icon(Icons.calendar_today),
                            ],
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      
                      // 备注
                      Text('备注', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _noteController,
                        decoration: InputDecoration(
                          hintText: '可选',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      
                      SizedBox(height: 16),
                      
                      // 固定支出选项
                      if (!isEditing) ... [
                        CheckboxListTile(
                          title: Text('添加到固定支出'),
                          value: _isFixedExpense,
                          onChanged: (value) {
                            setState(() {
                              _isFixedExpense = value ?? false;
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        
                        if (_isFixedExpense) ... [
                          Padding(
                            padding: const EdgeInsets.only(left: 32.0),
                            child: DropdownButton<String>(
                              value: _repeatType,
                              items: ['每天', '每周', '每月'].map((type) {
                                return DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _repeatType = value;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ],
                      
                      SizedBox(height: 24),
                      
                      // 保存按钮
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveExpense,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isSaving
                              ? CircularProgressIndicator()
                              : Text(isEditing ? '保存修改' : '保存', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  void _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除确认'),
        content: Text('确定要删除这笔支出吗？'),
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

    if (confirmed == true) {
      try {
        // Pass userId when deleting
        await _apiService.deleteBill(widget.expenseToEdit!['id'], widget.userId);
        Navigator.pop(context, true); // Return true to indicate successful deletion
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }
}