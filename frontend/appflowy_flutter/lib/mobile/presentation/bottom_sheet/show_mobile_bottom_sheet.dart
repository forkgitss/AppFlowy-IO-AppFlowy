import 'package:appflowy/mobile/presentation/bottom_sheet/bottom_sheet_buttons.dart';
import 'package:appflowy/plugins/base/drag_handler.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

extension BottomSheetPaddingExtension on BuildContext {
  /// Calculates the total amount of space that should be added to the bottom of
  /// a bottom sheet
  double bottomSheetPadding({
    bool ignoreViewPadding = true,
  }) {
    final viewPadding = MediaQuery.viewPaddingOf(this);
    final viewInsets = MediaQuery.viewInsetsOf(this);
    double bottom = 0.0;
    if (!ignoreViewPadding) {
      bottom += viewPadding.bottom;
    }
    // for screens with 0 view padding, add some even more space
    bottom += viewPadding.bottom == 0 ? 28.0 : 16.0;
    bottom += viewInsets.bottom;
    return bottom;
  }
}

Future<T?> showMobileBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool useSafeArea = true,
  bool isDragEnabled = true,
  bool showDragHandle = false,
  bool showHeader = false,
  // this field is only used if showHeader is true
  bool showBackButton = false,
  bool showCloseButton = false,
  bool showRemoveButton = false,
  VoidCallback? onRemove,
  // this field is only used if showHeader is true
  String title = '',
  bool isScrollControlled = true,
  bool showDivider = true,
  bool useRootNavigator = false,
  ShapeBorder? shape,
  // the padding of the content, the padding of the header area is fixed
  EdgeInsets padding = EdgeInsets.zero,
  Color? backgroundColor,
  BoxConstraints? constraints,
  Color? barrierColor,
  double? elevation,
  bool showDoneButton = false,
  void Function(BuildContext context)? onDone,
  bool enableDraggableScrollable = false,
  bool enableScrollable = false,
  // this field is only used if showDragHandle is true
  Widget Function(BuildContext, ScrollController)? scrollableWidgetBuilder,
  // only used when enableDraggableScrollable is true
  double minChildSize = 0.5,
  double maxChildSize = 0.8,
  double initialChildSize = 0.51,
  double bottomSheetPadding = 0,
  bool enablePadding = true,
  WidgetBuilder? dragHandleBuilder,
}) async {
  assert(
    showHeader ||
        title.isEmpty && !showCloseButton && !showBackButton && !showDoneButton,
  );
  assert(!(showCloseButton && showBackButton));

  shape ??= const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(16),
    ),
  );

  backgroundColor ??= Theme.of(context).brightness == Brightness.light
      ? const Color(0xFFF7F8FB)
      : const Color(0xFF23262B);
  barrierColor ??= Colors.black.withValues(alpha: 0.3);

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    enableDrag: isDragEnabled,
    useSafeArea: true,
    clipBehavior: Clip.antiAlias,
    constraints: constraints,
    barrierColor: barrierColor,
    elevation: elevation,
    backgroundColor: backgroundColor,
    shape: shape,
    useRootNavigator: useRootNavigator,
    builder: (context) {
      final List<Widget> children = [];

      final Widget child = builder(context);

      // if the children is only one, we don't need to wrap it with a column
      if (!showDragHandle && !showHeader && !showDivider) {
        return child;
      }

      // ----- header area -----
      if (showDragHandle) {
        children.add(
          dragHandleBuilder?.call(context) ?? const DragHandle(),
        );
      }

      if (showHeader) {
        children.add(
          BottomSheetHeader(
            showCloseButton: showCloseButton,
            showBackButton: showBackButton,
            showDoneButton: showDoneButton,
            showRemoveButton: showRemoveButton,
            title: title,
            onRemove: onRemove,
            onDone: onDone,
          ),
        );

        if (showDivider) {
          children.add(
            const Divider(height: 0.5, thickness: 0.5),
          );
        }
      }

      // ----- header area -----

      if (enableDraggableScrollable) {
        final keyboardSize =
            context.bottomSheetPadding() / MediaQuery.of(context).size.height;
        return DraggableScrollableSheet(
          expand: false,
          snap: true,
          initialChildSize: (initialChildSize + keyboardSize).clamp(0, 1),
          minChildSize: (minChildSize + keyboardSize).clamp(0, 1.0),
          maxChildSize: (maxChildSize + keyboardSize).clamp(0, 1.0),
          builder: (context, scrollController) {
            return Column(
              children: [
                ...children,
                scrollableWidgetBuilder?.call(
                      context,
                      scrollController,
                    ) ??
                    Expanded(
                      child: Scrollbar(
                        controller: scrollController,
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: child,
                        ),
                      ),
                    ),
              ],
            );
          },
        );
      } else if (enableScrollable) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...children,
            Flexible(
              child: SingleChildScrollView(
                child: child,
              ),
            ),
            VSpace(bottomSheetPadding),
          ],
        );
      }

      // ----- content area -----
      if (enablePadding) {
        // add content padding and extra bottom padding
        children.add(
          Padding(
            padding:
                padding + EdgeInsets.only(bottom: context.bottomSheetPadding()),
            child: child,
          ),
        );
      } else {
        children.add(child);
      }
      // ----- content area -----

      if (children.length == 1) {
        return children.first;
      }

      return useSafeArea
          ? SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: children,
            );
    },
  );
}

class BottomSheetHeader extends StatelessWidget {
  const BottomSheetHeader({
    super.key,
    required this.showBackButton,
    required this.showCloseButton,
    required this.showRemoveButton,
    required this.title,
    required this.showDoneButton,
    this.onRemove,
    this.onDone,
    this.onBack,
    this.onClose,
  });

  final String title;

  final bool showBackButton;
  final bool showCloseButton;
  final bool showRemoveButton;
  final bool showDoneButton;

  final VoidCallback? onRemove;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  final void Function(BuildContext context)? onDone;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: SizedBox(
        height: 44.0, // the height of the header area is fixed
        child: Stack(
          children: [
            if (showBackButton)
              Align(
                alignment: Alignment.centerLeft,
                child: BottomSheetBackButton(
                  onTap: onBack,
                ),
              ),
            if (showCloseButton)
              Align(
                alignment: Alignment.centerLeft,
                child: BottomSheetCloseButton(
                  onTap: onClose,
                ),
              ),
            if (showRemoveButton)
              Align(
                alignment: Alignment.centerLeft,
                child: BottomSheetRemoveButton(
                  onRemove: () => onRemove?.call(),
                ),
              ),
            Align(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 250),
                child: Text(
                  title,
                  style: theme.textStyle.heading4.prominent(
                    color: theme.textColorScheme.primary,
                  ),
                ),
              ),
            ),
            if (showDoneButton)
              Align(
                alignment: Alignment.centerRight,
                child: BottomSheetDoneButton(
                  onDone: () {
                    if (onDone != null) {
                      onDone?.call(context);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
