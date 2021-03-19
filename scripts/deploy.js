// scripts/deploy.js
async function main() {
  // We get the contract to deploy
  const SmartVault = await ethers.getContractFactory("SmartVaultUltraSlim");
  console.log("Deploying SmartVault...");
  const sv = await SmartVault.deploy();
  await sv.deployed();
  console.log("Smartvault deployed to:", sv.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
