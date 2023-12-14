# ERC-6909 Usability & Security Extensions

This is a proposal for an extension to ERC-6909 intended to address the usability and security issues caused by allowances and operators.

The first usability issue is the need to send two separate transactions in order to use a token with a protocol, given that any such use requires a prior `approve`. The second issue is the need to have native token to pay for gas fees, even if there is an actor willing to pay for the user.

The security issues arise from the way applications mitigate the above usability issues, by resorting to infinite approvals and operators. These methods result in overexposure to smart contract risk, since they allow unrestricted access to the user's assets for an indefinite amount of time to smart contracts that may later be found insecure.

The solution proposed here is a combination of 1) temporary approvals as described in EIP-1153, and 2) permits as described in ERC-2612.

The idea of temporary approvals is that a user grants an allowance to a spender, or sets an operator, only for the duration of a specific function call on a target contract. After the call returns, the allowance or operator status is reset. This extension proposes a function `temporaryApproveAndCall` implementing this functionality.

As an example, this mechanism can be used to execute a token swap by temporarily approving the amount of tokens that may need to be sold and invoking the swap function as the call. Even if fewer than the max amount of tokens are sold (due to price movement), the allowance is reset to 0 and the user has no exposure to future issues in the smart contracts involved in the swap.

The idea of ERC-20 permits is simply to provide an alternative to `approve` that is authorized by a signed message instead of a transaction coming directly from the user; this signed message can be submitted by a third party. In this proposal, this concept is adapted to the multi-token context of ERC-6909, and is split into two functions: 1) `approveBySig`, a function directly analogous to ERC-20 `permit`, and 2) `temporaryApproveAndCallBySig`, exactly analogous to `temporaryApproveAndCall` but authorized by signature. The signed message includes a `temporary` boolean flag to make the signer aware of the effects; if this flag is true the message also includes the exact call that will be made (as specified by `target` and `data`).

To deal with both operators and token approvals without too many functions, all operations in this extension deal with both simultaneously with parameters `operator`, `id`, and `amount` with the following semantics:

- `operator = false`: The `spender` is given allowance for one token as specified by `amount` and `id`.
- `operator = true`: The `spender` is set as an operator for the owner. `amount` and `id` must be 0 and are otherwise ignored.

```solidity
interface IERC6909X is IERC5267 {
    function temporaryApproveAndCall(
        address spender,
        bool operator,
        uint256 id,
        uint256 amount,
        address target,
        bytes calldata data
    ) external returns (bool);

    function temporaryApproveAndCallBySig(
        address owner,
        address spender,
        bool operator,
        uint256 id,
        uint256 amount,
        address target,
        bytes calldata data,
        uint256 deadline,
        bytes calldata signature
    ) external returns (bool);

    function approveBySig(
        address owner,
        address spender,
        bool operator,
        uint256 id,
        uint256 amount,
        uint256 deadline,
        bytes calldata signature
    ) external returns (bool);
}

interface IERC6909XCallback {
    function onTemporaryApprove(
        address owner,
        bool operator,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external returns (bytes4);
}

/// EIP-712 struct type
struct ERC6909XApproveAndCall {
    bool temporary;
    address owner;
    address spender;
    bool operator;
    uint256 id;
    uint256 amount;
    address target;
    bytes data;
    uint256 nonce;
    uint256 deadline;
}
```
