// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721Enumerable, ERC721, IERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract VerifiedContributor is ERC721Enumerable, AccessControl {
    bytes32 public constant MINT_ROLE = keccak256("MINT");
    bytes32 public constant BURN_ROLE = keccak256("BURN");

    error NotTransferable();

    constructor(
        string memory name_,
        string memory symbol_,
        address _admin
    ) ERC721(name_, symbol_) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    function supportsInterface(
        bytes4 _interfaceId
    )
        public
        view
        virtual
        override(ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return
            ERC721Enumerable.supportsInterface(_interfaceId) ||
            AccessControl.supportsInterface(_interfaceId);
    }

    /// @notice Mints a token to an address.
    /// @param to The address receiving the token.
    /// @param tokenId The id of the token to be minted.
    function mint(
        address to,
        uint256 tokenId
    ) external virtual onlyRole(MINT_ROLE) {
        _mint(to, tokenId);
    }

    /// @notice Burns a token.
    /// @param tokenId The id of the token to be burned.
    function burn(uint256 tokenId) external virtual onlyRole(BURN_ROLE) {
        _burn(tokenId);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override(ERC721, IERC721) {
        if (from != address(0)) {
            // Not a mint, token is non-transferable
            revert NotTransferable();
        }

        super.transferFrom(from, to, tokenId);
    }
}
