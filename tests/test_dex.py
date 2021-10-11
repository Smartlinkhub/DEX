import math
import unittest
import random
import json
from contextlib import contextmanager

from dataclasses import dataclass
from pytezos.context.impl import ExecutionContext
from pytezos.michelson.repl import InterpreterResult
from pytezos import ContractInterface
from pytezos.michelson.stack import MichelsonStack
from pytezos.michelson.micheline import MichelsonRuntimeError
from pytezos.rpc.errors import MichelsonError
from pytezos.crypto.key import Key
from pytezos import pytezos
from pytezos.contract.result import OperationResult

from pytezos.michelson.sections.storage import StorageSection
from decimal import Decimal


default_reserve = "tz1VYKnRgPyfZjdsnoVPyQrhBuhWHoP5QqxM"


# sandbox
alice_key = "edsk3EQB2zJvvGrMKzkUxhgERsy6qdDDw19TQyFWkYNUmGSxXiYm7Q"
alice_pk = "tz1Yigc57GHQixFwDEVzj5N1znSCU3aq15td"
bob_pk = "tz1RTrkJszz7MgNdeEvRLaek8CCrcvhTZTsg"
bob_key = "edsk4YDWx5QixxHtEfp5gKuYDd1AZLFqQhmquFgz64mDXghYYzW6T9"
shell = "http://localhost:8732"

# granadanet
# alice_key = "edsk393aKU2SCpyRAxbN4AhCBXUdXYfinhKeUF2g3ZPdWJQTQ4HRLx"
# alice_pk = "tz1PYSAPqDPH7GSx3sSptbqPr3a43eChPYsr"
# bob_key = alice_key
# bob_pk = alice_pk
# shell = "granadanet"
#
# florencenet
# alice_key = "edsk393aKU2SCpyRAxbN4AhCBXUdXYfinhKeUF2g3ZPdWJQTQ4HRLx"
# alice_pk = "tz1PYSAPqDPH7GSx3sSptbqPr3a43eChPYsr"
# bob_key = alice_key
# bob_pk = alice_pk
# shell = "https://florencenet.api.tez.ie/"

using_params = dict(shell=shell, key=alice_key)

pytezos = pytezos.using(**using_params)
send_conf = dict(min_confirmations=1)


@dataclass
class DexStorage:
    manager: str
    token_address: str = ""
    lp_token_address: str = "tz1Ke2h7sDdakHJQh8WX4Z372du1KChsksyU"

@dataclass
class FA12Storage:
    admin: str


@dataclass
class FA2Storage:
    admin: str


class Env:
    @staticmethod
    def deploy_fa2(init_storage: FA12Storage, token_info):
        with open("michelson/FA2.tz") as f:
            michelson = f.read()

        fa2 = ContractInterface.from_michelson(michelson).using(**using_params)
        token_metadata = {
            0: {
                "token_id": 0,
                "token_info": token_info,
            }
        }
        storage = {
            'administrator': init_storage.admin,
            'all_tokens': 0,
            'ledger': {},
            'metadata': {},
            'operators': {},
            'paused': False,
            'token_metadata': token_metadata
        }
        opg = fa2.originate(initial_storage=storage).send(**send_conf)
        fa2_addr = OperationResult.from_operation_group(opg.opg_result)[0].originated_contracts[0]
        fa2 = pytezos.using(**using_params).contract(fa2_addr)

        return fa2

    @staticmethod
    def deploy_fa12(init_storage: FA12Storage, token_info):
        with open("michelson/FA12.json") as f:
            source = f.read()

        micheline = json.loads(source)
        fa12 = ContractInterface.from_micheline(micheline).using(**using_params)
        token_metadata = {
            0: {
                "token_id": 0,
                "token_info": token_info,
            }
        }
        storage = {
            "administrator": init_storage.admin,
            "balances": {},
            "metadata": {},
            "paused": False,
            "token_metadata": token_metadata,
            "totalSupply": 0,
        }
        opg = fa12.originate(initial_storage=storage).send(**send_conf)
        fa12_addr = OperationResult.from_operation_group(opg.opg_result)[0].originated_contracts[0]
        fa12 = pytezos.using(**using_params).contract(fa12_addr)

        return fa12

    @staticmethod
    def deploy_factory_fa2():
        with open("michelson/factory_fa2.tz") as f:
            source = f.read()

        factory = ContractInterface.from_michelson(source).using(**using_params)
        factory_storage = {
            "empty_allowances": {},
            "empty_tokens": {},
            "empty_history": {},
            "empty_user_investments": {},
            "swaps": {},
            "token_to_swaps": {},
            "counter": 0,
            "default_reserve": default_reserve,
        }
        opg = factory.originate(initial_storage=factory_storage).send(**send_conf)
        factory_addr = OperationResult.from_operation_group(opg.opg_result)[0].originated_contracts[0]
        return pytezos.using(**using_params).contract(factory_addr)

    @staticmethod
    def deploy_factory(reserve=default_reserve):
        with open("michelson/factory_fa12.tz") as f:
            source = f.read()

        factory = ContractInterface.from_michelson(source).using(**using_params)
        factory_storage = {
            "empty_allowances": {},
            "empty_tokens": {},
            "empty_history": {},
            "empty_user_investments": {},
            "swaps": {},
            "token_to_swaps": {},
            "counter": 0,
            "default_reserve": reserve,
        }
        opg = factory.originate(initial_storage=factory_storage).send(**send_conf)
        factory_addr = OperationResult.from_operation_group(opg.opg_result)[0].originated_contracts[0]
        return pytezos.using(**using_params).contract(factory_addr)


default_token_info = [
    {
        "decimals": b"5",
        "symbol": b"KUSD",
        "name": b"Kolibri",
        "thumbnailUri": b"https://kolibri-data.s3.amazonaws.com/logo.png"
    },
    {
        "decimals": b"6",
        "symbol": b"wXTZ",
        "name": b"Wrapped Tezos",
        "thumbnailUri": b"https://raw.githubusercontent.com/StakerDAO/wrapped-xtz/dev/assets/wXTZ-token-FullColor.png"
    },
    {
        "decimals": b"3",
        "symbol": b"USDS",
        "name": b"Stably USD",
        "thumbnailUri": b"https://quipuswap.com/tokens/stably.png"
    },
    {
        "decimals": b"8",
        "symbol": b"tzBTC",
        "name": b"tzBTC",
        "thumbnailUri": b"https://tzbtc.io/wp-content/uploads/2020/03/tzbtc_logo_single.svg"
    },
    {
        "decimals": b"2",
        "symbol": b"STKR",
        "name": b"Staker Governance Token",
        "thumbnailUri": b"https://github.com/StakerDAO/resources/raw/main/stkr.png"
    },
    {
        "decimals": b"6",
        "symbol": b"USDtz",
        "name": b"USDtez",
        "thumbnailUri": b"https://usdtz.com/lightlogo10USDtz.png"
    },
    {
        "decimals": b"8",
        "symbol": b"ETHtz",
        "name": b"ETHtez",
        "thumbnailUri": b"https://ethtz.io/ETHtz_purple.png"
    },
]


def setup_swap_dashboard_data_test(tokenPool, xtzPool, reserve=default_reserve):
    factory = Env.deploy_factory(reserve)
    fa12_init_storage = FA12Storage(alice_pk)

    def setup_fa12_token(amount):
        token_info = {
            "decimals": b"0",
            "symbol": b"ETHtz",
            "name": b"ETHtez",
            "thumbnailUri": b"https://ethtz.io/ETHtz_purple.png"
        }
        token = Env.deploy_fa12(fa12_init_storage, token_info)
        token.mint({"address": alice_pk, "value": amount * 1000}).send(**send_conf)
        token.approve({"spender": factory.address, "value": amount}).send(**send_conf)
        return token

    token = setup_fa12_token(tokenPool)
    param = {"token_address": token.address, "token_amount": tokenPool}

    factory.launchExchange(param).with_amount(xtzPool).send(**send_conf)

    swap_address = factory.storage["swaps"][0]()
    swap = pytezos.using(**using_params).contract(swap_address)

    token.approve({"spender": swap.address, "value": 100000}).send(**send_conf)
    return swap, token


def get_xtz_balance(address):
    return int(pytezos.account(address)["balance"])


def get_opg_fee(resp):
    return int(resp.opg_result["contents"][0]["fee"])


class TestFactory(unittest.TestCase):
    def test_xtz_to_token_min_tokens_bought(self):
        """
        Since the Dexter contract was modified to lower the overall fee and
        redistribute some XTZ to the reserve, we test that:
        - the error_TOKENS_BOUGHT_MUST_BE_GREATER_THAN_OR_EQUAL_TO_MIN_TOKENS_BOUGHT
          exception throws when expected, that is, after the reserve fee
          has been taken from xtz_in
        """
        tokenPool = 10 ** 10
        xtzPool = 10 ** 10
        swap, token = setup_swap_dashboard_data_test(tokenPool, xtzPool)

        start_xtzPool = swap.storage["xtzPool"]()
        start_tokenPool = swap.storage["tokenPool"]()

        xtz_sold = 10000
        tokens_bought = (xtz_sold * 9972 * start_tokenPool) // (start_xtzPool * 10000 + (xtz_sold * 9972))

        try:
            swap.xtzToToken({"to": alice_pk, "minTokensBought": tokens_bought + 1, "deadline": "2029-09-06T15:08:29.000Z"}).with_amount(xtz_sold).send(**send_conf)
            self.assertEqual(True, False)
        except MichelsonError as e:
            self.assertEqual(e.args[0]['with'], {'int': '18'})

        swap.xtzToToken({"to": alice_pk, "minTokensBought": tokens_bought, "deadline": "2029-09-06T15:08:29.000Z"}).with_amount(xtz_sold).send(**send_conf)

    def test_token_to_xtz_min_xtz_bought(self):
        """
        Since the Dexter contract was modified to lower the overall fee and
        redistribute some XTZ to the reserve, we test that:
        - the error_XTZ_BOUGHT_MUST_BE_GREATER_THAN_OR_EQUAL_TO_MIN_XTZ_BOUGHT
          exception throws when expected, that is, after the reserve fee
          has been taken from xtz_out
        """
        tokenPool = 10 ** 10
        xtzPool = 10 ** 10
        swap, token = setup_swap_dashboard_data_test(tokenPool, xtzPool)

        start_xtzPool = swap.storage["xtzPool"]()
        start_tokenPool = swap.storage["tokenPool"]()

        tokensSold = 10000
        xtz_bought = (tokensSold * 9972 * start_xtzPool) // (start_tokenPool * 10000 + (tokensSold * 9972))

        try:
            swap.tokenToXtz({"to": alice_pk, "tokensSold": tokensSold, "minXtzBought": xtz_bought + 1, "deadline": "2029-09-06T15:08:29.000Z"}).send(**send_conf)
            self.assertEqual(True, False)
        except MichelsonError as e:
            self.assertEqual(e.args[0]['with'], {'int': '8'})

        swap.tokenToXtz({"to": alice_pk, "tokensSold": tokensSold, "minXtzBought": xtz_bought, "deadline": "2029-09-06T15:08:29.000Z"}).send(**send_conf)

    def test_swap_update_reserve(self):
        """
        The reserve needs to be able to modify the reserve from the
        swap contract storage. Other addresses should not be able to
        modify the reserve.
        """
        tokenPool = 10
        xtzPool = 10
        swap, _ = setup_swap_dashboard_data_test(tokenPool, xtzPool, alice_pk)
        swap.updateReserve(bob_pk).send(**send_conf)
        self.assertEqual(swap.storage["reserve"](), bob_pk)

        try:
            swap.updateReserve(alice_pk).send(**send_conf)
            self.assertEqual(True, False)
        except MichelsonError as e:
            self.assertEqual(e.args[0]['with'], {'int': '40'})

    def test_token_to_token_reserve_fee(self):
        """
        Since the Dexter contract was modified to lower the overall fee and
        redistribute some XTZ to the reserve, we test that:
        - the reserve gets its fee, so 0.06% on both swaps
        - the user gets the right amount of token_out
        - that both swaps after the transaction have:
          + xtzPool == its xtz balance
          + tokenPool == to its balance in the associated token contract
        """
        tokenPool = 10 ** 10
        xtzPool = 10 ** 10
        swap_in, token_in = setup_swap_dashboard_data_test(tokenPool, xtzPool)
        swap_out, token_out = setup_swap_dashboard_data_test(tokenPool, xtzPool)

        start_reserve_balance = get_xtz_balance(default_reserve)
        start_alice_token_out = token_out.getBalance(alice_pk, None).callback_view()
        swap_in_start_xtzPool = swap_in.storage["xtzPool"]()
        swap_in_start_tokenPool = swap_in.storage["tokenPool"]()
        swap_out_start_xtzPool = swap_out.storage["xtzPool"]()
        swap_out_start_tokenPool = swap_out.storage["tokenPool"]()

        self.assertEqual(get_xtz_balance(swap_in.address), swap_in_start_xtzPool)
        self.assertEqual(token_in.getBalance(swap_in.address, None).callback_view(), swap_in_start_tokenPool)

        tokensSold = 100000
        swap_in.tokenToToken({
            "outputDexterContract": swap_out.address,
            "minTokensBought": 0,
            "to": alice_pk,
            "tokensSold": tokensSold,
            "deadline": "2029-09-06T15:08:29.000Z"
        }).send(**send_conf)

        end_reserve_balance = get_xtz_balance(default_reserve)

        swap_in_xtz_bought = (tokensSold * 9972 * swap_in_start_xtzPool) // (swap_in_start_tokenPool * 10000 + (tokensSold * 9972))
        swap_in_reserve_fee = (tokensSold * 3 * swap_in_start_xtzPool) // (swap_in_start_tokenPool * 10000 + (tokensSold * 3))

        swap_out_xtz_sold = swap_in_xtz_bought
        swap_out_reserve_fee = swap_out_xtz_sold * 3 // 10000
        swap_out_tokens_bought = (swap_out_xtz_sold * 9972 * swap_out_start_tokenPool) // (swap_out_start_xtzPool * 10000 + (swap_out_xtz_sold * 9972))

        end_alice_token_out = token_out.getBalance(alice_pk, None).callback_view()
        swap_in_end_xtzPool = swap_in.storage["xtzPool"]()
        swap_in_end_tokenPool = swap_in.storage["tokenPool"]()

        reserve_fee = swap_in_reserve_fee + swap_out_reserve_fee

        # reserve has taxed proper xtz amount
        self.assertEqual(end_reserve_balance - start_reserve_balance, reserve_fee)
        # swap token balance equals its token pool
        self.assertEqual(token_in.getBalance(swap_in.address, None).callback_view(), swap_in_end_tokenPool)
        # swap xtz balance equals its xtz pool
        self.assertEqual(get_xtz_balance(swap_in.address), swap_in_end_xtzPool)
        # alice has got right amount of tokens
        self.assertEqual(end_alice_token_out - start_alice_token_out, swap_out_tokens_bought)

        ### swap out tokenPool and xtzPool are tested in xtz_to_token and do not need to be retested here
        ### we test that it is called with the right param when testing that alice gets the right amount of tokens out

        # we now show what the calculated values in the test were for manual review
        # notice that since initially xtzPool == tokenPool for both pools and
        # the pools are much larger than the amount exchange, we expect xtz_bought
        # to be close to tokenSold and the reserve fee to be small, which is the case.
        self.assertEqual(reserve_fee, 58)
        self.assertEqual(swap_out_tokens_bought, 99438)

        # history
        xtz_volume = (tokensSold * swap_in_start_xtzPool) // (swap_in_start_tokenPool + tokensSold)
        self.assertEqual(swap_in.storage["history"]["xtzVolume"](), xtz_volume)
        self.assertEqual(int(swap_in.storage["history"]["xtzPool"]()), swap_in_end_xtzPool)
        self.assertEqual(int(swap_in.storage["history"]["tokenPool"]()), swap_in_end_tokenPool)

    def test_token_to_xtz_reserve_fee(self):
        """
        Since the Dexter contract was modified to lower the overall fee and
        redistribute some XTZ to the reserve, we test that:
        - the reserve gets its fee, 0.06% of the xtz_out
        - the user gets the right amount of xtz_out
        - that the swap after the transaction has:
          + xtzPool == its xtz balance
          + tokenPool == to its balance in the associated token contract
        """
        tokenPool = 10 ** 10
        xtzPool = 10 ** 10
        swap, token = setup_swap_dashboard_data_test(tokenPool, xtzPool)

        start_reserve_balance = get_xtz_balance(default_reserve)
        start_alice_xtz = get_xtz_balance(alice_pk)
        start_xtzPool = swap.storage["xtzPool"]()
        start_tokenPool = swap.storage["tokenPool"]()

        self.assertEqual(get_xtz_balance(swap.address), start_xtzPool)
        self.assertEqual(token.getBalance(swap.address, None).callback_view(), start_tokenPool)

        tokensSold = 100000
        resp = swap.tokenToXtz({"to": alice_pk, "tokensSold": tokensSold, "minXtzBought": 0, "deadline": "2029-09-06T15:08:29.000Z"}).send(**send_conf)

        end_reserve_balance = get_xtz_balance(default_reserve)

        xtz_bought = (tokensSold * 9972 * start_xtzPool) // (start_tokenPool * 10000 + (tokensSold * 9972))
        reserve_fee = (tokensSold * 3 * start_xtzPool) // (start_tokenPool * 10000 + (tokensSold * 3))

        end_alice_xtz = get_xtz_balance(alice_pk)
        end_xtzPool = swap.storage["xtzPool"]()
        end_tokenPool = swap.storage["tokenPool"]()

        # reserve has taxed proper xtz amount
        self.assertEqual(reserve_fee, end_reserve_balance - start_reserve_balance)
        # swap token balance equals its token pool
        self.assertEqual(token.getBalance(swap.address, None).callback_view(), end_tokenPool)
        # swap xtz balance equals its xtz pool
        self.assertEqual(get_xtz_balance(swap.address), end_xtzPool)
        # alice has got right amount of tokens
        xtz_amount_from_internal_op_to_alice = int(resp.opg_result["contents"][0]["metadata"]["internal_operation_results"][1]["amount"])
        self.assertEqual(xtz_amount_from_internal_op_to_alice, xtz_bought)

        # we now show what the calculated values in the test were for manual review
        # notice that since initially xtzPool == tokenPool and the pools are much larger
        # than the amount exchange, we expect xtz_bought to be close to tokenSold and
        # the reserve fee to be small, which is the case.
        self.assertEqual(reserve_fee, 29)
        self.assertEqual(xtz_bought, 99719)

        # history
        xtz_volume = (tokensSold * start_xtzPool) // (start_tokenPool + tokensSold)
        self.assertEqual(swap.storage["history"]["xtzVolume"](), xtz_volume)
        self.assertEqual(int(swap.storage["history"]["xtzPool"]()), end_xtzPool)
        self.assertEqual(int(swap.storage["history"]["tokenPool"]()), end_tokenPool)

    def test_xtz_to_token_reserve_fee(self):
        """
        Since the Dexter contract was modified to lower the overall fee and
        redistribute some XTZ to the reserve, we test that:
        - the reserve gets its fee, 0.06% of the xtz_in
        - the user gets the right amount of token_out
        - that the swap after the transaction has:
          + xtzPool == its xtz balance
          + tokenPool == to its balance in the associated token contract
        """
        tokenPool = 10 ** 10
        xtzPool = 10 ** 10
        swap, token = setup_swap_dashboard_data_test(tokenPool, xtzPool)

        start_reserve_balance = get_xtz_balance(default_reserve)
        start_alice_token = token.getBalance(alice_pk, None).callback_view()
        start_xtzPool = swap.storage["xtzPool"]()
        start_tokenPool = swap.storage["tokenPool"]()

        self.assertEqual(get_xtz_balance(swap.address), start_xtzPool)
        self.assertEqual(token.getBalance(swap.address, None).callback_view(), start_tokenPool)

        xtz_sold = 100000
        swap.xtzToToken({"to": alice_pk, "minTokensBought": 0, "deadline": "2029-09-06T15:08:29.000Z"}).with_amount(xtz_sold).send(**send_conf)

        end_reserve_balance = get_xtz_balance(default_reserve)
        end_alice_token = token.getBalance(alice_pk, None).callback_view()

        tokens_bought = (xtz_sold * 9972 * start_tokenPool) // (start_xtzPool * 10000 + (xtz_sold * 9972))
        reserve_fee = (xtz_sold * 3) // 10000

        end_alice_token = token.getBalance(alice_pk, None).callback_view()
        end_xtzPool = swap.storage["xtzPool"]()
        end_tokenPool = swap.storage["tokenPool"]()

        # reserve has taxed proper xtz amount
        self.assertEqual(reserve_fee, end_reserve_balance - start_reserve_balance)
        # swap token balance equals its token pool
        self.assertEqual(token.getBalance(swap.address, None).callback_view(), end_tokenPool)
        # swap xtz balance equals its xtz pool
        self.assertEqual(get_xtz_balance(swap.address), end_xtzPool)
        # alice has got right amount of tokens
        self.assertEqual(end_alice_token - start_alice_token, tokens_bought)

        # we now show what the calculated values in the test were for manual review
        # notice that since initially xtzPool == tokenPool and the pools are much larger
        # than the traded amount, we expect tokens_bought to be close to xtz_sold and
        # the reserve fee to be small, which is the case.
        self.assertEqual(reserve_fee, 30)
        self.assertEqual(tokens_bought, 99719)

        # history
        self.assertEqual(swap.storage["history"]["xtzVolume"](), xtz_sold)
        self.assertEqual(int(swap.storage["history"]["xtzPool"]()), end_xtzPool)
        self.assertEqual(int(swap.storage["history"]["tokenPool"]()), end_tokenPool)

    def test_add_liquidity_dashboard_data(self):
        """We test that:
        - user investments are tracked so that they can be calculated later on
        - xtz/token pools are tracked so the price history can be trivially calculated later on"""
        tokenPool = 1000
        xtzPool = 10000
        swap, token = setup_swap_dashboard_data_test(tokenPool, xtzPool)
        xtzAmount = 10
        swap.addLiquidity({"owner": alice_pk, "minLqtMinted": 1, "maxTokensDeposited": 1000000000000, "deadline": "2029-09-06T15:08:29.000Z"}).with_amount(xtzAmount).send(**send_conf)
        self.assertEqual(swap.storage["user_investments"][alice_pk](), {'direction': 'aDD', 'token': swap.storage["tokenPool"]() - tokenPool, 'xtz': swap.storage["xtzPool"]() - xtzPool})
        self.assertEqual(swap.storage["history"]["xtzPool"](), swap.storage["xtzPool"]())
        self.assertEqual(swap.storage["history"]["tokenPool"](), swap.storage["tokenPool"]())

    def test_remove_liquidity_dashboard_data(self):
        """We test that:
        - user investments are tracked so that they can be calculated later on
        - xtz/token pools are tracked so the price history can be trivially calculated later on"""
        tokenPool = 1000
        xtzPool = 10000
        swap, token = setup_swap_dashboard_data_test(tokenPool, xtzPool)
        swap.removeLiquidity({"to": alice_pk, "lqtBurned": 100, "minXtzWithdrawn": 1, "minTokensWithdrawn": 1, "deadline": "2029-09-06T15:08:29.000Z"}).send(**send_conf)
        self.assertEqual(swap.storage["user_investments"][alice_pk](), {'direction': 'rEMOVE', 'token': tokenPool - swap.storage["tokenPool"](), 'xtz': xtzPool - swap.storage["xtzPool"]()})
        self.assertEqual(swap.storage["history"]["xtzPool"](), swap.storage["xtzPool"]())
        self.assertEqual(swap.storage["history"]["tokenPool"](), swap.storage["tokenPool"]())

    def test_xtz_to_token_dashboard_data(self):
        """We test that: xtz/token pools are tracked so the price history can be trivially calculated later on"""
        tokenPool = 1000
        xtzPool = 10000
        swap, token = setup_swap_dashboard_data_test(tokenPool, xtzPool)

        xtzAmount = 10
        swap.xtzToToken({"to": alice_pk, "minTokensBought": 0, "deadline": "2029-09-06T15:08:29.000Z"}).with_amount(xtzAmount).send(**send_conf)
        self.assertEqual(swap.storage["history"]["xtzPool"](), swap.storage["xtzPool"]())
        self.assertEqual(swap.storage["history"]["tokenPool"](), swap.storage["tokenPool"]())
        self.assertEqual(swap.storage["history"]["xtzVolume"](), xtzAmount)

        xtzAmount = 11
        swap.xtzToToken({"to": alice_pk, "minTokensBought": 0, "deadline": "2029-09-06T15:08:29.000Z"}).with_amount(xtzAmount).send(**send_conf)
        self.assertEqual(swap.storage["history"]["xtzVolume"](), xtzAmount)

    def token_to_xtz_dashboard_data(self):
        """We test that: xtz/token pools are tracked so the price history can be trivially calculated later on"""
        tokenPool = 1000
        xtzPool = 10000
        swap, token = setup_swap_dashboard_data_test(tokenPool, xtzPool)

        start_xtzPool = swap.storage["xtzPool"]()
        start_tokenPool = swap.storage["tokenPool"]()

        tokensSold = 10
        swap.tokenToXtz({"to": alice_pk, "tokensSold": tokensSold, "minXtzBought": 0, "deadline": "2029-09-06T15:08:29.000Z"}).send(**send_conf)
        self.assertEqual(swap.storage["history"]["xtzPool"](), swap.storage["xtzPool"]())
        self.assertEqual(swap.storage["history"]["tokenPool"](), swap.storage["tokenPool"]())

        xtz_volume = (tokensSold * start_xtzPool) // (start_tokenPool + tokensSold)
        self.assertEqual(swap.storage["history"]["xtzVolume"](), xtz_volume)

        new_xtzPool = swap.storage["xtzPool"]()
        new_tokenPool = swap.storage["tokenPool"]()
        tokensSold = 15
        swap.tokenToXtz({"to": alice_pk, "tokensSold": tokensSold, "minXtzBought": 0, "deadline": "2029-09-06T15:08:29.000Z"}).send(**send_conf)

        xtz_volume = (tokensSold * new_xtzPool) // (new_tokenPool + tokensSold)
        self.assertEqual(swap.storage["history"]["xtzVolume"](), xtz_volume)

    def test_token_to_token_dashboard_data(self):
        """We test that: xtz/token pools are tracked so the price history can be trivially calculated later on"""
        tokenPool = 1000
        xtzPool = 10000
        swap, token = setup_swap_dashboard_data_test(tokenPool, xtzPool)
        swap2, token2 = setup_swap_dashboard_data_test(tokenPool, xtzPool)

        start_xtzPool = swap.storage["xtzPool"]()
        start_tokenPool = swap.storage["tokenPool"]()

        tokensSold = 10
        swap.tokenToToken({"outputDexterContract": swap2.address, "minTokensBought": 0, "to": alice_pk, "tokensSold": 10, "deadline": "2029-09-06T15:08:29.000Z"}).send(**send_conf)
        self.assertEqual(swap.storage["history"]["xtzPool"](), swap.storage["xtzPool"]())
        self.assertEqual(swap.storage["history"]["tokenPool"](), swap.storage["tokenPool"]())

        xtz_volume = (tokensSold * start_xtzPool) // (start_tokenPool + tokensSold)
        self.assertEqual(swap.storage["history"]["xtzVolume"](), xtz_volume)

        self.assertEqual(swap2.storage["history"]["xtzPool"](), swap2.storage["xtzPool"]())
        self.assertEqual(swap2.storage["history"]["tokenPool"](), swap2.storage["tokenPool"]())

        new_xtzPool = swap.storage["xtzPool"]()
        new_tokenPool = swap.storage["tokenPool"]()
        tokensSold = 15
        swap.tokenToXtz({"to": alice_pk, "tokensSold": tokensSold, "minXtzBought": 0, "deadline": "2029-09-06T15:08:29.000Z"}).send(**send_conf)

        xtz_volume = (tokensSold * new_xtzPool) // (new_tokenPool + tokensSold)
        self.assertEqual(swap.storage["history"]["xtzVolume"](), xtz_volume)

    def test_launch_exchange_fa2(self):
        """We test that the FA2 factory launches an FA2 swap with an FA 2 token and
        configures it properly including the initial history big maps"""
        factory = Env.deploy_factory_fa2()
        fa2_init_storage = FA2Storage(alice_pk)

        def setup_fa2_token(amount):
            token_info = {
                "decimals": b"0",
                "symbol": b"ETHtz",
                "name": b"ETHtez",
                "thumbnailUri": b"https://ethtz.io/ETHtz_purple.png"
            }
            token = Env.deploy_fa2(fa2_init_storage, token_info)
            token.mint({"address": alice_pk, "amount": amount * 1000, "metadata": {}, "token_id": 0}).send(**send_conf)
            token.update_operators([{"add_operator": {"owner": alice_pk, "operator": factory.address, "token_id": 0}}]).send(**send_conf)
            return token

        tokenPool = 1000
        token = setup_fa2_token(tokenPool)
        param = {"token_address": token.address, "token_amount": tokenPool, "token_id": 0}

        xtzPool = 10000
        factory.launchExchange(param).with_amount(xtzPool).send(**send_conf)

        # should not fail
        swap_address = factory.storage["swaps"][0]()
        swap = pytezos.using(**using_params).contract(swap_address)

        # counter incremented
        self.assertEqual(factory.storage()["counter"], 1)

        ## testing swap storage initialization
        self.assertEqual(swap.storage()["xtzPool"], xtzPool)
        self.assertEqual(swap.storage()["tokenPool"], tokenPool)
        self.assertEqual(swap.storage()["selfIsUpdatingTokenPool"], False)
        self.assertEqual(swap.storage()["freezeBaker"], False)
        self.assertEqual(swap.storage()["manager"], factory.address)
        self.assertEqual(swap.storage()["tokenAddress"], token.address)
        self.assertEqual(swap.storage["history"]["tokenPool"](), tokenPool)
        self.assertEqual(swap.storage["history"]["xtzPool"](), xtzPool)
        self.assertEqual(swap.storage["history"]["xtzVolume"](), 0)
        lqt_total = xtzPool
        self.assertEqual(swap.storage()["lqtTotal"], lqt_total)
        self.assertEqual(swap.storage["user_investments"][alice_pk](), {'direction': 'aDD', 'token': 1000, 'xtz': 10000})

        ## test fa12 balances
        token_address = swap.storage()["tokenAddress"]
        token = pytezos.using(**using_params).contract(token_address)

        def get_balance(addr):
            return token.balance_of({"requests": [{"owner": addr, "token_id": 0}], "callback": None}).view()[0]['nat_2']

        self.assertEqual(get_balance(alice_pk), tokenPool * 1000 - tokenPool)
        self.assertEqual(get_balance(swap.address), tokenPool)

        ## check that swap contract has a balance equal to tokenPool
        self.assertEqual(pytezos.account(swap.address)["balance"], str(xtzPool))

        ## testing lqt token initialization
        lqt_token_address = swap.storage()["lqtAddress"]
        lqt_token = pytezos.using(**using_params).contract(lqt_token_address)

        self.assertEqual(lqt_token.storage()["admin"], swap.address)
        self.assertEqual(lqt_token.storage["tokens"][alice_pk](), lqt_total)
        self.assertEqual(lqt_token.storage["total_supply"](), lqt_total)

        ## test that we cannot launch exchange with same token
        token.update_operators([{"add_operator": {"owner": alice_pk, "operator": factory.address, "token_id": 0}}]).send(**send_conf)
        try:
            factory.launchExchange(param).with_amount(xtzPool).send(**send_conf)
            self.assertEqual(True, False)
        except MichelsonError as e:
            self.assertEqual(e.args[0]['with'], {'int': '3'})

    def test_launch_exchange(self):
        """We test that the FA1.2 factory launches an FA1.2 swap with an FA1.2 token and
        configures it properly including the initial history big maps"""
        factory = Env.deploy_factory()
        fa12_init_storage = FA12Storage(alice_pk)

        def setup_fa12_token(amount):
            token_info = {
                "decimals": b"0",
                "symbol": b"ETHtz",
                "name": b"ETHtez",
                "thumbnailUri": b"https://ethtz.io/ETHtz_purple.png"
            }
            token = Env.deploy_fa12(fa12_init_storage, token_info)
            token.mint({"address": alice_pk, "value": amount * 1000}).send(**send_conf)
            token.approve({"spender": factory.address, "value": amount}).send(**send_conf)
            return token

        tokenPool = 1000
        token = setup_fa12_token(tokenPool)
        param = {"token_address": token.address, "token_amount": tokenPool}

        xtzPool = 10000
        factory.launchExchange(param).with_amount(xtzPool).send(**send_conf)

        # should not fail
        swap_address = factory.storage["swaps"][0]()
        swap = pytezos.using(**using_params).contract(swap_address)

        # counter incremented
        self.assertEqual(factory.storage()["counter"], 1)

        ## testing swap storage initialization
        self.assertEqual(swap.storage()["xtzPool"], xtzPool)
        self.assertEqual(swap.storage()["tokenPool"], tokenPool)
        self.assertEqual(swap.storage()["selfIsUpdatingTokenPool"], False)
        self.assertEqual(swap.storage()["freezeBaker"], False)
        self.assertEqual(swap.storage()["manager"], factory.address)
        self.assertEqual(swap.storage()["tokenAddress"], token.address)
        self.assertEqual(swap.storage["history"]["tokenPool"](), tokenPool)
        self.assertEqual(swap.storage["history"]["xtzPool"](), xtzPool)
        self.assertEqual(swap.storage["history"]["xtzVolume"](), 0)
        lqt_total = xtzPool
        self.assertEqual(swap.storage()["lqtTotal"], lqt_total)
        self.assertEqual(swap.storage["user_investments"][alice_pk](), {'direction': 'aDD', 'token': 1000, 'xtz': 10000})

        ## test fa12 balances
        token_address = swap.storage()["tokenAddress"]
        token = pytezos.using(**using_params).contract(token_address)
        self.assertEqual(
            token.storage["balances"][alice_pk]()["balance"],
            tokenPool * 1000 - tokenPool
        )
        self.assertEqual(
            token.storage["balances"][swap.address]()["balance"],
            tokenPool
        )

        ## check that swap contract has a balance equal to tokenPool
        self.assertEqual(pytezos.account(swap.address)["balance"], str(xtzPool))

        ## testing lqt token initialization
        lqt_token_address = swap.storage()["lqtAddress"]
        lqt_token = pytezos.using(**using_params).contract(lqt_token_address)

        self.assertEqual(lqt_token.storage()["admin"], swap.address)
        self.assertEqual(lqt_token.storage["tokens"][alice_pk](), lqt_total)
        self.assertEqual(lqt_token.storage["total_supply"](), lqt_total)

        ## test that we cannot launch exchange with same token
        token.approve({"spender": factory.address, "value": tokenPool}).send(**send_conf)
        try:
            factory.launchExchange(param).with_amount(xtzPool).send(**send_conf)
            self.assertEqual(True, False)
        except MichelsonError as e:
            self.assertEqual(e.args[0]['with'], {'int': '3'})

    @unittest.skip("Only used to deploy on testnet for frontend tests")
    def test_deploy_swarm(self):
        """Used to deploy factory contracts along with FA1.2 and FA2 tokens.
        Should help with developing the application frontend."""
        factory = Env.deploy_factory()
        factory_fa2 = Env.deploy_factory_fa2()

        with open('contract_addresses.txt', 'w') as f:
            f.write(f'factory FA1.2: {factory.address}\n')
            f.write(f'factory FA2: {factory_fa2.address}\n')

        fa2_init_storage = FA2Storage(alice_pk)

        for token_info in default_token_info[3:]:
            decimals = int(token_info["decimals"].decode("utf-8"))
            token = Env.deploy_fa2(fa2_init_storage, token_info)
            amount = int(1000 * math.pow(10, decimals))
            token.mint({"address": alice_pk, "amount": amount * 1000, "metadata": {}, "token_id": 0}).send(**send_conf)
            token.update_operators([{"add_operator": {"owner": alice_pk, "operator": factory_fa2.address, "token_id": 0}}]).send(**send_conf)
            param = {"token_address": token.address, "token_amount": amount, "token_id": 0}
            opg = factory_fa2.launchExchange(param).with_amount(Decimal(10)).send(**send_conf)
            consumed_gas = OperationResult.consumed_gas(opg.opg_result)

            with open('contract_addresses.txt', 'a') as f:
                f.write(f'fa2 token: {token.address} ; {consumed_gas} gas \n')

        fa12_init_storage = FA12Storage(alice_pk)

        for token_info in default_token_info[:3]:
            decimals = int(token_info["decimals"].decode("utf-8"))
            token = Env.deploy_fa12(fa12_init_storage, token_info)
            amount = int(1000 * math.pow(10, decimals))
            token.mint({"address": alice_pk, "value": amount * 1000}).send(**send_conf)
            token.approve({"spender": factory.address, "value": amount}).send(**send_conf)
            param = {"token_address": token.address, "token_amount": amount}
            opg = factory.launchExchange(param).with_amount(Decimal(10)).send(**send_conf)
            consumed_gas = OperationResult.consumed_gas(opg.opg_result)

            with open('contract_addresses.txt', 'a') as f:
                f.write(f'fa1.2 token: {token.address} ; {consumed_gas} gas \n')


if __name__ == '__main__':
    unittest.main()
