require("dotenv").config();
var BigNumber = require("bignumber.js");
const API_URL = process.env.API_URL;
const PUBLIC_KEY = process.env.PUBLIC_KEY;
const PRIVATE_KEY = process.env.PRIVATE_KEY;

console.log(API_URL);
const { createAlchemyWeb3 } = require("@alch/alchemy-web3");
const web3 = createAlchemyWeb3(API_URL);

const contract = require("../artifacts/contracts/SmartVaultUltraSlim.sol/SmartVaultUltraSlim.json");
console.log(JSON.stringify(contract.abi));
const contractAddress = "0xEf68247c2b4EBE9fa8fe4b517991aaC6D4645e73";
const loadedContract = new web3.eth.Contract(contract.abi, contractAddress);

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
  await abstractCall(
    loadedContract.methods.initialize(
      "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
      "0x5eAe89DC1C671724A672ff0630122ee834098657",
      "0x41B5844f4680a8C38fBb695b7F9CFd1F64474a72"
    ),
    0,
    nonce
  );
  nonce = nonce + 1;
  await abstractCall(
    loadedContract.methods.addToken(
      "DAI",
      "0x4f96fe3b7a6cf9725f59d353f723c1bdb64ca6aa",
      false
    ),
    0,
    nonce
  );
  nonce = nonce + 1;
  /*await abstractCall(
    loadedContract.methods.addToken(
      "MKR",
      "0xAaF64BFCC32d0F15873a02163e7E500671a4ffcD"
    ),
    0,
    nonce
  );
  nonce = nonce + 1;*/
  await abstractCall(
    loadedContract.methods.deposit(),
    web3.utils.toWei("0.02", "ether"),
    nonce
  );
  nonce = nonce + 1;
  await abstractCall(
    loadedContract.methods.swap(
      web3.utils.toWei("0.01", "ether"),
      "ETH",
      "DAI",
      0
    ),
    0,
    nonce
  );
  nonce = nonce + 1;
  await abstractCall(
    loadedContract.methods.addLiquidityPool(
      "ETH",
      "DAI",
      web3.utils.toWei("0.0005", "ether"),
      web3.utils.toWei("0.005", "ether"),
      0,
      0,
      0
    ),
    0,
    nonce
  );
  nonce = nonce + 1;
  await abstractCall(
    loadedContract.methods.addToken(
      "ETH-DAI",
      "0xb10cf58e08b94480fcb81d341a63295ebb2062c2",
      false
    ),
    0,
    nonce
  );
  nonce = nonce + 1;
  await abstractCall(
    loadedContract.methods.addToken(
      "CDAI",
      "0xF0d0EB522cfa50B716B3b1604C4F0fA6f04376AD",
      true
    ),
    0,
    nonce
  );
  nonce = nonce + 1;
  await abstractCall(
    loadedContract.methods.approveToken(
      "0xF0d0EB522cfa50B716B3b1604C4F0fA6f04376AD",
      BigNumber(10 ** 24),
      "DAI"
    ),
    0,
    nonce
  );
  nonce = nonce + 1;
  await abstractCall(
    loadedContract.methods.lend(
      "DAI",
      "CDAI",
      web3.utils.toWei("0.1", "ether")
    ),
    0,
    nonce
  );
  nonce = nonce + 1;
  await abstractCall(
    loadedContract.methods.borrow(
      "ETH",
      "ETH",
      web3.utils.toWei("0.001", "ether")
    ),
    0,
    nonce
  );
  nonce = nonce + 1;
}

main();
