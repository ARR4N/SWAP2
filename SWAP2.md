## Terminology

1. **Trade**: the act of exchanging one set of assets for another.

2. **Party**:
   1. **Buyer**: the participant in a Trade (optionally) providing ETH as consideration; or
   2. **Seller**: the counterparty to the Buyer in the Trade.
   * If no ETH is being used as consideration then either participant can take on either role.

3. **Deal**: particulars / Schedule of a proposed or executed Trade, including Parties and assets.

4. **Instance**: a specific incarnation of a Deal, coupled to an unambiguous (counterfactual) contract address.
   * More than one Instance may share an identical Deal Schedule; e.g. if one is cancelled and later recreated. Two such Instances differ only in a nonce value.
   * For the most part, Deal and Instance can therefore be used interchangeably and this is done (even if incorrect) if being explicit would add unnecessary confusion.

5. **Execute** (a Deal):
   1. **Fill**: perform the Trade outlined by the Deal Schedule; or
   2. **Cancel**: permanently void a Deal Instance.
   

## Sequence diagram

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
    actor a as Anyone
    box transparent Trade Contracts
        participant c as Platform
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
    else Announcement
        a->>c: Deal Schedule
        c-->>idx: log event {Schedule + Instance address}
        Note over c,idx: Optional as can be fulfilled by a centralised<br />database, in which case all other steps read<br />from the database instead of the Indexer.
        idx-->>a: Instance address
    end

    par
        ps-xidx: Deal including me?
        idx--xps: Schedule + Instance address
        loop Approvals
            ps->>toks: approve(Instance)
        end
    end


    alt Fill
        alt Self-service
            b->>c: Fill (+ETH)
            c-->>d: Deploy (+ETH)
        else Third-party assistance
            opt Test transaction(s)
                b->>d: ETH / ERC-20
            end
            b->>d: (Remaining) ETH / ERC-20 consideration
            a->>c: Fill
            c-->>d: Deploy
        end

        Note over b,d: In both of the alternate scenarios above,<br />ETH is transferred from Buyer to Instance,<br />which is itself deployed.

        activate d
        d-->>toks: Perform transfers to fill Trade
        d-->>fee: Fees
        d-->>s: Post-fee ETH balance
        deactivate d

    else Cancel
        b->>c: Cancel
        c-->>d: Deploy
        activate d
        d-->>b: Return ETH (&PlusMinus; pre-paid ERC20s)
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

1. Third-party assistance is only needed for participants with bare-minimum ability; i.e. sending ETH and ERC-20s.
   1. Any participant capable of interacting with a website interface SHOULD use the self-service alternative and send ETH while Executing the Deal.
   2. Test transactions are unnecessary when Executing via the website as the address is never copied/entered manually.
2. Only the Buyer can actively Cancel otherwise we are open to griefing attacks. The Seller can still void an Instance by revoking at least one approval, in which case the deployment will revert.
3. Even if redeployment was possible (or the scammer attempted interference before Execution), the Instance address is cryptographically coupled to the Parties in a non-malleable fashion. A scammer can't induce a transfer of assets to themself without inducing a victim to approve an arbitrary address (i.e. the status quo).
