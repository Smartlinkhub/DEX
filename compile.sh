alias ligo="docker run --rm -v "$PWD":"$PWD" -w "$PWD" ligolang/ligo:0.20.0"
ligo compile-contract lqt_fa12.mligo main > lqt_fa12.tz
ligo compile-contract dex.mligo main > dex_fa12.tz
ligo compile-contract dex_fa2.mligo main > dex_fa2.tz
ligo compile-contract factory.mligo main > factory_fa12.tz
ligo compile-contract factory_fa2.mligo main > factory_fa2.tz
