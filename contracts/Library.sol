// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

library MyLibrary {

    function mul(
        uint256 x, 
        uint256 y) 
        pure internal 
        returns(uint z) 
    {
        require(y == 0 || (z = x * y) / y == x);
    }
    
}