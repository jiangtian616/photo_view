# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

`photo_view` 是一个 Flutter package，提供支持手势缩放、平移、旋转的图片/自定义内容展示组件。无第三方运行时依赖，仅依赖 Flutter SDK。

## 常用命令

```bash
# 运行所有测试
flutter test

# 运行单个测试文件
flutter test test/controller_test.dart

# 静态分析
flutter analyze

# 格式检查
./scripts/format.sh .
```

## 库入口

项目暴露两个顶层 library：

- **`photo_view.dart`** — 主库。导出 `PhotoView` 组件、`PhotoViewController`/`PhotoViewScaleStateController`、`PhotoViewComputedScale`、`PhotoViewScaleState`、`PhotoViewHeroAttributes`、`PhotoViewGestureDetectorScope` 及各种 typedef。
- **`photo_view_gallery.dart`** — 画廊库。导出 `PhotoViewGallery`（基于 PageView 的多页 PhotoView）和 `PhotoViewGalleryPageOptions`。

## 核心架构

### 组件层级

`PhotoView` (StatefulWidget) → 根据构造函数选择 `ImageWrapper` 或 `CustomChildWrapper` → 两者内部均使用 `PhotoViewCore` 作为实际渲染引擎。

`PhotoViewCore` 负责所有变换逻辑（缩放、位置、旋转），内部使用 Flutter 的 `Transform`/`Matrix4`。

### 手势系统

`PhotoViewGestureDetector` (`lib/src/core/photo_view_gesture_detector.dart`) 是自定义手势检测器，组合了三个 recognizer：

1. **`PhotoViewGestureRecognizer`** (extends `ScaleGestureRecognizer`) — 处理双指缩放和拖拽。通过 `HitCornersDetector` mixin 判断内容是否处于边缘，从而允许父级滚动手势在边缘时胜出。
2. **`DoubleTapAndTagDragZoomGestureRecognizer`** — 处理双击循环缩放状态，以及"按住拖动缩放"（tap-drag-zoom）。
3. **`TapGestureRecognizer`** — 处理 `onTapUp`/`onTapDown` 回调。

`PhotoViewGestureDetectorScope` 是 InheritedWidget，用于在画廊等可滚动容器中传递滚动轴信息，协调手势竞争。

### 控制器与状态

- **`PhotoViewController`** — 外部控制缩放、位置、旋转。内部使用 `IgnorableValueNotifier<PhotoViewControllerValue>`，通过 `outputStateStream` 暴露状态变更。
- **`PhotoViewScaleStateController`** — 控制缩放状态（initial / covering / originalSize / zoomedIn / zoomedOut），驱动双击循环行为。
- **`PhotoViewControllerDelegate`** mixin — 由 `PhotoViewCoreState` 混入，同步 controller 和 scaleStateController。

### "Ignorable" 通知模式

`IgnorableChangeNotifier` / `IgnorableValueNotifier<T>` (`lib/src/utils/ignorable_change_notifier.dart`) 提供了双层监听器机制：
- `notifyListeners()` — 通知所有监听器（普通 + ignorable）
- `notifySomeListeners()` — 仅通知普通监听器（跳过 ignorable）

这用于内部状态更新不触发外部回调的场景（如 `setScaleInvisibly()`）。

### PhotoViewComputedScale

不是传统 enum，而是一个类似 enum 的类，提供 `contained` 和 `covered` 两个常量。支持乘法/除法运算符，所以可以写成 `PhotoViewComputedScale.contained * 0.8`。`PhotoViewUtils.getScaleForScaleState()` 将其解析为实际 double 值。

### 画廊

`PhotoViewGallery` 内嵌 `CachedPageView`（自定义的 PageView 子类，暴露了 PageView 内部的 `cacheExtent`），每个页面是一个独立的 `PhotoView`。通过 `PhotoViewGestureDetectorScope` 确保页面切换手势与图片缩放手势的协调。
