pragma solidity ^0.8.0;

import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ICERC20.sol";
import "./interfaces/ICETH.sol";
import "./interfaces/IComptroller.sol";

contract SmartVaultUltraSlim {
  // contract manager
  address public immutable manager;

  // compound and uniswap objects
  IUniswapV2Router02 public uniswapRouter;
  IComptroller public comptroller;
  ICETH public cETH;

  // token utility mappings
  mapping(string => address) public tokenAddresses;
  mapping(string => IERC20) public tokenMap;
  mapping(string => ICERC20) public cTokenMap;

  // balances mapping
  mapping(string => uint256) public balances;

  // ethereum string, used to save on compilation
  string public symbolETH = "ETH";

  constructor() {
    // define contract manager
    manager = msg.sender;
  }

  function initialize(address UNISWAP_ROUTER_ADDRESS, address COMPTROLLER_ADDRESS, address CETH_ADDRESS) external restricted {
    // initialize Uniswap Router
    uniswapRouter = IUniswapV2Router02(UNISWAP_ROUTER_ADDRESS);
    // initialize Compound comptroller
    comptroller = IComptroller(COMPTROLLER_ADDRESS);
    // initialize Compound ethereum
    cETH = ICETH(CETH_ADDRESS);
  }

  function deposit() external payable {
    // update balances on receipt of ETH
    balances[symbolETH] = balances[symbolETH] + msg.value;
  }

  fallback() external payable {}

  function addBalance(string memory token, uint amount) private {
    // add to token balance
    balances[token] = balances[token] + amount;
  }

  function subtractBalance(string memory token, uint amount) private {
    // subtract from token balance
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
    string memory tokenName
  ) public restricted {
    // manager can call approve token
    IERC20 token = tokenMap[tokenName];
    token.approve(transferAddress, transferAmount);
  }

  function addToken(
    string memory token,
    address tokenAddress,
    bool isCToken
  ) external restricted {
    tokenAddresses[token] = tokenAddress;
    if (isCToken){
      cTokenMap[token] = ICERC20(tokenAddress);
    } else {
      tokenMap[token] = IERC20(tokenAddress);
      approveToken(address(uniswapRouter), 2**256 - 1, token);
    }
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
    string memory fromToken,
    string memory toToken,
    uint deadline
  ) external payable restricted {
    require(balances[fromToken] >= tradeAmount, 'Q1');
    uint[] memory amounts;
    if (tokenAddresses[fromToken] == tokenAddresses[symbolETH]) {
      amounts = uniswapRouter.swapExactETHForTokens{value : tradeAmount}(0, tradePath(uniswapRouter.WETH(), tokenAddresses[toToken]), address(this), block.timestamp + 15000);
    } else if (tokenAddresses[toToken] == tokenAddresses[symbolETH]) {
      amounts = uniswapRouter.swapExactTokensForETH(tradeAmount, 0, tradePath(tokenAddresses[fromToken], uniswapRouter.WETH()), address(this), deadline);
    } else {
      amounts = uniswapRouter.swapExactTokensForTokens(tradeAmount, 0, tradePath(tokenAddresses[fromToken], tokenAddresses[toToken]), address(this), deadline);
    }
    subtractBalance(fromToken, amounts[0]);
    addBalance(toToken, amounts[1]);
  }

  function addLiquidityPool(
    string memory tokenA,
    string memory tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin,
    uint deadline
  ) external restricted {
    require(balances[tokenA] >= amountADesired, 'Q2');
    require(balances[tokenB] >= amountBDesired, 'Q3');
    deadline = block.timestamp + 15000;
    uint amountA;
    uint amountB;
    uint liquidity;
    if (tokenAddresses[tokenA] != tokenAddresses[symbolETH]) {
      (amountA, amountB, liquidity) = uniswapRouter.addLiquidity(tokenAddresses[tokenA], tokenAddresses[tokenB], amountADesired, amountBDesired, amountAMin, amountBMin, address(this), deadline);
    } else {
      (amountA, amountB, liquidity) = uniswapRouter.addLiquidityETH{value : amountADesired}(tokenAddresses[tokenB], amountBDesired, amountBMin, amountAMin, address(this), deadline);
    }
    string memory liquidityToken = string(abi.encodePacked(tokenA, '-', tokenB));
    subtractBalance(tokenA, amountA);
    subtractBalance(tokenB, amountB);
    addBalance(liquidityToken, liquidity);
  }

  function removeLiquidityPool(
    string memory tokenA,
    string memory tokenB,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    uint deadline
  ) external restricted {
    string memory liquidityToken = string(abi.encodePacked(tokenA, '-', tokenB));
    require(balances[liquidityToken] >= liquidity, 'Q4');
    deadline = block.timestamp + 15000;
    uint amountA;
    uint amountB;
    if (tokenAddresses[tokenA] != tokenAddresses[symbolETH]) {
      (amountA, amountB) = uniswapRouter.removeLiquidity(tokenAddresses[tokenA], tokenAddresses[tokenB], liquidity, amountAMin, amountBMin, address(this), deadline);
    } else{
      (amountA, amountB) = uniswapRouter.removeLiquidityETH(tokenAddresses[tokenB], liquidity, amountBMin, amountAMin, address(this), deadline);
    }
    addBalance(tokenA, amountA);
    addBalance(tokenB, amountB);
    subtractBalance(liquidityToken, liquidity);
  }

  function lend(
    string memory tokenName,
    string memory cTokenName,
    uint toLend
  ) external restricted {
    // Mint cTokens
    require(balances[tokenName] >= toLend, 'Q5');
    if (tokenAddresses[tokenName] != tokenAddresses[symbolETH]) {
      ICERC20 cToken = cTokenMap[cTokenName];
      uint prevBalance = cToken.balanceOf(address(this));
      uint mintResult = cToken.mint(toLend);
      uint currBalance = cToken.balanceOf(address(this));
      (uint256 error2, uint256 liquidity, uint256 shortfall) = comptroller.getAccountLiquidity(address(this));
    } else {
      uint prevBalance = cETH.balanceOf(address(this));
      cETH.mint{value : toLend}();
      uint currBalance = cETH.balanceOf(address(this));
      (uint256 error2, uint256 liquidity, uint256 shortfall) = comptroller.getAccountLiquidity(address(this));
    }
  }

  function borrow(
    string memory tokenName,
    string memory cTokenName,
    uint toBorrow
  ) external {
    // TODO : Add collateral check
    if (tokenAddresses[tokenName] != tokenAddresses[symbolETH]) {
      ICERC20 cToken = cTokenMap[cTokenName];
      // Borrow token
      uint prevBalance = tokenMap[tokenName].balanceOf(address(this));
      cToken.borrow(toBorrow);
      uint currBalance = tokenMap[tokenName].balanceOf(address(this));
    } else {
      uint prevBalance = address(this).balance;
      cETH.borrow(toBorrow);
      uint currBalance = address(this).balance;
    }
  }

  function redeem(
    string memory tokenName,
    string memory cTokenName,
    uint toRedeem
  ) external {
    // TODO : Add redemption check
    if (tokenAddresses[tokenName] != tokenAddresses[symbolETH]) {
      ICERC20 cToken = cTokenMap[cTokenName];
      // Redeem for underlying token
      uint prevBalance = tokenMap[tokenName].balanceOf(address(this));
      cToken.redeem(toRedeem);
      uint currBalance = tokenMap[tokenName].balanceOf(address(this));
    } else {
      // Redeem for underlying ETH
      uint prevBalance = address(this).balance;
      cETH.redeem(toRedeem);
      uint currBalance = address(this).balance;
    }
  }
}
