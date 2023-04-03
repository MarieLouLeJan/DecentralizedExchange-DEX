// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "./LPToken.sol";
import "./Library.sol";


/**
@todo 
@dev VOIR TOUTES LES FONCTIONS > https://etherscan.io/address/0x12EDE161c702D1494612d19f05992f43aa6A26FB#writeContract
@dev swapWithExactTarget 
@dev send allowance / approve front end before addLiquidity 
@ >>> how to comfirm how much allowance in front end ? By sending a message as for permit ?
@dev Make a factory
@dev check event in all functions
*/

// NOTES > 


/**
 * @title Decentralized Exchange
 * @author Marie-Lou LE JAN
 * @notice Our dex takes a fee of .4%
 * @notice if he wants to add more he needs to take back his first rewards, add more and update LPTimestamp
 */

contract MySwap is Ownable, LPToken {
    using MyLibrary for uint256;

    uint256 public constant FEE_NUMERATOR = 4;
    uint256 public constant FEE_DENOMINATOR = 1000;

    bool private poolCreated;

    bool private isLocked;

    address public tokenA;
    address public tokenB;

    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public lastBlock;

    uint256 public k;

    uint256 public lastBlockChecked;
    uint256 public lastReserveA;
    uint256 public lastReserveB;

    constructor(
        address _tokenA, 
        address _tokenB
        )
        LPToken('MLPTOKEN', 'MLPT')
        notAddress0(_tokenA)
        notAddress0(_tokenB) 
        {
        tokenA = _tokenA;
        tokenB = _tokenB;
        emit DEXInitialized(_tokenA, _tokenB);
        poolCreated = false;
        isLocked = false;
    }


    /// MODIFIERS

    modifier notAddress0(address _token) {
        require(_token != address(0), "Token can not have address(0)");
        _;
    }
    modifier notAmount0(uint256 _amount){
        require(_amount != 0, "Amount can not be 0");
        _;
    }
    modifier tokenExists(address _token) {
        require(_token == address(tokenA) || _token == address(tokenB), "This token does not exists");
        _;
    }
    modifier lock() {
        require(isLocked == false, 'swap locked');
        isLocked = true;
        _;
        isLocked = false;
    }

    
    /// EVENTS

    event DEXInitialized(
        address tokenA,
        address tokenB
    );
    
    event PoolCreated(
        uint amountA,
        uint amountB
    );
    event LiquidityAdded(
        address provider, 
        uint amountA,
        uint amountB
    );
    event LiquidityRemoved(
        address provider, 
        uint amountA,
        uint amountB
    );
    event Swaped(
        address user,
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut,
        uint256 _amountOut
    );
    event KUpdated(
        uint256 newK
    );


    // UTILS FUNCTIONS

    function setLock(
        bool _isLocked
        ) 
        onlyOwner public 
    {
        isLocked = _isLocked;
    }
    function getReserves() 
        internal view 
        returns(uint256, uint256) 
    {
        return(reserveA, reserveB);
    }
    function getLastBlock()
        internal view 
        returns(uint256) 
    {
        return(lastBlock);
    }
    function getLastReserves() 
        internal view 
        returns(uint256, uint256, uint256) 
    {
        return(lastReserveA, lastReserveB, lastBlockChecked);
    }
    function getK() 
        internal view 
        returns(uint256) 
    {
        return k;
    }
    function getRate(
        uint resIn,
        uint resOut
        ) 
        internal pure 
        returns(uint256 targetAmount) 
    {
        return(resOut / resIn);
    }
    function getTotalVolume() 
        internal
        view
        returns(uint256 totalVolume) 
    {
        if(lastBlockChecked == 0) {
            totalVolume = 0;
        } else {
            uint256 blocksSinceLastCheck = lastBlock - lastBlockChecked;
            totalVolume = ((reserveA - lastReserveA) + (reserveB - lastReserveB)) / blocksSinceLastCheck;
        }
    }


    // CALCULATION & UPDATES FUNCTIONS

    function updateK() 
        internal
    {
        k = reserveA.mul(reserveB);
        emit KUpdated(k);
    }
    function updateReserves() 
        internal 
    {
        lastReserveA = reserveA;
        lastReserveB = reserveB;
        lastBlockChecked = lastBlock;

        reserveA = ERC20(tokenA).balanceOf(address(this));
        reserveB = ERC20(tokenB).balanceOf(address(this));
        lastBlock = block.timestamp;
    }

    /**
     * @notice Calculate how much rewards does a LP will receive
     * 
     * @param shareA tokenA share
     * @param shareB tokenB share
     * @param provider his address
     *
     * @dev 1. Calculate the `duration` over which it has kept his LPtokens 
     * @dev 2. Calculate the `feeFactor` for tokenA & tokenB
     * @dev 3. Multiply the `duration` by the `feeFactor` to get the reward
     * 
     * @return rewardA - Reward tokenA
     * @return rewardB - Reward tokenB
     */
    function calculateReward(
        uint256 shareA,
        uint256 shareB,
        address provider
        )
        internal 
        view
        returns(uint256 rewardA, uint256 rewardB) 
    {
        // 1.
        uint256 duration = block.timestamp - LPTimestamp[provider];
        // 2
        uint256 feeFactorA = shareA.mul(FEE_NUMERATOR / FEE_DENOMINATOR);
        uint256 feeFactorB = shareB.mul(FEE_NUMERATOR / FEE_DENOMINATOR);
        // 3.
        rewardA = duration.mul(feeFactorA);
        rewardB = duration.mul(feeFactorB);
    } 

    function calculateFees(
        uint256 liquidity
        ) 
        view
        internal 
        returns(uint256 providerDueFees)
    {
        uint256 _totalSupply = totalSupply();
        uint256 totalVolume = getTotalVolume();
        uint256 totalFees = totalVolume.mul(FEE_NUMERATOR / FEE_DENOMINATOR);
        providerDueFees =  totalFees.mul(liquidity / _totalSupply);
         
    }

    function calculateLPRatio(
        address provider
        ) 
        internal view
        returns(uint256 lpRatio) 
    {
        uint256 _totalSupply = totalSupply();
        uint256 lpBalance = balanceOf(provider);
        lpRatio = lpBalance / _totalSupply;
    }


    // DEX FUNCTIONS


    /**
     * @notice Create a pool. This function can be call only once.
     *          Once it has been executed, `poolCreated` is set to true
     *          and this function requires that poolCreated is initially false to be runed.
     *          Upon the creation of the DEX, 
     *          we assume that the value of tokenA is equal to the value of tokenB.
     * 
     * @param amountA - uint256 amount of tokenA creater wants to provider 
     * @param amountB - uint256 amount of tokenB creater wants to provider
     * 
     * @dev Requirement amountA & amountB not zero
     * @dev Requirement Only owner - pool creator can call this function
     * @dev 1. Requirement Pool not created yet
     * @dev 2. Requirement AmountA equal to amountB
     * @dev 3. Requirement Provider has enough balance of both tokens
     * @dev 4. Requirement - Transfer success from provider to contract for both tokens
     * @dev 5. Provider mint MLPT as share
     * @dev 6. Emit PoolCreated event
     * @dev 7. Turn poolCreated to true, then the function can't be called again
     */
    function createPool(        
        uint256 amountA,
        uint256 amountB
        )
        notAmount0(amountA)
        notAmount0(amountB)
        onlyOwner
        public
    {
        // 1.
        require(poolCreated == false, "Pool has already been created");
        // 2.
        require(amountA == amountB, "Amounts must be the same");
        // 3.
        require(ERC20(tokenA).balanceOf(msg.sender) >= amountA, "maxAmountA must be <= user balance");
        require(ERC20(tokenB).balanceOf(msg.sender) >= amountB, "maxAmountB must be <= user balance");

        // 4.
        bool successA = ERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        require(successA, "Transfer tokenA fail");
        bool successB = ERC20(tokenB).transferFrom(msg.sender, address(this), amountA);
        require(successB, "Transfer tokenB fail");

        // 5.
        uint256 amountToMint = Math.sqrt(amountA.mul(amountB));
        mint(msg.sender, amountToMint);

        // 6.
        emit PoolCreated(
            amountA, 
            amountB
        );

        // 9.
        poolCreated = true;
    }


    /**
     * @notice - A provider add liquidity to pool - public function
     * 
     * @param maxAmountA - maxi amount tokenA that the provider is willing to inject
     * @param maxAmountB - maxi amount tokenB that the provider is willing to inject
     * 
     * @dev Requirement amountA & amountB not zero
     * @dev 1. Get the correct amounts according to the rate
     * @dev 2. Requirement - Provider must have enough balances
     * @dev 3. Requirement - Transfer success from provider to contract for both tokens
     * @dev 4. Provider mint mySwap LP Token as share
     * @dev 6. Emit LiquidityAdded event 
     */

    function addLiquidity(
        uint256 maxAmountA,
        uint256 maxAmountB
        )    
        notAmount0(maxAmountA)
        notAmount0(maxAmountB)
        lock
        public
    {
        uint rate;
        uint amountA;
        uint amountB;

        address provider = msg.sender;

        // 1.
        rate = getRate(reserveB, reserveA);
        amountA = rate.mul(maxAmountA); 
        amountB = maxAmountB;
        bool isOk = maxAmountA >= amountA;

        if(!isOk) {
            rate = getRate(reserveA, reserveB);
            amountB = rate.mul(maxAmountB);
            amountA = maxAmountA;
        }

        if(balanceOf(provider) > 0) {
            transferOnlyReward(provider);
        }
    
        // 2.
        require(ERC20(tokenA).balanceOf(provider) >= amountA, "TokenA balance too low");
        require(ERC20(tokenB).balanceOf(provider) >= amountB, "TokenB balance too low");

        // 3.
        bool successA = ERC20(tokenA).transferFrom(provider, address(this), amountA);
        require(successA, "Transfer tokenB fail");
        bool successB = ERC20(tokenB).transferFrom(provider, address(this), amountA);
        require(successB, "Transfer tokenB fail");


        // 4.
        uint256 amountToMint = Math.min(amountA.mul(totalSupply()) / reserveA, amountB.mul(totalSupply()) / reserveB);
        mint(provider, amountToMint);
        
        // 5.
        updateReserves();
        updateK();

        // 6.
        emit LiquidityAdded(
            provider, 
            amountA,
            amountB
        );
    }


    /**
     * @notice This function is triggered whenever a liquidity provider (LP)
     *         either sells their LP token or adds new liquidity to the pool.
     *         In the latter case, the LP receives their rewards and begins 
     *         accumulating them again according to the new timestamps.
     *         In the last case, he get back his rewards and start culumating again
     *         Note that there is no need to update the reserves or the K value
     *         since the _afterTokenTransfer function will be automatically called in either case.

     * @param provider address
     * 
     * @dev 1. Calculate his ratio, shares and reward
     * @dev 2. Requirement - success for both reward transfers 
     * 
     * @return success bool
     */
    function transferOnlyReward(
        address provider
        ) 
        internal 
        returns(bool success) 
    {
        // (uint256 resA, uint256 resB) = getReserves();
        uint256 lpRatio = calculateLPRatio(provider);
        uint256 shareA = lpRatio.mul(reserveA);
        uint256 shareB = lpRatio.mul(reserveB);
        (uint256 rewardA, uint256 rewardB) = calculateReward(shareA, shareB, provider);

        bool successA = ERC20(tokenA).transfer(provider, rewardA);
        require(successA, "Transfer rewards tokenB fail");

        bool successB = ERC20(tokenB).transfer(provider, rewardB);
        require(successB, "Transfer rewards tokenB fail");

        success = true;
    }



    /**
     * @notice Swap with exact supply amount
     * 
     * @param path The trading path of the swap transaction
     * @param supplyAmount The exact supply amount.
     * @param minTargetAmount The acceptable minimum target amount
     * 
     * @dev 1. Requirement - Both token address have to be managed by this dex
     * @dev 2. Determine the path of the swap
     * @dev 3. Caculate total amount out according to rate and fee
     * @dev 4. Requirement - `amountOut` calculated must be greater or equal than `minTargetAmount`
     * @dev 5. Make sure that DEX has enough balance
     * @dev 6. Requirement - Both transfers must succeed
     * @dev 7. Update reserve (not `k` as total amount of reserve doesn't change after a swap)
     * @dev 8. Emit a `Swaped` event
     */ 

    function swap(
        address[2] calldata path,
        uint256 supplyAmount,
        uint256 minTargetAmount
        ) 
        public
        lock
    {
        //1.
        for(uint i = 0; i < path.length; i++) {
            require((path[i] == tokenA) || (path[i] ==  tokenB), "This token does not exists in this DEX");
        }
        
        // 2.
        bool isTokenA = path[0] == tokenA;
        (ERC20 tokenIn, ERC20 tokenOut, uint resIn, uint resOut) = isTokenA
            ? (ERC20(tokenA), ERC20(tokenB), reserveA, reserveB)
            : (ERC20(tokenB), ERC20(tokenA), reserveB, reserveA);

        // Function _transfer takes care of it
        // require(tokenIn.balanceOf(msg.sender) >= supplyAmount, "Supply amount must be <= user balance");

        // 3.
        uint rate = getRate(resOut, resIn);
        uint256 amountOutBeforeFees =  rate.mul(supplyAmount);
        uint256 fees = amountOutBeforeFees.mul(FEE_NUMERATOR / FEE_DENOMINATOR);
        uint amountOut = amountOutBeforeFees + fees;

        // 4.
        require(amountOut >= minTargetAmount, "Insufficient output amount");

        // 5.
        require(tokenIn.balanceOf(address(this)) >= supplyAmount, "DEX doesn't have enough tokens");

        // 6.
        bool successIn = tokenIn.transferFrom(msg.sender, address(this), supplyAmount);
        require(successIn, "Transfer supply failed");
        bool successOut = tokenOut.transfer(msg.sender, amountOut);
        require(successOut, "Transfer out failed");

        // 7.
        updateReserves();

        // 8.
        emit Swaped(
            msg.sender,
            address(tokenIn),
            supplyAmount,
            address(tokenOut),
            amountOut
        );
    }


    /**
     * @notice LP remove liquidity from DEX
     * 
     * @param liquidity - Amount LPToken want to get back
     * @param amountAMin - The acceptable minimum tokenA amount
     * @param amountBMin - The acceptable minimum tokenB amount
     * @param provider - address of LP
     * 
     * @dev Requirement - LP's address can't be address zero
     * @dev 1. Requirement - Provider must be `msg.sender`
     * @dev 2. Requirement - Provider's balance must be greater or equal then liquidity
     * @dev 3. Calculate his shares and rewards
     * @dev 4. Requirement - Amounts to send back must be greater or equal than minimum amounts
     * @dev 5. Transfer his LPtoken to DEX contract's address
     * @dev 6. Requirement - Transfer amounts tokenA & tokenB to LP's address has to succeed
     * @dev 7. Burn LPTokens
     * @dev 8. Emit a `LiquidityRemoved` event
     */
    function removeLiquidity(
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address provider
        ) 
        public 
        notAddress0(provider)
        lock
    {
        // 1.
        require(provider == msg.sender, "Only msg.sender can claim his liquidity");

        // 2.
        require(balanceOf(provider) >= liquidity, "amount provided must be equal or lower than provider's balance");
        
        // 3.
        uint256 shareA = calculateLPRatio(provider).mul(reserveA);
        uint256 shareB = calculateLPRatio(provider).mul(reserveB);
        (uint256 rewardA, uint256 rewardB) = calculateReward(shareA, shareB, provider);
        uint256 amountA = shareA + rewardA;
        uint256 amountB = shareB + rewardB;

        // 4.
        require(amountA >= amountAMin, 'AmountA is less than amountAMin');
        require(amountB >= amountBMin, 'AmountB is less than amountAMin');

        // 5.
        transferFrom(provider, address(this), liquidity);

        // 6.
        bool successA = ERC20(tokenA).transfer(provider, amountA);
        require(successA, "Transfer tokenA failed");
        bool successB = ERC20(tokenB).transfer(provider, amountB);
        require(successB, "Transfer tokenB failed");

        // 7.
        burn(provider);

        // 8.
        emit LiquidityRemoved(
            provider, 
            amountA, 
            amountB
        );
    }

    /**
     * @notice transfer function for LPTokens
     * 
     * @param to buyer address
     * @param amount amount being sold
     * 
     * @dev 1. Requirement - owner (LP seller) has enough balance
     * @dev 2. LP seller get back rewards he cumulated
     * @dev 3. Call _transfer function
     * 
     * @return bool
     */
    function transfer(
        address to, 
        uint256 amount
        ) 
        public override 
        returns(bool) 
    {
        address owner = _msgSender();
        // 1.
        require(balanceOf(owner) >= amount, "Balance lower than amount");
        // 2.
        transferOnlyReward(owner);
        // 3.
        _transfer(owner, to, amount);
        return true;
    }


    /**
     * @notice Function called after each transfer, burn and mint of LPtoken
     * 
     * @dev 1. Update `LPTimestamp`
     * @dev 2. Update `reserves`
     * @dev 3. Update `k`
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amountLPToken
        ) 
        internal 
        override
    { 
        // 1.
        LPTimestamp[from] = 0;
        LPTimestamp[to] = block.timestamp;
        // 2.
        updateReserves();
        // 3.
        updateK();
        delete amountLPToken;
    }

}