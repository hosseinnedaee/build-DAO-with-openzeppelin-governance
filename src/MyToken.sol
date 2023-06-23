// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "openzeppelin/access/Ownable.sol";

contract MyToken is ERC20, ERC20Permit, ERC20Votes, Ownable {
    constructor() ERC20("MyToken", "MTK") ERC20Permit("MyToken") {}

    function mint(address to, uint256 amount) public payable {
        require(msg.value >= amount, "not enough ether");
        _mint(to, amount);
    }

    function withdraw(address to, uint256 amount) public onlyOwner() {
        require(amount <= address(this).balance, "more than balance");
        (bool success, ) = to.call{value: amount}("");
        require(success, "withdraw failed");
    }

    // The functions below are overrides required by Solidity.

    function _afterTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }
}