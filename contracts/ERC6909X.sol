// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ERC6909.sol";
import "@openzeppelin/contracts/interfaces/IERC5267.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

bytes32 constant APPROVE_AND_CALL_TYPE_HASH = keccak256("ERC6909XApproveAndCall(bool temporary,address owner,address spender,bool operator,uint256 id,uint256 amount,address target,bytes data,uint256 nonce,uint256 deadline)");

interface IERC6909X is IERC5267 {
    function temporaryApproveAndCall(address spender, bool operator, uint256 id, uint256 amount, address target, bytes calldata data) external returns (bool);

    function temporaryApproveAndCallBySig(address owner, address spender, bool operator, uint256 id, uint256 amount, address target, bytes calldata data, uint256 deadline, bytes calldata signature) external returns (bool);

    function approveBySig(address owner, address spender, bool operator, uint256 id, uint256 amount, uint256 deadline, bytes calldata signature) external returns (bool);
}

interface IERC6909XCallback {
    function onTemporaryApprove(address owner, bool operator, uint256 id, uint256 amount, bytes calldata data) external returns (bytes4);
}

contract ERC6909X is ERC6909, IERC6909X, EIP712 {
    mapping (address owner => uint256) public nonces;

    constructor(string memory domainName, string memory domainVersion) EIP712(domainName, domainVersion) {}

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool supported) {
        return super.supportsInterface(interfaceId) || interfaceId == type(IERC6909X).interfaceId;
    }

    function temporaryApproveAndCall(address spender, bool operator, uint256 id, uint256 amount, address target, bytes memory data) external returns (bool) {
        _temporaryApproveAndCall(msg.sender, spender, operator, id, amount, target, data);
        return true;
    }

    function temporaryApproveAndCallBySig(address owner, address spender, bool operator, uint256 id, uint256 amount, address target, bytes memory data, uint256 deadline, bytes memory signature) external returns (bool) {
        uint256 nonce = nonces[owner]++;
        _validateApproveAndCallSignature(/* temporary = */ true, owner, spender, operator, id, amount, target, data, nonce, deadline, signature);
        _temporaryApproveAndCall(owner, spender, operator, id, amount, target, data);
        return true;
    }

    function approveBySig(address owner, address spender, bool operator, uint256 id, uint256 amount, uint256 deadline, bytes memory signature) external returns (bool) {
        uint256 nonce = nonces[owner]++;
        _validateApproveAndCallSignature(/* temporary = */ false, owner, spender, operator, id, amount, address(0), "", nonce, deadline, signature);
        _setSpenderAccess(owner, spender, operator, id, amount);
        return true;
    }

    function _temporaryApproveAndCall(address owner, address spender, bool operator, uint256 id, uint256 amount, address target, bytes memory data) internal {
        (bool prevIsOperator, uint256 prevAllowance) = _setSpenderAccess(owner, spender, operator, id, amount);

        bytes4 ack = IERC6909XCallback(target).onTemporaryApprove(owner, operator, id, amount, data);
        require(ack == IERC6909XCallback.onTemporaryApprove.selector, "invalid ack");

        if (operator) {
            isOperator[owner][spender] = prevIsOperator;
        } else {
            allowance[owner][spender][id] = prevAllowance;
        }
    }

    function _setSpenderAccess(address owner, address spender, bool operator, uint256 id, uint256 amount) internal returns (bool prevIsOperator, uint256 prevAllowance) {
        if (operator) {
            require(id == 0 && amount == 0, "invalid params");
            prevIsOperator = isOperator[owner][spender];
            isOperator[owner][spender] = true;
        } else {
            prevAllowance = allowance[owner][spender][id];
            allowance[owner][spender][id] = amount;
        }
    }

    function _validateApproveAndCallSignature(bool temporary, address owner, address spender, bool operator, uint256 id, uint256 amount, address target, bytes memory data, uint256 nonce, uint256 deadline, bytes memory signature) internal view {
        bytes32 messageHash = _hashApproveAndCallMessage(temporary, owner, spender, operator, id, amount, target, data, nonce, deadline);
        require(SignatureChecker.isValidSignatureNow(owner, messageHash, signature), "invalid sig");
    }

    function _hashApproveAndCallMessage(bool temporary, address owner, address spender, bool operator, uint256 id, uint256 amount, address target, bytes memory data, uint256 nonce, uint256 deadline) internal view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(
            APPROVE_AND_CALL_TYPE_HASH,
            temporary,
            owner,
            spender,
            operator,
            id,
            amount,
            target,
            keccak256(data),
            nonce,
            deadline
        )));
    }
}
