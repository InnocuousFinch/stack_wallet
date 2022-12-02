import 'package:stackwallet/models/paymint/transactions_model.dart';

final transactionData = TransactionData.fromMap({
  "a51831f09072dc9edb3130f677a484ca03bced8f6d803e8df83a1ed84bc06c0a": tx1,
  "39a9c37d54d04f9ac6ed45aaa1a02b058391b5d1fc0e2e1d67e50f36b1d82896": tx2,
  "e53ef367a5f9d8493825400a291136870ea24a750f63897f559851ab80ea1020": tx3,
  "10e14b1d34c18a563b476c4c36688eb7caebf6658e25753074471d2adef460ba": tx4,
});

final tx1 = Transaction(
  txid: "a51831f09072dc9edb3130f677a484ca03bced8f6d803e8df83a1ed84bc06c0a",
  confirmedStatus: true,
  confirmations: 15447,
  txType: "Received",
  amount: 10000000,
  fees: 53600,
  height: 1299909,
  address: "PtQCgwUx9mLmRDWxB3J7MPnNsWDcce7a5g",
  timestamp: 1667814832,
  worthNow: "0.00",
  worthAtBlockTimestamp: "0.00",
  inputSize: 2,
  outputSize: 2,
  inputs: [
    Input(
      txid: "e53ef367a5f9d8493825400a291136870ea24a750f63897f559851ab80ea1020",
      vout: 1,
    ),
    Input(
      txid: "b255bf1b4b2f1a76eab45fd69e589b655261b049f238807b0acbf304d1b8195b",
      vout: 0,
    ),
  ],
  outputs: [
    Output(
      scriptpubkeyAddress: "PtQCgwUx9mLmRDWxB3J7MPnNsWDcce7a5g",
      value: 10000000,
    ),
    Output(
      scriptpubkeyAddress: "PsHtVuRCybcTpJQN6ckLFptPB7k9ZkqztA",
      value: 9946400,
    )
  ],
);

final tx2 = Transaction(
  txid: "39a9c37d54d04f9ac6ed45aaa1a02b058391b5d1fc0e2e1d67e50f36b1d82896",
  confirmedStatus: true,
  confirmations: 13927,
  txType: "Sent",
  amount: 50000000,
  fees: 49500,
  height: 1301433,
  address: "PcKLXor8hqb3qSjtoHQThapJSbPapSDt4C",
  timestamp: 1668010880,
  worthNow: "0.00",
  worthAtBlockTimestamp: "0.00",
  inputSize: 1,
  outputSize: 2,
  inputs: [
    Input(
      txid: "909bdf555736c272df0e1df52ca5fcce4f1090b74c0e5d9319bb40e02f4b3add",
      vout: 1,
    ),
  ],
  outputs: [
    Output(
      scriptpubkeyAddress: "PcKLXor8hqb3qSjtoHQThapJSbPapSDt4C",
      value: 50000000,
    ),
    Output(
      scriptpubkeyAddress: "PjDq9kwadvgKNtQLTdGqcDsFzPmk9LMjT7",
      value: 1749802000,
    ),
  ],
);

final tx3 = Transaction(
  txid: "e53ef367a5f9d8493825400a291136870ea24a750f63897f559851ab80ea1020",
  confirmedStatus: true,
  confirmations: 23103,
  txType: "Received",
  amount: 10000000,
  fees: 34623,
  height: 1292263,
  address: "PhDSyHLt7ejdPXGve3HFr93pSdFLHUBwdr",
  timestamp: 1666827392,
  worthNow: "0.00",
  worthAtBlockTimestamp: "0.00",
  inputSize: 1,
  outputSize: 2,
  inputs: [
    Input(
      txid: "8a2c6a4c0797d057f20f93b5e3b6e5f306493c67b2341626e0375f30f35a2d47",
      vout: 0,
    )
  ],
  outputs: [
    Output(
      scriptpubkeyAddress: "PYv7kk7TKQsSosWLuLveMJqAYxTiDiK5kp",
      value: 39915877,
    ),
    Output(
      scriptpubkeyAddress: "PhDSyHLt7ejdPXGve3HFr93pSdFLHUBwdr",
      value: 10000000,
    ),
  ],
);

final tx4 = Transaction(
  txid: "10e14b1d34c18a563b476c4c36688eb7caebf6658e25753074471d2adef460ba",
  confirmedStatus: true,
  confirmations: 493,
  txType: "Sent",
  amount: 9945773,
  fees: 27414,
  height: 1314873,
  address: "PpqgMahyfqfasunUKfkmVfdpyhhrHa2ibY",
  timestamp: 1669740960,
  worthNow: "0.00",
  worthAtBlockTimestamp: "0.00",
  inputSize: 1,
  outputSize: 1,
  inputs: [
    Input(
      txid: "aab01876c4db40b35ba00bbfb7c58aaec32cad7dc136214b7344a944606cbe73",
      vout: 0,
    ),
  ],
  outputs: [
    Output(
      scriptpubkeyAddress: "PpqgMahyfqfasunUKfkmVfdpyhhrHa2ibY",
      value: 9945773,
    ),
  ],
);

final tx1Raw = {
  "txid": "a51831f09072dc9edb3130f677a484ca03bced8f6d803e8df83a1ed84bc06c0a",
  "hash": "46b7358ccbc018da4e144188f311657e8b694f056211d7511726c4259dca86b4",
  "size": 374,
  "vsize": 267,
  "version": 160,
  "locktime": 1299908,
  "vin": [
    {
      "txid":
          "e53ef367a5f9d8493825400a291136870ea24a750f63897f559851ab80ea1020",
      "vout": 1,
      "scriptSig": {"asm": "", "hex": ""},
      "txinwitness": [
        "30440220336bf0952b543314ba37b1bb8866a65b2482b499c715d778e92e90d7d59c6a39022072cae4341ca8825bee8043ae91f18de5776edd069ed228142eca55a16c887d6b01",
        "026b4ca62de9e8f63abd0a6cf176536fe8e6a64d6343b6396aa9fb35232520e4a7"
      ],
      "sequence": 4294967293
    },
    {
      "txid":
          "b255bf1b4b2f1a76eab45fd69e589b655261b049f238807b0acbf304d1b8195b",
      "vout": 0,
      "scriptSig": {"asm": "", "hex": ""},
      "txinwitness": [
        "304402205b914f31952958d54f0290d47eef6d9042259387c9493993882e24bd9acefe00022066b16f2f41885a85051c9bff4c119ecddc0209520e9a93d75866624f11b4e82d01",
        "026b4ca62de9e8f63abd0a6cf176536fe8e6a64d6343b6396aa9fb35232520e4a7"
      ],
      "sequence": 4294967293
    }
  ],
  "vout": [
    {
      "n": 0,
      "type": "standard",
      "value": 0.1,
      "valueSat": 10000000,
      "scriptPubKey": {
        "asm":
            "OP_DUP OP_HASH160 e0923d464a2c30438f0808e4af94868253b63ca0 OP_EQUALVERIFY OP_CHECKSIG",
        "hex": "76a914e0923d464a2c30438f0808e4af94868253b63ca088ac",
        "reqSigs": 1,
        "type": "pubkeyhash",
        "addresses": ["PtQCgwUx9mLmRDWxB3J7MPnNsWDcce7a5g"],
        "address": "PtQCgwUx9mLmRDWxB3J7MPnNsWDcce7a5g"
      }
    },
    {
      "n": 1,
      "type": "standard",
      "value": 0.099464,
      "valueSat": 9946400,
      "scriptPubKey": {
        "asm":
            "OP_DUP OP_HASH160 d4686eee8cd127b50d28869627d61b38cc63fe4a OP_EQUALVERIFY OP_CHECKSIG",
        "hex": "76a914d4686eee8cd127b50d28869627d61b38cc63fe4a88ac",
        "reqSigs": 1,
        "type": "pubkeyhash",
        "addresses": ["PsHtVuRCybcTpJQN6ckLFptPB7k9ZkqztA"],
        "address": "PsHtVuRCybcTpJQN6ckLFptPB7k9ZkqztA"
      }
    }
  ],
  "blockhash":
      "b7cb29eb9cb4fa73c4da32f5cf8dfd90194eb6b689d4e547fa9b3176a698a741",
  "height": 1299909,
  "confirmations": 15447,
  "time": 1667814832,
  "blocktime": 1667814832
};

final tx2Raw = {
  "txid": "39a9c37d54d04f9ac6ed45aaa1a02b058391b5d1fc0e2e1d67e50f36b1d82896",
  "hash": "85130125ec9e37a48670fb5eb0a2780b94ea958cd700a1237ff75775d8a0edb0",
  "size": 226,
  "vsize": 173,
  "version": 160,
  "locktime": 1301432,
  "vin": [
    {
      "txid":
          "909bdf555736c272df0e1df52ca5fcce4f1090b74c0e5d9319bb40e02f4b3add",
      "vout": 1,
      "scriptSig": {"asm": "", "hex": ""},
      "txinwitness": [
        "30440220486c87376122e2d3ca7154f41a45fdafa2865412ec90e4b3db791915eee1d13002204cca8520a655b43c3cddc216725cc8508cd9b326a39ed99ed893be59167289af01",
        "03acc7ad6e2e9560db73f7ec7ef2f55a6115d85069cf0eacfe3ab663f33415573c"
      ],
      "sequence": 4294967293
    }
  ],
  "vout": [
    {
      "n": 0,
      "type": "standard",
      "value": 0.5,
      "valueSat": 50000000,
      "scriptPubKey": {
        "asm":
            "OP_DUP OP_HASH160 3024b192883be45b197b548f71155829af980724 OP_EQUALVERIFY OP_CHECKSIG",
        "hex": "76a9143024b192883be45b197b548f71155829af98072488ac",
        "reqSigs": 1,
        "type": "pubkeyhash",
        "addresses": ["PcKLXor8hqb3qSjtoHQThapJSbPapSDt4C"],
        "address": "PcKLXor8hqb3qSjtoHQThapJSbPapSDt4C"
      }
    },
    {
      "n": 1,
      "type": "standard",
      "value": 17.49802,
      "valueSat": 1749802000,
      "scriptPubKey": {
        "asm":
            "OP_DUP OP_HASH160 7be2f80f6b9f6df740142fb34668c25c4e5c8bd5 OP_EQUALVERIFY OP_CHECKSIG",
        "hex": "76a9147be2f80f6b9f6df740142fb34668c25c4e5c8bd588ac",
        "reqSigs": 1,
        "type": "pubkeyhash",
        "addresses": ["PjDq9kwadvgKNtQLTdGqcDsFzPmk9LMjT7"],
        "address": "PjDq9kwadvgKNtQLTdGqcDsFzPmk9LMjT7"
      }
    }
  ],
  "blockhash":
      "065c7328f1a768f3005ab7bfb322806bcc0cf88a96e89830b44991cc434c9955",
  "height": 1301433,
  "confirmations": 13927,
  "time": 1668010880,
  "blocktime": 1668010880
};

final tx3Raw = {
  "txid": "aab01876c4db40b35ba00bbfb7c58aaec32cad7dc136214b7344a944606cbe73",
  "hash": "7b932948c95cf483798011da3fc77b6d53ee26d3d2ba4d90748cd007bdce48e8",
  "version": 160,
  "size": 188,
  "vsize": 135,
  "weight": 269,
  "locktime": 0,
  "vin": [
    {
      "txid":
          "a51831f09072dc9edb3130f677a484ca03bced8f6d803e8df83a1ed84bc06c0a",
      "vout": 0,
      "scriptSig": {"asm": "", "hex": ""},
      "txinwitness": [
        "30440220167c925d22181bd817f909086367407b41bb5b666b576707477003055d22e22802200a6d9ce8af926df44155ad5e821c91769842185328f9445763a7d80c4f26948201",
        "02fd8149574cb75cb1a498248a3ec56ec983f470ad7964f1db011196315039a627"
      ],
      "sequence": 4294967293
    }
  ],
  "vout": [
    {
      "value": 0.09973187,
      "n": 0,
      "scriptPubKey": {
        "asm": "0 9696fb321b31c0d2d02dbd46e37454006805a44f",
        "hex": "00149696fb321b31c0d2d02dbd46e37454006805a44f",
        "reqSigs": 1,
        "type": "witness_v0_keyhash",
        "addresses": ["pw1qj6t0kvsmx8qd95pdh4rwxaz5qp5qtfz0xq2rja"],
        "address": "pw1qj6t0kvsmx8qd95pdh4rwxaz5qp5qtfz0xq2rja"
      }
    }
  ],
  "hex":
      "02000000000102d7609f2ebf00afdc6b8cda9a5e92b4b9a0b8aaafadf890fbf99721854395fadf0000000000ffffffffc16f9a7f51ab9ea6f6ba16c7dd008d6d3a04b7bb198234133024e25bdec6f8800100000000ffffffff0240420f0000000000160014756037000a8676334b35368581a29143fc0784718a8ab701000000001600148207ee56ed52878d546567f29d17332b85f66e4b0247304402203535cf570aca7c1acfa6e8d2f43e0b188b76d0b7a75ffca448e6af953ffe8b6302202ea52b312aaaf6d615d722bd92535d1e8b25fa9584a8dbe34dfa1ea9c18105ca0121038b68078a95f73f8710e8464dec52c61f9e21675ddf69d4f61b93cc417cf73d7402473044022045268613674326251c46caeaf435081ca753e4ee2018d79480c4930ad7d5e19f022050090a9add82e7272b8206b9d369675e7e9a5f1396fc93490143f005366610290121028e2ede901e69887cb80603c8e207839f61a477d59beff17705162a2045dd974e00000000",
  "blockhash":
      "98f388ba99e3b6fc421c23edf3c699ada082b01e5a5d130af7550b7fa6184f2f",
  "confirmations": 147,
  "time": 1663145287,
  "blocktime": 1663145287
};

final tx4Raw = {
  "txid": "10e14b1d34c18a563b476c4c36688eb7caebf6658e25753074471d2adef460ba",
  "hash": "cb0d83958db55c91fb9cd9cab65ee516e63aea68ae5650a692918779ceb46576",
  "size": 191,
  "vsize": 138,
  "version": 160,
  "locktime": 1314871,
  "vin": [
    {
      "txid":
          "aab01876c4db40b35ba00bbfb7c58aaec32cad7dc136214b7344a944606cbe73",
      "vout": 0,
      "scriptSig": {"asm": "", "hex": ""},
      "txinwitness": [
        "304402202e33ab9c5bb6a50c24de9ebfd1b2f398b4c9027787fb9620fda515a25b62ffcf02205e8371aeeda3b3765fa1e2a5c7ebce5dffbf18932012670c1f5266992f9ed9c901",
        "039ca6c697fed4daf1697f137e7d5b113ff7b6c48ea48d707addd9cfa51889a42a"
      ],
      "sequence": 4294967293
    }
  ],
  "vout": [
    {
      "n": 0,
      "type": "standard",
      "value": 0.09945773,
      "valueSat": 9945773,
      "scriptPubKey": {
        "asm":
            "OP_DUP OP_HASH160 b9833ad924ab05567ea2b679a5c523c66a1da6d7 OP_EQUALVERIFY OP_CHECKSIG",
        "hex": "76a914b9833ad924ab05567ea2b679a5c523c66a1da6d788ac",
        "reqSigs": 1,
        "type": "pubkeyhash",
        "addresses": ["PpqgMahyfqfasunUKfkmVfdpyhhrHa2ibY"],
        "address": "PpqgMahyfqfasunUKfkmVfdpyhhrHa2ibY"
      }
    }
  ],
  "blockhash":
      "74e2d8acec688645120925c8a10d2fdf9ec61278534c0788d749162a6899ddaf",
  "height": 1314873,
  "confirmations": 493,
  "time": 1669740960,
  "blocktime": 1669740960
};
