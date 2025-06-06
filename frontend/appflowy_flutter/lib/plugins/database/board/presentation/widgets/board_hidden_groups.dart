import 'dart:io';

import 'package:appflowy/features/workspace/logic/workspace_bloc.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/database/application/cell/cell_controller.dart';
import 'package:appflowy/plugins/database/application/database_controller.dart';
import 'package:appflowy/plugins/database/application/row/row_cache.dart';
import 'package:appflowy/plugins/database/application/row/row_controller.dart';
import 'package:appflowy/plugins/database/board/application/board_bloc.dart';
import 'package:appflowy/plugins/database/board/group_ext.dart';
import 'package:appflowy/plugins/database/grid/presentation/layout/sizes.dart';
import 'package:appflowy/plugins/database/tab_bar/tab_bar_view.dart';
import 'package:appflowy/plugins/database/widgets/cell/card_cell_builder.dart';
import 'package:appflowy/plugins/database/widgets/cell/card_cell_skeleton/text_card_cell.dart';
import 'package:appflowy/plugins/database/widgets/row/row_detail.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flowy_infra_ui/style_widget/hover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HiddenGroupsColumn extends StatelessWidget {
  const HiddenGroupsColumn({
    super.key,
    required this.margin,
    required this.shrinkWrap,
  });

  final EdgeInsets margin;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final databaseController = context.read<BoardBloc>().databaseController;
    return BlocSelector<BoardBloc, BoardState, BoardLayoutSettingPB?>(
      selector: (state) => state.maybeMap(
        orElse: () => null,
        ready: (value) => value.layoutSettings,
      ),
      builder: (context, layoutSettings) {
        if (layoutSettings == null) {
          return const SizedBox.shrink();
        }
        final isCollapsed = layoutSettings.collapseHiddenGroups;
        final leftPadding = margin.left +
            context.read<DatabasePluginWidgetBuilderSize>().paddingLeft;
        final leftPaddingWithMaxDocWidth = context
            .read<DatabasePluginWidgetBuilderSize>()
            .paddingLeftWithMaxDocumentWidth;
        return AnimatedSize(
          alignment: AlignmentDirectional.topStart,
          curve: Curves.easeOut,
          duration: const Duration(milliseconds: 150),
          child: isCollapsed
              ? SizedBox(
                  height: 50,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 80 + leftPaddingWithMaxDocWidth,
                      right: 8,
                    ),
                    child: Center(
                      child: _collapseExpandIcon(context, isCollapsed),
                    ),
                  ),
                )
              : Container(
                  width: 274 + leftPaddingWithMaxDocWidth,
                  padding: EdgeInsets.only(
                    left: leftPadding,
                    right: margin.right + 4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 50,
                        child: Row(
                          children: [
                            Expanded(
                              child: FlowyText.medium(
                                LocaleKeys.board_hiddenGroupSection_sectionTitle
                                    .tr(),
                                overflow: TextOverflow.ellipsis,
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                            _collapseExpandIcon(context, isCollapsed),
                          ],
                        ),
                      ),
                      _hiddenGroupList(databaseController),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _hiddenGroupList(DatabaseController databaseController) {
    final hiddenGroupList = HiddenGroupList(
      shrinkWrap: shrinkWrap,
      databaseController: databaseController,
    );
    return shrinkWrap ? hiddenGroupList : Expanded(child: hiddenGroupList);
  }

  Widget _collapseExpandIcon(BuildContext context, bool isCollapsed) {
    return FlowyTooltip(
      message: isCollapsed
          ? LocaleKeys.board_hiddenGroupSection_expandTooltip.tr()
          : LocaleKeys.board_hiddenGroupSection_collapseTooltip.tr(),
      preferBelow: false,
      child: FlowyIconButton(
        width: 20,
        height: 20,
        iconColorOnHover: Theme.of(context).colorScheme.onSurface,
        onPressed: () => context
            .read<BoardBloc>()
            .add(BoardEvent.toggleHiddenSectionVisibility(!isCollapsed)),
        icon: FlowySvg(
          isCollapsed
              ? FlowySvgs.hamburger_s_s
              : FlowySvgs.pull_left_outlined_s,
        ),
      ),
    );
  }
}

class HiddenGroupList extends StatelessWidget {
  const HiddenGroupList({
    super.key,
    required this.databaseController,
    required this.shrinkWrap,
  });

  final DatabaseController databaseController;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BoardBloc, BoardState>(
      builder: (context, state) {
        return state.maybeMap(
          orElse: () => const SizedBox.shrink(),
          ready: (state) => ReorderableListView.builder(
            proxyDecorator: (child, index, animation) => Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  child,
                  MouseRegion(
                    cursor: Platform.isWindows
                        ? SystemMouseCursors.click
                        : SystemMouseCursors.grabbing,
                    child: const SizedBox.expand(),
                  ),
                ],
              ),
            ),
            shrinkWrap: shrinkWrap,
            buildDefaultDragHandles: false,
            itemCount: state.hiddenGroups.length,
            itemBuilder: (_, index) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              key: ValueKey("hiddenGroup${state.hiddenGroups[index].groupId}"),
              child: HiddenGroupCard(
                group: state.hiddenGroups[index],
                index: index,
                bloc: context.read<BoardBloc>(),
              ),
            ),
            onReorder: (oldIndex, newIndex) {
              if (oldIndex < newIndex) {
                newIndex--;
              }
              final fromGroupId = state.hiddenGroups[oldIndex].groupId;
              final toGroupId = state.hiddenGroups[newIndex].groupId;
              context
                  .read<BoardBloc>()
                  .add(BoardEvent.reorderGroup(fromGroupId, toGroupId));
            },
          ),
        );
      },
    );
  }
}

class HiddenGroupCard extends StatefulWidget {
  const HiddenGroupCard({
    super.key,
    required this.group,
    required this.index,
    required this.bloc,
  });

  final GroupPB group;
  final BoardBloc bloc;
  final int index;

  @override
  State<HiddenGroupCard> createState() => _HiddenGroupCardState();
}

class _HiddenGroupCardState extends State<HiddenGroupCard> {
  final PopoverController _popoverController = PopoverController();

  @override
  Widget build(BuildContext context) {
    final databaseController = widget.bloc.databaseController;
    final primaryField = databaseController.fieldController.fieldInfos
        .firstWhereOrNull((element) => element.isPrimary)!;
    return AppFlowyPopover(
      controller: _popoverController,
      direction: PopoverDirection.bottomWithCenterAligned,
      triggerActions: PopoverTriggerFlags.none,
      constraints: const BoxConstraints(maxWidth: 234, maxHeight: 300),
      popupBuilder: (popoverContext) {
        return BlocProvider.value(
          value: context.read<BoardBloc>(),
          child: HiddenGroupPopupItemList(
            viewId: databaseController.viewId,
            groupId: widget.group.groupId,
            primaryFieldId: primaryField.id,
            rowCache: databaseController.rowCache,
          ),
        );
      },
      child: HiddenGroupButtonContent(
        popoverController: _popoverController,
        groupId: widget.group.groupId,
        index: widget.index,
        bloc: widget.bloc,
      ),
    );
  }
}

class HiddenGroupButtonContent extends StatelessWidget {
  const HiddenGroupButtonContent({
    super.key,
    required this.popoverController,
    required this.groupId,
    required this.index,
    required this.bloc,
  });

  final PopoverController popoverController;
  final String groupId;
  final int index;
  final BoardBloc bloc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: popoverController.show,
        child: FlowyHover(
          builder: (context, isHovering) {
            return BlocProvider<BoardBloc>.value(
              value: bloc,
              child: BlocBuilder<BoardBloc, BoardState>(
                builder: (context, state) {
                  return state.maybeMap(
                    orElse: () => const SizedBox.shrink(),
                    ready: (state) {
                      final group = state.hiddenGroups.firstWhereOrNull(
                        (g) => g.groupId == groupId,
                      );
                      if (group == null) {
                        return const SizedBox.shrink();
                      }

                      return SizedBox(
                        height: 32,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 3,
                          ),
                          child: Row(
                            children: [
                              HiddenGroupCardActions(
                                isVisible: isHovering,
                                index: index,
                              ),
                              const HSpace(4),
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: FlowyText(
                                        group.generateGroupName(
                                          bloc.databaseController,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const HSpace(6),
                                    FlowyText(
                                      group.rows.length.toString(),
                                      overflow: TextOverflow.ellipsis,
                                      color: Theme.of(context).hintColor,
                                    ),
                                  ],
                                ),
                              ),
                              if (isHovering) ...[
                                const HSpace(6),
                                FlowyIconButton(
                                  width: 20,
                                  icon: const FlowySvg(
                                    FlowySvgs.show_m,
                                    size: Size.square(16),
                                  ),
                                  onPressed: () =>
                                      context.read<BoardBloc>().add(
                                            BoardEvent.setGroupVisibility(
                                              group,
                                              true,
                                            ),
                                          ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class HiddenGroupCardActions extends StatelessWidget {
  const HiddenGroupCardActions({
    super.key,
    required this.isVisible,
    required this.index,
  });

  final bool isVisible;
  final int index;

  @override
  Widget build(BuildContext context) {
    return ReorderableDragStartListener(
      index: index,
      enabled: isVisible,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: SizedBox(
          height: 14,
          width: 14,
          child: isVisible
              ? FlowySvg(
                  FlowySvgs.drag_element_s,
                  color: Theme.of(context).hintColor,
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class HiddenGroupPopupItemList extends StatelessWidget {
  const HiddenGroupPopupItemList({
    super.key,
    required this.groupId,
    required this.viewId,
    required this.primaryFieldId,
    required this.rowCache,
  });

  final String groupId;
  final String viewId;
  final String primaryFieldId;
  final RowCache rowCache;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BoardBloc, BoardState>(
      builder: (context, state) {
        return state.maybeMap(
          orElse: () => const SizedBox.shrink(),
          ready: (state) {
            final group = state.hiddenGroups.firstWhereOrNull(
              (g) => g.groupId == groupId,
            );
            if (group == null) {
              return const SizedBox.shrink();
            }
            final bloc = context.read<BoardBloc>();
            final cells = <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: FlowyText(
                  group.generateGroupName(bloc.databaseController),
                  fontSize: 10,
                  color: Theme.of(context).hintColor,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ...group.rows.map(
                (item) {
                  final rowController = RowController(
                    rowMeta: item,
                    viewId: viewId,
                    rowCache: rowCache,
                  );
                  rowController.initialize();

                  final databaseController =
                      context.read<BoardBloc>().databaseController;

                  return HiddenGroupPopupItem(
                    cellContext: rowCache.loadCells(item).firstWhere(
                          (cellContext) =>
                              cellContext.fieldId == primaryFieldId,
                        ),
                    rowController: rowController,
                    rowMeta: item,
                    cellBuilder: CardCellBuilder(
                      databaseController: databaseController,
                    ),
                    onPressed: () {
                      FlowyOverlay.show(
                        context: context,
                        builder: (_) => BlocProvider.value(
                          value: context.read<UserWorkspaceBloc>(),
                          child: RowDetailPage(
                            databaseController: databaseController,
                            rowController: rowController,
                            userProfile: context.read<BoardBloc>().userProfile,
                          ),
                        ),
                      );
                      PopoverContainer.of(context).close();
                    },
                  );
                },
              ),
            ];

            return ListView.separated(
              itemBuilder: (context, index) => cells[index],
              itemCount: cells.length,
              separatorBuilder: (context, index) =>
                  VSpace(GridSize.typeOptionSeparatorHeight),
              shrinkWrap: true,
            );
          },
        );
      },
    );
  }
}

class HiddenGroupPopupItem extends StatelessWidget {
  const HiddenGroupPopupItem({
    super.key,
    required this.rowMeta,
    required this.cellContext,
    required this.onPressed,
    required this.cellBuilder,
    required this.rowController,
  });

  final RowMetaPB rowMeta;
  final CellContext cellContext;
  final RowController rowController;
  final CardCellBuilder cellBuilder;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: FlowyButton(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        text: cellBuilder.build(
          cellContext: cellContext,
          styleMap: {FieldType.RichText: _titleCellStyle(context)},
          hasNotes: false,
        ),
        onTap: onPressed,
      ),
    );
  }

  TextCardCellStyle _titleCellStyle(BuildContext context) {
    return TextCardCellStyle(
      padding: EdgeInsets.zero,
      textStyle: Theme.of(context).textTheme.bodyMedium!,
      titleTextStyle: Theme.of(context)
          .textTheme
          .bodyMedium!
          .copyWith(fontSize: 11, overflow: TextOverflow.ellipsis),
    );
  }
}
