// =============================================================================
// Entrypoints
// =============================================================================

type add_liquidity =
  [@layout:comb]
  { owner : address ;
    minLqtMinted : nat ;
    maxTokensDeposited : nat ;
    deadline : timestamp ;
  }

type remove_liquidity =
  [@layout:comb]
  { [@annot:to] to_ : address ; // recipient of the liquidity redemption
    lqtBurned : nat ;  // amount of lqt owned by sender to burn
    minXtzWithdrawn : tez ; // minimum amount of tez to withdraw
    minTokensWithdrawn : nat ; // minimum amount of tokens to whitdw
    deadline : timestamp ; // the time before which the request must be completed
  }

type xtz_to_token =
  [@layout:comb]
  { [@annot:to] to_ : address ;
    minTokensBought : nat ;
    deadline : timestamp ;
  }

type token_to_xtz =
  [@layout:comb]
  { [@annot:to] to_ : address ;
    tokensSold : nat ;
    minXtzBought : tez ;
    deadline : timestamp ;
  }

type set_baker =
  [@layout:comb]
  { baker : key_hash option ;
    freezeBaker : bool ;
  }

type token_to_token =
  [@layout:comb]
  { outputDexterContract : address ;
    minTokensBought : nat ;
    [@annot:to] to_ : address ;
    tokensSold : nat ;
    deadline : timestamp ;
  }

#if FA2
type update_token_pool_internal = ((address * nat) * nat) list
#else
type update_token_pool_internal = nat
#endif

type update_reserve = address

type entrypoint =
| UpdateReserve   of update_reserve
| AddLiquidity    of add_liquidity
| RemoveLiquidity of remove_liquidity
| XtzToToken      of xtz_to_token
| TokenToXtz      of token_to_xtz
| SetBaker        of set_baker
| SetManager      of address
| SetLqtAddress   of address
| Default         of unit
| UpdateTokenPool of unit
| UpdateTokenPoolInternal of update_token_pool_internal
| TokenToToken    of token_to_token

// =============================================================================
// Storage
// =============================================================================

type investment_direction =
  | ADD
  | REMOVE

type investment_delta = {
  xtz : tez ;
  token : nat ;
  direction : investment_direction ;
}

type storage =
  [@layout:comb]
  { tokenPool : nat ;
    xtzPool : tez ;
    lqtTotal : nat ;
    selfIsUpdatingTokenPool : bool ;
    freezeBaker : bool ;
    manager : address ;
    tokenAddress : address ;
#if FA2
    tokenId : nat ;
#endif
    lqtAddress : address ;
    history : (string, nat) big_map ;
    user_investments : (address, investment_delta) big_map ;
    reserve : address ;
  }

// =============================================================================
// Type Synonyms
// =============================================================================

type result = operation list * storage

#if FA2
// FA2
type token_id = nat
type token_contract_transfer = (address * (address * (token_id * nat)) list) list
type balance_of = ((address * token_id) list * ((((address * nat) * nat) list) contract))
#else
// FA1.2
type token_contract_transfer = address * (address * nat)
type get_balance = address * (nat contract)
#endif

// custom entrypoint for LQT FA1.2
type mintOrBurn =
  [@layout:comb]
  { quantity : int ;
    target : address }

// =============================================================================
// Error codes
// =============================================================================

[@inline] let error_TOKEN_CONTRACT_MUST_HAVE_A_TRANSFER_ENTRYPOINT  = 0n
(* 1n *)
[@inline] let error_SELF_IS_UPDATING_TOKEN_POOL_MUST_BE_FALSE       = 2n
[@inline] let error_THE_CURRENT_TIME_MUST_BE_LESS_THAN_THE_DEADLINE = 3n
[@inline] let error_MAX_TOKENS_DEPOSITED_MUST_BE_GREATER_THAN_OR_EQUAL_TO_TOKENS_DEPOSITED = 4n
[@inline] let error_LQT_MINTED_MUST_BE_GREATER_THAN_MIN_LQT_MINTED = 5n
(* 6n *)
(* 7n *)
[@inline] let error_XTZ_BOUGHT_MUST_BE_GREATER_THAN_OR_EQUAL_TO_MIN_XTZ_BOUGHT = 8n
[@inline] let error_INVALID_TO_ADDRESS = 9n
[@inline] let error_AMOUNT_MUST_BE_ZERO = 10n
[@inline] let error_THE_AMOUNT_OF_XTZ_WITHDRAWN_MUST_BE_GREATER_THAN_OR_EQUAL_TO_MIN_XTZ_WITHDRAWN = 11n
[@inline] let error_LQT_CONTRACT_MUST_HAVE_A_MINT_OR_BURN_ENTRYPOINT = 12n
[@inline] let error_THE_AMOUNT_OF_TOKENS_WITHDRAWN_MUST_BE_GREATER_THAN_OR_EQUAL_TO_MIN_TOKENS_WITHDRAWN = 13n
[@inline] let error_CANNOT_BURN_MORE_THAN_THE_TOTAL_AMOUNT_OF_LQT = 14n
[@inline] let error_TOKEN_POOL_MINUS_TOKENS_WITHDRAWN_IS_NEGATIVE = 15n
(* 16n *)
(* 17n *)
[@inline] let error_TOKENS_BOUGHT_MUST_BE_GREATER_THAN_OR_EQUAL_TO_MIN_TOKENS_BOUGHT = 18n
[@inline] let error_TOKEN_POOL_MINUS_TOKENS_BOUGHT_IS_NEGATIVE = 19n
[@inline] let error_ONLY_MANAGER_CAN_SET_BAKER = 20n
[@inline] let error_ONLY_MANAGER_CAN_SET_MANAGER = 21n
[@inline] let error_BAKER_PERMANENTLY_FROZEN = 22n
[@inline] let error_ONLY_MANAGER_CAN_SET_LQT_ADRESS = 23n
[@inline] let error_LQT_ADDRESS_ALREADY_SET = 24n
[@inline] let error_CALL_NOT_FROM_AN_IMPLICIT_ACCOUNT = 25n
(* 26n *)
(* 27n *)
#if FA2
[@inline] let error_INVALID_FA2_TOKEN_CONTRACT_MISSING_BALANCE_OF = 28n
#else
[@inline] let error_INVALID_FA12_TOKEN_CONTRACT_MISSING_GETBALANCE = 28n
#endif
[@inline] let error_THIS_ENTRYPOINT_MAY_ONLY_BE_CALLED_BY_GETBALANCE_OF_TOKENADDRESS = 29n
(* 30n *)
[@inline] let error_INVALID_INTERMEDIATE_CONTRACT = 31n
[@inline] let error_INVALID_FA2_BALANCE_RESPONSE = 32n
[@inline] let error_UNEXPECTED_REENTRANCE_IN_UPDATE_TOKEN_POOL = 33n
(* 40n *)
[@inline] let error_ONLY_RESERVE_CAN_UPDATE_RESERVE = 40n


// =============================================================================
// Functions
// =============================================================================

(* this is slightly inefficient to inline, but, nice to have a clean stack for
   the entrypoints for the Coq verification *)
[@inline]
let mutez_to_natural (a: tez) : nat =  a / 1mutez

[@inline]
let natural_to_mutez (a: nat): tez = a * 1mutez

[@inline]
let is_a_nat (i : int) : nat option = Michelson.is_nat i

let ceildiv (numerator : nat) (denominator : nat) : nat =
    match (ediv numerator denominator) with
        | None   -> (failwith("DIV by 0") : nat)
        | Some v ->  let (q, r) = v in if r = 0n then q else q + 1n

[@inline]
let mint_or_burn (storage : storage) (target : address) (quantity : int) : operation =
    let lqt_admin : mintOrBurn contract =
    match (Tezos.get_entrypoint_opt "%mintOrBurn" storage.lqtAddress :  mintOrBurn contract option) with
    | None -> (failwith error_LQT_CONTRACT_MUST_HAVE_A_MINT_OR_BURN_ENTRYPOINT : mintOrBurn contract)
    | Some contract -> contract in
    Tezos.transaction {quantity = quantity ; target = target} 0mutez lqt_admin

[@inline]
let token_transfer (storage : storage) (from : address) (to_ : address) (token_amount : nat) : operation =
    let token_contract: token_contract_transfer contract =
    match (Tezos.get_entrypoint_opt "%transfer" storage.tokenAddress : token_contract_transfer contract option) with
    | None -> (failwith error_TOKEN_CONTRACT_MUST_HAVE_A_TRANSFER_ENTRYPOINT : token_contract_transfer contract)
    | Some contract -> contract in
#if FA2
    Tezos.transaction [(from, [(to_, (storage.tokenId, token_amount))])] 0mutez token_contract
#else
    Tezos.transaction (from, (to_, token_amount)) 0mutez token_contract
#endif

[@inline]
let xtz_transfer (to_ : address) (amount_ : tez) : operation =
    let to_contract : unit contract =
    match (Tezos.get_contract_opt to_ : unit contract option) with
    | None -> (failwith error_INVALID_TO_ADDRESS : unit contract)
    | Some c -> c in
    Tezos.transaction () amount_ to_contract

// =============================================================================
// Entrypoint Functions
// =============================================================================

// We assume the contract is originated with at least one liquidity
// provider set up already, so lqtTotal, xtzPool and tokenPool will
// always be positive after the initial setup, unless all liquidity is
// removed, at which point the contract is considered dead and stops working
// properly. (To prevent this, at least one address should keep at least a
// small amount of liquidity in the contract forever.)

let add_liquidity (param : add_liquidity) (storage: storage) : result =
    let { owner = owner ;
          minLqtMinted = minLqtMinted ;
          maxTokensDeposited = maxTokensDeposited ;
          deadline = deadline } = param in

    if storage.selfIsUpdatingTokenPool then
        (failwith error_SELF_IS_UPDATING_TOKEN_POOL_MUST_BE_FALSE : result)
    else if Tezos.now >= deadline then
        (failwith error_THE_CURRENT_TIME_MUST_BE_LESS_THAN_THE_DEADLINE : result)
    else
        // the contract is initialized, use the existing exchange rate
        // mints nothing if the contract has been emptied, but that's OK
        let xtzPool   : nat = mutez_to_natural storage.xtzPool in
        let nat_amount : nat = mutez_to_natural Tezos.amount  in
        let lqt_minted : nat = nat_amount * storage.lqtTotal  / xtzPool in
        let tokens_deposited : nat = ceildiv (nat_amount * storage.tokenPool) xtzPool in

        if tokens_deposited > maxTokensDeposited then
            (failwith error_MAX_TOKENS_DEPOSITED_MUST_BE_GREATER_THAN_OR_EQUAL_TO_TOKENS_DEPOSITED : result)
        else if lqt_minted < minLqtMinted then
            (failwith error_LQT_MINTED_MUST_BE_GREATER_THAN_MIN_LQT_MINTED : result)
        else
            let storage = {storage with
                lqtTotal  = storage.lqtTotal + lqt_minted ;
                tokenPool = storage.tokenPool + tokens_deposited ;
                xtzPool   = storage.xtzPool + Tezos.amount} in

            let history = Big_map.update "tokenPool" (Some storage.tokenPool) storage.history in
            let history = Big_map.update "xtzPool" (Some (mutez_to_natural storage.xtzPool)) history in
            let history = Big_map.update "tokenPool" (Some storage.tokenPool) history in

            let user_investments = Big_map.update Tezos.sender (Some { xtz= Tezos.amount; token=tokens_deposited; direction=ADD}) storage.user_investments in
            let storage = { storage with history = history ; user_investments = user_investments } in

            // send tokens from sender to exchange
            let op_token = token_transfer storage Tezos.sender Tezos.self_address tokens_deposited in
            // mint lqt tokens for them
            let op_lqt = mint_or_burn storage owner (int lqt_minted) in
            ([op_token; op_lqt], storage)

let remove_liquidity (param : remove_liquidity) (storage : storage) : result =
    let { to_ = to_ ;
          lqtBurned = lqtBurned ;
          minXtzWithdrawn = minXtzWithdrawn ;
          minTokensWithdrawn = minTokensWithdrawn ;
          deadline = deadline } = param in

    if storage.selfIsUpdatingTokenPool then
      (failwith error_SELF_IS_UPDATING_TOKEN_POOL_MUST_BE_FALSE : result)
    else if Tezos.now >= deadline then
      (failwith error_THE_CURRENT_TIME_MUST_BE_LESS_THAN_THE_DEADLINE : result)
    else if Tezos.amount > 0mutez then
        (failwith error_AMOUNT_MUST_BE_ZERO : result)
    else begin
        let xtz_withdrawn    : tez = natural_to_mutez ((lqtBurned * (mutez_to_natural storage.xtzPool)) / storage.lqtTotal) in
        let tokens_withdrawn : nat = lqtBurned * storage.tokenPool /  storage.lqtTotal in

        // Check that minimum withdrawal conditions are met
        if xtz_withdrawn < minXtzWithdrawn then
            (failwith error_THE_AMOUNT_OF_XTZ_WITHDRAWN_MUST_BE_GREATER_THAN_OR_EQUAL_TO_MIN_XTZ_WITHDRAWN : result)
        else if tokens_withdrawn < minTokensWithdrawn  then
            (failwith error_THE_AMOUNT_OF_TOKENS_WITHDRAWN_MUST_BE_GREATER_THAN_OR_EQUAL_TO_MIN_TOKENS_WITHDRAWN : result)
        // Proceed to form the operations and update the storage
        else begin
            // calculate lqtTotal, convert int to nat
            let new_lqtTotal = match (is_a_nat ( storage.lqtTotal - lqtBurned)) with
                // This check should be unecessary, the fa12 logic normally takes care of it
                | None -> (failwith error_CANNOT_BURN_MORE_THAN_THE_TOTAL_AMOUNT_OF_LQT : nat)
                | Some n -> n in
            // Calculate tokenPool, convert int to nat
            let new_tokenPool = match is_a_nat (storage.tokenPool - tokens_withdrawn) with
                | None -> (failwith error_TOKEN_POOL_MINUS_TOKENS_WITHDRAWN_IS_NEGATIVE : nat)
                | Some n -> n in

            let op_lqt = mint_or_burn storage Tezos.sender (0 - lqtBurned) in
            let op_token = token_transfer storage Tezos.self_address to_ tokens_withdrawn in
            let op_xtz = xtz_transfer to_ xtz_withdrawn in
            let storage = {storage with xtzPool = storage.xtzPool - xtz_withdrawn ; lqtTotal = new_lqtTotal ; tokenPool = new_tokenPool} in

            let history = Big_map.update "tokenPool" (Some storage.tokenPool) storage.history in
            let history = Big_map.update "xtzPool" (Some (mutez_to_natural storage.xtzPool)) history in
            let user_investments = Big_map.update Tezos.sender (Some {xtz=xtz_withdrawn; token=tokens_withdrawn; direction=REMOVE}) storage.user_investments in
            let storage = { storage with history = history ; user_investments = user_investments } in

            ([op_lqt; op_token; op_xtz], storage)
        end
    end

let update_xtz_volume (xtz_amount : tez) (history : (string, nat) big_map) =
  let current_xtz_volume = match Big_map.find_opt "xtzVolume" history with
    | Some v -> v
    | None -> 0n
  in
  Big_map.update "xtzVolume" (Some (current_xtz_volume + (mutez_to_natural xtz_amount))) history


let xtz_to_token (param : xtz_to_token) (storage : storage) =
   let { to_ = to_ ;
         minTokensBought = minTokensBought ;
         deadline = deadline } = param in

    if storage.selfIsUpdatingTokenPool then
        (failwith error_SELF_IS_UPDATING_TOKEN_POOL_MUST_BE_FALSE : result)
    else if Tezos.now >= deadline then
        (failwith error_THE_CURRENT_TIME_MUST_BE_LESS_THAN_THE_DEADLINE : result)
    else begin
        // we don't check that xtzPool > 0, because that is impossible
        // unless all liquidity has been removed
        let xtzPool = mutez_to_natural storage.xtzPool in
        let nat_amount = mutez_to_natural Tezos.amount in
        let tokens_bought =
            (let bought = (nat_amount * 9972n * storage.tokenPool) / (xtzPool * 10000n + (nat_amount * 9972n)) in
            if bought < minTokensBought then
                (failwith error_TOKENS_BOUGHT_MUST_BE_GREATER_THAN_OR_EQUAL_TO_MIN_TOKENS_BOUGHT : nat)
            else
                bought)
        in
        let reserve_fee = natural_to_mutez (nat_amount * 3n / 10000n) in
        let new_tokenPool = (match is_nat (storage.tokenPool - tokens_bought) with
            | None -> (failwith error_TOKEN_POOL_MINUS_TOKENS_BOUGHT_IS_NEGATIVE : nat)
            | Some difference -> difference) in
        let new_xtzPool = storage.xtzPool + Tezos.amount - reserve_fee in

        // update xtzPool
        let storage = { storage with xtzPool = new_xtzPool ; tokenPool = new_tokenPool } in
        let history = Big_map.update "tokenPool" (Some storage.tokenPool) storage.history in
        let history = Big_map.update "xtzPool" (Some (mutez_to_natural storage.xtzPool)) history in
        let history = Big_map.update "xtzVolume" (Some nat_amount) history in
        let storage = { storage with history = history } in
        // send tokens_withdrawn to to address
        // if tokens_bought is greater than storage.tokenPool, this will fail
        let op = token_transfer storage Tezos.self_address to_ tokens_bought in
        let op_tez_to_reserve = xtz_transfer storage.reserve reserve_fee in

        let ops = if reserve_fee = 0mutez then [ op ] else [ op; op_tez_to_reserve ] in
        (ops, storage)
    end


let token_to_xtz (param : token_to_xtz) (storage : storage) =
    let { to_ = to_ ;
          tokensSold = tokensSold ;
          minXtzBought = minXtzBought ;
          deadline = deadline } = param in

    if storage.selfIsUpdatingTokenPool then
        (failwith error_SELF_IS_UPDATING_TOKEN_POOL_MUST_BE_FALSE : result)
    else if Tezos.now >= deadline then
        (failwith error_THE_CURRENT_TIME_MUST_BE_LESS_THAN_THE_DEADLINE : result)
    else if Tezos.amount > 0mutez then
        (failwith error_AMOUNT_MUST_BE_ZERO : result)
    else
        // we don't check that tokenPool > 0, because that is impossible
        // unless all liquidity has been removed
        let xtz_bought =
            let bought = natural_to_mutez (((tokensSold * 9972n * (mutez_to_natural storage.xtzPool)) / (storage.tokenPool * 10000n + (tokensSold * 9972n)))) in
                if bought < minXtzBought then (failwith error_XTZ_BOUGHT_MUST_BE_GREATER_THAN_OR_EQUAL_TO_MIN_XTZ_BOUGHT : tez) else bought in
        let reserve_fee =
            natural_to_mutez (((tokensSold * 3n * (mutez_to_natural storage.xtzPool)) / (storage.tokenPool * 10000n + (tokensSold * 3n)))) in
        let xtz_volume =
            natural_to_mutez (((tokensSold * (mutez_to_natural storage.xtzPool)) / (storage.tokenPool + tokensSold))) in

        let op_token = token_transfer storage Tezos.sender Tezos.self_address tokensSold in
        let op_tez = xtz_transfer to_ xtz_bought in
        let op_reserve = xtz_transfer storage.reserve reserve_fee in

        let new_tokenPool = storage.tokenPool + tokensSold in
        let new_xtzPool = storage.xtzPool - xtz_bought - reserve_fee in

        let history = Big_map.update "tokenPool" (Some new_tokenPool) storage.history in
        let history = Big_map.update "xtzPool" (Some (mutez_to_natural new_xtzPool)) history in
        let history = Big_map.update "xtzVolume" (Some (mutez_to_natural xtz_volume)) history in
        let storage = {storage with tokenPool = new_tokenPool ;
                                    xtzPool = new_xtzPool ;
                                    history = history } in

        let ops = if reserve_fee = 0mutez then [op_token ; op_tez ] else [op_token ; op_tez ; op_reserve] in
        (ops, storage)

// entrypoint to allow depositing funds
let default_ (storage : storage) : result =
    // update xtzPool
    if (storage.selfIsUpdatingTokenPool) then
        (failwith error_SELF_IS_UPDATING_TOKEN_POOL_MUST_BE_FALSE: result)
    else
        let storage = {storage with xtzPool = storage.xtzPool + Tezos.amount } in
        (([] : operation list), storage)

// set baker
let set_baker (param : set_baker) (storage : storage) : result =
    let { baker = baker ;
          freezeBaker = freezeBaker } = param in
    if storage.selfIsUpdatingTokenPool then
      (failwith error_SELF_IS_UPDATING_TOKEN_POOL_MUST_BE_FALSE : result)
    else if Tezos.amount > 0mutez then
       (failwith error_AMOUNT_MUST_BE_ZERO  : result)
    else if Tezos.sender <> storage.manager then
        (failwith error_ONLY_MANAGER_CAN_SET_BAKER : result)
    else if storage.freezeBaker then
        (failwith error_BAKER_PERMANENTLY_FROZEN : result)
    else
        ([ Tezos.set_delegate baker ], {storage with freezeBaker = freezeBaker})

// set manager
let set_manager (new_manager : address) (storage : storage) : result =
    if storage.selfIsUpdatingTokenPool then
      (failwith error_SELF_IS_UPDATING_TOKEN_POOL_MUST_BE_FALSE : result)
    else if Tezos.amount > 0mutez then
        (failwith error_AMOUNT_MUST_BE_ZERO : result)
    else if Tezos.sender <> storage.manager then
        (failwith error_ONLY_MANAGER_CAN_SET_MANAGER : result)
    else
        (([] : operation list), {storage with manager = new_manager})

// set lqt_address
let set_lqt_address (lqtAddress : address) (storage : storage) : result =
    if storage.selfIsUpdatingTokenPool then
        (failwith error_SELF_IS_UPDATING_TOKEN_POOL_MUST_BE_FALSE : result)
    else if Tezos.amount > 0mutez then
        (failwith error_AMOUNT_MUST_BE_ZERO : result)
    else if Tezos.sender <> storage.manager then
        (failwith error_ONLY_MANAGER_CAN_SET_LQT_ADRESS : result)
    else if storage.lqtAddress <> ("tz1Ke2h7sDdakHJQh8WX4Z372du1KChsksyU" : address) then
        (failwith error_LQT_ADDRESS_ALREADY_SET : result)
    else
        (([] : operation list), {storage with lqtAddress = lqtAddress})


let update_token_pool (storage : storage) : result =
    if Tezos.sender <> Tezos.source then
        (failwith error_CALL_NOT_FROM_AN_IMPLICIT_ACCOUNT : result)
    else if Tezos.amount > 0mutez then
      (failwith error_AMOUNT_MUST_BE_ZERO : result)
    else if storage.selfIsUpdatingTokenPool then
      (failwith error_UNEXPECTED_REENTRANCE_IN_UPDATE_TOKEN_POOL : result)
    else
      let cfmm_update_token_pool_internal : update_token_pool_internal contract = Tezos.self "%updateTokenPoolInternal"  in
#if FA2
      let token_balance_of : balance_of contract = (match
        (Tezos.get_entrypoint_opt "%balance_of" storage.tokenAddress : balance_of contract option) with
        | None -> (failwith error_INVALID_FA2_TOKEN_CONTRACT_MISSING_BALANCE_OF : balance_of contract)
        | Some contract -> contract) in
      let op = Tezos.transaction ([(Tezos.self_address, storage.tokenId)], cfmm_update_token_pool_internal) 0mutez token_balance_of in
#else
      let token_get_balance : get_balance contract = (match
        (Tezos.get_entrypoint_opt "%getBalance" storage.tokenAddress : get_balance contract option) with
        | None -> (failwith error_INVALID_FA12_TOKEN_CONTRACT_MISSING_GETBALANCE : get_balance contract)
        | Some contract -> contract) in
      let op = Tezos.transaction (Tezos.self_address, cfmm_update_token_pool_internal) 0mutez token_get_balance in
#endif
      ([ op ], {storage with selfIsUpdatingTokenPool = true})

let update_token_pool_internal (token_pool : update_token_pool_internal) (storage : storage) : result =
    if (not storage.selfIsUpdatingTokenPool or sender <> storage.tokenAddress) then
      (failwith error_THIS_ENTRYPOINT_MAY_ONLY_BE_CALLED_BY_GETBALANCE_OF_TOKENADDRESS : result)
    else if Tezos.amount > 0mutez then
      (failwith error_AMOUNT_MUST_BE_ZERO : result)
    else
#if FA2
        // we trust the FA2 to provide the expected balance. there are no BFS
        // shenanigans to worry about unless the token contract misbehaves
        let token_pool =
          match token_pool with
          | [] -> (failwith error_INVALID_FA2_BALANCE_RESPONSE : nat)
          | x :: _xs -> x.1 in
#endif
        let storage = {storage with tokenPool = token_pool ; selfIsUpdatingTokenPool = false} in
        (([ ] : operation list), storage)

let token_to_token (param : token_to_token) (storage : storage) : result =
    let { outputDexterContract = outputDexterContract ;
          minTokensBought = minTokensBought ;
          to_ = to_ ;
          tokensSold = tokensSold ;
          deadline = deadline } = param in

    let outputDexterContract_contract: xtz_to_token contract =
        (match (Tezos.get_entrypoint_opt "%xtzToToken" outputDexterContract : xtz_to_token contract option) with
            | None -> (failwith error_INVALID_INTERMEDIATE_CONTRACT :  xtz_to_token contract)
            | Some c -> c) in

    if storage.selfIsUpdatingTokenPool then
      (failwith error_SELF_IS_UPDATING_TOKEN_POOL_MUST_BE_FALSE : result)
    else if Tezos.amount > 0mutez then
      (failwith error_AMOUNT_MUST_BE_ZERO : result)
    else if Tezos.now >= deadline then
      (failwith error_THE_CURRENT_TIME_MUST_BE_LESS_THAN_THE_DEADLINE : result)
    else
        // we don't check that tokenPool > 0, because that is impossible unless all liquidity has been removed
        let xtz_bought =
            natural_to_mutez (((tokensSold * 9972n * (mutez_to_natural storage.xtzPool)) / (storage.tokenPool * 10000n + (tokensSold * 9972n)))) in
        let reserve_fee =
            natural_to_mutez (((tokensSold * 3n * (mutez_to_natural storage.xtzPool)) / (storage.tokenPool * 10000n + (tokensSold * 3n)))) in
        let xtz_volume =
            natural_to_mutez (((tokensSold * (mutez_to_natural storage.xtzPool)) / (storage.tokenPool + tokensSold))) in

        let new_tokenPool = storage.tokenPool + tokensSold in
        let new_xtzPool = storage.xtzPool - xtz_bought - reserve_fee in
        let history = Big_map.update "tokenPool" (Some new_tokenPool) storage.history in
        let history = Big_map.update "xtzPool" (Some (mutez_to_natural new_xtzPool)) history in
        let history = Big_map.update "xtzVolume" (Some (mutez_to_natural xtz_volume)) history in

        let storage = {storage with tokenPool = new_tokenPool ;
                                    xtzPool = new_xtzPool ;
                                    history = history }  in

        let op1 = token_transfer storage Tezos.sender Tezos.self_address tokensSold in
        let op2 =
          Tezos.transaction
            {to_ = to_; minTokensBought = minTokensBought; deadline = deadline}
            xtz_bought
            outputDexterContract_contract in
        let op_reserve = xtz_transfer storage.reserve reserve_fee in
        let ops = if reserve_fee = 0mutez then [op1; op2 ] else [op1; op2; op_reserve] in
        (ops , storage)

[@inline]
let update_reserve (param : update_reserve) (storage : storage) : result =
  if Tezos.sender <> storage.reserve then
    (failwith error_ONLY_RESERVE_CAN_UPDATE_RESERVE : result)
  else
    (([] : operation list), {storage with reserve = param})

// =============================================================================
// Main
// =============================================================================

let main ((entrypoint, storage) : entrypoint * storage) : result =
    match entrypoint with
    | UpdateReserve param ->
        update_reserve param storage
    | AddLiquidity param ->
        add_liquidity param storage
    | RemoveLiquidity param ->
        remove_liquidity param storage
    | SetBaker param ->
        set_baker param storage
    | SetManager param ->
        set_manager param storage
    | SetLqtAddress param ->
        set_lqt_address param storage
    | Default ->
        default_ storage
    | UpdateTokenPool  ->
        update_token_pool storage
    | XtzToToken param ->
        xtz_to_token param storage
    | TokenToXtz param ->
        token_to_xtz param storage
    | TokenToToken param ->
        token_to_token param storage
    | UpdateTokenPoolInternal token_pool ->
        update_token_pool_internal token_pool storage

