alias ligo="docker run --rm -v "$PWD":"$PWD" -w "$PWD" ligolang/ligo:0.20.0"
ligo compile-contract lqt_fa12.mligo main > michelson/lqt_fa12.tz
ligo compile-contract dex.mligo main > michelson/dex_fa12.tz
ligo compile-contract dex_fa2.mligo main > michelson/dex_fa2.tz
ligo compile-contract factory.mligo main > michelson/factory_fa12.tz
ligo compile-contract factory_fa2.mligo main > michelson/factory_fa2.tz
