#!/bin/bash

mkdir -p build
(cd ../../crypto_plugins/flutter_libepiccash/scripts/windows && ./build_all.sh && cp build/libepic_cash_wallet.dll ../../../../)  &
(cd ../../crypto_plugins/flutter_liblelantus/scripts/windows && ./build_all.sh && cp build/libmobileliblelantus.dll ../../../../) &
(cd ../../crypto_plugins/flutter_libmonero/scripts/windows && ./build_all.sh && cp build/libcw_monero.dll ../../../../ && cp build/libcw_wownero.dll ../../../../) &

wait
echo "Done building"
