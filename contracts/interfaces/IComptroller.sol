pragma solidity ^0.8.0;
interface IComptroller {
    function markets(address) external returns (bool, uint);
    function enterMarkets(address[] calldata) external returns (uint[] memory);
    function getAccountLiquidity(address) external view returns (uint, uint, uint);
}
