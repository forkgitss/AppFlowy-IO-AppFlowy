import 'package:appflowy/core/helpers/url_launcher.dart';
import 'package:appflowy/env/cloud_env.dart';
import 'package:appflowy/env/env.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/shared/share/constants.dart';
import 'package:appflowy/shared/error_page/error_page.dart';
import 'package:appflowy/workspace/application/settings/appflowy_cloud_setting_bloc.dart';
import 'package:appflowy/workspace/application/settings/appflowy_cloud_urls_bloc.dart';
import 'package:appflowy/workspace/presentation/settings/widgets/_restart_app_button.dart';
import 'package:appflowy/workspace/presentation/settings/widgets/web_url_hint_widget.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy/workspace/presentation/widgets/toggle/toggle.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/size.dart';
import 'package:flowy_infra/theme_extension.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppFlowyCloudViewSetting extends StatelessWidget {
  const AppFlowyCloudViewSetting({
    super.key,
    this.serverURL = kAppflowyCloudUrl,
    this.authenticatorType = AuthenticatorType.appflowyCloud,
    required this.restartAppFlowy,
  });

  final String serverURL;
  final AuthenticatorType authenticatorType;
  final VoidCallback restartAppFlowy;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FlowyResult<CloudSettingPB, FlowyError>>(
      future: UserEventGetCloudConfig().send(),
      builder: (context, snapshot) {
        if (snapshot.data != null &&
            snapshot.connectionState == ConnectionState.done) {
          return snapshot.data!.fold(
            (setting) => _renderContent(context, setting),
            (err) => FlowyErrorPage.message(err.toString(), howToFix: ""),
          );
        }

        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }

  BlocProvider<AppFlowyCloudSettingBloc> _renderContent(
    BuildContext context,
    CloudSettingPB setting,
  ) {
    return BlocProvider(
      create: (context) => AppFlowyCloudSettingBloc(setting)
        ..add(const AppFlowyCloudSettingEvent.initial()),
      child: BlocBuilder<AppFlowyCloudSettingBloc, AppFlowyCloudSettingState>(
        builder: (context, state) {
          return Column(
            children: [
              const VSpace(8),
              if (state.workspaceType == WorkspaceTypePB.ServerW)
                const AppFlowyCloudEnableSync(),
              const VSpace(6),
              // const AppFlowyCloudSyncLogEnabled(),
              const VSpace(12),
              RestartButton(
                onClick: () {
                  NavigatorAlertDialog(
                    title: LocaleKeys.settings_menu_restartAppTip.tr(),
                    confirm: () async {
                      await useBaseWebDomain(
                        ShareConstants.defaultBaseWebDomain,
                      );
                      await useAppFlowyBetaCloudWithURL(
                        serverURL,
                        authenticatorType,
                      );
                      restartAppFlowy();
                    },
                  ).show(context);
                },
                showRestartHint: state.showRestartHint,
              ),
            ],
          );
        },
      ),
    );
  }
}

class CustomAppFlowyCloudView extends StatelessWidget {
  const CustomAppFlowyCloudView({required this.restartAppFlowy, super.key});

  final VoidCallback restartAppFlowy;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FlowyResult<CloudSettingPB, FlowyError>>(
      future: UserEventGetCloudConfig().send(),
      builder: (context, snapshot) {
        if (snapshot.data != null &&
            snapshot.connectionState == ConnectionState.done) {
          return snapshot.data!.fold(
            (setting) => _renderContent(setting),
            (err) => FlowyErrorPage.message(err.toString(), howToFix: ""),
          );
        } else {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
      },
    );
  }

  BlocProvider<AppFlowyCloudSettingBloc> _renderContent(
    CloudSettingPB setting,
  ) {
    final List<Widget> children = [];
    children.addAll([
      const AppFlowyCloudEnableSync(),
      // const AppFlowyCloudSyncLogEnabled(),
      const VSpace(40),
    ]);

    // If the enableCustomCloud flag is true, then the user can dynamically configure cloud settings. Otherwise, the user cannot dynamically configure cloud settings.
    if (Env.enableCustomCloud) {
      children.add(
        AppFlowyCloudURLs(restartAppFlowy: () => restartAppFlowy()),
      );
    } else {
      children.add(
        Row(
          children: [
            FlowyText(LocaleKeys.settings_menu_cloudServerType.tr()),
            const Spacer(),
            const FlowyText(Env.afCloudUrl),
          ],
        ),
      );
    }
    return BlocProvider(
      create: (context) => AppFlowyCloudSettingBloc(setting)
        ..add(const AppFlowyCloudSettingEvent.initial()),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class AppFlowyCloudURLs extends StatelessWidget {
  const AppFlowyCloudURLs({super.key, required this.restartAppFlowy});

  final VoidCallback restartAppFlowy;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          AppFlowyCloudURLsBloc()..add(const AppFlowyCloudURLsEvent.initial()),
      child: BlocListener<AppFlowyCloudURLsBloc, AppFlowyCloudURLsState>(
        listener: (context, state) async {
          if (state.restartApp) {
            restartAppFlowy();
          }
        },
        child: BlocBuilder<AppFlowyCloudURLsBloc, AppFlowyCloudURLsState>(
          builder: (context, state) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppFlowySelfHostTip(),
                const VSpace(12),
                CloudURLInput(
                  title: LocaleKeys.settings_menu_cloudURL.tr(),
                  url: state.config.base_url,
                  hint: LocaleKeys.settings_menu_cloudURLHint.tr(),
                  onChanged: (text) {
                    context.read<AppFlowyCloudURLsBloc>().add(
                          AppFlowyCloudURLsEvent.updateServerUrl(
                            text,
                          ),
                        );
                  },
                ),
                const VSpace(8),
                CloudURLInput(
                  title: LocaleKeys.settings_menu_webURL.tr(),
                  url: state.config.base_web_domain,
                  hint: LocaleKeys.settings_menu_webURLHint.tr(),
                  hintBuilder: (context) => const WebUrlHintWidget(),
                  onChanged: (text) {
                    context.read<AppFlowyCloudURLsBloc>().add(
                          AppFlowyCloudURLsEvent.updateBaseWebDomain(
                            text,
                          ),
                        );
                  },
                ),
                const VSpace(12),
                RestartButton(
                  onClick: () {
                    NavigatorAlertDialog(
                      title: LocaleKeys.settings_menu_restartAppTip.tr(),
                      confirm: () {
                        context.read<AppFlowyCloudURLsBloc>().add(
                              const AppFlowyCloudURLsEvent.confirmUpdate(),
                            );
                      },
                    ).show(context);
                  },
                  showRestartHint: state.showRestartHint,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class AppFlowySelfHostTip extends StatelessWidget {
  const AppFlowySelfHostTip({super.key});

  final url =
      "https://docs.appflowy.io/docs/guides/appflowy/self-hosting-appflowy#build-appflowy-with-a-self-hosted-server";

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.6,
      child: RichText(
        text: TextSpan(
          children: <TextSpan>[
            TextSpan(
              text: LocaleKeys.settings_menu_selfHostStart.tr(),
              style: Theme.of(context).textTheme.bodySmall!,
            ),
            TextSpan(
              text: " ${LocaleKeys.settings_menu_selfHostContent.tr()} ",
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontSize: FontSizes.s14,
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => afLaunchUrlString(url),
            ),
            TextSpan(
              text: LocaleKeys.settings_menu_selfHostEnd.tr(),
              style: Theme.of(context).textTheme.bodySmall!,
            ),
          ],
        ),
      ),
    );
  }
}

@visibleForTesting
class CloudURLInput extends StatefulWidget {
  const CloudURLInput({
    super.key,
    required this.title,
    required this.url,
    required this.hint,
    required this.onChanged,
    this.hintBuilder,
  });

  final String title;
  final String url;
  final String hint;
  final ValueChanged<String> onChanged;
  final WidgetBuilder? hintBuilder;

  @override
  CloudURLInputState createState() => CloudURLInputState();
}

class CloudURLInputState extends State<CloudURLInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.url);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHint(context),
        SizedBox(
          height: 28,
          child: TextField(
            controller: _controller,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
            decoration: InputDecoration(
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: AFThemeExtension.of(context).onBackground,
                ),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              hintText: widget.hint,
              errorText: context.read<AppFlowyCloudURLsBloc>().state.urlError,
            ),
            onChanged: widget.onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildHint(BuildContext context) {
    final children = <Widget>[
      FlowyText(
        widget.title,
        fontSize: 12,
      ),
    ];

    if (widget.hintBuilder != null) {
      children.add(widget.hintBuilder!(context));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class AppFlowyCloudEnableSync extends StatelessWidget {
  const AppFlowyCloudEnableSync({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppFlowyCloudSettingBloc, AppFlowyCloudSettingState>(
      builder: (context, state) {
        return Row(
          children: [
            FlowyText.medium(LocaleKeys.settings_menu_enableSync.tr()),
            const Spacer(),
            Toggle(
              value: state.setting.enableSync,
              onChanged: (value) => context
                  .read<AppFlowyCloudSettingBloc>()
                  .add(AppFlowyCloudSettingEvent.enableSync(value)),
            ),
          ],
        );
      },
    );
  }
}

class AppFlowyCloudSyncLogEnabled extends StatelessWidget {
  const AppFlowyCloudSyncLogEnabled({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppFlowyCloudSettingBloc, AppFlowyCloudSettingState>(
      builder: (context, state) {
        return Row(
          children: [
            FlowyText.medium(LocaleKeys.settings_menu_enableSyncLog.tr()),
            const Spacer(),
            Toggle(
              value: state.isSyncLogEnabled,
              onChanged: (value) {
                if (value) {
                  showCancelAndConfirmDialog(
                    context: context,
                    title: LocaleKeys.settings_menu_enableSyncLog.tr(),
                    description:
                        LocaleKeys.settings_menu_enableSyncLogWarning.tr(),
                    confirmLabel: LocaleKeys.button_confirm.tr(),
                    onConfirm: (_) {
                      context
                          .read<AppFlowyCloudSettingBloc>()
                          .add(AppFlowyCloudSettingEvent.enableSyncLog(value));
                    },
                  );
                } else {
                  context
                      .read<AppFlowyCloudSettingBloc>()
                      .add(AppFlowyCloudSettingEvent.enableSyncLog(value));
                }
              },
            ),
          ],
        );
      },
    );
  }
}

class BillingGateGuard extends StatelessWidget {
  const BillingGateGuard({required this.builder, super.key});

  final Widget Function(BuildContext context) builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: isBillingEnabled(),
      builder: (context, snapshot) {
        final isBillingEnabled = snapshot.data ?? false;
        if (isBillingEnabled &&
            snapshot.connectionState == ConnectionState.done) {
          return builder(context);
        }

        // If the billing is not enabled, show nothing
        return const SizedBox.shrink();
      },
    );
  }
}

Future<bool> isBillingEnabled() async {
  final result = await UserEventGetCloudConfig().send();
  return result.fold(
    (cloudSetting) {
      final whiteList = [
        "https://beta.appflowy.cloud",
        "https://test.appflowy.cloud",
      ];
      if (kDebugMode) {
        whiteList.add("http://localhost:8000");
      }

      final isWhiteListed = whiteList.contains(cloudSetting.serverUrl);
      if (!isWhiteListed) {
        Log.warn("Billing is not enabled for server ${cloudSetting.serverUrl}");
      }
      return isWhiteListed;
    },
    (err) {
      Log.error("Failed to get cloud config: $err");
      return false;
    },
  );
}
