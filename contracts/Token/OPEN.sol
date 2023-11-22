// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20Votes, ERC20Permit, ERC20, IERC20, IERC20Metadata, IERC20Permit, IVotes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {IERC20MintBurnable} from "./IERC20MintBurnable.sol";

contract OPEN is ERC20Votes, AccessControl, IERC20MintBurnable {
    bytes32 public constant MINT_ROLE = keccak256("MINT");
    uint256 immutable maxSupply;

    error SurpassMaxSupply();

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        address _admin
    ) ERC20(_name, _symbol) ERC20Permit(_name) {
        maxSupply = _maxSupply;
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    /// @inheritdoc AccessControl
    function supportsInterface(
        bytes4 _interfaceId
    ) public view virtual override returns (bool) {
        return
            _interfaceId == type(IERC20).interfaceId ||
            _interfaceId == type(IERC20Metadata).interfaceId ||
            _interfaceId == type(IERC20Permit).interfaceId ||
            _interfaceId == type(IVotes).interfaceId ||
            _interfaceId == type(IERC20MintBurnable).interfaceId ||
            super.supportsInterface(_interfaceId);
    }

    /// @inheritdoc IERC20MintBurnable
    function mint(
        address account,
        uint256 amount
    ) external onlyRole(MINT_ROLE) {
        if (totalSupply() + amount > maxSupply) {
            revert SurpassMaxSupply();
        }

        _mint(account, amount);
    }

    /// @inheritdoc IERC20MintBurnable
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    // https://forum.openzeppelin.com/t/self-delegation-in-erc20votes/17501/12?u=novaknole
    /// @inheritdoc ERC20Votes
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._afterTokenTransfer(from, to, amount);

        // Automatically turn on delegation on mint/transfer but only for the first time.
        if (
            to != address(0) &&
            numCheckpoints(to) == 0 &&
            delegates(to) == address(0)
        ) {
            _delegate(to, to);
        }
    }
}
