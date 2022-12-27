import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cw_core/monero_transaction_priority.dart';
import 'package:cw_core/node.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_credentials.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_service.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_monero/api/exceptions/creation_transaction_exception.dart';
import 'package:cw_monero/monero_wallet.dart';
import 'package:cw_monero/pending_monero_transaction.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_libmonero/core/key_service.dart';
import 'package:flutter_libmonero/core/wallet_creation_service.dart';
import 'package:flutter_libmonero/monero/monero.dart';
import 'package:flutter_libmonero/view_model/send/output.dart' as monero_output;
import 'package:http/http.dart';
import 'package:mutex/mutex.dart';
import 'package:stackwallet/hive/db.dart';
import 'package:stackwallet/models/node_model.dart';
import 'package:stackwallet/models/paymint/fee_object_model.dart';
import 'package:stackwallet/models/paymint/transactions_model.dart';
import 'package:stackwallet/models/paymint/utxo_model.dart';
import 'package:stackwallet/services/coins/coin_service.dart';
import 'package:stackwallet/services/event_bus/events/global/blocks_remaining_event.dart';
import 'package:stackwallet/services/event_bus/events/global/refresh_percent_changed_event.dart';
import 'package:stackwallet/services/event_bus/events/global/updated_in_background_event.dart';
import 'package:stackwallet/services/event_bus/events/global/wallet_sync_status_changed_event.dart';
import 'package:stackwallet/services/event_bus/global_event_bus.dart';
import 'package:stackwallet/services/node_service.dart';
import 'package:stackwallet/services/price.dart';
import 'package:stackwallet/utilities/constants.dart';
import 'package:stackwallet/utilities/default_nodes.dart';
import 'package:stackwallet/utilities/enums/coin_enum.dart';
import 'package:stackwallet/utilities/enums/fee_rate_type_enum.dart';
import 'package:stackwallet/utilities/flutter_secure_storage_interface.dart';
import 'package:stackwallet/utilities/format.dart';
import 'package:stackwallet/utilities/logger.dart';
import 'package:stackwallet/utilities/prefs.dart';
import 'package:stackwallet/utilities/stack_file_system.dart';

const int MINIMUM_CONFIRMATIONS = 10;

class MoneroWallet extends CoinServiceAPI {
  final String _walletId;
  final Coin _coin;
  final PriceAPI _priceAPI;
  final SecureStorageInterface _secureStorage;
  final Prefs _prefs;

  String _walletName;
  bool _shouldAutoSync = false;
  bool _isConnected = false;
  bool _hasCalledExit = false;
  bool refreshMutex = false;
  bool longMutex = false;

  WalletService? walletService;
  KeyService? keysStorage;
  MoneroWalletBase? walletBase;
  WalletCreationService? _walletCreationService;
  Timer? _autoSaveTimer;

  Future<String>? _currentReceivingAddress;
  Future<FeeObject>? _feeObject;
  Future<TransactionData>? _transactionData;

  Mutex prepareSendMutex = Mutex();
  Mutex estimateFeeMutex = Mutex();

  MoneroWallet({
    required String walletId,
    required String walletName,
    required Coin coin,
    required SecureStorageInterface secureStorage,
    PriceAPI? priceAPI,
    Prefs? prefs,
  })  : _walletId = walletId,
        _walletName = walletName,
        _coin = coin,
        _priceAPI = priceAPI ?? PriceAPI(Client()),
        _secureStorage = secureStorage,
        _prefs = prefs ?? Prefs.instance;

  @override
  bool get isFavorite {
    try {
      return DB.instance.get<dynamic>(boxName: walletId, key: "isFavorite")
          as bool;
    } catch (e, s) {
      Logging.instance.log(
          "isFavorite fetch failed (returning false by default): $e\n$s",
          level: LogLevel.Error);
      return false;
    }
  }

  @override
  set isFavorite(bool markFavorite) {
    DB.instance.put<dynamic>(
        boxName: walletId, key: "isFavorite", value: markFavorite);
  }

  @override
  bool get shouldAutoSync => _shouldAutoSync;

  @override
  set shouldAutoSync(bool shouldAutoSync) {
    if (_shouldAutoSync != shouldAutoSync) {
      _shouldAutoSync = shouldAutoSync;
      // xmr wallets cannot be open at the same time
      // leave following commented out for now

      // if (!shouldAutoSync) {
      //   timer?.cancel();
      //   moneroAutosaveTimer?.cancel();
      //   timer = null;
      //   moneroAutosaveTimer = null;
      //   stopNetworkAlivePinging();
      // } else {
      //   startNetworkAlivePinging();
      //   // Walletbase needs to be open for this to work
      //   refresh();
      // }
    }
  }

  @override
  String get walletName => _walletName;

  // setter for updating on rename
  @override
  set walletName(String newName) => _walletName = newName;

  @override
  // not used for monero
  Future<List<String>> get allOwnAddresses => throw UnimplementedError();

  @override
  Future<Decimal> get availableBalance async {
    int runningBalance = 0;
    for (final entry in walletBase!.balance!.entries) {
      runningBalance += entry.value.unlockedBalance;
    }
    return Format.satoshisToAmount(runningBalance, coin: coin);
  }

  @override
  // not used
  Future<Decimal> get balanceMinusMaxFee => throw UnimplementedError();

  @override
  Coin get coin => _coin;

  @override
  Future<String> confirmSend({required Map<String, dynamic> txData}) async {
    try {
      Logging.instance.log("confirmSend txData: $txData", level: LogLevel.Info);
      final pendingMoneroTransaction =
          txData['pendingMoneroTransaction'] as PendingMoneroTransaction;
      try {
        await pendingMoneroTransaction.commit();
        Logging.instance.log(
            "transaction ${pendingMoneroTransaction.id} has been sent",
            level: LogLevel.Info);
        return pendingMoneroTransaction.id;
      } catch (e, s) {
        Logging.instance.log("$walletName monero confirmSend: $e\n$s",
            level: LogLevel.Error);
        rethrow;
      }
    } catch (e, s) {
      Logging.instance.log("Exception rethrown from confirmSend(): $e\n$s",
          level: LogLevel.Info);
      rethrow;
    }
  }

  @override
  Future<String> get currentReceivingAddress =>
      _currentReceivingAddress ??= _getCurrentAddressForChain(0);

  @override
  Future<int> estimateFeeFor(int satoshiAmount, int feeRate) async {
    MoneroTransactionPriority priority;

    switch (feeRate) {
      case 1:
        priority = MoneroTransactionPriority.regular;
        break;
      case 2:
        priority = MoneroTransactionPriority.medium;
        break;
      case 3:
        priority = MoneroTransactionPriority.fast;
        break;
      case 4:
        priority = MoneroTransactionPriority.fastest;
        break;
      case 0:
      default:
        priority = MoneroTransactionPriority.slow;
        break;
    }

    final fee = walletBase!.calculateEstimatedFee(priority, satoshiAmount);

    return fee;
  }

  @override
  Future<void> exit() async {
    if (!_hasCalledExit) {
      _hasCalledExit = true;
      _autoSaveTimer?.cancel();
      await walletBase?.save(prioritySave: true);
      walletBase?.close();
    }
  }

  @override
  Future<FeeObject> get fees => _feeObject ??= _getFees();

  @override
  Future<void> fullRescan(
    int maxUnusedAddressGap,
    int maxNumberOfIndexesToCheck,
  ) async {
    var restoreHeight = walletBase?.walletInfo.restoreHeight;
    highestPercentCached = 0;
    await walletBase?.rescan(height: restoreHeight);
  }

  @override
  Future<bool> generateNewAddress() async {
    try {
      const String indexKey = "receivingIndex";
      // First increment the receiving index
      await _incrementAddressIndexForChain(0);
      final newReceivingIndex =
          DB.instance.get<dynamic>(boxName: walletId, key: indexKey) as int;

      // Use new index to derive a new receiving address
      final newReceivingAddress =
          await _generateAddressForChain(0, newReceivingIndex);

      // Add that new receiving address to the array of receiving addresses
      await _addToAddressesArrayForChain(newReceivingAddress, 0);

      // Set the new receiving address that the service

      _currentReceivingAddress = Future(() => newReceivingAddress);

      return true;
    } catch (e, s) {
      Logging.instance.log(
          "Exception rethrown from generateNewAddress(): $e\n$s",
          level: LogLevel.Error);
      return false;
    }
  }

  @override
  bool get hasCalledExit => _hasCalledExit;

  @override
  Future<void> initializeExisting() async {
    Logging.instance.log(
      "Opening existing ${coin.prettyName} wallet $walletName...",
      level: LogLevel.Info,
    );

    if ((DB.instance.get<dynamic>(boxName: walletId, key: "id")) == null) {
      throw Exception(
          "Attempted to initialize an existing wallet using an unknown wallet ID!");
    }

    walletService =
        monero.createMoneroWalletService(DB.instance.moneroWalletInfoBox);
    keysStorage = KeyService(_secureStorage);

    await _prefs.init();
    // final data =
    //     DB.instance.get<dynamic>(boxName: walletId, key: "latest_tx_model")
    //         as TransactionData?;
    // if (data != null) {
    //   _transactionData = Future(() => data);
    // }

    String password;
    try {
      password = await keysStorage!.getWalletPassword(walletName: _walletId);
    } catch (_) {
      throw Exception("Monero password not found for $walletName");
    }
    walletBase = (await walletService!.openWallet(_walletId, password))
        as MoneroWalletBase;
    walletBase!.onNewBlock = onNewBlock;
    walletBase!.onNewTransaction = onNewTransaction;
    walletBase!.syncStatusChanged = syncStatusChanged;
    Logging.instance.log(
      "Opened existing ${coin.prettyName} wallet $walletName",
      level: LogLevel.Info,
    );
    // Wallet already exists, triggers for a returning user

    String indexKey = "receivingIndex";
    final curIndex =
        await DB.instance.get<dynamic>(boxName: walletId, key: indexKey) as int;
    // Use new index to derive a new receiving address
    final newReceivingAddress = await _generateAddressForChain(0, curIndex);
    Logging.instance.log("xmr address in init existing: $newReceivingAddress",
        level: LogLevel.Info);
    _currentReceivingAddress = Future(() => newReceivingAddress);
  }

  @override
  Future<void> initializeNew() async {
    await _prefs.init();

    // this should never fail
    if ((await _secureStorage.read(key: '${_walletId}_mnemonic')) != null) {
      throw Exception(
          "Attempted to overwrite mnemonic on generate new wallet!");
    }

    walletService =
        monero.createMoneroWalletService(DB.instance.moneroWalletInfoBox);
    keysStorage = KeyService(_secureStorage);
    WalletInfo walletInfo;
    WalletCredentials credentials;
    try {
      String name = _walletId;
      final dirPath =
          await _pathForWalletDir(name: name, type: WalletType.monero);
      final path = await _pathForWallet(name: name, type: WalletType.monero);
      credentials = monero.createMoneroNewWalletCredentials(
        name: name,
        language: "English",
      );

      // subtract a couple days to ensure we have a buffer for SWB
      final bufferedCreateHeight = monero.getHeigthByDate(
          date: DateTime.now().subtract(const Duration(days: 2)));

      await DB.instance.put<dynamic>(
          boxName: walletId, key: "restoreHeight", value: bufferedCreateHeight);

      walletInfo = WalletInfo.external(
          id: WalletBase.idFor(name, WalletType.monero),
          name: name,
          type: WalletType.monero,
          isRecovery: false,
          restoreHeight: bufferedCreateHeight,
          date: DateTime.now(),
          path: path,
          dirPath: dirPath,
          // TODO: find out what to put for address
          address: '');
      credentials.walletInfo = walletInfo;

      _walletCreationService = WalletCreationService(
        secureStorage: _secureStorage,
        walletService: walletService,
        keyService: keysStorage,
      );
      _walletCreationService?.changeWalletType();
      // To restore from a seed
      final wallet = await _walletCreationService?.create(credentials);

      await _secureStorage.write(
          key: '${_walletId}_mnemonic', value: wallet?.seed.trim());
      walletInfo.address = wallet?.walletAddresses.address;
      await DB.instance
          .add<WalletInfo>(boxName: WalletInfo.boxName, value: walletInfo);
      walletBase?.close();
      walletBase = wallet as MoneroWalletBase;
      walletBase!.onNewBlock = onNewBlock;
      walletBase!.onNewTransaction = onNewTransaction;
      walletBase!.syncStatusChanged = syncStatusChanged;
    } catch (e, s) {
      //todo: come back to this
      debugPrint("some nice searchable string thing");
      debugPrint(e.toString());
      debugPrint(s.toString());
      walletBase?.close();
    }
    final node = await _getCurrentNode();
    final host = Uri.parse(node.host).host;
    await walletBase!.connectToNode(
        node: Node(uri: "$host:${node.port}", type: WalletType.monero));
    await walletBase!.startSync();
    await DB.instance
        .put<dynamic>(boxName: walletId, key: "id", value: _walletId);

    // Set relevant indexes
    await DB.instance
        .put<dynamic>(boxName: walletId, key: "receivingIndex", value: 0);
    await DB.instance
        .put<dynamic>(boxName: walletId, key: "changeIndex", value: 0);
    await DB.instance.put<dynamic>(
      boxName: walletId,
      key: 'blocked_tx_hashes',
      value: ["0xdefault"],
    ); // A list of transaction hashes to represent frozen utxos in wallet
    // initialize address book entries
    await DB.instance.put<dynamic>(
        boxName: walletId,
        key: 'addressBookEntries',
        value: <String, String>{});
    await DB.instance
        .put<dynamic>(boxName: walletId, key: "isFavorite", value: false);

    // Generate and add addresses to relevant arrays
    final initialReceivingAddress = await _generateAddressForChain(0, 0);
    // final initialChangeAddress = await _generateAddressForChain(1, 0);

    await _addToAddressesArrayForChain(initialReceivingAddress, 0);
    // await _addToAddressesArrayForChain(initialChangeAddress, 1);

    await DB.instance.put<dynamic>(
        boxName: walletId,
        key: 'receivingAddresses',
        value: [initialReceivingAddress]);
    await DB.instance
        .put<dynamic>(boxName: walletId, key: "receivingIndex", value: 0);

    _currentReceivingAddress = Future(() => initialReceivingAddress);
    walletBase?.close();
    Logging.instance
        .log("initializeNew for $walletName $walletId", level: LogLevel.Info);
  }

  @override
  bool get isConnected => _isConnected;

  @override
  bool get isRefreshing => refreshMutex;

  @override
  // not used in xmr
  Future<int> get maxFee => throw UnimplementedError();

  @override
  Future<List<String>> get mnemonic async {
    final mnemonicString =
        await _secureStorage.read(key: '${_walletId}_mnemonic');
    if (mnemonicString == null) {
      return [];
    }
    final List<String> data = mnemonicString.split(' ');
    return data;
  }

  @override
  // not used in xmr
  Future<Decimal> get pendingBalance => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> prepareSend({
    required String address,
    required int satoshiAmount,
    Map<String, dynamic>? args,
  }) async {
    String toAddress = address;
    try {
      final feeRate = args?["feeRate"];
      if (feeRate is FeeRateType) {
        MoneroTransactionPriority feePriority;
        switch (feeRate) {
          case FeeRateType.fast:
            feePriority = MoneroTransactionPriority.fast;
            break;
          case FeeRateType.average:
            feePriority = MoneroTransactionPriority.regular;
            break;
          case FeeRateType.slow:
            feePriority = MoneroTransactionPriority.slow;
            break;
        }

        Future<PendingTransaction>? awaitPendingTransaction;
        try {
          // check for send all
          bool isSendAll = false;
          final balance = await availableBalance;
          final satInDecimal =
              Format.satoshisToAmount(satoshiAmount, coin: coin);
          if (satInDecimal == balance) {
            isSendAll = true;
          }
          Logging.instance
              .log("$toAddress $satoshiAmount $args", level: LogLevel.Info);
          String amountToSend = satInDecimal
              .toStringAsFixed(Constants.decimalPlacesForCoin(coin));
          Logging.instance
              .log("$satoshiAmount $amountToSend", level: LogLevel.Info);

          monero_output.Output output = monero_output.Output(walletBase!);
          output.address = toAddress;
          output.sendAll = isSendAll;
          output.setCryptoAmount(amountToSend);

          List<monero_output.Output> outputs = [output];
          Object tmp = monero.createMoneroTransactionCreationCredentials(
              outputs: outputs, priority: feePriority);

          await prepareSendMutex.protect(() async {
            awaitPendingTransaction = walletBase!.createTransaction(tmp);
          });
        } catch (e, s) {
          Logging.instance.log("Exception rethrown from prepareSend(): $e\n$s",
              level: LogLevel.Warning);
        }

        PendingMoneroTransaction pendingMoneroTransaction =
            await (awaitPendingTransaction!) as PendingMoneroTransaction;

        int realfee = Format.decimalAmountToSatoshis(
            Decimal.parse(pendingMoneroTransaction.feeFormatted), coin);
        debugPrint("fee? $realfee");
        Map<String, dynamic> txData = {
          "pendingMoneroTransaction": pendingMoneroTransaction,
          "fee": realfee,
          "addresss": toAddress,
          "recipientAmt": satoshiAmount,
        };

        Logging.instance.log("prepare send: $txData", level: LogLevel.Info);
        return txData;
      } else {
        throw ArgumentError("Invalid fee rate argument provided!");
      }
    } catch (e, s) {
      Logging.instance.log("Exception rethrown from prepare send(): $e\n$s",
          level: LogLevel.Info);

      if (e.toString().contains("Incorrect unlocked balance")) {
        throw Exception("Insufficient balance!");
      } else if (e is CreationTransactionException) {
        throw Exception("Insufficient funds to pay for transaction fee!");
      } else {
        throw Exception("Transaction failed with error code $e");
      }
    }
  }

  @override
  Future<void> recoverFromMnemonic({
    required String mnemonic,
    required int maxUnusedAddressGap,
    required int maxNumberOfIndexesToCheck,
    required int height,
  }) async {
    await _prefs.init();
    longMutex = true;
    final start = DateTime.now();
    try {
      // Logging.instance.log("IS_INTEGRATION_TEST: $integrationTestFlag");
      // if (!integrationTestFlag) {
      //   final features = await electrumXClient.getServerFeatures();
      //   Logging.instance.log("features: $features");
      //   if (_networkType == BasicNetworkType.main) {
      //     if (features['genesis_hash'] != GENESIS_HASH_MAINNET) {
      //       throw Exception("genesis hash does not match main net!");
      //     }
      //   } else if (_networkType == BasicNetworkType.test) {
      //     if (features['genesis_hash'] != GENESIS_HASH_TESTNET) {
      //       throw Exception("genesis hash does not match test net!");
      //     }
      //   }
      // }
      // check to make sure we aren't overwriting a mnemonic
      // this should never fail
      if ((await _secureStorage.read(key: '${_walletId}_mnemonic')) != null) {
        longMutex = false;
        throw Exception("Attempted to overwrite mnemonic on restore!");
      }
      await _secureStorage.write(
          key: '${_walletId}_mnemonic', value: mnemonic.trim());

      await DB.instance
          .put<dynamic>(boxName: walletId, key: "restoreHeight", value: height);

      walletService =
          monero.createMoneroWalletService(DB.instance.moneroWalletInfoBox);
      keysStorage = KeyService(_secureStorage);
      WalletInfo walletInfo;
      WalletCredentials credentials;
      String name = _walletId;
      final dirPath =
          await _pathForWalletDir(name: name, type: WalletType.monero);
      final path = await _pathForWallet(name: name, type: WalletType.monero);
      credentials = monero.createMoneroRestoreWalletFromSeedCredentials(
        name: name,
        height: height,
        mnemonic: mnemonic.trim(),
      );
      try {
        walletInfo = WalletInfo.external(
            id: WalletBase.idFor(name, WalletType.monero),
            name: name,
            type: WalletType.monero,
            isRecovery: false,
            restoreHeight: credentials.height ?? 0,
            date: DateTime.now(),
            path: path,
            dirPath: dirPath,
            // TODO: find out what to put for address
            address: '');
        credentials.walletInfo = walletInfo;

        _walletCreationService = WalletCreationService(
          secureStorage: _secureStorage,
          walletService: walletService,
          keyService: keysStorage,
        );
        _walletCreationService!.changeWalletType();
        // To restore from a seed
        final wallet =
            await _walletCreationService!.restoreFromSeed(credentials);
        walletInfo.address = wallet.walletAddresses.address;
        await DB.instance
            .add<WalletInfo>(boxName: WalletInfo.boxName, value: walletInfo);
        walletBase?.close();
        walletBase = wallet as MoneroWalletBase;
        walletBase!.onNewBlock = onNewBlock;
        walletBase!.onNewTransaction = onNewTransaction;
        walletBase!.syncStatusChanged = syncStatusChanged;
        await DB.instance.put<dynamic>(
            boxName: walletId,
            key: 'receivingAddresses',
            value: [walletInfo.address!]);
        await DB.instance
            .put<dynamic>(boxName: walletId, key: "receivingIndex", value: 0);
        await DB.instance
            .put<dynamic>(boxName: walletId, key: "id", value: _walletId);
        await DB.instance
            .put<dynamic>(boxName: walletId, key: "changeIndex", value: 0);
        await DB.instance.put<dynamic>(
          boxName: walletId,
          key: 'blocked_tx_hashes',
          value: ["0xdefault"],
        ); // A list of transaction hashes to represent frozen utxos in wallet
        // initialize address book entries
        await DB.instance.put<dynamic>(
            boxName: walletId,
            key: 'addressBookEntries',
            value: <String, String>{});
        await DB.instance
            .put<dynamic>(boxName: walletId, key: "isFavorite", value: false);
      } catch (e, s) {
        debugPrint(e.toString());
        debugPrint(s.toString());
      }
      final node = await _getCurrentNode();
      final host = Uri.parse(node.host).host;
      await walletBase!.connectToNode(
          node: Node(uri: "$host:${node.port}", type: WalletType.monero));
      await walletBase!.rescan(height: credentials.height);
      walletBase!.close();
    } catch (e, s) {
      Logging.instance.log(
          "Exception rethrown from recoverFromMnemonic(): $e\n$s",
          level: LogLevel.Error);
      longMutex = false;
      rethrow;
    }
    longMutex = false;

    final end = DateTime.now();
    Logging.instance.log(
        "$walletName Recovery time: ${end.difference(start).inMilliseconds} millis",
        level: LogLevel.Info);
  }

  @override
  Future<void> refresh() async {
    if (refreshMutex) {
      Logging.instance.log("$walletId $walletName refreshMutex denied",
          level: LogLevel.Info);
      return;
    } else {
      refreshMutex = true;
    }

    GlobalEventBus.instance.fire(
      WalletSyncStatusChangedEvent(
        WalletSyncStatus.syncing,
        walletId,
        coin,
      ),
    );

    final newTxData = await _fetchTransactionData();
    _transactionData = Future(() => newTxData);

    await _checkCurrentReceivingAddressesForTransactions();
    String indexKey = "receivingIndex";
    final curIndex =
        DB.instance.get<dynamic>(boxName: walletId, key: indexKey) as int;
    // Use new index to derive a new receiving address
    try {
      final newReceivingAddress = await _generateAddressForChain(0, curIndex);
      _currentReceivingAddress = Future(() => newReceivingAddress);
    } catch (e, s) {
      Logging.instance.log(
          "Failed to call _generateAddressForChain(0, $curIndex): $e\n$s",
          level: LogLevel.Error);
    }

    if (walletBase?.syncStatus is SyncedSyncStatus) {
      refreshMutex = false;
      GlobalEventBus.instance.fire(
        WalletSyncStatusChangedEvent(
          WalletSyncStatus.synced,
          walletId,
          coin,
        ),
      );
    }
  }

  @override
  Future<String> send({
    required String toAddress,
    required int amount,
    Map<String, String> args = const {},
  }) {
    // not used for xmr
    throw UnimplementedError();
  }

  @override
  Future<bool> testNetworkConnection() async {
    return await walletBase?.isConnected() ?? false;
  }

  bool _isActive = false;

  @override
  void Function(bool)? get onIsActiveWalletChanged => (isActive) async {
        if (_isActive == isActive) {
          return;
        }
        _isActive = isActive;

        if (isActive) {
          _hasCalledExit = false;
          String? password;
          try {
            password =
                await keysStorage?.getWalletPassword(walletName: _walletId);
          } catch (e, s) {
            throw Exception("Password not found $e, $s");
          }
          walletBase = (await walletService?.openWallet(_walletId, password!))
              as MoneroWalletBase?;

          walletBase!.onNewBlock = onNewBlock;
          walletBase!.onNewTransaction = onNewTransaction;
          walletBase!.syncStatusChanged = syncStatusChanged;

          if (!(await walletBase!.isConnected())) {
            final node = await _getCurrentNode();
            final host = Uri.parse(node.host).host;
            await walletBase?.connectToNode(
                node: Node(uri: "$host:${node.port}", type: WalletType.monero));
          }
          await walletBase?.startSync();
          await refresh();
          _autoSaveTimer?.cancel();
          _autoSaveTimer = Timer.periodic(
            const Duration(seconds: 93),
            (_) async => await walletBase?.save(),
          );
        } else {
          await exit();
          // _autoSaveTimer?.cancel();
          // await walletBase?.save(prioritySave: true);
          // walletBase?.close();
        }
      };

  @override
  Future<Decimal> get totalBalance async {
    final balanceEntries = walletBase?.balance?.entries;
    if (balanceEntries != null) {
      int bal = 0;
      for (var element in balanceEntries) {
        bal = bal + element.value.fullBalance;
      }
      return Format.satoshisToAmount(bal, coin: coin);
    } else {
      final transactions = walletBase!.transactionHistory!.transactions;
      int transactionBalance = 0;
      for (var tx in transactions!.entries) {
        if (tx.value.direction == TransactionDirection.incoming) {
          transactionBalance += tx.value.amount!;
        } else {
          transactionBalance += -tx.value.amount! - tx.value.fee!;
        }
      }

      return Format.satoshisToAmount(transactionBalance, coin: coin);
    }
  }

  @override
  Future<TransactionData> get transactionData =>
      _transactionData ??= _fetchTransactionData();

  @override
  // not used for xmr
  Future<List<UtxoObject>> get unspentOutputs => throw UnimplementedError();

  @override
  Future<void> updateNode(bool shouldRefresh) async {
    final node = await _getCurrentNode();

    final host = Uri.parse(node.host).host;
    await walletBase?.connectToNode(
        node: Node(uri: "$host:${node.port}", type: WalletType.monero));

    // TODO: is this sync call needed? Do we need to notify ui here?
    await walletBase?.startSync();

    if (shouldRefresh) {
      await refresh();
    }
  }

  @override
  Future<void> updateSentCachedTxData(Map<String, dynamic> txData) {
    // not used for xmr
    throw UnimplementedError();
  }

  @override
  bool validateAddress(String address) => walletBase!.validateAddress(address);

  @override
  String get walletId => _walletId;

  /// Returns the latest receiving/change (external/internal) address for the wallet depending on [chain]
  /// and
  /// [chain] - Use 0 for receiving (external), 1 for change (internal). Should not be any other value!
  Future<String> _getCurrentAddressForChain(int chain) async {
    // Here, we assume that chain == 1 if it isn't 0
    String arrayKey = chain == 0 ? "receivingAddresses" : "changeAddresses";
    final internalChainArray = (DB.instance
        .get<dynamic>(boxName: walletId, key: arrayKey)) as List<dynamic>;
    return internalChainArray.last as String;
  }

  /// Increases the index for either the internal or external chain, depending on [chain].
  /// [chain] - Use 0 for receiving (external), 1 for change (internal). Should not be any other value!
  Future<void> _incrementAddressIndexForChain(int chain) async {
    // Here we assume chain == 1 if it isn't 0
    String indexKey = chain == 0 ? "receivingIndex" : "changeIndex";

    final newIndex =
        (DB.instance.get<dynamic>(boxName: walletId, key: indexKey)) + 1;
    await DB.instance
        .put<dynamic>(boxName: walletId, key: indexKey, value: newIndex);
  }

  Future<String> _generateAddressForChain(int chain, int index) async {
    //
    String address = walletBase!.getTransactionAddress(chain, index);

    return address;
  }

  /// Adds [address] to the relevant chain's address array, which is determined by [chain].
  /// [address] - Expects a standard native segwit address
  /// [chain] - Use 0 for receiving (external), 1 for change (internal). Should not be any other value!
  Future<void> _addToAddressesArrayForChain(String address, int chain) async {
    String chainArray = '';
    if (chain == 0) {
      chainArray = 'receivingAddresses';
    } else {
      chainArray = 'changeAddresses';
    }

    final addressArray =
        DB.instance.get<dynamic>(boxName: walletId, key: chainArray);
    if (addressArray == null) {
      Logging.instance.log(
          'Attempting to add the following to $chainArray array for chain $chain:${[
            address
          ]}',
          level: LogLevel.Info);
      await DB.instance
          .put<dynamic>(boxName: walletId, key: chainArray, value: [address]);
    } else {
      // Make a deep copy of the existing list
      final List<String> newArray = [];
      addressArray
          .forEach((dynamic _address) => newArray.add(_address as String));
      newArray.add(address); // Add the address passed into the method
      await DB.instance
          .put<dynamic>(boxName: walletId, key: chainArray, value: newArray);
    }
  }

  Future<FeeObject> _getFees() async {
    // TODO: not use random hard coded values here
    return FeeObject(
      numberOfBlocksFast: 10,
      numberOfBlocksAverage: 15,
      numberOfBlocksSlow: 20,
      fast: MoneroTransactionPriority.fast.raw!,
      medium: MoneroTransactionPriority.regular.raw!,
      slow: MoneroTransactionPriority.slow.raw!,
    );
  }

  Future<TransactionData> _fetchTransactionData() async {
    await walletBase!.updateTransactions();
    final transactions = walletBase?.transactionHistory!.transactions;

    // final cachedTransactions =
    //     DB.instance.get<dynamic>(boxName: walletId, key: 'latest_tx_model')
    //         as TransactionData?;
    // int latestTxnBlockHeight =
    //     DB.instance.get<dynamic>(boxName: walletId, key: "storedTxnDataHeight")
    //             as int? ??
    //         0;

    // final txidsList = DB.instance
    //         .get<dynamic>(boxName: walletId, key: "cachedTxids") as List? ??
    //     [];
    //
    // final Set<String> cachedTxids = Set<String>.from(txidsList);

    // sort thing stuff
    // change to get Monero price
    final priceData =
        await _priceAPI.getPricesAnd24hChange(baseCurrency: _prefs.currency);
    Decimal currentPrice = priceData[coin]?.item1 ?? Decimal.zero;
    final List<Map<String, dynamic>> midSortedArray = [];

    if (transactions != null) {
      for (var tx in transactions.entries) {
        // cachedTxids.add(tx.value.id);
        Logging.instance.log(
            "${tx.value.accountIndex} ${tx.value.addressIndex} ${tx.value.amount} ${tx.value.date} "
            "${tx.value.direction} ${tx.value.fee} ${tx.value.height} ${tx.value.id} ${tx.value.isPending} ${tx.value.key} "
            "${tx.value.recipientAddress}, ${tx.value.additionalInfo} con:${tx.value.confirmations}"
            " ${tx.value.keyIndex}",
            level: LogLevel.Info);
        final worthNow = (currentPrice *
                Format.satoshisToAmount(
                  tx.value.amount!,
                  coin: coin,
                ))
            .toStringAsFixed(2);
        Map<String, dynamic> midSortedTx = {};
        // // create final tx map
        midSortedTx["txid"] = tx.value.id;
        midSortedTx["confirmed_status"] = !tx.value.isPending &&
            tx.value.confirmations! >= MINIMUM_CONFIRMATIONS;
        midSortedTx["confirmations"] = tx.value.confirmations ?? 0;
        midSortedTx["timestamp"] =
            (tx.value.date.millisecondsSinceEpoch ~/ 1000);
        midSortedTx["txType"] =
            tx.value.direction == TransactionDirection.incoming
                ? "Received"
                : "Sent";
        midSortedTx["amount"] = tx.value.amount;
        midSortedTx["worthNow"] = worthNow;
        midSortedTx["worthAtBlockTimestamp"] = worthNow;
        midSortedTx["fees"] = tx.value.fee;
        if (tx.value.direction == TransactionDirection.incoming) {
          final addressInfo = tx.value.additionalInfo;

          midSortedTx["address"] = walletBase?.getTransactionAddress(
            addressInfo!['accountIndex'] as int,
            addressInfo['addressIndex'] as int,
          );
        } else {
          midSortedTx["address"] = "";
        }

        final int txHeight = tx.value.height ?? 0;
        midSortedTx["height"] = txHeight;
        // if (txHeight >= latestTxnBlockHeight) {
        //   latestTxnBlockHeight = txHeight;
        // }

        midSortedTx["aliens"] = <dynamic>[];
        midSortedTx["inputSize"] = 0;
        midSortedTx["outputSize"] = 0;
        midSortedTx["inputs"] = <dynamic>[];
        midSortedTx["outputs"] = <dynamic>[];
        midSortedArray.add(midSortedTx);
      }
    }

    // sort by date  ----
    midSortedArray
        .sort((a, b) => (b["timestamp"] as int) - (a["timestamp"] as int));
    Logging.instance.log(midSortedArray, level: LogLevel.Info);

    // buildDateTimeChunks
    final Map<String, dynamic> result = {"dateTimeChunks": <dynamic>[]};
    final dateArray = <dynamic>[];

    for (int i = 0; i < midSortedArray.length; i++) {
      final txObject = midSortedArray[i];
      final date = extractDateFromTimestamp(txObject["timestamp"] as int);
      final txTimeArray = [txObject["timestamp"], date];

      if (dateArray.contains(txTimeArray[1])) {
        result["dateTimeChunks"].forEach((dynamic chunk) {
          if (extractDateFromTimestamp(chunk["timestamp"] as int) ==
              txTimeArray[1]) {
            if (chunk["transactions"] == null) {
              chunk["transactions"] = <Map<String, dynamic>>[];
            }
            chunk["transactions"].add(txObject);
          }
        });
      } else {
        dateArray.add(txTimeArray[1]);
        final chunk = {
          "timestamp": txTimeArray[0],
          "transactions": [txObject],
        };
        result["dateTimeChunks"].add(chunk);
      }
    }

    // final transactionsMap = cachedTransactions?.getAllTransactions() ?? {};
    final Map<String, Transaction> transactionsMap = {};
    transactionsMap
        .addAll(TransactionData.fromJson(result).getAllTransactions());

    final txModel = TransactionData.fromMap(transactionsMap);

    // await DB.instance.put<dynamic>(
    //     boxName: walletId,
    //     key: 'storedTxnDataHeight',
    //     value: latestTxnBlockHeight);
    // await DB.instance.put<dynamic>(
    //     boxName: walletId, key: 'latest_tx_model', value: txModel);
    // await DB.instance.put<dynamic>(
    //     boxName: walletId,
    //     key: 'cachedTxids',
    //     value: cachedTxids.toList(growable: false));

    return txModel;
  }

  Future<String> _pathForWalletDir({
    required String name,
    required WalletType type,
  }) async {
    Directory root = await StackFileSystem.applicationRootDirectory();

    final prefix = walletTypeToString(type).toLowerCase();
    final walletsDir = Directory('${root.path}/wallets');
    final walletDire = Directory('${walletsDir.path}/$prefix/$name');

    if (!walletDire.existsSync()) {
      walletDire.createSync(recursive: true);
    }

    return walletDire.path;
  }

  Future<String> _pathForWallet({
    required String name,
    required WalletType type,
  }) async =>
      await _pathForWalletDir(name: name, type: type)
          .then((path) => '$path/$name');

  Future<NodeModel> _getCurrentNode() async {
    return NodeService(secureStorageInterface: _secureStorage)
            .getPrimaryNodeFor(coin: coin) ??
        DefaultNodes.getNodeFor(coin);
  }

  void onNewBlock() {
    //
    print("=============================");
    print("New Block!");
    print("=============================");
  }

  void onNewTransaction() {
    //
    print("=============================");
    print("New Transaction!");
    print("=============================");

    // call this here?
    GlobalEventBus.instance.fire(
      UpdatedInBackgroundEvent(
        "New data found in $walletId $walletName in background!",
        walletId,
      ),
    );
  }

  void syncStatusChanged() async {
    final syncStatus = walletBase?.syncStatus;
    if (syncStatus != null) {
      if (syncStatus.progress() == 1) {
        refreshMutex = false;
      }

      WalletSyncStatus? status;
      _isConnected = true;

      if (syncStatus is SyncingSyncStatus) {
        final int blocksLeft = syncStatus.blocksLeft;

        // ensure at least 1 to prevent math errors
        final int height = max(1, syncStatus.height);

        final nodeHeight = height + blocksLeft;

        final percent = height / nodeHeight;

        final highest = max(highestPercentCached, percent);

        // update cached
        if (highestPercentCached < percent) {
          highestPercentCached = percent;
        }

        GlobalEventBus.instance.fire(
          RefreshPercentChangedEvent(
            highest,
            walletId,
          ),
        );
        GlobalEventBus.instance.fire(
          BlocksRemainingEvent(
            blocksLeft,
            walletId,
          ),
        );
      } else if (syncStatus is SyncedSyncStatus) {
        status = WalletSyncStatus.synced;
      } else if (syncStatus is NotConnectedSyncStatus) {
        status = WalletSyncStatus.unableToSync;
        _isConnected = false;
      } else if (syncStatus is StartingSyncStatus) {
        status = WalletSyncStatus.syncing;
        GlobalEventBus.instance.fire(
          RefreshPercentChangedEvent(
            highestPercentCached,
            walletId,
          ),
        );
      } else if (syncStatus is FailedSyncStatus) {
        status = WalletSyncStatus.unableToSync;
        _isConnected = false;
      } else if (syncStatus is ConnectingSyncStatus) {
        status = WalletSyncStatus.syncing;
        GlobalEventBus.instance.fire(
          RefreshPercentChangedEvent(
            highestPercentCached,
            walletId,
          ),
        );
      } else if (syncStatus is ConnectedSyncStatus) {
        status = WalletSyncStatus.syncing;
        GlobalEventBus.instance.fire(
          RefreshPercentChangedEvent(
            highestPercentCached,
            walletId,
          ),
        );
      } else if (syncStatus is LostConnectionSyncStatus) {
        status = WalletSyncStatus.unableToSync;
        _isConnected = false;
      }

      if (status != null) {
        GlobalEventBus.instance.fire(
          WalletSyncStatusChangedEvent(
            status,
            walletId,
            coin,
          ),
        );
      }
    }
  }

  Future<void> _checkCurrentReceivingAddressesForTransactions() async {
    try {
      await _checkReceivingAddressForTransactions();
    } catch (e, s) {
      Logging.instance.log(
          "Exception rethrown from _checkCurrentReceivingAddressesForTransactions(): $e\n$s",
          level: LogLevel.Error);
      rethrow;
    }
  }

  Future<void> _checkReceivingAddressForTransactions() async {
    try {
      int highestIndex = -1;
      for (var element
          in walletBase!.transactionHistory!.transactions!.entries) {
        if (element.value.direction == TransactionDirection.incoming) {
          int curAddressIndex =
              element.value.additionalInfo!['addressIndex'] as int;
          if (curAddressIndex > highestIndex) {
            highestIndex = curAddressIndex;
          }
        }
      }

      // Check the new receiving index
      String indexKey = "receivingIndex";
      final curIndex =
          DB.instance.get<dynamic>(boxName: walletId, key: indexKey) as int;
      if (highestIndex >= curIndex) {
        // First increment the receiving index
        await _incrementAddressIndexForChain(0);
        final newReceivingIndex =
            DB.instance.get<dynamic>(boxName: walletId, key: indexKey) as int;

        // Use new index to derive a new receiving address
        final newReceivingAddress =
            await _generateAddressForChain(0, newReceivingIndex);

        // Add that new receiving address to the array of receiving addresses
        await _addToAddressesArrayForChain(newReceivingAddress, 0);

        _currentReceivingAddress = Future(() => newReceivingAddress);
      }
    } on SocketException catch (se, s) {
      Logging.instance.log(
          "SocketException caught in _checkReceivingAddressForTransactions(): $se\n$s",
          level: LogLevel.Error);
      return;
    } catch (e, s) {
      Logging.instance.log(
          "Exception rethrown from _checkReceivingAddressForTransactions(): $e\n$s",
          level: LogLevel.Error);
      rethrow;
    }
  }

  double get highestPercentCached =>
      DB.instance.get<dynamic>(boxName: walletId, key: "highestPercentCached")
          as double? ??
      0;

  set highestPercentCached(double value) => DB.instance.put<dynamic>(
        boxName: walletId,
        key: "highestPercentCached",
        value: value,
      );
}
