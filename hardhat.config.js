require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config();


module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    sepolia: {
      url: `https://sepolia.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [process.env.PRIVATE_KEY]
    },
    mumbai: {
      url: "https://rpc-mumbai.maticvigil.com",
      accounts: [process.env.PRIVATE_KEY]
    },
    localGanache: {
      url: process.env.GANACHE_PROVIDER_URL,
      accounts: [process.env.GANACHE_PRIVATE_KEY]
    }
  },
  solidity: {
    compilers: [
      {
        version: "0.8.17"
      }
    ]
  }
};