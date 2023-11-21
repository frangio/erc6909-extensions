// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../ERC6909X.sol";

contract TestToken is ERC6909X {
  constructor(address initialOwner, uint256 tokenId, uint256 tokenSupply) ERC6909X("TestToken", "1") {
    _mint(initialOwner, tokenId, tokenSupply);
  }
}
