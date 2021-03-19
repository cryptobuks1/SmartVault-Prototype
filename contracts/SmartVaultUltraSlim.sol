pragma solidity ^0.8.0;

import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ICERC20.sol";
import "./interfaces/ICETH.sol";
import "./interfaces/IComptroller.sol";

contract SmartVaultUltraSlim {
  // contract manager
  address public manager;

  // compound and uniswap objects
  IUniswapV2Router02 public uniswapRouter;
  IComptroller public comptroller;
  ICETH public cETH;

  // balances mapping
  mapping(address => uint256) public balances;

  constructor() {
    // define contract manager
    manager = msg.sender;
  }

  function initialize(address UNISWAP_ROUTER_ADDRESS, address COMPTROLLER_ADDRESS, address CETH_ADDRESS) external restricted {
    // initialize Uniswap Router, cannot be modified elsewhere
    uniswapRouter = IUniswapV2Router02(UNISWAP_ROUTER_ADDRESS);
    // initialize Compound comptroller, cannot be modified elsewhere
    comptroller = IComptroller(COMPTROLLER_ADDRESS);
    // initialize Compound ethereum, cannot be modified elsewhere
    cETH = ICETH(CETH_ADDRESS);
  }

  function deposit() external payable {
    // update balances on receipt of ETH
    balances[address(0x0)] = balances[address(0x0)] + msg.value;
    addBalance(address(0x0), msg.value);
  }

  function withdraw(address[] memory tokens, uint[] memory withdrawls, address payable account) external {
    // update balances on withdraw of token
    require(balances[address(0x1)] == 0, 'R0');
    for (uint i=0; i<tokens.length; i++) {
      require(balances[tokens[i]] >= withdrawls[i], 'R1');
      subBalance(tokens[i], withdrawls[i]);
      if (tokens[i] != address(0x0)) {
        IERC20 token_ = IERC20(tokens[i]);
        token_.approve(account, withdrawls[i]);
        token_.transfer(account, withdrawls[i]);
      } else {
        (bool sent, ) = account.call{value: withdrawls[i]}("");
      }
    }
  }

  fallback() external payable {}

  function addBalance(address token, uint amount) private {
    // add to token balance
    balances[token] = balances[token] + amount;
  }

  function subBalance(address token, uint amount) private {
    // sub from token balance
    balances[token] = balances[token] - amount;
  }

  modifier restricted() {
    // make sure it is manager calling
    require(msg.sender == manager, "Q0");
    _;
  }

  function approveToken(
    address transferAddress,
    uint transferAmount,
    address tokenAddress
  ) public restricted {
    // manager can call approve token
    IERC20(tokenAddress).approve(transferAddress, transferAmount);
  }

  function tradePath(
    address fromToken,
    address toToken
  ) private pure returns (address[] memory)  {
    // uniswap router takes trade path [tokenA, tokenB, ... tokenZ] - for now we assume are only support token path [tokenA, tokenB]
    address[] memory path = new address[](2);
    path[0] = fromToken;
    path[1] = toToken;
    return path;
  }

  function swap(
    uint tradeAmount,
    address fromToken,
    address toToken,
    uint deadline
  ) external payable restricted {
    require(balances[fromToken] >= tradeAmount, 'Q1');
    deadline = block.timestamp + 15000;
    uint[] memory amounts;
    if (fromToken == address(0x0)) {
      amounts = uniswapRouter.swapExactETHForTokens{value : tradeAmount}(0, tradePath(uniswapRouter.WETH(), toToken), address(this), deadline);
    } else if (toToken == address(0x0)) {
      amounts = uniswapRouter.swapExactTokensForETH(tradeAmount, 0, tradePath(fromToken, uniswapRouter.WETH()), address(this), deadline);
    } else {
      amounts = uniswapRouter.swapExactTokensForTokens(tradeAmount, 0, tradePath(fromToken, toToken), address(this), deadline);
    }
    subBalance(fromToken, amounts[0]);
    addBalance(toToken, amounts[1]);
  }

  function addLiquidityPool(
    address tokenA,
    address tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint deadline
  ) external restricted {
    require(balances[tokenA] >= amountADesired, 'Q2');
    require(balances[tokenB] >= amountBDesired, 'Q3');
    deadline = block.timestamp + 15000;
    uint amountA;
    uint amountB;
    uint liquidity;
    if (tokenA != address(0x0)) {
      (amountA, amountB, liquidity) = uniswapRouter.addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, 0, 0, address(this), deadline);
    } else {
      (amountA, amountB, liquidity) = uniswapRouter.addLiquidityETH{value : amountADesired}(tokenB, amountBDesired, 0, 0, address(this), deadline);
    }
    subBalance(tokenA, amountA);
    subBalance(tokenB, amountB);
    address liquidityToken = address(uint160(uint256(keccak256(abi.encodePacked(tokenA, tokenB)))));
    addBalance(liquidityToken, liquidity);
  }

  function removeLiquidityPool(
    address tokenA,
    address tokenB,
    uint liquidity,
    uint deadline
  ) external payable restricted {
    address liquidityToken = address(uint160(uint256(keccak256(abi.encodePacked(tokenA, tokenB)))));
    require(balances[liquidityToken] >= liquidity, 'Q4');
    deadline = block.timestamp + 15000;
    uint amountA;
    uint amountB;
    if (tokenA != address(0x0)) {
      (amountA, amountB) = uniswapRouter.removeLiquidity(tokenA, tokenB, liquidity, 0, 0, address(this), deadline);
    } else{
      (amountA, amountB) = uniswapRouter.removeLiquidityETH(tokenB, liquidity, 0, 0, address(this), deadline);
    }
    addBalance(tokenA, amountA);
    addBalance(tokenB, amountB);
    subBalance(liquidityToken, liquidity);
  }

  function lend(
    address token,
    address cToken,
    uint toLend
  ) external restricted {
    // Mint cTokens
    require(balances[token] >= toLend, 'Q5');
    if (token != address(0x0)) {
      ICERC20 cToken_ = ICERC20(cToken);
      uint prevBalance = cToken_.balanceOf(address(this));
      cToken_.mint(toLend);
      subBalance(token, toLend);
      addBalance(cToken, cToken_.balanceOf(address(this))-prevBalance);
    } else {
      uint prevBalance = cETH.balanceOf(address(this));
      cETH.mint{value : toLend}();
      subBalance(token, toLend);
      addBalance(cToken, cETH.balanceOf(address(this))-prevBalance);
    }
  }

  function redeem(
    address token,
    address cToken,
    uint toRedeem
  ) external restricted {
    require(balances[cToken] >= toRedeem, 'Q6');
    // TODO : Add redemption check
    if (token != address(0x0)) {
      // Redeem for underlying token
      IERC20 token_ = IERC20(token);
      uint prevBalance = token_.balanceOf(address(this));
      ICERC20(cToken).redeem(toRedeem);
      subBalance(token, toRedeem);
      addBalance(cToken, token_.balanceOf(address(this))-prevBalance);
    } else {
      // Redeem for underlying ETH
      uint prevBalance = address(this).balance;
      cETH.redeem(toRedeem);
      subBalance(address(0x0), toRedeem);
      addBalance(cToken, address(this).balance-prevBalance);
    }
  }

  function borrow(
    address token,
    address cToken,
    uint toBorrow
  ) external restricted {
    // TODO : Add collateral check (?), no rather do offline~
    address debtToken = address(uint160(uint256(keccak256(abi.encodePacked(token, address(0x1))))));
    if (token != address(0x0)) {
      // Borrow token
      ICERC20(cToken).borrow(toBorrow);
      addBalance(debtToken, toBorrow);
      addBalance(address(0x1), toBorrow);
    } else {
      cETH.borrow(toBorrow);
      addBalance(debtToken, toBorrow);
      addBalance(address(0x1), toBorrow);
    }
  }

  function repay(
    address token,
    address cToken,
    uint toRepay
  ) external restricted {
    address debtToken = address(uint160(uint256(keccak256(abi.encodePacked(token, address(0x1))))));
    require(balances[debtToken] >= toRepay, 'Q7');
    if (token != address(0x0)) {
      // Borrow token
      ICERC20(cToken).repayBorrow(toRepay);
      subBalance(debtToken, toRepay);
      subBalance(address(0x1), toRepay);
   } else {
      cETH.repayBorrow(toRepay);
      subBalance(debtToken, toRepay);
      subBalance(address(0x1), toRepay);
    }
  }
}
