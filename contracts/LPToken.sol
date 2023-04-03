// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "./Library.sol";

contract LPToken is ERC20Permit, ERC20Burnable {
    using MyLibrary for uint256;
    
    address public tokenOwner;
    mapping(address => uint256) LPTimestamp;

    event LpTokenMinted(
        address provider,
        uint256 amountMinted
    );
    event LpTokenBurned(
        address provider,
        uint256 amountBurned
    );

    constructor(
        string memory _name, 
        string memory _symbol
    ) 
    ERC20(_name, _symbol) 
    ERC20Permit(_name)
    {
        tokenOwner = payable( msg.sender);
    }


    /// ERC20 FUNCTIONS
    
    /**
     * @notice Mint MSLP as share for providers - internal function
     * 
     * @param _to - provider's address
     * @param _amount - amount to be minted
     * 
     * @dev 1. Calculate amountToMint
     * @dev 2. Requirement - amount to mint greater than zero
     * @dev 3. Mint amount to provider
     * @dev 4. Emit MSLPMinted event
     * 
     * @return success bool
     */
    function mint(
        address _to, 
        uint256 _amount
        ) 
        internal
        returns(bool success)
    {

        // 2.
        require(_amount > 0, "Amount to mint is zero");

        // 3.
        _mint(_to, _amount);
        
        //4.
        emit LpTokenMinted(
            msg.sender,
            _amount
        );

        success = true;
    }

    function burn(
        address _provider
        )
        internal
        returns(bool success)
    {
        uint256 amountToBurn = balanceOf(address(this));
        _burn(address(this), amountToBurn);
        emit LpTokenBurned(_provider, amountToBurn);

        success = true;
    }

}