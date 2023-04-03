// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract Token is ERC20Capped, ERC20Burnable {

    address payable public owner;

    constructor(
        string memory _name, 
        string memory _symbol,
        uint256 _initialSupply, 
        uint256 _cap
    ) 
    ERC20(_name, _symbol) 
    ERC20Capped(_cap * (10 ** decimals()))
    {
        owner = payable( msg.sender);
        _mint(owner, _initialSupply * (10 ** decimals()));
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }


    function _beforeTokenTransfer(address from, address to, uint256 value) internal virtual override {
        super._beforeTokenTransfer(from, to, value);
    }
    

    function _mint(address account, uint256 amount) internal virtual override(ERC20Capped, ERC20) {
        require(ERC20.totalSupply() + amount <= cap(), "ERC20Capped: cap exceeded");
        super._mint(account, amount);
    }
    
    // function destroy() public onlyOwner {
    //     selfdestruct(owner);
    // }

}