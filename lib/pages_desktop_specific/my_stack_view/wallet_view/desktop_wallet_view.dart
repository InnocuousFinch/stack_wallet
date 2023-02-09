import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:stackwallet/notifications/show_flush_bar.dart';
import 'package:stackwallet/pages/paynym/paynym_claim_view.dart';
import 'package:stackwallet/pages/paynym/paynym_home_view.dart';
import 'package:stackwallet/pages_desktop_specific/my_stack_view/wallet_view/sub_widgets/delete_wallet_button.dart';
import 'package:stackwallet/pages_desktop_specific/my_stack_view/wallet_view/sub_widgets/desktop_wallet_summary.dart';
import 'package:stackwallet/pages_desktop_specific/my_stack_view/wallet_view/sub_widgets/my_wallet.dart';
import 'package:stackwallet/pages_desktop_specific/my_stack_view/wallet_view/sub_widgets/network_info_button.dart';
import 'package:stackwallet/pages_desktop_specific/my_stack_view/wallet_view/sub_widgets/recent_desktop_transactions.dart';
import 'package:stackwallet/pages_desktop_specific/my_stack_view/wallet_view/sub_widgets/wallet_keys_button.dart';
import 'package:stackwallet/providers/global/auto_swb_service_provider.dart';
import 'package:stackwallet/providers/global/paynym_api_provider.dart';
import 'package:stackwallet/providers/providers.dart';
import 'package:stackwallet/providers/ui/transaction_filter_provider.dart';
import 'package:stackwallet/providers/wallet/my_paynym_account_state_provider.dart';
import 'package:stackwallet/services/coins/firo/firo_wallet.dart';
import 'package:stackwallet/services/event_bus/events/global/wallet_sync_status_changed_event.dart';
import 'package:stackwallet/services/event_bus/global_event_bus.dart';
import 'package:stackwallet/services/mixins/paynym_wallet_interface.dart';
import 'package:stackwallet/utilities/assets.dart';
import 'package:stackwallet/utilities/constants.dart';
import 'package:stackwallet/utilities/enums/backup_frequency_type.dart';
import 'package:stackwallet/utilities/enums/coin_enum.dart';
import 'package:stackwallet/utilities/enums/derive_path_type_enum.dart';
import 'package:stackwallet/utilities/logger.dart';
import 'package:stackwallet/utilities/text_styles.dart';
import 'package:stackwallet/utilities/theme/stack_colors.dart';
import 'package:stackwallet/widgets/background.dart';
import 'package:stackwallet/widgets/conditional_parent.dart';
import 'package:stackwallet/widgets/custom_buttons/app_bar_icon_button.dart';
import 'package:stackwallet/widgets/custom_loading_overlay.dart';
import 'package:stackwallet/widgets/desktop/desktop_app_bar.dart';
import 'package:stackwallet/widgets/desktop/desktop_dialog.dart';
import 'package:stackwallet/widgets/desktop/desktop_scaffold.dart';
import 'package:stackwallet/widgets/desktop/primary_button.dart';
import 'package:stackwallet/widgets/desktop/secondary_button.dart';
import 'package:stackwallet/widgets/hover_text_field.dart';
import 'package:stackwallet/widgets/loading_indicator.dart';
import 'package:stackwallet/widgets/rounded_white_container.dart';

/// [eventBus] should only be set during testing
class DesktopWalletView extends ConsumerStatefulWidget {
  const DesktopWalletView({
    Key? key,
    required this.walletId,
    this.eventBus,
  }) : super(key: key);

  static const String routeName = "/desktopWalletView";

  final String walletId;
  final EventBus? eventBus;

  @override
  ConsumerState<DesktopWalletView> createState() => _DesktopWalletViewState();
}

class _DesktopWalletViewState extends ConsumerState<DesktopWalletView> {
  late final TextEditingController controller;
  late final EventBus eventBus;

  late final bool _shouldDisableAutoSyncOnLogOut;
  bool _rescanningOnOpen = false;

  Future<void> onBackPressed() async {
    await _logout();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _logout() async {
    final managerProvider = ref
        .read(walletsChangeNotifierProvider)
        .getManagerProvider(widget.walletId);
    if (_shouldDisableAutoSyncOnLogOut) {
      // disable auto sync if it was enabled only when loading wallet
      ref.read(managerProvider).shouldAutoSync = false;
    }
    ref.read(transactionFilterProvider.state).state = null;
    if (ref.read(prefsChangeNotifierProvider).isAutoBackupEnabled &&
        ref.read(prefsChangeNotifierProvider).backupFrequencyType ==
            BackupFrequencyType.afterClosingAWallet) {
      unawaited(ref.read(autoSWBServiceProvider).doBackup());
    }
    ref.read(managerProvider.notifier).isActiveWallet = false;
  }

  Future<void> attemptAnonymize() async {
    final managerProvider = ref
        .read(walletsChangeNotifierProvider)
        .getManagerProvider(widget.walletId);

    bool shouldPop = false;
    unawaited(
      showDialog(
        context: context,
        builder: (context) => WillPopScope(
          child: const CustomLoadingOverlay(
            message: "Anonymizing balance",
            eventBus: null,
          ),
          onWillPop: () async => shouldPop,
        ),
      ),
    );
    final firoWallet = ref.read(managerProvider).wallet as FiroWallet;

    final publicBalance = await firoWallet.availablePublicBalance();
    if (publicBalance <= Decimal.zero) {
      shouldPop = true;
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        Navigator.of(context).popUntil(
          ModalRoute.withName(DesktopWalletView.routeName),
        );
        unawaited(
          showFloatingFlushBar(
            type: FlushBarType.info,
            message: "No funds available to anonymize!",
            context: context,
          ),
        );
      }
      return;
    }

    try {
      await firoWallet.anonymizeAllPublicFunds();
      shouldPop = true;
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        Navigator.of(context).popUntil(
          ModalRoute.withName(DesktopWalletView.routeName),
        );
        unawaited(
          showFloatingFlushBar(
            type: FlushBarType.success,
            message: "Anonymize transaction submitted",
            context: context,
          ),
        );
      }
    } catch (e) {
      shouldPop = true;
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        Navigator.of(context).popUntil(
          ModalRoute.withName(DesktopWalletView.routeName),
        );
        await showDialog<dynamic>(
          context: context,
          builder: (_) => DesktopDialog(
            maxWidth: 400,
            maxHeight: 300,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Anonymize all failed",
                    style: STextStyles.desktopH3(context),
                  ),
                  const Spacer(
                    flex: 1,
                  ),
                  Text(
                    "Reason: $e",
                    style: STextStyles.desktopTextSmall(context),
                  ),
                  const Spacer(
                    flex: 2,
                  ),
                  Row(
                    children: [
                      const Spacer(),
                      const SizedBox(
                        width: 16,
                      ),
                      Expanded(
                        child: PrimaryButton(
                          label: "Ok",
                          buttonHeight: ButtonHeight.l,
                          onPressed:
                              Navigator.of(context, rootNavigator: true).pop,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> onPaynymButtonPressed() async {
    unawaited(
      showDialog(
        context: context,
        builder: (context) => const LoadingIndicator(
          width: 100,
        ),
      ),
    );

    final manager =
        ref.read(walletsChangeNotifierProvider).getManager(widget.walletId);

    final wallet = manager.wallet as PaynymWalletInterface;

    final code =
        await wallet.getPaymentCode(DerivePathTypeExt.primaryFor(manager.coin));

    final account = await ref.read(paynymAPIProvider).nym(code.toString());

    Logging.instance.log(
      "my nym account: $account",
      level: LogLevel.Info,
    );

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();

      // check if account exists and for matching code to see if claimed
      if (account.value != null && account.value!.codes.first.claimed) {
        ref.read(myPaynymAccountStateProvider.state).state = account.value!;

        await Navigator.of(context).pushNamed(
          PaynymHomeView.routeName,
          arguments: widget.walletId,
        );
      } else {
        await Navigator.of(context).pushNamed(
          PaynymClaimView.routeName,
          arguments: widget.walletId,
        );
      }
    }
  }

  @override
  void initState() {
    controller = TextEditingController();
    final managerProvider = ref
        .read(walletsChangeNotifierProvider)
        .getManagerProvider(widget.walletId);

    controller.text = ref.read(managerProvider).walletName;

    eventBus =
        widget.eventBus != null ? widget.eventBus! : GlobalEventBus.instance;

    ref.read(managerProvider).isActiveWallet = true;
    if (!ref.read(managerProvider).shouldAutoSync) {
      // enable auto sync if it wasn't enabled when loading wallet
      ref.read(managerProvider).shouldAutoSync = true;
      _shouldDisableAutoSyncOnLogOut = true;
    } else {
      _shouldDisableAutoSyncOnLogOut = false;
    }

    if (ref.read(managerProvider).rescanOnOpenVersion == Constants.rescanV1) {
      _rescanningOnOpen = true;
      ref.read(managerProvider).fullRescan(20, 1000).then(
            (_) => ref.read(managerProvider).resetRescanOnOpen().then(
                  (_) => WidgetsBinding.instance.addPostFrameCallback(
                    (_) => setState(() => _rescanningOnOpen = false),
                  ),
                ),
          );
    } else {
      ref.read(managerProvider).refresh();
    }

    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(walletsChangeNotifierProvider
        .select((value) => value.getManager(widget.walletId)));
    final coin = manager.coin;
    final managerProvider = ref.watch(walletsChangeNotifierProvider
        .select((value) => value.getManagerProvider(widget.walletId)));

    return ConditionalParent(
      condition: _rescanningOnOpen,
      builder: (child) {
        return Stack(
          children: [
            child,
            Background(
              child: CustomLoadingOverlay(
                message:
                    "Migration in progress\nThis could take a while\nPlease don't leave this screen",
                subMessage: "This only needs to run once per wallet",
                eventBus: null,
                textColor: Theme.of(context).extension<StackColors>()!.textDark,
              ),
            )
          ],
        );
      },
      child: DesktopScaffold(
        appBar: DesktopAppBar(
          background: Theme.of(context).extension<StackColors>()!.popupBG,
          leading: Expanded(
            child: Row(
              children: [
                const SizedBox(
                  width: 32,
                ),
                AppBarIconButton(
                  size: 32,
                  color: Theme.of(context)
                      .extension<StackColors>()!
                      .textFieldDefaultBG,
                  shadows: const [],
                  icon: SvgPicture.asset(
                    Assets.svg.arrowLeft,
                    width: 18,
                    height: 18,
                    color: Theme.of(context)
                        .extension<StackColors>()!
                        .topNavIconPrimary,
                  ),
                  onPressed: onBackPressed,
                ),
                const SizedBox(
                  width: 15,
                ),
                SvgPicture.asset(
                  Assets.svg.iconFor(coin: coin),
                  width: 32,
                  height: 32,
                ),
                const SizedBox(
                  width: 12,
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                  ),
                  child: IntrinsicWidth(
                    child: DesktopWalletNameField(
                      walletId: widget.walletId,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    NetworkInfoButton(
                      walletId: widget.walletId,
                      eventBus: eventBus,
                    ),
                    const SizedBox(
                      width: 2,
                    ),
                    WalletKeysButton(
                      walletId: widget.walletId,
                    ),
                    const SizedBox(
                      width: 2,
                    ),
                    DeleteWalletButton(
                      walletId: widget.walletId,
                    ),
                    const SizedBox(
                      width: 12,
                    ),
                  ],
                ),
              ],
            ),
          ),
          useSpacers: false,
          isCompactHeight: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              RoundedWhiteContainer(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      Assets.svg.iconFor(coin: coin),
                      width: 40,
                      height: 40,
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    DesktopWalletSummary(
                      walletId: widget.walletId,
                      managerProvider: managerProvider,
                      initialSyncStatus: ref.watch(managerProvider
                              .select((value) => value.isRefreshing))
                          ? WalletSyncStatus.syncing
                          : WalletSyncStatus.synced,
                    ),
                    const Spacer(),
                    if (coin == Coin.firo) const SizedBox(width: 10),
                    if (coin == Coin.firo)
                      SecondaryButton(
                        width: 180,
                        buttonHeight: ButtonHeight.l,
                        label: "Anonymize funds",
                        onPressed: () async {
                          await showDialog<void>(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => DesktopDialog(
                              maxWidth: 500,
                              maxHeight: 210,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 20),
                                child: Column(
                                  children: [
                                    Text(
                                      "Attention!",
                                      style: STextStyles.desktopH2(context),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      "You're about to anonymize all of your public funds.",
                                      style:
                                          STextStyles.desktopTextSmall(context),
                                    ),
                                    const SizedBox(height: 32),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SecondaryButton(
                                          width: 200,
                                          buttonHeight: ButtonHeight.l,
                                          label: "Cancel",
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                        const SizedBox(width: 20),
                                        PrimaryButton(
                                          width: 200,
                                          buttonHeight: ButtonHeight.l,
                                          label: "Continue",
                                          onPressed: () {
                                            Navigator.of(context).pop();

                                            unawaited(attemptAnonymize());
                                          },
                                        )
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    if (ref.watch(walletsChangeNotifierProvider.select(
                        (value) => value
                            .getManager(widget.walletId)
                            .hasPaynymSupport)))
                      SecondaryButton(
                        label: "PayNym",
                        width: 160,
                        buttonHeight: ButtonHeight.l,
                        icon: SvgPicture.asset(
                          Assets.svg.user,
                          height: 20,
                          width: 20,
                          color: Theme.of(context)
                              .extension<StackColors>()!
                              .buttonTextSecondary,
                        ),
                        onPressed: onPaynymButtonPressed,
                      ),
                    // if (coin == Coin.firo) const SizedBox(width: 16),
                    // SecondaryButton(
                    //   width: 180,
                    //   buttonHeight: ButtonHeight.l,
                    //   onPressed: () {
                    //     _onExchangePressed(context);
                    //   },
                    //   label: "Exchange",
                    //   icon: Container(
                    //     width: 24,
                    //     height: 24,
                    //     decoration: BoxDecoration(
                    //       borderRadius: BorderRadius.circular(24),
                    //       color: Theme.of(context)
                    //           .extension<StackColors>()!
                    //           .buttonBackPrimary
                    //           .withOpacity(0.2),
                    //     ),
                    //     child: Center(
                    //       child: SvgPicture.asset(
                    //         Assets.svg.arrowRotate2,
                    //         width: 14,
                    //         height: 14,
                    //         color: Theme.of(context)
                    //             .extension<StackColors>()!
                    //             .buttonTextSecondary,
                    //       ),
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ),
              const SizedBox(
                height: 24,
              ),
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 450,
                      child: MyWallet(
                        walletId: widget.walletId,
                      ),
                    ),
                    const SizedBox(
                      width: 16,
                    ),
                    Expanded(
                      child: RecentDesktopTransactions(
                        walletId: widget.walletId,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
