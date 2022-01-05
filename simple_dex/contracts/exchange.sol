

// =================== CS251 DEX Project =================== // 
//        @authors: Simon Tao '22, Mathew Hogan '22          //
// ========================================================= //    
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '../interfaces/erc20_interface.sol';
import '../libraries/safe_math.sol';
import './giao.sol';

contract TokenExchange {
    using SafeMath for uint;
    address public admin;

    address tokenAddr = 0xa9FdD8409171Cb99Dd4007F8498627f2476D1B29;// TODO: Paste token contract address here.
    GiaoToken private token = GiaoToken(tokenAddr);         // TODO: Replace "Token" with your token class.             

    // Liquidity pool for the exchange
    uint public token_reserves = 0;
    uint public eth_reserves = 0;

    // Multiplier for Precision
    uint constant _multiplier = 100000;

    // Constant: x * y = k
    uint public k;

    //mapping for LPs
    mapping(address=>uint256) LP;
    uint256 public total_LP = 0;
    
    // liquidity rewards
    uint private swap_fee_numerator = 997;       // TODO Part 5: Set liquidity providers' returns.
    uint private swap_fee_denominator = 1000;
    
    event AddLiquidity(address from, uint amount);
    event RemoveLiquidity(address to, uint amount);
    event Received(address from, uint amountETH);

    constructor() 
    {
        admin = msg.sender;
    }
    
    modifier AdminOnly {
        require(msg.sender == admin, "Only admin can use this function!");
        _;
    }

    // Used for receiving ETH
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
    fallback() external payable{}

    // Function createPool: Initializes a liquidity pool between your Token and ETH.
    // ETH will be sent to pool in this transaction as msg.value
    // amountTokens specifies the amount of tokens to transfer from the liquidity provider.
    // Sets up the initial exchange rate for the pool by setting amount of token and amount of ETH.
    function createPool(uint amountTokens)
        external
        payable
        AdminOnly
    {
        // require pool does not yet exist
        require (token_reserves == 0, "Token reserves was not 0");
        require (eth_reserves == 0, "ETH reserves was not 0.");

        // require nonzero values were sent
        require (msg.value > 0, "Need ETH to create pool.");
        require (amountTokens > 0, "Need tokens to create pool.");

        token.transferFrom(msg.sender, address(this), amountTokens);
        eth_reserves = msg.value;
        token_reserves = amountTokens;
        k = eth_reserves.mul(token_reserves);

        // TODO: Keep track of the initial liquidity added so the initial provider
        //          can remove this liquidity

        total_LP = total_LP.add(eth_reserves.mul(2));
        LP[msg.sender] = total_LP;
        emit AddLiquidity(msg.sender, msg.value.mul(2));
    }

    // ============================================================
    //                    FUNCTIONS TO IMPLEMENT
    // ============================================================
    /* Be sure to use the SafeMath library for all operations! */
    
    // Function priceToken: Calculate the price of your token in ETH.
    // You can change the inputs, or the scope of your function, as needed.
    function priceToken() 
        public 
        view
        returns (uint)
    {
        return _multiplier.mul(eth_reserves).div(token_reserves);
    }

    // Function priceETH: Calculate the price of ETH for your token.
    // You can change the inputs, or the scope of your function, as needed.
    function priceETH()
        public
        view
        returns (uint)
    {
        return _multiplier.mul(token_reserves).div(eth_reserves);
    }


    /* ========================= Liquidity Provider Functions =========================  */ 

    // Function addLiquidity: Adds liquidity given a supply of ETH (sent to the contract as msg.value)
    // You can change the inputs, or the scope of your function, as needed.
    function addLiquidity(uint max_exchange_rate, uint min_exchange_rate) 
        external 
        payable
    {
        /******* TODO: Implement this function *******/
        /* HINTS:
            Calculate the liquidity to be added based on what was sent in and the prices.
            If the caller possesses insufficient tokens to equal the ETH sent, then transaction must fail.
            Update token_reserves, eth_reserves, and k.
            Emit AddLiquidity event.
        */
        uint256 tokenAmt = msg.value.mul(priceETH()).div(_multiplier);
        //calculate the amount of token we can add based on slippage.
        uint min_token = max_exchange_rate.mul(msg.value).div(_multiplier);
        uint max_token = min_exchange_rate.mul(msg.value).div(_multiplier);
        require(tokenAmt >= min_token && tokenAmt <= max_token, "HIGH SLIPPAGE");
        //taking in TOKEN into contract
        token.transferFrom(msg.sender, address(this), tokenAmt);
        //distribute new LP tokens: based on portion of total LP value.
        uint256 new_LP = total_LP.mul(msg.value).div(eth_reserves); // calculate the amount of new LP.
        LP[msg.sender] = LP[msg.sender].add(new_LP); // add new LP to mapping.
        total_LP = total_LP.add(new_LP); //add new LP to total LP supply.

        eth_reserves = eth_reserves.add(msg.value);
        token_reserves = token_reserves.add(tokenAmt);
        k = eth_reserves.mul(token_reserves);

        emit AddLiquidity(msg.sender, msg.value.mul(2) );
    }


    // Function removeLiquidity: Removes liquidity given the desired amount of ETH to remove.
    // You can change the inputs, or the scope of your function, as needed.
    function removeLiquidity(uint amountETH, uint max_exchange_rate, uint min_exchange_rate)
        public 
        payable
    {
        /******* TODO: Implement this function *******/
        /* HINTS:
            Calculate the amount of your tokens that should be also removed.
            Transfer the ETH and Token to the provider.
            Update token_reserves, eth_reserves, and k.
            Emit RemoveLiquidity event.
        */
        // check if the address has enough LP tokens.
        uint256 withdrawn_LP = total_LP.mul(amountETH).div(eth_reserves);
        require(LP[msg.sender] >= withdrawn_LP, "INSU_LP");
        // number of token to be withdrawn
        uint256 numTokens = amountETH.mul(token_reserves).div(eth_reserves);
        // check slippage
        uint min_token = max_exchange_rate.mul(amountETH).div(_multiplier);
        uint max_token = min_exchange_rate.mul(amountETH).div(_multiplier);
        require(numTokens >= min_token && numTokens <= max_token, "HIGH SLIPPAGE");

        //burn LP tokens and remove LP token from supply.
        LP[msg.sender] = LP[msg.sender].sub(withdrawn_LP);
        total_LP = total_LP.sub(withdrawn_LP);
        
        //update new reserve balances
        eth_reserves = eth_reserves.sub(amountETH);
        token_reserves = token_reserves.sub(numTokens);
        k = eth_reserves.mul(token_reserves);

        //move token into user address
        token.transfer(msg.sender, numTokens);

        //move ETH into user address
        payable(msg.sender).transfer(amountETH);

        emit RemoveLiquidity(msg.sender, amountETH.mul(2));

    }

    // Function removeAllLiquidity: Removes all liquidity that msg.sender is entitled to withdraw
    // You can change the inputs, or the scope of your function, as needed.
    function removeAllLiquidity(uint max_exchange_rate, uint min_exchange_rate)
        external
        payable
    {
        /******* TODO: Implement this function *******/
        /* HINTS:
            Decide on the maximum allowable ETH that msg.sender can remove.
            Call removeLiquidity().
        */
        //check if LP is bigger than 0
        require(LP[msg.sender] > 0, "INSU_LP");
        uint256 numTokens = LP[msg.sender].mul(token_reserves).div(total_LP);
        uint256 numETH = LP[msg.sender].mul(eth_reserves).div(total_LP);

        // check slippage
        uint min_token = max_exchange_rate.mul(numETH).div(_multiplier);
        uint max_token = min_exchange_rate.mul(numETH).div(_multiplier);
        require(numTokens >= min_token && numTokens <= max_token, "SLIPPAGE HIGH");


        //burn LP tokens and remove LP token from supply.
        total_LP = total_LP.sub(LP[msg.sender]);
        LP[msg.sender] = 0;
        
        //update new reserve balances
        eth_reserves = eth_reserves.sub(numETH);
        token_reserves = token_reserves.sub(numTokens);
        k = eth_reserves.mul(token_reserves);

        //move token into user address
        token.transfer(msg.sender, numTokens);

        //move ETH into user address
        payable(msg.sender).transfer(numETH);

        emit RemoveLiquidity(msg.sender, numETH.mul(2));
    }

    /***  Define helper functions for liquidity management here as needed: ***/



    /* ========================= Swap Functions =========================  */ 

    // Function swapTokensForETH: Swaps your token with ETH
    // You can change the inputs, or the scope of your function, as needed.
    function swapTokensForETH(uint amountTokens, uint max_exchange_rate)
        external 
        payable
    {
        require(amountTokens > 0,"Token Amount must >0"); // cannot swap 0 value.
        require(token.balanceOf(msg.sender)>=amountTokens, "INSU_TOKEN"); //check if the user has enough token
        require(token.allowance(msg.sender, address(this)) >= amountTokens, "NOT APPROVED"); // check if the exchange has allowance to spend the token

        //Liquidity Reward.
        amountTokens = amountTokens.mul(swap_fee_numerator).div(swap_fee_denominator);

        //calculate how much eth will swapped.
        uint256 delta_eth = eth_reserves.mul(amountTokens).div(token_reserves.add(amountTokens)); // (y * delta_x)/ (x + delta_x)
        // calculate minimum eth in return, based on slippage.
        uint min_eth = amountTokens.mul(max_exchange_rate).div(_multiplier);
        require(min_eth <= delta_eth, "SLIPPAGE High");
        //check if treasury is 0.
        require(eth_reserves>(delta_eth),"ETH_reserve 0"); 
        //move token into pool
        token.transferFrom(msg.sender, address(this), amountTokens);
        //update balances
        eth_reserves = eth_reserves.sub(delta_eth);
        token_reserves = token_reserves.add(amountTokens);
        k = eth_reserves.mul(token_reserves);
        //send eth
        payable(msg.sender).transfer(delta_eth);



        /***************************/
        // DO NOT MODIFY BELOW THIS LINE
        /* Check for x * y == k, assuming x and y are rounded to the nearest integer. */
        // Check for Math.abs(token_reserves * eth_reserves - k) < (token_reserves + eth_reserves + 1));
        //   to account for the small decimal errors during uint division rounding.
        uint check = token_reserves.mul(eth_reserves);
        if (check >= k) {
            check = check.sub(k);
        }
        else {
            check = k.sub(check);
        }
        assert(check < (token_reserves.add(eth_reserves).add(1)));
    }



    // Function swapETHForTokens: Swaps ETH for your tokens.
    // ETH is sent to contract as msg.value.
    // You can change the inputs, or the scope of your function, as needed.
    function swapETHForTokens(uint max_exchange_rate)
        external
        payable 
    {
        /******* TODO: Implement this function *******/
        /* HINTS:
            Calculate amount of your tokens should be swapped based on exchange rate.
            Transfer the amount of your tokens to the provider.
            If performing the swap would exhaus total token supply, transaction must fail.
            Update token_reserves and eth_reserves.

            Part 4: 
                Expand the function to take in addition parameters as needed.
                If current exchange_rate > slippage limit, abort the swap. 
            
            Part 5: 
                Only exchange amountTokens * (1 - %liquidity), 
                    where % is sent to liquidity providers.
                Keep track of the liquidity fees to be added.
        */
        //eth value cannot be 0
        require(msg.value>0,"ETH Value 0");

        //Liquidity Reward.
        uint eth_value = msg.value.mul(swap_fee_numerator).div(swap_fee_denominator);

        //eth value cannot be 0
        require(eth_value>0,"ETH Value 0");
        //calculate how much token will swapped.
        uint256 delta_token = token_reserves.mul(eth_value).div(eth_reserves.add(eth_value)); // (y * delta_x)/ (x + delta_x)
        // calculate minimum eth in return, based on slippage.
        uint min_token = msg.value.mul(max_exchange_rate).div(_multiplier);
        require(min_token < delta_token, "SLIPPAGE High"); 
        //check if treasury is 0.
        require(token_reserves > (delta_token),"Token_reserve 0"); 
        //update balances
        eth_reserves = eth_reserves.add(msg.value);
        token_reserves = token_reserves.sub(delta_token);
        k = eth_reserves.mul(token_reserves);
        //send token
        token.transfer(msg.sender, delta_token);


        /**************************/
        // DO NOT MODIFY BELOW THIS LINE
        /* Check for x * y == k, assuming x and y are rounded to the nearest integer. */
        // Check for Math.abs(token_reserves * eth_reserves - k) < (token_reserves + eth_reserves + 1));
        //   to account for the small decimal errors during uint division rounding.
        uint check = token_reserves.mul(eth_reserves);
        if (check >= k) {
            check = check.sub(k);
        }
        else {
            check = k.sub(check);
        }
        assert(check < (token_reserves.add(eth_reserves).add(1)));
    }

    /***  Define helper functions for swaps here as needed: ***/

}
