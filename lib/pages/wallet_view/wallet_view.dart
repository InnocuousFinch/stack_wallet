import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:isar/isar.dart';
import 'package:stackwallet/models/isar/exchange_cache/currency.dart';
import 'package:stackwallet/notifications/show_flush_bar.dart';
import 'package:stackwallet/pages/buy_view/buy_in_wallet_view.dart';
import 'package:stackwallet/pages/coin_control/coin_control_view.dart';
import 'package:stackwallet/pages/exchange_view/wallet_initiated_exchange_view.dart';
import 'package:stackwallet/pages/home_view/home_view.dart';
import 'package:stackwallet/pages/notification_views/notifications_view.dart';
import 'package:stackwallet/pages/paynym/paynym_claim_view.dart';
import 'package:stackwallet/pages/paynym/paynym_home_view.dart';
import 'package:stackwallet/pages/receive_view/receive_view.dart';
import 'package:stackwallet/pages/send_view/send_view.dart';
import 'package:stackwallet/pages/settings_views/wallet_settings_view/wallet_network_settings_view/wallet_network_settings_view.dart';
import 'package:stackwallet/pages/settings_views/wallet_settings_view/wallet_settings_view.dart';
import 'package:stackwallet/pages/wallet_view/sub_widgets/transactions_list.dart';
import 'package:stackwallet/pages/wallet_view/sub_widgets/wallet_summary.dart';
import 'package:stackwallet/pages/wallet_view/transaction_views/all_transactions_view.dart';
import 'package:stackwallet/providers/global/auto_swb_service_provider.dart';
import 'package:stackwallet/providers/global/paynym_api_provider.dart';
import 'package:stackwallet/providers/providers.dart';
import 'package:stackwallet/providers/ui/transaction_filter_provider.dart';
import 'package:stackwallet/providers/ui/unread_notifications_provider.dart';
import 'package:stackwallet/providers/wallet/my_paynym_account_state_provider.dart';
import 'package:stackwallet/providers/wallet/public_private_balance_state_provider.dart';
import 'package:stackwallet/providers/wallet/wallet_balance_toggle_state_provider.dart';
import 'package:stackwallet/services/coins/firo/firo_wallet.dart';
import 'package:stackwallet/services/coins/manager.dart';
import 'package:stackwallet/services/event_bus/events/global/node_connection_status_changed_event.dart';
import 'package:stackwallet/services/event_bus/events/global/wallet_sync_status_changed_event.dart';
import 'package:stackwallet/services/event_bus/global_event_bus.dart';
import 'package:stackwallet/services/exchange/exchange_data_loading_service.dart';
import 'package:stackwallet/services/mixins/paynym_wallet_interface.dart';
import 'package:stackwallet/utilities/assets.dart';
import 'package:stackwallet/utilities/constants.dart';
import 'package:stackwallet/utilities/enums/backup_frequency_type.dart';
import 'package:stackwallet/utilities/enums/coin_enum.dart';
import 'package:stackwallet/utilities/enums/derive_path_type_enum.dart';
import 'package:stackwallet/utilities/enums/wallet_balance_toggle_state.dart';
import 'package:stackwallet/utilities/logger.dart';
import 'package:stackwallet/utilities/text_styles.dart';
import 'package:stackwallet/utilities/theme/stack_colors.dart';
import 'package:stackwallet/widgets/background.dart';
import 'package:stackwallet/widgets/conditional_parent.dart';
import 'package:stackwallet/widgets/custom_buttons/app_bar_icon_button.dart';
import 'package:stackwallet/widgets/custom_buttons/blue_text_button.dart';
import 'package:stackwallet/widgets/custom_loading_overlay.dart';
import 'package:stackwallet/widgets/loading_indicator.dart';
import 'package:stackwallet/widgets/stack_dialog.dart';
import 'package:stackwallet/widgets/wallet_navigation_bar/components/icons/buy_nav_icon.dart';
import 'package:stackwallet/widgets/wallet_navigation_bar/components/icons/coin_control_nav_icon.dart';
import 'package:stackwallet/widgets/wallet_navigation_bar/components/icons/exchange_nav_icon.dart';
import 'package:stackwallet/widgets/wallet_navigation_bar/components/icons/paynym_nav_icon.dart';
import 'package:stackwallet/widgets/wallet_navigation_bar/components/icons/receive_nav_icon.dart';
import 'package:stackwallet/widgets/wallet_navigation_bar/components/icons/send_nav_icon.dart';
import 'package:stackwallet/widgets/wallet_navigation_bar/components/wallet_navigation_bar_item.dart';
import 'package:stackwallet/widgets/wallet_navigation_bar/wallet_navigation_bar.dart';
import 'package:tuple/tuple.dart';

/// [eventBus] should only be set during testing
class WalletView extends ConsumerStatefulWidget {
  const WalletView({
    Key? key,
    required this.walletId,
    required this.managerProvider,
    this.eventBus,
  }) : super(key: key);

  static const String routeName = "/wallet";
  static const double navBarHeight = 65.0;

  final String walletId;
  final ChangeNotifierProvider<Manager> managerProvider;
  final EventBus? eventBus;

  @override
  ConsumerState<WalletView> createState() => _WalletViewState();
}

class _WalletViewState extends ConsumerState<WalletView> {
  late final EventBus eventBus;
  late final String walletId;
  late final ChangeNotifierProvider<Manager> managerProvider;

  late final bool _shouldDisableAutoSyncOnLogOut;

  late WalletSyncStatus _currentSyncStatus;
  late NodeConnectionStatus _currentNodeStatus;

  late StreamSubscription<dynamic> _syncStatusSubscription;
  late StreamSubscription<dynamic> _nodeStatusSubscription;

  bool _rescanningOnOpen = false;

  @override
  void initState() {
    walletId = widget.walletId;
    managerProvider = widget.managerProvider;

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

    if (ref.read(managerProvider).isRefreshing) {
      _currentSyncStatus = WalletSyncStatus.syncing;
      _currentNodeStatus = NodeConnectionStatus.connected;
    } else {
      _currentSyncStatus = WalletSyncStatus.synced;
      if (ref.read(managerProvider).isConnected) {
        _currentNodeStatus = NodeConnectionStatus.connected;
      } else {
        _currentNodeStatus = NodeConnectionStatus.disconnected;
        _currentSyncStatus = WalletSyncStatus.unableToSync;
      }
    }

    eventBus =
        widget.eventBus != null ? widget.eventBus! : GlobalEventBus.instance;

    _syncStatusSubscription =
        eventBus.on<WalletSyncStatusChangedEvent>().listen(
      (event) async {
        if (event.walletId == widget.walletId) {
          // switch (event.newStatus) {
          //   case WalletSyncStatus.unableToSync:
          //     break;
          //   case WalletSyncStatus.synced:
          //     break;
          //   case WalletSyncStatus.syncing:
          //     break;
          // }
          setState(() {
            _currentSyncStatus = event.newStatus;
          });
        }
      },
    );

    _nodeStatusSubscription =
        eventBus.on<NodeConnectionStatusChangedEvent>().listen(
      (event) async {
        if (event.walletId == widget.walletId) {
          // switch (event.newStatus) {
          //   case NodeConnectionStatus.disconnected:
          //     break;
          //   case NodeConnectionStatus.connected:
          //     break;
          // }
          setState(() {
            _currentNodeStatus = event.newStatus;
          });
        }
      },
    );

    super.initState();
  }

  @override
  void dispose() {
    _nodeStatusSubscription.cancel();
    _syncStatusSubscription.cancel();
    super.dispose();
  }

  DateTime? _cachedTime;

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    const timeout = Duration(milliseconds: 1500);
    if (_cachedTime == null || now.difference(_cachedTime!) > timeout) {
      _cachedTime = now;
      unawaited(showDialog<dynamic>(
        context: context,
        barrierDismissible: false,
        builder: (_) => WillPopScope(
          onWillPop: () async {
            Navigator.of(context).popUntil(
              ModalRoute.withName(HomeView.routeName),
            );
            _logout();
            return false;
          },
          child: const StackDialog(title: "Tap back again to exit wallet"),
        ),
      ).timeout(
        timeout,
        onTimeout: () => Navigator.of(context).popUntil(
          ModalRoute.withName(WalletView.routeName),
        ),
      ));
    }
    return false;
  }

  void _logout() async {
    if (_shouldDisableAutoSyncOnLogOut) {
      // disable auto sync if it was enabled only when loading wallet
      ref.read(managerProvider).shouldAutoSync = false;
    }
    ref.read(managerProvider.notifier).isActiveWallet = false;
    ref.read(transactionFilterProvider.state).state = null;
    if (ref.read(prefsChangeNotifierProvider).isAutoBackupEnabled &&
        ref.read(prefsChangeNotifierProvider).backupFrequencyType ==
            BackupFrequencyType.afterClosingAWallet) {
      unawaited(ref.read(autoSWBServiceProvider).doBackup());
    }
  }

  Widget _buildNetworkIcon(WalletSyncStatus status) {
    switch (status) {
      case WalletSyncStatus.unableToSync:
        return SvgPicture.asset(
          Assets.svg.radioProblem,
          color: Theme.of(context).extension<StackColors>()!.accentColorRed,
          width: 20,
          height: 20,
        );
      case WalletSyncStatus.synced:
        return SvgPicture.asset(
          Assets.svg.radio,
          color: Theme.of(context).extension<StackColors>()!.accentColorGreen,
          width: 20,
          height: 20,
        );
      case WalletSyncStatus.syncing:
        return SvgPicture.asset(
          Assets.svg.radioSyncing,
          color: Theme.of(context).extension<StackColors>()!.accentColorYellow,
          width: 20,
          height: 20,
        );
    }
  }

  void _onExchangePressed(BuildContext context) async {
    final coin = ref.read(managerProvider).coin;

    final currency = ExchangeDataLoadingService.instance.isar.currencies
        .where()
        .tickerEqualToAnyExchangeNameName(coin.ticker)
        .findFirstSync();

    if (coin.isTestNet) {
      await showDialog<void>(
        context: context,
        builder: (_) => const StackOkDialog(
          title: "Exchange not available for test net coins",
        ),
      );
    } else {
      if (mounted) {
        unawaited(
          Navigator.of(context).pushNamed(
            WalletInitiatedExchangeView.routeName,
            arguments: Tuple2(
              walletId,
              currency == null ? Coin.bitcoin : coin,
            ),
          ),
        );
      }
    }
  }

  void _onBuyPressed(BuildContext context) async {
    final coin = ref.read(managerProvider).coin;

    if (coin.isTestNet) {
      await showDialog<void>(
        context: context,
        builder: (_) => const StackOkDialog(
          title: "Buy not available for test net coins",
        ),
      );
    } else {
      if (mounted) {
        unawaited(
          Navigator.of(context).pushNamed(
            BuyInWalletView.routeName,
            arguments: coin.hasBuySupport ? coin : Coin.bitcoin,
          ),
        );
      }
    }
  }

  Future<void> attemptAnonymize() async {
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

    final publicBalance = firoWallet.availablePublicBalance();
    if (publicBalance <= Decimal.zero) {
      shouldPop = true;
      if (mounted) {
        Navigator.of(context).popUntil(
          ModalRoute.withName(WalletView.routeName),
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
        Navigator.of(context).popUntil(
          ModalRoute.withName(WalletView.routeName),
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
        Navigator.of(context).popUntil(
          ModalRoute.withName(WalletView.routeName),
        );
        await showDialog<dynamic>(
          context: context,
          builder: (_) => StackOkDialog(
            title: "Anonymize all failed",
            message: "Reason: $e",
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("BUILD: $runtimeType");

    final coin = ref.watch(managerProvider.select((value) => value.coin));

    return ConditionalParent(
      condition: _rescanningOnOpen,
      builder: (child) {
        return WillPopScope(
          onWillPop: () async => !_rescanningOnOpen,
          child: Stack(
            children: [
              child,
              Background(
                child: CustomLoadingOverlay(
                  message:
                      "Migration in progress\nThis could take a while\nPlease don't leave this screen",
                  subMessage: "This only needs to run once per wallet",
                  eventBus: null,
                  textColor:
                      Theme.of(context).extension<StackColors>()!.textDark,
                ),
              )
            ],
          ),
        );
      },
      child: WillPopScope(
        onWillPop: _onWillPop,
        child: Background(
          child: Stack(
            children: [
              Scaffold(
                backgroundColor:
                    Theme.of(context).extension<StackColors>()!.background,
                appBar: AppBar(
                  leading: AppBarBackButton(
                    onPressed: () {
                      _logout();
                      Navigator.of(context).pop();
                    },
                  ),
                  titleSpacing: 0,
                  title: Row(
                    children: [
                      SvgPicture.asset(
                        Assets.svg.iconFor(coin: coin),
                        // color: Theme.of(context).extension<StackColors>()!.accentColorDark
                        width: 24,
                        height: 24,
                      ),
                      const SizedBox(
                        width: 16,
                      ),
                      Expanded(
                        child: Text(
                          ref.watch(managerProvider
                              .select((value) => value.walletName)),
                          style: STextStyles.navBarTitle(context),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    ],
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 10,
                        bottom: 10,
                        right: 10,
                      ),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: AppBarIconButton(
                          key: const Key("walletViewRadioButton"),
                          size: 36,
                          shadows: const [],
                          color: Theme.of(context)
                              .extension<StackColors>()!
                              .background,
                          icon: _buildNetworkIcon(_currentSyncStatus),
                          onPressed: () {
                            Navigator.of(context).pushNamed(
                              WalletNetworkSettingsView.routeName,
                              arguments: Tuple3(
                                walletId,
                                _currentSyncStatus,
                                _currentNodeStatus,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 10,
                        bottom: 10,
                        right: 10,
                      ),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: AppBarIconButton(
                          key: const Key("walletViewAlertsButton"),
                          size: 36,
                          shadows: const [],
                          color: Theme.of(context)
                              .extension<StackColors>()!
                              .background,
                          icon: SvgPicture.asset(
                            ref.watch(notificationsProvider.select((value) =>
                                    value.hasUnreadNotificationsFor(walletId)))
                                ? Assets.svg.bellNew(context)
                                : Assets.svg.bell,
                            width: 20,
                            height: 20,
                            color: ref.watch(notificationsProvider.select(
                                    (value) => value
                                        .hasUnreadNotificationsFor(walletId)))
                                ? null
                                : Theme.of(context)
                                    .extension<StackColors>()!
                                    .topNavIconPrimary,
                          ),
                          onPressed: () {
                            // reset unread state
                            ref.refresh(unreadNotificationsStateProvider);

                            Navigator.of(context)
                                .pushNamed(
                              NotificationsView.routeName,
                              arguments: walletId,
                            )
                                .then((_) {
                              final Set<int> unreadNotificationIds = ref
                                  .read(unreadNotificationsStateProvider.state)
                                  .state;
                              if (unreadNotificationIds.isEmpty) return;

                              List<Future<dynamic>> futures = [];
                              for (int i = 0;
                                  i < unreadNotificationIds.length - 1;
                                  i++) {
                                futures.add(ref
                                    .read(notificationsProvider)
                                    .markAsRead(
                                        unreadNotificationIds.elementAt(i),
                                        false));
                              }

                              // wait for multiple to update if any
                              Future.wait(futures).then((_) {
                                // only notify listeners once
                                ref.read(notificationsProvider).markAsRead(
                                    unreadNotificationIds.last, true);
                              });
                            });
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 10,
                        bottom: 10,
                        right: 10,
                      ),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: AppBarIconButton(
                          key: const Key("walletViewSettingsButton"),
                          size: 36,
                          shadows: const [],
                          color: Theme.of(context)
                              .extension<StackColors>()!
                              .background,
                          icon: SvgPicture.asset(
                            Assets.svg.bars,
                            color: Theme.of(context)
                                .extension<StackColors>()!
                                .accentColorDark,
                            width: 20,
                            height: 20,
                          ),
                          onPressed: () {
                            //todo: check if print needed
                            // debugPrint("wallet view settings tapped");
                            Navigator.of(context).pushNamed(
                              WalletSettingsView.routeName,
                              arguments: Tuple4(
                                walletId,
                                ref.read(managerProvider).coin,
                                _currentSyncStatus,
                                _currentNodeStatus,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                body: SafeArea(
                  child: Container(
                    color:
                        Theme.of(context).extension<StackColors>()!.background,
                    child: Column(
                      children: [
                        const SizedBox(
                          height: 10,
                        ),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: WalletSummary(
                              walletId: walletId,
                              managerProvider: managerProvider,
                              initialSyncStatus: ref.watch(managerProvider
                                      .select((value) => value.isRefreshing))
                                  ? WalletSyncStatus.syncing
                                  : WalletSyncStatus.synced,
                            ),
                          ),
                        ),
                        if (coin == Coin.firo)
                          const SizedBox(
                            height: 10,
                          ),
                        if (coin == Coin.firo)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    style: Theme.of(context)
                                        .extension<StackColors>()!
                                        .getSecondaryEnabledButtonStyle(
                                            context),
                                    onPressed: () async {
                                      await showDialog<void>(
                                        context: context,
                                        builder: (context) => StackDialog(
                                          title: "Attention!",
                                          message:
                                              "You're about to anonymize all of your public funds.",
                                          leftButton: TextButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            child: Text(
                                              "Cancel",
                                              style: STextStyles.button(context)
                                                  .copyWith(
                                                color: Theme.of(context)
                                                    .extension<StackColors>()!
                                                    .accentColorDark,
                                              ),
                                            ),
                                          ),
                                          rightButton: TextButton(
                                            onPressed: () async {
                                              Navigator.of(context).pop();

                                              unawaited(attemptAnonymize());
                                            },
                                            style: Theme.of(context)
                                                .extension<StackColors>()!
                                                .getPrimaryEnabledButtonStyle(
                                                    context),
                                            child: Text(
                                              "Continue",
                                              style:
                                                  STextStyles.button(context),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      "Anonymize funds",
                                      style:
                                          STextStyles.button(context).copyWith(
                                        color: Theme.of(context)
                                            .extension<StackColors>()!
                                            .buttonTextSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(
                          height: 20,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Transactions",
                                style:
                                    STextStyles.itemSubtitle(context).copyWith(
                                  color: Theme.of(context)
                                      .extension<StackColors>()!
                                      .textDark3,
                                ),
                              ),
                              CustomTextButton(
                                text: "See all",
                                onTap: () {
                                  Navigator.of(context).pushNamed(
                                    AllTransactionsView.routeName,
                                    arguments: walletId,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                          height: 12,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ClipRRect(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(
                                  Constants.size.circularBorderRadius,
                                ),
                                bottom: Radius.circular(
                                  // WalletView.navBarHeight / 2.0,
                                  Constants.size.circularBorderRadius,
                                ),
                              ),
                              child: ShaderMask(
                                blendMode: BlendMode.dstOut,
                                shaderCallback: (Rect bounds) {
                                  return const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.transparent,
                                      Colors.white,
                                    ],
                                    stops: [
                                      0.0,
                                      0.8,
                                      1.0,
                                    ], // 10% purple, 80% transparent, 10% purple
                                  ).createShader(bounds);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(
                                      Constants.size.circularBorderRadius,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: TransactionsList(
                                          managerProvider: managerProvider,
                                          walletId: walletId,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              WalletNavigationBar(
                items: [
                  WalletNavigationBarItemData(
                    label: "Receive",
                    icon: const ReceiveNavIcon(),
                    onTap: () {
                      final coin = ref.read(managerProvider).coin;
                      if (mounted) {
                        unawaited(
                          Navigator.of(context).pushNamed(
                            ReceiveView.routeName,
                            arguments: Tuple2(
                              walletId,
                              coin,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  WalletNavigationBarItemData(
                    label: "Send",
                    icon: const SendNavIcon(),
                    onTap: () {
                      final walletId = ref.read(managerProvider).walletId;
                      final coin = ref.read(managerProvider).coin;
                      switch (ref
                          .read(walletBalanceToggleStateProvider.state)
                          .state) {
                        case WalletBalanceToggleState.full:
                          ref
                              .read(publicPrivateBalanceStateProvider.state)
                              .state = "Public";
                          break;
                        case WalletBalanceToggleState.available:
                          ref
                              .read(publicPrivateBalanceStateProvider.state)
                              .state = "Private";
                          break;
                      }
                      Navigator.of(context).pushNamed(
                        SendView.routeName,
                        arguments: Tuple2(
                          walletId,
                          coin,
                        ),
                      );
                    },
                  ),
                  if (Constants.enableExchange)
                    WalletNavigationBarItemData(
                      label: "Swap",
                      icon: const ExchangeNavIcon(),
                      onTap: () => _onExchangePressed(context),
                    ),
                  if (Constants.enableExchange)
                    WalletNavigationBarItemData(
                      label: "Buy",
                      icon: const BuyNavIcon(),
                      onTap: () => _onBuyPressed(context),
                    ),
                ],
                moreItems: [
                  if (ref.watch(
                        walletsChangeNotifierProvider.select(
                          (value) => value
                              .getManager(widget.walletId)
                              .hasCoinControlSupport,
                        ),
                      ) &&
                      ref.watch(
                        prefsChangeNotifierProvider.select(
                          (value) => value.enableCoinControl,
                        ),
                      ))
                    WalletNavigationBarItemData(
                      label: "Coin control",
                      icon: const CoinControlNavIcon(),
                      onTap: () {
                        Navigator.of(context).pushNamed(
                          CoinControlView.routeName,
                          arguments: Tuple2(
                            widget.walletId,
                            CoinControlViewType.manage,
                          ),
                        );
                      },
                    ),
                  if (ref.watch(walletsChangeNotifierProvider.select((value) =>
                      value.getManager(widget.walletId).hasPaynymSupport)))
                    WalletNavigationBarItemData(
                      label: "PayNym",
                      icon: const PaynymNavIcon(),
                      onTap: () async {
                        unawaited(
                          showDialog(
                            context: context,
                            builder: (context) => const LoadingIndicator(
                              width: 100,
                            ),
                          ),
                        );

                        final manager = ref
                            .read(walletsChangeNotifierProvider)
                            .getManager(widget.walletId);

                        final paynymInterface =
                            manager.wallet as PaynymWalletInterface;

                        final code = await paynymInterface.getPaymentCode(
                            DerivePathTypeExt.primaryFor(manager.coin));

                        final account = await ref
                            .read(paynymAPIProvider)
                            .nym(code.toString());

                        Logging.instance.log(
                          "my nym account: $account",
                          level: LogLevel.Info,
                        );

                        if (mounted) {
                          Navigator.of(context).pop();

                          // check if account exists and for matching code to see if claimed
                          if (account.value != null &&
                              account.value!.codes.first.claimed) {
                            ref.read(myPaynymAccountStateProvider.state).state =
                                account.value!;

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
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
