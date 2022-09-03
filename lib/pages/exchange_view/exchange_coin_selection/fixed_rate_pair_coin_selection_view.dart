import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:stackwallet/models/exchange/change_now/available_floating_rate_pair.dart';
import 'package:stackwallet/models/exchange/change_now/currency.dart';
import 'package:stackwallet/utilities/assets.dart';
import 'package:stackwallet/utilities/cfcolors.dart';
import 'package:stackwallet/utilities/constants.dart';
import 'package:stackwallet/utilities/enums/coin_enum.dart';
import 'package:stackwallet/utilities/text_styles.dart';
import 'package:stackwallet/widgets/custom_buttons/app_bar_icon_button.dart';
import 'package:stackwallet/widgets/icon_widgets/x_icon.dart';
import 'package:stackwallet/widgets/loading_indicator.dart';
import 'package:stackwallet/widgets/rounded_white_container.dart';
import 'package:stackwallet/widgets/stack_text_field.dart';
import 'package:stackwallet/widgets/textfield_icon_button.dart';
import 'package:tuple/tuple.dart';

class FixedRateMarketPairCoinSelectionView extends ConsumerStatefulWidget {
  const FixedRateMarketPairCoinSelectionView({
    Key? key,
    required this.markets,
    required this.currencies,
    required this.isFrom,
  }) : super(key: key);

  final List<AvailablePair> markets;
  final List<Currency> currencies;
  final bool isFrom;

  @override
  ConsumerState<FixedRateMarketPairCoinSelectionView> createState() =>
      _FixedRateMarketPairCoinSelectionViewState();
}

class _FixedRateMarketPairCoinSelectionViewState
    extends ConsumerState<FixedRateMarketPairCoinSelectionView> {
  late TextEditingController _searchController;
  final _searchFocusNode = FocusNode();

  late final List<AvailablePair> markets;
  late List<AvailablePair> _markets;

  late final bool isFrom;

  Tuple2<String, String> _imageUrlAndNameFor(String ticker) {
    final matches = widget.currencies.where(
        (element) => element.ticker.toLowerCase() == ticker.toLowerCase());

    if (matches.isNotEmpty) {
      return Tuple2(matches.first.image, matches.first.name);
    }
    return Tuple2("", ticker);
  }

  void filter(String text) {
    setState(() {
      _markets = [
        ...markets.where((e) {
          final String ticker = isFrom ? e.fromCurrency : e.toCurrency;
          final __currencies = widget.currencies
              .where((e) => e.ticker.toLowerCase() == ticker.toLowerCase());
          if (__currencies.isNotEmpty) {
            return __currencies.first.name
                    .toLowerCase()
                    .contains(text.toLowerCase()) ||
                ticker.toLowerCase().contains(text.toLowerCase());
          }
          return ticker.toLowerCase().contains(text.toLowerCase());
        })
      ];
    });
  }

  @override
  void initState() {
    _searchController = TextEditingController();
    isFrom = widget.isFrom;

    markets = [...widget.markets];
    if (isFrom) {
      markets.sort(
        (a, b) => a.fromCurrency
            .toLowerCase()
            .compareTo(b.fromCurrency.toLowerCase()),
      );
      for (Coin coin in Coin.values.reversed) {
        int index = markets.indexWhere((element) =>
            element.fromCurrency.toLowerCase() == coin.ticker.toLowerCase());
        if (index > 0) {
          final market = markets.removeAt(index);
          markets.insert(0, market);
        }
      }
    } else {
      markets.sort(
        (a, b) =>
            a.toCurrency.toLowerCase().compareTo(b.toCurrency.toLowerCase()),
      );
      for (Coin coin in Coin.values.reversed) {
        int index = markets.indexWhere((element) =>
            element.toCurrency.toLowerCase() == coin.ticker.toLowerCase());
        if (index > 0) {
          final market = markets.removeAt(index);
          markets.insert(0, market);
        }
      }
    }

    _markets = [...markets];

    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CFColors.almostWhite,
      appBar: AppBar(
        leading: AppBarBackButton(
          onPressed: () async {
            if (FocusScope.of(context).hasFocus) {
              FocusScope.of(context).unfocus();
              await Future<void>.delayed(const Duration(milliseconds: 50));
            }
            if (mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          "Choose a coin to exchange",
          style: STextStyles.pageTitleH2,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              height: 16,
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(
                Constants.size.circularBorderRadius,
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: filter,
                style: STextStyles.field,
                decoration: standardInputDecoration(
                  "Search",
                  _searchFocusNode,
                ).copyWith(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 16,
                    ),
                    child: SvgPicture.asset(
                      Assets.svg.search,
                      width: 16,
                      height: 16,
                    ),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(right: 0),
                          child: UnconstrainedBox(
                            child: Row(
                              children: [
                                TextFieldIconButton(
                                  child: const XIcon(),
                                  onTap: () async {
                                    setState(() {
                                      _searchController.text = "";
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            Text(
              "Popular coins",
              style: STextStyles.smallMed12,
            ),
            const SizedBox(
              height: 12,
            ),
            Builder(builder: (context) {
              final items = _markets
                  .where((e) => Coin.values
                      .where((coin) =>
                          coin.ticker.toLowerCase() ==
                          (isFrom
                              ? e.fromCurrency.toLowerCase()
                              : e.toCurrency.toLowerCase()))
                      .isNotEmpty)
                  .toList(growable: false);

              return RoundedWhiteContainer(
                padding: const EdgeInsets.all(0),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (builderContext, index) {
                    final String ticker = isFrom
                        ? items[index].fromCurrency
                        : items[index].toCurrency;

                    final tuple = _imageUrlAndNameFor(ticker);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop(ticker);
                        },
                        child: RoundedWhiteContainer(
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: SvgPicture.network(
                                  tuple.item1,
                                  width: 20,
                                  height: 20,
                                  placeholderBuilder: (_) =>
                                      const LoadingIndicator(),
                                ),
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                              Text(
                                "${tuple.item2} / ${ticker.toUpperCase()}",
                                style: STextStyles.titleBold12,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
            const SizedBox(
              height: 20,
            ),
            Text(
              "All coins",
              style: STextStyles.smallMed12,
            ),
            const SizedBox(
              height: 12,
            ),
            Flexible(
              child: RoundedWhiteContainer(
                padding: const EdgeInsets.all(0),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _markets.length,
                  itemBuilder: (builderContext, index) {
                    final String ticker = isFrom
                        ? _markets[index].fromCurrency
                        : _markets[index].toCurrency;

                    final tuple = _imageUrlAndNameFor(ticker);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop(ticker);
                        },
                        child: RoundedWhiteContainer(
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: SvgPicture.network(
                                  tuple.item1,
                                  width: 20,
                                  height: 20,
                                  placeholderBuilder: (_) =>
                                      const LoadingIndicator(),
                                ),
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                              Text(
                                "${tuple.item2} / ${ticker.toUpperCase()}",
                                style: STextStyles.titleBold12,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
