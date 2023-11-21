// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC6909, IERC6909XCallback} from "../ERC6909X.sol";

contract TestCallback is IERC6909XCallback {
    ERC6909 internal token;

    constructor(ERC6909 _token) {
        token = _token;
    }

    function onTemporaryApprove(
        address owner,
        bool operator,
        uint256 id,
        uint256,
        bytes calldata data
    ) external override returns (bytes4) {
        require(msg.sender == address(token));
        require(!operator);
        (address receiver, uint256 amount) = abi.decode(data, (address, uint256));
        token.transferFrom(owner, receiver, id, amount);
        return this.onTemporaryApprove.selector;
    }
}
