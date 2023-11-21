# ERC-6909 Usability & Security Extensions

This is a proposal for an extension to ERC-6909 intended to address the usability and security issues caused by allowances and operators.

One usability issue is the need to send two separate transactions in order to use a token with a protocol (`approve` followed by a protocol interaction). Another issue is the need to have native token to pay for gas fees, even when there is an actor willing to pay those fees for the user.

The security issue is the overexposure to smart contract risk that comes from using infinite approvals or operators in order to mitigate the prior usability issues. These methods provide unrestricted access to the user's assets for an indefinite amount of time to smart contracts that may later be found to be insecure.

The solution proposed here is a combination of 1) temporary approvals as described in EIP-1153, and 2) permits as described in ERC-2612.

The idea of temporary approvals is that a user grants an allowance to a spender, or sets an operator, only for the duration of a specific function call on a target contract. After the call returns the allowance or operator status is reset.

As an example, this mechanism can be used to execute a token swap by temporarily approving the amount of tokens that may need to be sold and invoking the swap function in the callback. Even if fewer than the max amount of tokens are sold (due to price movement), the allowance is reset to 0 and the user has no exposure to future issues in the smart contracts involved in the swap.

The idea of ERC-20 permits is simply to allow setting a user's allowance as authorized by a signed message. In this proposal, this concept is adapted to the context of ERC-6909 and extended for temporary approve and call with a `temporary` boolean flag and the callback to call.

To deal with both operators and token approvals without a combinatorial explosion of functions, all operations in this extension deal with both simultaneously, with the following semantics.

- `operator = true`, `id = 0`, `amount = 0`: The `spender` is set as an operator for the owner.
- `operator = false`: The `spender` is given allowance `amount` for token `id`.

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
