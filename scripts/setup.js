require("dotenv").config();
var BigNumber = require("bignumber.js");
const API_URL = process.env.API_URL;
const PUBLIC_KEY = process.env.PUBLIC_KEY;
const PRIVATE_KEY = process.env.PRIVATE_KEY;

const { createAlchemyWeb3 } = require("@alch/alchemy-web3");
const web3 = createAlchemyWeb3(API_URL);

const contract = require("../artifacts/contracts/SmartVaultUltraSlim.sol/SmartVaultUltraSlim.json");
const contractAddress = "0xCBc9453dC2403b6D351712c012e3c6569bBeeEF1";
const loadedContract = new web3.eth.Contract(contract.abi, contractAddress);

const ADDRESS_UNISWAP = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
const ADDRESS_COMPOUND = "0x5eAe89DC1C671724A672ff0630122ee834098657";

const ADDRESS_ETH = "0x0000000000000000000000000000000000000000";
const ADDRESS_CETH = "0x41B5844f4680a8C38fBb695b7F9CFd1F64474a72";

const ADDRESS_DAI = "0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa";
const ADDRESS_CDAI = "0xF0d0EB522cfa50B716B3b1604C4F0fA6f04376AD";

const ADDRESS_ETHDAILP = "0xb10cf58e08b94480fcb81d341a63295ebb2062c2";

async function transact(gasEstimate, data, val, plusNonce) {
  console.log("transacting ....");
  const nonce =
    (await web3.eth.getTransactionCount(PUBLIC_KEY, "latest")) + plusNonce; // get latest nonce
  console.log("nonce = " + nonce);
  console.log("plusNonce = " + plusNonce);

  // Create the transaction
  const tx = {
    from: PUBLIC_KEY,
    to: contractAddress,
    nonce: nonce,
    gas: gasEstimate,
    data: data,
    value: val,
  };

  // Sign the transaction
  const signPromise = web3.eth.accounts.signTransaction(tx, PRIVATE_KEY);
  signPromise
    .then((signedTx) => {
      web3.eth.sendSignedTransaction(
        signedTx.rawTransaction,
        function (err, hash) {
          if (!err) {
            console.log(
              "The hash of your transaction is: ",
              hash,
              "\n Check Alchemy's Mempool to view the status of your transaction!"
            ); //
          } else {
            console.log(
              "Something went wrong when submitting your transaction:",
              err
            );
          }
        }
      );
    })
    .catch((err) => {
      console.log("Promise failed:", err);
    });
}

async function printBalances() {
  balances = await loadedContract.methods.balances(ADDRESS_ETH).call();
  console.log("Account balance for ETH = " + balances / 10 ** 18);
  balances = await loadedContract.methods.balances(ADDRESS_CETH).call();
  console.log("Account balance for CETH = " + balances / 10 ** 18);

  balances = await loadedContract.methods.balances(ADDRESS_DAI).call();
  console.log("Account balance for DAI = " + balances / 10 ** 18);
  balances = await loadedContract.methods.balances(ADDRESS_CDAI).call();
  console.log("Account balance for DAI = " + balances / 10 ** 18);
}

async function abstractCall(call, value = 0, plusNonce = 0) {
  gasEstimate = 0;
  try {
    gasEstimate = (await call.estimateGas()) + 150000; // estimate gas
  } catch (err) {
    gasEstimate = 600001;
  }
  console.log("initializing gasEstimate = " + gasEstimate);
  transact(gasEstimate, call.encodeABI(), value, plusNonce);
}

async function main() {
  const manager = await loadedContract.methods.manager().call();
  console.log("The manager is: " + manager);
  nonce = 0;

  // Initialize the contract
  await abstractCall(
    loadedContract.methods.initialize(
      ADDRESS_UNISWAP,
      ADDRESS_COMPOUND,
      ADDRESS_CETH
    ),
    0,
    nonce
  );
  nonce = nonce + 1;

  // Deposit funds
  await abstractCall(
    loadedContract.methods.deposit(),
    web3.utils.toWei("0.05", "ether"),
    nonce
  );
  nonce = nonce + 1;
  console.log("After depositing:");
  printBalances();
  // Do a swap, ETH -> DAI
  await abstractCall(
    loadedContract.methods.swap(
      web3.utils.toWei("0.01", "ether"),
      ADDRESS_ETH,
      ADDRESS_DAI,
      0
    ),
    0,
    nonce
  );
  nonce = nonce + 1;
  console.log("After swapping:");
  printBalances();

  // approve DAI transfers to uniswap router
  await abstractCall(
    loadedContract.methods.approveToken(
      ADDRESS_UNISWAP,
      BigNumber(10 ** 28),
      ADDRESS_DAI
    ),
    0,
    nonce
  );
  nonce = nonce + 1;

  // Pool some liquidity in ETH-DAI
  await abstractCall(
    loadedContract.methods.addLiquidityPool(
      ADDRESS_ETH,
      ADDRESS_DAI,
      web3.utils.toWei("0.0001", "ether"),
      web3.utils.toWei("0.1", "ether"),
      0
    ),
    0,
    nonce
  );
  nonce = nonce + 1;
  console.log("After pooling:");
  printBalances();

  // approve ETH-DAI lp token transfers to uniswap router
  await abstractCall(
    loadedContract.methods.approveToken(
      ADDRESS_UNISWAP,
      BigNumber(10 ** 28),
      ADDRESS_ETHDAILP
    ),
    0,
    nonce
  );
  nonce = nonce + 1;

  // Test removing ETH-DAI lp from uniswap pool
  await abstractCall(
    loadedContract.methods.removeLiquidityPool(
      ADDRESS_ETH,
      ADDRESS_DAI,
      web3.utils.toWei("0.0001", "ether"),
      0
    ),
    0,
    nonce
  );
  nonce = nonce + 1;

  // Test lending ETH on compound protocol
  await abstractCall(
    loadedContract.methods.lend(
      ADDRESS_ETH,
      ADDRESS_CETH,
      web3.utils.toWei("0.01", "ether")
    ),
    0,
    nonce
  );
  nonce = nonce + 1;

  // Test borrowing DAI on compound protocol
  await abstractCall(
    loadedContract.methods.borrow(
      ADDRESS_DAI,
      ADDRESS_CDAI,
      web3.utils.toWei("0.1", "ether")
    ),
    0,
    nonce
  );
  nonce = nonce + 1;
}

main();
