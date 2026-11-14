import 'package:flutter/material.dart';

class SubordinateScrollController extends ScrollController {
  SubordinateScrollController(
    this.parent, {
    String subordinateDebugLabel = 'subordinate',
  });
  final ScrollController parent;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) =>
      parent.createScrollPosition(physics, context, oldPosition);

  @override
  void attach(ScrollPosition position) {
    try {
      if (position.runtimeType.toString() != '_NestedScrollPosition') return;
      parent.attach(position);
      super.attach(position);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  void detach(ScrollPosition position) {
    try {
      if (position.runtimeType.toString() != '_NestedScrollPosition') return;
      parent.detach(position);
      super.detach(position);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  void dispose() {
    for (final position in positions) {
      parent.detach(position);
    }

    super.dispose();
  }
}

/// 详情页各 Tab 的滚动控制器：跨 build 复用，避免每次重建都新建
/// SubordinateScrollController 并在后台重新挂载 ScrollPosition。
mixin DetailTabScrollMixin {
  ScrollController? _tabScrollController;
  ScrollController? _idleScrollController;
  ScrollController? _parentController;
  final List<ScrollController> _staleControllers = [];

  ScrollController tabScrollController(BuildContext context, bool active) {
    _idleScrollController ??= ScrollController();
    if (!active) {
      return _idleScrollController!;
    }
    final parent = PrimaryScrollController.maybeOf(context);
    // NestedScrollView 重建后父控制器会变化，需要重新创建并挂载
    if (_tabScrollController == null || parent != _parentController) {
      if (_tabScrollController != null) {
        _staleControllers.add(_tabScrollController!);
      }
      _parentController = parent;
      _tabScrollController =
          parent == null ? ScrollController() : SubordinateScrollController(parent);
    }
    return _tabScrollController!;
  }

  void disposeTabScrollController() {
    for (final controller in _staleControllers) {
      controller.dispose();
    }
    _staleControllers.clear();
    _tabScrollController?.dispose();
    _idleScrollController?.dispose();
    _tabScrollController = null;
    _idleScrollController = null;
    _parentController = null;
  }
}
