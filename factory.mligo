[@inline] let error_TOKEN_CONTRACT_MUST_HAVE_A_TRANSFER_ENTRYPOINT  = 0n
[@inline] let error_DEX_SET_LQT_ADDRESS_DOES_NOT_EXIST = 1n
[@inline] let error_SELF_SET_LQT_ADDRESS_DOES_NOT_EXIST = 2n
[@inline] let error_TOKEN_ALREADY_EXISTS = 3n

type create_dex_func = (operation * address)

type allowance_key =
  [@layout:comb]
  { owner : address;
    spender : address }

type tokens = (address, nat) big_map
type allowances = (allowance_key, nat) big_map

type investment_direction =
  | ADD
  | REMOVE

type investment_delta = {
  xtz : tez ;
  token : nat ;
  direction : investment_direction ;
}
type dex_storage =
  [@layout:comb]
  { tokenPool : nat ;
    xtzPool : tez ;
    lqtTotal : nat ;
    selfIsUpdatingTokenPool : bool ;
    freezeBaker : bool ;
    manager : address ;
    tokenAddress : address ;
#if FA2
    token_id : nat ;
#endif
    lqtAddress : address ;
    history : (string, nat) big_map ;
    user_investments : (address, investment_delta) big_map ;
    reserve : address ;
  }

#if FA2
type token_identifier = address * nat
#else
type token_identifier = address
#endif

type token_metadata_entry = {
  token_id: nat;
  token_info: (string, bytes) map;
}
type storage = {
  swaps: (nat, address) big_map;
  token_to_swaps: (token_identifier, address) big_map;
  counter: nat;
  empty_history: (string, nat) big_map;
  empty_user_investments: (address, investment_delta) big_map;
  empty_tokens: (address, nat) big_map;
  empty_allowances: (allowance_key, nat) big_map;
  default_reserve: address;
  default_token_metadata : (nat, token_metadata_entry) big_map;
  default_metadata: (string, bytes) big_map;
}
type result = operation list * storage

let deploy_dex (init_storage : dex_storage) : (operation * address) =
  [%Michelson ({| {  UNPPAIIR ;
                     CREATE_CONTRACT
#if FA2
#include "./dex_fa2.tz"
#else
#include "./dex_fa12.tz"
#endif
;
                     PAIR } |} : ((key_hash option) * tez * dex_storage) -> (operation * address))] ((None : key_hash option), Tezos.amount, init_storage)

type lp_token_storage =
  [@layout:comb]
  { tokens : tokens;
    allowances : allowances;
    admin : address;
    total_supply : nat;
    metadata : (string, bytes) big_map;
    token_metadata : (nat, token_metadata_entry) big_map;
  }

let deploy_lp_token (init_storage : lp_token_storage) : (operation * address) =
  [%Michelson ({| {  UNPPAIIR ;
                     CREATE_CONTRACT
#include "./lqt_fa12.tz"
;
                     PAIR } |} : ((key_hash option) * tez * lp_token_storage) -> (operation * address))] ((None : key_hash option), 0tez, init_storage)

type transfer =
  [@layout:comb]
  { [@annot:from] address_from : address;
    [@annot:to] address_to : address;
    value : nat }

let sqrt (y: nat) =
    if y > 3n then
        let z = y in
        let x = y / 2n + 1n in
        let rec iter (x, y, z: nat * nat * nat): nat =
            if x < z then
                iter ((y / x + x) / 2n, y, x)
            else
                z
        in
        iter (x, y, z)
    else if y <> 0n then
        1n
    else
        0n

[@inline]
let mutez_to_natural (a: tez) : nat =  a / 1mutez


type set_lqt_address_param = {
  dex_address: address;
  lqt_address: address;
}
[@inline] let set_lqt_address (self: address) (p: set_lqt_address_param) (s: storage)  =
    if Tezos.sender <> self then
        (failwith "only self can call this entrypoint" : result)
    else
        let set_lqt_address_entrypoint : address contract =
          match (Tezos.get_entrypoint_opt "%setLqtAddress" p.dex_address :  address contract option) with
          | None -> (failwith error_DEX_SET_LQT_ADDRESS_DOES_NOT_EXIST: address contract)
          | Some contract -> contract in
        let set_lqt_address = Tezos.transaction p.lqt_address 0mutez set_lqt_address_entrypoint in
        ([set_lqt_address], s)


type launch_exchange_param = {
    token_address: address;
#if FA2
    token_id: nat;
#endif
    token_amount: nat;
}

type txs_item =
  [@layout:comb]
  {
    to_: address;
    token_id: nat;
    amount: nat;
}
type transfer_fa2_item =
  [@layout:comb]
  {
    from_: address;
    txs: txs_item list;
  }
type transfer_fa2 = transfer_fa2_item list

[@inline] let launch_exchange (self: address) (launch_exchange_param: launch_exchange_param) (s: storage)  =
#if FA2
    if Big_map.mem (launch_exchange_param.token_address, launch_exchange_param.token_id) s.token_to_swaps then
#else
    if Big_map.mem launch_exchange_param.token_address s.token_to_swaps then
#endif
        (failwith error_TOKEN_ALREADY_EXISTS : result)
    else
        let lqtTotal = mutez_to_natural Tezos.amount in
        let history = Big_map.update "tokenPool" (Some (launch_exchange_param.token_amount)) s.empty_history in
        let history = Big_map.update "xtzPool" (Some (mutez_to_natural Tezos.amount)) history in
        let history = Big_map.update "xtzVolume" (Some 0n) history in
        let user_investments = Big_map.update Tezos.sender (Some {xtz=Tezos.amount; token=launch_exchange_param.token_amount; direction=ADD}) s.empty_user_investments in
        let dex_init_storage : dex_storage = {
          tokenPool = launch_exchange_param.token_amount;
          xtzPool = Tezos.amount ;
          lqtTotal = lqtTotal ;
          selfIsUpdatingTokenPool = false ;
          freezeBaker = false ;
          manager = self ;
          tokenAddress = launch_exchange_param.token_address ;
#if FA2
          token_id = launch_exchange_param.token_id;
#endif
          lqtAddress = ("tz1Ke2h7sDdakHJQh8WX4Z372du1KChsksyU" : address) ;
          history = history ;
          user_investments = user_investments ;
          reserve = s.default_reserve ;
        } in

        let dex_res = deploy_dex (dex_init_storage) in

        //let lp_token_metadata = Big_map.update "swap" (Some (Bytes.pack launch_exchange_param.token_address)) s.default_metadata in
        let lp_token_init_storage = {
            tokens = Big_map.update Tezos.sender (Some lqtTotal) s.empty_tokens;
            allowances = s.empty_allowances;
            admin = dex_res.1;
            total_supply = lqtTotal;
            token_metadata = s.default_token_metadata;
            metadata = s.default_metadata;
        } in

        let lp_token_res = deploy_lp_token (lp_token_init_storage) in

        let new_storage = {
          swaps = Big_map.update s.counter (Some dex_res.1) s.swaps;
#if FA2
          token_to_swaps = Big_map.update (launch_exchange_param.token_address, launch_exchange_param.token_id)  (Some dex_res.1) s.token_to_swaps;
#else
          token_to_swaps = Big_map.update launch_exchange_param.token_address  (Some dex_res.1) s.token_to_swaps;
#endif
          counter = s.counter + 1n;
          empty_tokens = s.empty_tokens;
          empty_allowances = s.empty_allowances;
          empty_history = s.empty_history;
          empty_user_investments = s.empty_user_investments;
          default_reserve = s.default_reserve;
          default_metadata = s.default_metadata;
          default_token_metadata = s.default_token_metadata;
        } in

#if FA2
        let transfer : transfer_fa2 contract =
        match (Tezos.get_entrypoint_opt "%transfer" launch_exchange_param.token_address :  transfer_fa2 contract option) with
        | None -> (failwith error_TOKEN_CONTRACT_MUST_HAVE_A_TRANSFER_ENTRYPOINT : transfer_fa2 contract)
        | Some contract -> contract in
        let transfer_param = [{
            from_ = Tezos.sender ;
            txs = [{
                to_ = dex_res.1;
                token_id = launch_exchange_param.token_id;
                amount = launch_exchange_param.token_amount
            }]
        }] in
        let transfer_tokens = Tezos.transaction transfer_param 0mutez transfer in
#else
        let transfer : transfer contract =
        match (Tezos.get_entrypoint_opt "%transfer" launch_exchange_param.token_address :  transfer contract option) with
        | None -> (failwith error_TOKEN_CONTRACT_MUST_HAVE_A_TRANSFER_ENTRYPOINT : transfer contract)
        | Some contract -> contract in
        let transfer_tokens = Tezos.transaction { address_from = Tezos.sender; address_to = dex_res.1; value = launch_exchange_param.token_amount } 0mutez transfer in
#endif

        let set_lqt_address_entrypoint : set_lqt_address_param contract =
        match (Tezos.get_entrypoint_opt "%setLqtAddress" self :  set_lqt_address_param contract option) with
        | None -> (failwith error_SELF_SET_LQT_ADDRESS_DOES_NOT_EXIST: set_lqt_address_param contract)
        | Some contract -> contract in
        let set_lqt_address = Tezos.transaction { dex_address = dex_res.1 ; lqt_address = lp_token_res.1 } 0mutez set_lqt_address_entrypoint in

        ([dex_res.0; lp_token_res.0; transfer_tokens; set_lqt_address], new_storage)

type param =
    | LaunchExchange of launch_exchange_param
    | SetLqtAddress of set_lqt_address_param

let main ((param, storage) : param * storage) =
    match param with
    | LaunchExchange p -> launch_exchange Tezos.self_address p storage
    | SetLqtAddress p -> set_lqt_address Tezos.self_address p storage
