
import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../utils/toast.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';

class ValuesEditorPage extends StatefulWidget {
  const ValuesEditorPage({super.key});

  @override
  State<ValuesEditorPage> createState() => _ValuesEditorPageState();
}

class _ValuesEditorPageState extends State<ValuesEditorPage> {
  late List<String> _selectedBaseValues;
  late Map<String, TextEditingController> _sceneControllers;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _selectedBaseValues = List.from(StorageService().baseValues);
    final savedSceneValues = StorageService().sceneValues;
    _sceneControllers = {};
    for (final scene in Constants.scenes) {
      _sceneControllers[scene] = TextEditingController(
        text: savedSceneValues[scene] ?? '',
      );
    }
  }

  void _toggleBaseValue(String id) {
    setState(() {
      if (_selectedBaseValues.contains(id)) {
        _selectedBaseValues.remove(id);
      } else {
        _selectedBaseValues.add(id);
      }
    });
  }

  Future<void> _save() async {
    await StorageService().setBaseValues(_selectedBaseValues);
    final sceneValues = <String, String>{};
    for (final entry in _sceneControllers.entries) {
      if (entry.value.text.trim().isNotEmpty) {
        sceneValues[entry.key] = entry.value.text.trim();
      }
    }
    await StorageService().setSceneValues(sceneValues);
    if (mounted) {
      AppToast.show(context, '价值观设置已保存');
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    for (final c in _sceneControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ==================== 基础处事底线 ====================
                      _buildSectionTitle('基础处事底线', Icons.shield_outlined),
                      const SizedBox(height: 6),
                      Text(
                        '勾选你希望AI严格遵守的处事原则',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted.withOpacity(0.8)),
                      ),
                      const SizedBox(height: 12),
                      _buildCard(
                        child: Column(
                          children: Constants.baseValues.map((item) {
                            final isSelected = _selectedBaseValues.contains(item['id']);
                            return GestureDetector(
                              onTap: () => _toggleBaseValue(item['id']!),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.accentStart.withOpacity(0.08)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      width: 22,
                                      height: 22,
                                      margin: const EdgeInsets.only(top: 1, right: 12),
                                      decoration: BoxDecoration(
                                        gradient: isSelected ? AppTheme.accentGradient : null,
                                        color: isSelected ? null : AppTheme.bgDarker,
                                        borderRadius: BorderRadius.circular(6),
                                        border: isSelected
                                            ? null
                                            : Border.all(color: Colors.white.withOpacity(0.15)),
                                        boxShadow: isSelected ? AppTheme.accentGlow : null,
                                      ),
                                      child: isSelected
                                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                                          : null,
                                    ),
                                    Expanded(
                                      child: Text(
                                        item['text']!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          height: 1.5,
                                          color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ==================== 分人群专属价值观 ====================
                      _buildSectionTitle('分人群专属价值观', Icons.people_outline),
                      const SizedBox(height: 6),
                      Text(
                        '为不同关系场景添加专属约束，让回复更精准',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted.withOpacity(0.8)),
                      ),
                      const SizedBox(height: 16),
                      _buildSceneTabs(),
                      const SizedBox(height: 16),
                      _buildCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.accentGradient,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  Constants.scenes[_selectedTab],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _sceneControllers[Constants.scenes[_selectedTab]],
                              maxLines: 4,
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: Constants.sceneValueHints[Constants.scenes[_selectedTab]],
                                hintStyle: TextStyle(color: AppTheme.textMuted.withOpacity(0.5)),
                                filled: true,
                                fillColor: AppTheme.bgDarker,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.all(14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 头部 ====================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textSecondary, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              ShaderMask(
                shaderCallback: (bounds) => AppTheme.accentGradient.createShader(bounds),
                child: const Text(
                  '价值观设置',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: _save,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: AppTheme.accentGlow,
              ),
              child: const Text(
                '保存',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 场景 Tab ====================

  Widget _buildSceneTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(Constants.scenes.length, (index) {
          final isSelected = index == _selectedTab;
          return GestureDetector(
            onTap: () => setState(() => _selectedTab = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                gradient: isSelected ? AppTheme.accentGradient : null,
                color: isSelected ? null : AppTheme.bgCard,
                borderRadius: BorderRadius.circular(20),
                border: isSelected ? null : Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: isSelected ? AppTheme.accentGlow : null,
              ),
              child: Text(
                Constants.scenes[index],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ==================== 通用组件 ====================

  Widget _buildSectionTitle(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.accentStart),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGlassGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: child,
    );
  }
}
