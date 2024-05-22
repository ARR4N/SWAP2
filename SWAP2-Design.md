# SWAP2 Design

## Summary

SWAP2 is a protocol for OTC NFT trading using ephemeral, CREATE2-deployed contracts.
Single-use contracts, cryptographically coupled to specific trades, limit `ERC721.setApprovalForAll()` to a least-privileges scope and also automatically expire.
The need for per-trade approvals is a deliberate design trade-off to provide increased security for high-value, low-volume trades.

## Requirements

TODO

## Security: threat model

### General attack vectors

#### Unrevoked approvals

Non-custodial marketplace and OTC-swap contracts can only transfer tokens through approval mechanisms.
For 721 and 1155 tokens, this is typically achieved via `setApprovalForAll()` even though only one or some tokens are to be traded.

Best practice requires the owner to revoke these permissions after the trade, and websites like [revoke.cash](https://revoke.cash) assist in tracking outstanding approvals.
However people either forget to do so or have pending trades from the same collection, requiring ongoing permission.

#### Off-chain signature phishing

Once a contract has been approved to transfer tokens, an extra gating mechanism must be in place to confirm the owner’s intent to trade.
While this can be achieved through an on-chain record, it typically takes the form of an off-chain signature as this doesn’t require any gas to be spent.

Off-chain signatures are, however, easier to phish and harder to trace.
The use of such signatures for other actions (e.g. site login) reduces user vigilance, making them far more likely to sign anything requested by a malicious website—wallets typically don’t warn about these either.
Furthermore, their off-chain nature makes them extremely hard to trace and users may be left with lingering doubts over what they’ve inadvertently signed.

#### Case study

The combination of the two [attack vectors](#general-attack-vectors) are what led to the [theft of over $1M in NFTs from Kevin Rose](https://www.coindesk.com/web3/2023/01/25/kevin-rose-says-nft-wallet-with-dozens-of-high-value-collectibles-hacked/).
The primary author of SWAP2 was on a call with Kevin when this happened and was heavily involved in the investigation.
Having recently listed a Chromie Squiggle for sale, Kevin was vulnerable due to unrevoked approvals, and fell victim to a phishing attack for OpenSea-compatible signatures.

### Mitigation

TODO: contract addresses in lieu of message digests for signing

### SWAP2 attack vectors

TODO: Collisions / second pre-images

#### Proposal

## Terminology

1. **Trade** / **Swap**: the act of exchanging one set of assets for another.

2. **Party**:
   1. **Buyer**: the participant in a Trade (optionally) providing ETH/ERC20 as **Consideration**; or
   2. **Seller**: the counterparty to the Buyer in the Trade.
   * If no ETH/ERC0 is being used as Consideration then either participant can take on either role.

3. **Deal**: particulars / **Schedule** of a proposed or executed Trade, including Parties and assets.
   1. The code has diverged from this specific terminology, encoding a Deal as a `struct <T>Swap`, not a `<T>Deal`, where `<T>` describes the broad asset categories.

5. **Instance**: a specific incarnation of a Deal, coupled to an unambiguous (counterfactual) contract address.
   * More than one Instance may share an identical Deal Schedule; e.g. if one is cancelled and later recreated. Two such Instances differ only in their [CREATE2 salts](https://eips.ethereum.org/EIPS/eip-1014).
   * For the most part, Deal and Instance can therefore be used interchangeably and this is done (even if incorrect) if being explicit would add unnecessary confusion.
   * Code (primarily the tests) generally refer to an instance as `address swapper`.

6. **Deployer** / **Factory**: a contract capable of deploying Instances and predicting their deployed addresses.

7. **Execute** (a Deal):
   1. **Fill**: perform the Trade outlined by the Deal Schedule; or
   2. **Cancel**: permanently void a Deal Instance.

> [!NOTE]
> Execution of a Deal occurs in the constructor of the Instance contract.
> Deployed contracts are minimal artifacts of only a few bytes.

### States

An Instance can be in any of the following states:

1. **Proposed**: an optional pseudo-state in which the Instance address is emitted as a contract event.
2. **Pending**: awaiting at least one (ERC20/721/1155) approval of the Instance address.
3. **Ready**: not awaiting any approvals, but not yet Executed.
4. **Filled**: _as defined in Terminology_.
5. **Cancelled**: _as defined in Terminology_.

> [!IMPORTANT]
> Although the Proposed state is optional, there are [important security benefits](#proposal) that go beyond merely computing the predicted address in a trusted manner.

```mermaid
stateDiagram-v2
direction LR

state Counterfactual {
  pr : Proposed
  p : Pending
  r : Ready
}
state Deployed {
  f : Filled
  c : Cancelled
}

[*] --> p
[*] --> pr
pr --> p: Automatic
p --> r: Final approval
r --> p: Any approval revoked

state e <<choice>>
r --> e: Execute
e --> f: fill()
e --> c: cancel()
f --> [*]
c --> [*]
```

## Sequence diagram

This diagram provides a high-level overview of the entire user experience for all participants, beyond just the smart contracts.
Where possible, standard diagram semantics are used, but some are modified for blockchain-specific behaviour.

* Lines:
  * Solid: the participant initiated an action.
  * Dotted: the participant's action was a consequence of another's (e.g. event logging or return value).
* Heads:
  * Arrow: transaction (i.e. included in the blockchain).
  * X: read-only call (i.e. no change in blockchain state).
* Contract existence:
  * A solid bar over a contract's vertical line indicates an already-deployed contract.
  * The lack of a solid bar:
    * _Before_ deployment indicates a counterfactual (hypothetical) contract with predictable address; and
    * _After_ deployment indicates that the deployed code is a minimal artifact, incapable of performing actions (i.e. all actions are performed in the constructor).

---

```mermaid

sequenceDiagram
autonumber
    actor a as Anyone
    box transparent Trade Contracts
        participant c as Deployer
        participant d as Deal Instance
    end
    activate c

    participant idx as Indexer

    box transparent Parties
        actor b as Buyer
        actor s as Seller
        actor ps as Buyer & Seller
    end

    participant toks as ERC-20,721,1155s in Schedule
    activate toks

    actor fee as Fee recipient(s)
    actor sc as Scammer
    
    alt
        a-xc: Deal Schedule
        Note over c,d: Platform predicts disposable,<br />deal-coupled contract's address.
        c--xa: Instance address
    else Proposal
        a->>c: Deal Schedule
        c-->>idx: log event {Schedule + salt + Instance address}
        Note over c,idx: Optional as can be fulfilled by a centralised<br />database, in which case all other steps read<br />from the database instead of the Indexer.
        Note over c,idx: NOTE: See security benefits of trustless salts<br />in section on State definitions.
        idx-->>a: Instance address
    end

    par
        ps-xidx: Deal including me?
        idx--xps: Schedule + salt + Instance address
        loop Approvals
            ps->>toks: approve(Instance)
        end
    end


    alt Fill
        alt Self-service
            b->>c: Fill (+ETH)
            c-->>d: Deploy (+ETH)
        else Third-party assistance
            opt ETH-only test transaction(s)
                b->>d: ETH
            end
            b->>d: (Remaining) ETH / ERC-20 consideration
            a->>c: Fill
            c-->>d: Deploy
        end

        Note over b,d: In both of the alternate scenarios above, ETH is<br />ultimately transferred from Buyer to Instance,<br />which is deployed at or after the time of transfer(s).

        activate d
        d-->>toks: Perform transfers to fill Trade
        d-->>fee: Fees
        d-->>s: Post-fee ETH/ERC20 balance
        deactivate d

    else Cancel
        b->>c: Cancel
        c-->>d: Deploy
        activate d
        d-->>b: Return ETH
        deactivate d
    end

    break Accidental
        b--xd: Impossible to send (and lock) ETH<br />(ERC-20s can't be blocked)
    end

    break Attempted theft
        sc--xc: No signatures to phish
        c--xd: Re-deployment is impossible
        Note right of c: Implicit reentrancy protection
    end

    %% This is the only way to force Mermaid to show the activation box
    deactivate c
    deactivate toks
```

---

### Notes

1. Third-party assistance is only needed for participants with bare-minimum ability; i.e. sending ETH.
   1. Any participant capable of interacting with a website interface SHOULD use the self-service alternative and send ETH while Executing the Deal.
   2. Test transactions are unnecessary when Executing via the website as the address is never copied/entered manually.
2. Only one of the Parties can actively Cancel otherwise we are open to griefing attacks.
3. Even if redeployment was possible (or the scammer attempted interference before Execution), the Instance address is cryptographically coupled to the Parties in a non-malleable fashion. A scammer can't induce a transfer of assets to themself without inducing a victim to approve an arbitrary address (i.e. the status quo).